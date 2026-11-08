//! The host the running app starts for AI clients (ADR 0019, M4 plan question 1a): it listens on
//! a local socket only, never on a network address, and only while the app's switch is on.
//!
//! Its folder, `mcp` in the app data directory, holds what `ferman-mcp` needs to connect:
//!
//! - `token`: 64 hex digits, new each time the host starts, readable by the user alone. A
//!   connection's first 65 bytes must be the token and a newline, or it is closed.
//! - On macOS and Linux, `socket`: a Unix domain socket, in a folder only the user can open
//!   (0700), itself 0600.
//! - On Windows, `pipe`: the name of a named pipe with a random part, which refuses remote
//!   callers.

use std::fs;
use std::io::Write as _;
use std::path::{Path, PathBuf};
use std::sync::{Arc, PoisonError};
use std::thread::JoinHandle;

use futures_channel::oneshot;
use tokio::io::{AsyncRead, AsyncReadExt as _, AsyncWrite};

use crate::facade::engine::Engine;
use crate::facade::error::{ApiError, ErrorKind, MessageKey};

/// The host's folder in the app data directory.
const FOLDER: &str = "mcp";
/// The token's file in the folder.
const TOKEN: &str = "token";
/// The token's length in hex digits.
const TOKEN_LEN: usize = 64;

/// A running host. Dropping it stops it: the listener closes, every connection ends (its client
/// disconnects and its open transactions roll back) and its files go.
pub(in crate::facade) struct Host {
    stop: Option<oneshot::Sender<()>>,
    thread: Option<JoinHandle<()>>,
    folder: PathBuf,
}

impl std::fmt::Debug for Host {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Host").finish_non_exhaustive()
    }
}

impl Drop for Host {
    fn drop(&mut self) {
        if let Some(stop) = self.stop.take() {
            let _ = stop.send(());
        }
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
        for file in [TOKEN, ENDPOINT] {
            let _ = fs::remove_file(self.folder.join(file));
        }
    }
}

fn io(err: &std::io::Error) -> ApiError {
    ApiError::new(ErrorKind::Io, MessageKey::INTERNAL).with_details(err.kind().to_string())
}

/// A new token: 32 random bytes in hex.
fn new_token() -> Result<String, ApiError> {
    let mut bytes = [0_u8; TOKEN_LEN / 2];
    getrandom::fill(&mut bytes).map_err(|_| ApiError::internal("no random numbers"))?;
    Ok(bytes.iter().map(|byte| format!("{byte:02x}")).collect())
}

/// Writes `contents` to `path`, readable by the user alone, through a temporary file and a
/// rename so `ferman-mcp` never reads half of it.
fn write_private(path: &Path, contents: &str) -> Result<(), ApiError> {
    let temporary = path.with_extension("new");
    let _ = fs::remove_file(&temporary);
    let mut options = fs::OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    std::os::unix::fs::OpenOptionsExt::mode(&mut options, 0o600);
    let mut file = options.open(&temporary).map_err(|err| io(&err))?;
    file.write_all(contents.as_bytes())
        .and_then(|()| file.sync_all())
        .map_err(|err| io(&err))?;
    drop(file);
    fs::rename(&temporary, path).map_err(|err| io(&err))
}

/// Whether `a` and `b` are equal, in a time that does not depend on where they differ.
fn same(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).fold(0, |diff, (x, y)| diff | (x ^ y)) == 0
}

