//! Running an API future from synchronous code.

use std::future::Future;
use std::sync::Arc;
use std::task::{Context, Poll, Wake, Waker};
use std::thread::{self, Thread};

/// Runs `future` to completion on the current thread and returns its output.
///
/// For synchronous callers of the facade: ferman-cli and tests. The thread sleeps until the engine
/// wakes it (a render-thread reply, for example), so waiting costs no CPU. Never call it from an
/// async function, and never from an FRB worker: it blocks the calling thread.
pub fn block_on<F: Future>(future: F) -> F::Output {
    let waker = Waker::from(Arc::new(ThreadWaker(thread::current())));
    let mut cx = Context::from_waker(&waker);
    // `Box::pin`, not `std::pin::pin!`, which flutter_rust_bridge codegen cannot parse (see
    // `guard_async`).
    let mut future = Box::pin(future);
    loop {
        if let Poll::Ready(output) = future.as_mut().poll(&mut cx) {
            return output;
        }
        // A wake that arrives before the park makes the park return at once, so none is lost;
        // a spurious return just polls again.
        thread::park();
    }
}

/// Wakes the thread that is blocked in [`block_on`].
struct ThreadWaker(Thread);

impl Wake for ThreadWaker {
    fn wake(self: Arc<Self>) {
        self.0.unpark();
    }

    fn wake_by_ref(self: &Arc<Self>) {
        self.0.unpark();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::mpsc;
    use std::time::Duration;

    #[test]
    fn a_ready_future_returns_at_once() {
        assert_eq!(block_on(async { 7 }), 7);
    }

    #[test]
    fn a_future_woken_from_another_thread_completes() {
        // A future that is pending until another thread sends a value and wakes it.
        struct Pending {
            values: mpsc::Receiver<u32>,
            wakers: mpsc::Sender<Waker>,
        }
        impl Future for Pending {
            type Output = u32;
            fn poll(self: std::pin::Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<u32> {
                match self.values.try_recv() {
                    Ok(value) => Poll::Ready(value),
                    Err(_) => {
                        self.wakers.send(cx.waker().clone()).unwrap();
                        Poll::Pending
                    }
                }
            }
        }
        let (value_tx, values) = mpsc::channel();
        let (wakers, waker_rx) = mpsc::channel::<Waker>();
        let helper = thread::spawn(move || {
            let waker = waker_rx.recv().unwrap();
            thread::sleep(Duration::from_millis(10));
            value_tx.send(42).unwrap();
            waker.wake();
        });
        assert_eq!(block_on(Pending { values, wakers }), 42);
        helper.join().unwrap();
    }
}
