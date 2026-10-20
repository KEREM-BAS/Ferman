//! The tile queue: each view's wanted set, and the order the render thread works through them
//! (docs/ARCHITECTURE.md §4.5, ADR 0009).
//!
//! - **Wanted sets.** A request replaces the view's wanted set and carries a generation; a request
//!   with an older generation than the view's newest is ignored. Queued items that are no longer
//!   wanted are dropped before rendering.
//! - **Order.** Priority class first, then the order the view listed the item, then the view. Views
//!   with work in the same class take turns, so three views requesting at once all progress.
//! - **Delivery.** A finished bitmap goes to every view of its document that still wants it, with
//!   that view's newest generation, so a tile two views share is rendered once. A view that no
//!   longer wants it does not get it; the cache keeps it.

use std::collections::BTreeMap;

use crate::thread::{DocumentId, ViewId};
use crate::tiles::{Item, Priority, ViewEvent, ViewSink, Wanted};

/// One queued item of a view.
#[derive(Debug, Clone, Copy)]
struct Pending {
    item: Item,
    priority: Priority,
    /// Its place in the request, which orders items of one class.
    rank: usize,
}

/// A view: whose pages it shows, its newest wanted set, and where its events go.
struct View {
    document: DocumentId,
    generation: u64,
    /// Sorted by priority class, then rank.
    pending: Vec<Pending>,
    sink: Box<dyn ViewSink>,
}

/// Every open view and its pending items.
#[derive(Default)]
pub(crate) struct Queue {
    views: BTreeMap<ViewId, View>,
}

impl std::fmt::Debug for Queue {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Queue")
            .field("views", &self.views.len())
            .field("pending", &self.pending())
            .finish()
    }
}

impl Queue {
    /// Adds a view of `document` with an empty wanted set.
    pub(crate) fn open(&mut self, view: ViewId, document: DocumentId, sink: Box<dyn ViewSink>) {
        self.views.insert(
            view,
            View {
                document,
                generation: 0,
                pending: Vec::new(),
                sink,
            },
        );
    }

    /// Removes a view; its sink is dropped, which ends its stream.
    pub(crate) fn close(&mut self, view: ViewId) {
        self.views.remove(&view);
    }

    /// Removes every view of `document`.
    pub(crate) fn close_document(&mut self, document: DocumentId) {
        self.views.retain(|_, view| view.document != document);
    }

    /// The document `view` shows, if it is open.
    pub(crate) fn document(&self, view: ViewId) -> Option<DocumentId> {
        self.views.get(&view).map(|view| view.document)
    }

    /// Whether `generation` is newer than the newest wanted set of `view`, so a request with it
    /// replaces that set. False for a view that is not open.
    pub(crate) fn is_newer(&self, view: ViewId, generation: u64) -> bool {
        self.views
            .get(&view)
            .is_some_and(|view| generation > view.generation)
    }

    /// Replaces the wanted set of `view` with `wanted`, in its order, and records `generation`. A
    /// repeated item keeps its first place. Callers check [`Queue::is_newer`] first.
    pub(crate) fn replace(&mut self, view: ViewId, generation: u64, wanted: &[Wanted]) {
        let Some(view) = self.views.get_mut(&view) else {
            return;
        };
        let mut pending: Vec<Pending> = Vec::with_capacity(wanted.len());
        for (rank, entry) in wanted.iter().enumerate() {
            if !pending.iter().any(|queued| queued.item == entry.item) {
                pending.push(Pending {
                    item: entry.item,
                    priority: entry.priority,
                    rank,
                });
            }
        }
        // Stable, so the view's order holds inside each class.
        pending.sort_by_key(|queued| queued.priority);
        view.generation = generation;
        view.pending = pending;
    }

    /// Whether any view has an item to render.
    pub(crate) fn has_work(&self) -> bool {
        self.views.values().any(|view| !view.pending.is_empty())
    }

    /// The number of queued items over all views.
    pub(crate) fn pending(&self) -> usize {
        self.views.values().map(|view| view.pending.len()).sum()
    }

    /// The next item to render and its document: the first pending item of each view, compared by
    /// class, then rank, then view.
    pub(crate) fn next(&self) -> Option<(DocumentId, Item)> {
        self.views
            .iter()
            .filter_map(|(id, view)| {
                let first = view.pending.first()?;
                Some((
                    (first.priority, first.rank, *id),
                    (view.document, first.item),
                ))
            })
            .min_by_key(|(order, _)| *order)
            .map(|(_, next)| next)
    }

    /// Takes `item` out of every view of `document` that wants it and delivers what `event` makes
    /// for that view's generation. A view whose receiver is gone is closed. Returns how many views
    /// got it.
    pub(crate) fn deliver(
        &mut self,
        document: DocumentId,
        item: &Item,
        mut event: impl FnMut(u64) -> ViewEvent,
    ) -> usize {
        let mut delivered = 0;
        let mut gone = Vec::new();
        for (id, view) in &mut self.views {
            if view.document != document {
                continue;
            }
            let Some(index) = view.pending.iter().position(|queued| queued.item == *item) else {
                continue;
            };
            view.pending.remove(index);
            if view.sink.deliver(event(view.generation)) {
                delivered += 1;
            } else {
                gone.push(*id);
            }
        }
        for id in gone {
            self.views.remove(&id);
        }
        delivered
    }