/// Serves one accepted connection once it gives the token.
async fn accept<S>(engine: &'static Engine, token: Arc<String>, mut stream: S)
where
    S: AsyncRead + AsyncWrite + Send + Unpin + 'static,
{
    let mut first = [0_u8; TOKEN_LEN + 1];
    let proved = stream.read_exact(&mut first).await.is_ok()
        && first.last() == Some(&b'\n')
        && same(first.get(..TOKEN_LEN).unwrap_or_default(), token.as_bytes());
    if !proved {
        tracing::warn!("an MCP connection without the token was closed");
        return;
    }
    if let Err(err) = super::serve(engine, stream).await {
        tracing::warn!(kind = %err.kind, "an MCP connection failed");
    }
}

#[cfg(unix)]
const ENDPOINT: &str = "socket";
#[cfg(windows)]
const ENDPOINT: &str = "pipe";

#[cfg(unix)]
type Listener = tokio::net::UnixListener;

/// Binds the socket in `folder`, refusing when another app serves it.
#[cfg(unix)]
fn listen(folder: &Path) -> Result<Listener, ApiError> {
    use std::os::unix::fs::PermissionsExt as _;
    let path = folder.join(ENDPOINT);
    if std::os::unix::net::UnixStream::connect(&path).is_ok() {
        return Err(ApiError::new(ErrorKind::FileLocked, MessageKey::INTERNAL)
            .with_details("another Ferman serves AI clients"));
    }
    let _ = fs::remove_file(&path);
    // shortcut: macOS limits a socket's path to 103 bytes, which a long home folder under the
    // sandbox's container can pass (the bind then fails as Io); bind a shorter path in the
    // container's tmp if a user meets it.
    let listener = std::os::unix::net::UnixListener::bind(&path).map_err(|err| io(&err))?;
    fs::set_permissions(&path, fs::Permissions::from_mode(0o600)).map_err(|err| io(&err))?;
    listener.set_nonblocking(true).map_err(|err| io(&err))?;
    Listener::from_std(listener).map_err(|err| io(&err))
}

#[cfg(unix)]
async fn serve_all(engine: &'static Engine, token: Arc<String>, listener: Listener) {
    while let Ok((stream, _)) = listener.accept().await {
        tokio::spawn(accept(engine, Arc::clone(&token), stream));
    }
}

#[cfg(windows)]
struct Listener {
    name: String,
    first: tokio::net::windows::named_pipe::NamedPipeServer,
}

/// Creates the pipe, under a name with a random part that `folder`'s `pipe` file gives.
#[cfg(windows)]
fn listen(folder: &Path) -> Result<Listener, ApiError> {
    let name = format!(
        r"\\.\pipe\ferman-mcp-{}",
        new_token()?.get(..16).unwrap_or_default()
    );
    let first = tokio::net::windows::named_pipe::ServerOptions::new()
        .first_pipe_instance(true)
        .reject_remote_clients(true)
        .create(&name)
        .map_err(|err| io(&err))?;
    write_private(&folder.join(ENDPOINT), &name)?;
    Ok(Listener { name, first })
}

#[cfg(windows)]
async fn serve_all(engine: &'static Engine, token: Arc<String>, listener: Listener) {
    use tokio::net::windows::named_pipe::ServerOptions;
    let Listener { name, first } = listener;
    let mut server = first;
    loop {
        if server.connect().await.is_err() {
            return;
        }
        let Ok(next) = ServerOptions::new()
            .reject_remote_clients(true)
            .create(&name)
        else {
            return;
        };
        let connected = std::mem::replace(&mut server, next);
        tokio::spawn(accept(engine, Arc::clone(&token), connected));
    }
}

impl Host {
    /// Starts the host in `app_data`'s `mcp` folder, on a thread of its own.
    pub(in crate::facade) fn start(
        engine: &'static Engine,
        app_data: &Path,
    ) -> Result<Self, ApiError> {
        let folder = app_data.join(FOLDER);
        let mut builder = fs::DirBuilder::new();
        builder.recursive(true);
        #[cfg(unix)]
        std::os::unix::fs::DirBuilderExt::mode(&mut builder, 0o700);
        builder.create(&folder).map_err(|err| io(&err))?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt as _;
            fs::set_permissions(&folder, fs::Permissions::from_mode(0o700))
                .map_err(|err| io(&err))?;
        }
        // rmcp's connections need the timers too.
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|err| io(&err))?;
        let listener = {
            let _entered = runtime.enter();
            listen(&folder)?
        };
        let token = Arc::new(new_token()?);
        write_private(&folder.join(TOKEN), &token)?;
        let (stop, stopped) = oneshot::channel::<()>();
        let thread = std::thread::Builder::new()
            .name("ferman-mcp-host".to_owned())
            .spawn(move || {
                runtime.block_on(async move {
                    tokio::spawn(serve_all(engine, token, listener));
                    let _ = stopped.await;
                });
                // Dropping the runtime drops every connection's task.
                drop(runtime);
            })
            .map_err(|err| io(&err))?;
        Ok(Self {
            stop: Some(stop),
            thread: Some(thread),
            folder,
        })
    }

    /// The folder `ferman-mcp` takes.
    pub(in crate::facade) fn folder(&self) -> &Path {
        &self.folder
    }
}

impl Engine {
    /// Starts the host for AI clients in `app_data`'s `mcp` folder, in place of the one before,
    /// and returns the folder, which `ferman-mcp` takes as its argument.
    ///
    /// # Errors
    ///
    /// `Io` when the folder, socket, pipe or token cannot be made, and `FileLocked` when another
    /// Ferman serves the folder.
    pub fn start_mcp_host(&'static self, app_data: PathBuf) -> Result<PathBuf, ApiError> {
        let mut host = self.mcp_host.lock().unwrap_or_else(PoisonError::into_inner);
        // The old host goes first: it holds the socket.
        drop(host.take());
        let started = Host::start(self, &app_data)?;
        let folder = started.folder().to_path_buf();
        *host = Some(started);
        Ok(folder)
    }

    /// Stops the host: every client disconnects and its open transactions roll back. Nothing
    /// happens when it is not running.
    pub fn stop_mcp_host(&self) {
        let host = self
            .mcp_host
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .take();
        drop(host);
    }
}
