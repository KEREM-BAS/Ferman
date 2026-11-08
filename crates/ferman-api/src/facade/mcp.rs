//! The local MCP server for AI clients (ADR 0019), behind the `mcp` feature: on in the desktop
//! app, off for ferman-cli and the web build. It brings rmcp and tokio into the engine for this
//! feature alone, the shown need ADR 0009 asks for (M4 plan decision 37: rmcp 3.8.0, pinned
//! below the newest release, passed `cargo deny` when W7 started).
//!
//! The app starts the host ([`Engine::start_mcp_host`], off by default): a Unix domain socket in
//! a folder only the user can open on macOS and Linux, a named pipe that refuses remote callers
//! on Windows, never a network address. `ferman-mcp`, the byte pump an AI client starts, connects
//! to it and proves itself with the host's token, a file in the same folder.
//!
//! [`serve`] runs one client's connection: the client says its name in the MCP `initialize`
//! handshake and is connected to the engine under it, read only ([`Engine::connect_client`]);
//! when the connection ends, however it ends, the client is disconnected and its open
//! transactions are rolled back ([`Engine::disconnect_client`]). Its tools (`tools`) read the open
//! documents under read permission and change them only once the user grants edit.

mod host;
mod tools;

use std::sync::{Arc, Mutex, PoisonError};

use rmcp::handler::server::router::tool::ToolRouter;
use rmcp::model::{
    Implementation, InitializeRequestParams, InitializeResult, ServerCapabilities, ServerConfig,
};
use rmcp::service::RequestContext;
use rmcp::{ErrorData, RoleServer, ServerHandler, ServiceExt as _, tool_handler};

pub(super) use host::Host;

use super::clients::ClientId;
use super::engine::Engine;
use super::error::ApiError;
use super::version::APP_VERSION;

/// The name a client gets when its handshake gives none.
const UNNAMED: &str = "MCP client";

/// The server one connection talks to: the engine and, from the handshake, its client.
#[derive(Clone)]
struct Server {
    engine: &'static Engine,
    client: Arc<Mutex<Option<ClientId>>>,
    tools: ToolRouter<Self>,
}

impl std::fmt::Debug for Server {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Server")
            .field("client", &self.client)
            .finish_non_exhaustive()
    }
}

#[tool_handler(router = self.tools)]
impl ServerHandler for Server {
    fn get_info(&self) -> ServerConfig {
        let mut config = ServerConfig::new(ServerCapabilities::builder().enable_tools().build());
        config.server_info = Implementation::new("Ferman", APP_VERSION);
        config
    }

    async fn initialize(
        &self,
        request: InitializeRequestParams,
        context: RequestContext<RoleServer>,
    ) -> Result<InitializeResult, ErrorData> {
        context.peer.set_peer_info(request.clone());
        let name = Some(request.client_info.name.trim())
            .filter(|name| !name.is_empty())
            .unwrap_or(UNNAMED)
            .to_owned();
        let mut client = self.client.lock().unwrap_or_else(PoisonError::into_inner);
        // A second handshake on one connection keeps the first name.
        if client.is_none() {
            *client = Some(self.engine.connect_client(name));
        }
        self.negotiate_initialize(&request)
    }
}

/// Disconnects the connection's client when dropped: when the connection closes, fails or its
/// task is cancelled.
struct Connection(Server);

impl Drop for Connection {
    fn drop(&mut self) {
        let client = self
            .0
            .client
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .take();
        if let Some(client) = client {
            self.0.engine.disconnect_client(client);
        }
    }
}

/// Serves one client's connection over `stream` until it closes, on the tokio runtime of the
/// caller (the host's).
///
/// # Errors
///
/// `Internal` when the MCP handshake fails or the connection's task ends with a panic.
pub async fn serve<S>(engine: &'static Engine, stream: S) -> Result<(), ApiError>
where
    S: tokio::io::AsyncRead + tokio::io::AsyncWrite + Send + 'static,
{
    let server = Server {
        engine,
        client: Arc::default(),
        tools: Server::tool_router(),
    };
    let _connection = Connection(server.clone());
    let running = server
        .serve(stream)
        .await
        .map_err(|err| ApiError::internal(format!("the MCP handshake failed: {err}")))?;
    running
        .waiting()
        .await
        .map_err(|_join| ApiError::internal("the MCP connection's task failed"))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use tokio::io::{AsyncBufReadExt as _, AsyncWriteExt as _, BufReader};

    use super::*;
    use crate::facade::{EngineConfig, PdfiumLibrary};

    #[test]
    fn a_client_is_connected_by_its_name_until_its_connection_closes() {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();
        let engine: &'static Engine = Box::leak(Box::new(Engine::start(EngineConfig {
            pdfium: PdfiumLibrary::Disabled,
        })));
        runtime.block_on(async {
            let (ours, theirs) = tokio::io::duplex(64 * 1024);
            let (read, mut write) = tokio::io::split(theirs);
            let mut lines = BufReader::new(read).lines();
            let served = serve(engine, ours);
            let client = async {
                write
                    .write_all(
                        concat!(
                            r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":"#,
                            r#"{"protocolVersion":"2025-06-18","capabilities":{},"#,
                            r#""clientInfo":{"name":"Stand-in","version":"1"}}}"#,
                            "\n",
                        )
                        .as_bytes(),
                    )
                    .await
                    .unwrap();
                let reply = lines.next_line().await.unwrap().unwrap();
                assert!(reply.contains(r#""name":"Ferman""#), "{reply}");
                assert!(reply.contains(r#""tools""#), "{reply}");
                write
                    .write_all(b"{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}\n")
                    .await
                    .unwrap();
                // The handshake's answer came after the client was connected.
                let names: Vec<String> = engine
                    .connected_clients()
                    .into_iter()
                    .map(|client| client.name)
                    .collect();
                assert_eq!(names, ["Stand-in"]);
                assert!(!engine.connected_clients()[0].may_edit);
                write.shutdown().await.unwrap();
                drop(write);
            };
            let (served, ()) = tokio::join!(served, client);
            served.unwrap();
        });
        assert!(engine.connected_clients().is_empty());
    }
}