    /// Delivers `event` to `view` outside any item, such as a request it could not take. A view
    /// whose receiver is gone is closed.
    pub(crate) fn send(&mut self, view: ViewId, event: ViewEvent) {
        if let Some(open) = self.views.get_mut(&view)
            && !open.sink.deliver(event)
        {
            self.views.remove(&view);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tiles::{FailReason, Failed, ThumbnailRequest};
    use crossbeam_channel::{Receiver, unbounded};

    fn thumbnail(page: u32) -> Item {
        Item::Thumbnail(ThumbnailRequest { page, size: 100 })
    }

    fn want(page: u32, priority: Priority) -> Wanted {
        Wanted {
            item: thumbnail(page),
            priority,
        }
    }

    fn failed(item: Item) -> impl FnMut(u64) -> ViewEvent {
        move |generation| {
            ViewEvent::Failed(Failed {
                item,
                generation,
                reason: FailReason::Internal,
            })
        }
    }

    fn view(queue: &mut Queue, id: u64, document: u64) -> Receiver<ViewEvent> {
        let (sender, receiver) = unbounded();
        queue.open(ViewId(id), DocumentId(document), Box::new(sender));
        receiver
    }

    /// Takes every item in queue order, failing each, and returns their pages.
    fn drain(queue: &mut Queue) -> Vec<u32> {
        let mut pages = Vec::new();
        while let Some((document, item)) = queue.next() {
            pages.push(item.page());
            queue.deliver(document, &item, failed(item));
        }
        pages
    }

    #[test]
    fn classes_come_first_then_the_views_order() {
        let mut queue = Queue::default();
        let _events = view(&mut queue, 1, 1);
        queue.replace(
            ViewId(1),
            1,
            &[
                want(10, Priority::Thumbnail),
                want(1, Priority::Visible),
                want(20, Priority::Background),
                want(2, Priority::Visible),
                want(5, Priority::Prefetch),
            ],
        );
        assert_eq!(drain(&mut queue), [1, 2, 5, 10, 20]);
    }

    #[test]
    fn views_take_turns_within_a_class() {
        let mut queue = Queue::default();
        let _a = view(&mut queue, 1, 1);
        let _b = view(&mut queue, 2, 2);
        let _c = view(&mut queue, 3, 3);
        for id in 1..=3 {
            let base = u32::try_from(id).unwrap() * 100;
            queue.replace(
                ViewId(id),
                1,
                &[
                    want(base, Priority::Visible),
                    want(base + 1, Priority::Visible),
                ],
            );
        }
        assert_eq!(drain(&mut queue), [100, 200, 300, 101, 201, 301]);
    }

    #[test]
    fn a_new_set_replaces_the_old_one() {
        let mut queue = Queue::default();
        let _events = view(&mut queue, 1, 1);
        queue.replace(
            ViewId(1),
            1,
            &[want(1, Priority::Visible), want(2, Priority::Visible)],
        );
        assert!(queue.is_newer(ViewId(1), 2));
        assert!(!queue.is_newer(ViewId(1), 1));
        queue.replace(ViewId(1), 2, &[want(3, Priority::Visible)]);
        assert_eq!(drain(&mut queue), [3]);
        assert!(!queue.is_newer(ViewId(9), 5));
    }

    #[test]
    fn one_rendering_serves_every_view_that_wants_it() {
        let mut queue = Queue::default();
        let a = view(&mut queue, 1, 7);
        let b = view(&mut queue, 2, 7);
        let other = view(&mut queue, 3, 8);
        queue.replace(ViewId(1), 4, &[want(1, Priority::Visible)]);
        queue.replace(ViewId(2), 9, &[want(1, Priority::Thumbnail)]);
        queue.replace(ViewId(3), 1, &[want(1, Priority::Visible)]);
        let item = thumbnail(1);
        assert_eq!(queue.deliver(DocumentId(7), &item, failed(item)), 2);
        let generation = |event: ViewEvent| match event {
            ViewEvent::Failed(failed) => failed.generation,
            ViewEvent::Rendered(rendered) => rendered.generation,
        };
        assert_eq!(generation(a.try_recv().unwrap()), 4);
        assert_eq!(generation(b.try_recv().unwrap()), 9);
        assert!(other.try_recv().is_err());
        assert_eq!(queue.pending(), 1);
    }

    #[test]
    fn repeated_items_keep_their_first_place() {
        let mut queue = Queue::default();
        let _events = view(&mut queue, 1, 1);
        queue.replace(
            ViewId(1),
            1,
            &[
                want(1, Priority::Prefetch),
                want(2, Priority::Visible),
                want(1, Priority::Visible),
            ],
        );
        assert_eq!(queue.pending(), 2);
        assert_eq!(drain(&mut queue), [2, 1]);
    }

    #[test]
    fn a_view_whose_receiver_is_gone_closes() {
        let mut queue = Queue::default();
        let events = view(&mut queue, 1, 1);
        queue.replace(
            ViewId(1),
            1,
            &[want(1, Priority::Visible), want(2, Priority::Visible)],
        );
        drop(events);
        let item = thumbnail(1);
        assert_eq!(queue.deliver(DocumentId(1), &item, failed(item)), 0);
        assert_eq!(queue.document(ViewId(1)), None);
        assert!(!queue.has_work());
    }

    #[test]
    fn closing_a_document_closes_its_views() {
        let mut queue = Queue::default();
        let _a = view(&mut queue, 1, 1);
        let _b = view(&mut queue, 2, 2);
        queue.close_document(DocumentId(1));
        assert_eq!(queue.document(ViewId(1)), None);
        assert_eq!(queue.document(ViewId(2)), Some(DocumentId(2)));
    }
}
