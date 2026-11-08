//! `ferman-mcp`, the process an AI client such as Claude Desktop starts for Ferman (ADR 0019, M4
//! plan question 1b). It holds no PDF code: it connects the client's standard input and output
//! to the running app's host, a Unix domain socket on macOS and Linux and a named pipe on Windows,
//! after the host's token, and moves bytes both ways until either side closes.
//!
//! Usage: `ferman-mcp <folder>`, the host's folder that Ferman's Settings gives (the `mcp`
//! folder in the app data directory). When Ferman is not running, or its switch for AI clients
//! is off, it says so on standard error and exits with status 1; a wrong usage exits with 2.
#![forbid(unsafe_code)]

use std::io::Write as _;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use tokio::io::{AsyncRead, AsyncWrite, AsyncWriteExt as _};

/// What the user reads when the app cannot be reached.
const NOT_RUNNING: &str = "Ferman is not running, or AI clients are turned off. Open Ferman and \
                           turn on AI clients in Settings, then try again.";

fn main() -> ExitCode {
    let mut args = std::env::args_os().skip(1);
    let (Some(folder), None) = (args.next(), args.next()) else {
        say("usage: ferman-mcp <folder>");
        return ExitCode::from(2);
    };
    let runtime = match tokio::runtime::Builder::new_current_thread()
        .enable_io()
        .build()
    {
        Ok(runtime) => runtime,
        Err(err) => {
            say(&format!("ferman-mcp: {err}"));
            return ExitCode::FAILURE;
        }
    };
    let code = runtime.block_on(run(PathBuf::from(folder)));
    // Standard input's reader may still wait on a blocking thread; do not wait for it.
    runtime.shutdown_background();
    code
}

fn say(line: &str) {
    let _ = writeln!(std::io::stderr(), "{line}");
}

async fn run(folder: PathBuf) -> ExitCode {
    let Ok(token) = std::fs::read_to_string(folder.join("token")) else {
        say(NOT_RUNNING);
        return ExitCode::FAILURE;
    };
    let Ok(stream) = connect(&folder).await else {
        say(NOT_RUNNING);
        return ExitCode::FAILURE;
    };
    match pump(stream, token.trim()).await {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            say(&format!(
                "ferman-mcp: the connection to Ferman ended: {err}"
            ));
            ExitCode::FAILURE
        }
    }
}

#[cfg(unix)]
async fn connect(folder: &Path) -> std::io::Result<tokio::net::UnixStream> {
    tokio::net::UnixStream::connect(folder.join("socket")).await
}

#[cfg(windows)]
async fn connect(
    folder: &Path,
) -> std::io::Result<tokio::net::windows::named_pipe::NamedPipeClient> {
    let name = std::fs::read_to_string(folder.join("pipe"))?;
    tokio::net::windows::named_pipe::ClientOptions::new().open(name.trim())
}

/// Sends the token, then copies standard input to the app and the app to standard output; the
/// app closing the connection ends the pump.
async fn pump<S>(stream: S, token: &str) -> std::io::Result<()>
where
    S: AsyncRead + AsyncWrite + Send + 'static,
{
    let (mut from_app, mut to_app) = tokio::io::split(stream);
    to_app.write_all(format!("{token}\n").as_bytes()).await?;
    let upstream = tokio::spawn(async move {
        let _ = tokio::io::copy(&mut tokio::io::stdin(), &mut to_app).await;
        // The client closed its side: tell the app, which then closes the connection.
        let _ = to_app.shutdown().await;
    });
    let mut stdout = tokio::io::stdout();
    let copied = tokio::io::copy(&mut from_app, &mut stdout).await;
    let _ = stdout.flush().await;
    upstream.abort();
    copied.map(|_| ())
}
