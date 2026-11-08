//! The MCP host and its tools (ADR 0019) over the real socket or pipe, as `ferman-mcp` reaches
//! them: a connection without the token is closed; a stand-in client lists the tools and the open
//! documents, reads, is refused an edit while read only, edits once the user grants edit, and its
//! first change to a signed document waits for the user's answer to a request. Nothing listens
//! on TCP, and the folder, socket and token are the user's alone.
//!
//! The tests marked ignored need PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
//! Build with the `mcp` feature: `cargo test -p ferman-api --features mcp --test mcp`.
#![cfg(feature = "mcp")]
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::sync::mpsc;
use std::time::Duration;

use ferman_api::facade::{
    ClientRequest, ClientRequestKind, DocumentId, Engine, EngineConfig, PdfiumLibrary, RequestSink,
    block_on,
};
use serde_json::{Value, json};
use tokio::io::{AsyncBufReadExt as _, AsyncReadExt as _, AsyncWriteExt as _, BufReader};

#[cfg(unix)]
type Stream = tokio::net::UnixStream;
#[cfg(windows)]
type Stream = tokio::net::windows::named_pipe::NamedPipeClient;

#[cfg(unix)]
async fn raw(folder: &Path) -> Stream {
    tokio::net::UnixStream::connect(folder.join("socket"))
        .await
        .unwrap()
}

#[cfg(windows)]
async fn raw(folder: &Path) -> Stream {
    let name = std::fs::read_to_string(folder.join("pipe")).unwrap();
    tokio::net::windows::named_pipe::ClientOptions::new()
        .open(name.trim())
        .unwrap()
}

/// A stand-in MCP client: JSON-RPC lines over the host's socket, as `ferman-mcp` pumps them.
struct Client {
    lines: tokio::io::Lines<BufReader<tokio::io::ReadHalf<Stream>>>,
    write: tokio::io::WriteHalf<Stream>,
    next: u64,
}

impl Client {
    async fn connect(folder: &Path, name: &str) -> Self {
        let token = std::fs::read_to_string(folder.join("token")).unwrap();
        let (read, mut write) = tokio::io::split(raw(folder).await);
        write
            .write_all(format!("{token}\n").as_bytes())
            .await
            .unwrap();
        let mut client = Self {
            lines: BufReader::new(read).lines(),
            write,
            next: 1,
        };
        let reply = client
            .request(
                "initialize",
                json!({
                    "protocolVersion": "2025-06-18",
                    "capabilities": {},
                    "clientInfo": { "name": name, "version": "1" },
                }),
            )
            .await;
        assert_eq!(reply["serverInfo"]["name"], "Ferman");
        client
            .send(&json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }))
            .await;
        client
    }

    async fn send(&mut self, message: &Value) {
        self.write
            .write_all(format!("{message}\n").as_bytes())
            .await
            .unwrap();
    }

    /// Sends a request and returns its result, skipping notifications.
    async fn request(&mut self, method: &str, params: Value) -> Value {
        let id = self.next;
        self.next += 1;
        self.send(&json!({ "jsonrpc": "2.0", "id": id, "method": method, "params": params }))
            .await;
        loop {
            let line = self.lines.next_line().await.unwrap().unwrap();
            let message: Value = serde_json::from_str(&line).unwrap();
            if message["id"] == id {
                assert!(message.get("error").is_none(), "{message}");
                return message["result"].clone();
            }
        }
    }

    /// Calls a tool: its JSON answer, or the error text.
    async fn call(&mut self, tool: &str, arguments: Value) -> Result<Value, String> {
        let result = self
            .request(
                "tools/call",
                json!({ "name": tool, "arguments": arguments }),
            )
            .await;
        let text = result["content"][0]["text"].as_str().unwrap().to_owned();
        if result["isError"] == true {
            Err(text)
        } else {
            Ok(serde_json::from_str(&text).unwrap())
        }
    }
}

fn runtime() -> tokio::runtime::Runtime {
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap()
}

fn folder(test: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("ferman-mcp-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

/// The TCP sockets this process listens on, as the system lists them.
#[cfg(unix)]
fn tcp_listening() -> Option<String> {
    let output = std::process::Command::new("lsof")
        .args(["-nP", "-a", "-p", &std::process::id().to_string(), "-iTCP"])
        .output()
        .ok()?;
    Some(String::from_utf8_lossy(&output.stdout).into_owned())
}

#[cfg(windows)]
fn tcp_listening() -> Option<String> {
    let output = std::process::Command::new("netstat")
        .args(["-ano", "-p", "TCP"])
        .output()
        .ok()?;
    let pid = std::process::id().to_string();
    Some(
        String::from_utf8_lossy(&output.stdout)
            .lines()
            .filter(|line| {
                line.contains("LISTENING") && line.split_whitespace().last() == Some(pid.as_str())
            })
            .collect::<Vec<_>>()
            .join("\n"),
    )
}

#[test]
fn the_host_is_the_users_alone_lists_its_tools_and_never_listens_on_tcp() {
    let engine: &'static Engine = Box::leak(Box::new(Engine::start(EngineConfig {
        pdfium: PdfiumLibrary::Disabled,
    })));
    let app_data = folder("host");
    let mcp = engine.start_mcp_host(app_data.clone()).unwrap();
    assert_eq!(mcp, app_data.join("mcp"));
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt as _;
        let mode = |name: &str| {
            std::fs::metadata(mcp.join(name))
                .unwrap()
                .permissions()
                .mode()
                & 0o777
        };
        assert_eq!(
            std::fs::metadata(&mcp).unwrap().permissions().mode() & 0o777,
            0o700
        );
        assert_eq!(mode("socket"), 0o600);
        assert_eq!(mode("token"), 0o600);
    }
    runtime().block_on(async {
        // Without the token the connection is closed, and no client connects.
        let mut stranger = raw(&mcp).await;
        stranger
            .write_all(format!("{}\n", "0".repeat(64)).as_bytes())
            .await
            .unwrap();
        let mut rest = Vec::new();
        let _ = stranger.read_to_end(&mut rest).await;
        assert!(rest.is_empty());
        assert!(engine.connected_clients().is_empty());
        // A connection that never gives the token is closed after a short wait.
        let mut silent = raw(&mcp).await;
        let mut rest = Vec::new();
        let closed =
            tokio::time::timeout(Duration::from_secs(10), silent.read_to_end(&mut rest)).await;
        assert!(closed.is_ok(), "a silent connection was kept open");

        let mut client = Client::connect(&mcp, "Stand-in").await;
        let tools = client.request("tools/list", json!({})).await;
        let names: Vec<&str> = tools["tools"]
            .as_array()
            .unwrap()
            .iter()
            .map(|tool| tool["name"].as_str().unwrap())
            .collect();
        for tool in [
            "list_documents",
            "read_page_text",
            "search_text",
            "edit_text",
            "rotate_pages",
            "add_comment",
            "fill_field",
            "compress",
            "combine_files",
            "set_bookmarks",
            "set_metadata",
            "attach_file",
            "add_signature",
            "save",
        ] {
            assert!(names.contains(&tool), "{tool} missing from {names:?}");
        }
        // Every tool has a schema for its arguments.
        assert!(
            tools["tools"]
                .as_array()
                .unwrap()
                .iter()
                .all(|tool| tool["inputSchema"]["type"] == "object")
        );
        assert_eq!(
            client.call("list_documents", json!({})).await,
            Ok(json!([]))
        );
        if let Some(listening) = tcp_listening() {
            assert!(
                !listening.contains("LISTEN"),
                "the process listens on TCP:\n{listening}"
            );
        }
    });
    engine.stop_mcp_host();
    assert!(engine.connected_clients().is_empty());
    assert!(!mcp.join("token").exists());
    std::fs::remove_dir_all(&app_data).unwrap();
}

/// One engine with PDFium for the tests that open documents.
fn engine() -> &'static Engine {
    static ENGINE: OnceLock<Engine> = OnceLock::new();
    ENGINE.get_or_init(|| {
        let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
        Engine::start(EngineConfig {
            pdfium: PdfiumLibrary::Path(library.into()),
        })
    })
}

fn open(dir: &Path, name: &str) -> DocumentId {
    let path = dir.join(format!("{name}.pdf"));
    let corpus = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"));
    std::fs::copy(corpus, &path).unwrap();
    block_on(engine().open(path, None)).unwrap().id
}

/// The tests that answer requests take turns: the engine has one request sink.
static ANSWERING: std::sync::Mutex<()> = std::sync::Mutex::new(());

/// Hands the requests to the user's stand-in.
struct Requests(mpsc::Sender<ClientRequest>);

impl RequestSink for Requests {
    fn deliver(&mut self, request: ClientRequest) {
        let _ = self.0.send(request);
    }
}

/// The block of page 1 that reads `needle`, and its text, as the client reads them.
async fn block(client: &mut Client, document: u64, needle: &str) -> (u64, String) {
    let blocks = client
        .call("read_page_text", json!({ "document": document, "page": 1 }))
        .await
        .unwrap();
    let block = blocks
        .as_array()
        .unwrap()
        .iter()
        .find(|block| block["text"].as_str().unwrap().contains(needle))
        .unwrap();
    (
        block["block"].as_u64().unwrap(),
        block["text"].as_str().unwrap().to_owned(),
    )
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_stand_in_client_reads_is_refused_edits_once_granted_and_asks_on_a_signed_file() {
    let _turn = ANSWERING
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    let app_data = folder("client");
    let plain = open(&app_data, "edit-e15-helvetica");
    let signed = open(&app_data, "kira-tr-signed");
    // The user allows every request, and the test hears of each.
    let (requests, incoming) = mpsc::channel::<ClientRequest>();
    let (heard, asked) = mpsc::channel();
    std::thread::spawn(move || {
        for request in incoming {
            engine().answer_client_request(request.id, true);
            let _ = heard.send(request);
        }
    });
    engine().watch_client_requests(Box::new(Requests(requests)));
    let mcp = engine().start_mcp_host(app_data.clone()).unwrap();
    runtime().block_on(async {
        let mut client = Client::connect(&mcp, "Stand-in").await;
        let listed = client.call("list_documents", json!({})).await.unwrap();
        let ids: Vec<u64> = listed
            .as_array()
            .unwrap()
            .iter()
            .map(|document| document["document"].as_u64().unwrap())
            .collect();
        assert!(ids.contains(&plain.get()) && ids.contains(&signed.get()));
        let found = client
            .call(
                "search_text",
                json!({ "document": plain.get(), "query": "Monday" }),
            )
            .await
            .unwrap();
        assert_eq!(found["matches"][0]["page"], 1);

        // Read only: the edit is refused and changes nothing.
        let (id, text) = block(&mut client, plain.get(), "Monday").await;
        let edit = json!({
            "document": plain.get(), "page": 1, "block": id,
            "text": text.replace("Monday", "Friday"),
        });
        let refused = client.call("edit_text", edit.clone()).await.unwrap_err();
        assert!(refused.contains("permission"), "{refused}");
        let refused = client
            .call(
                "rotate_pages",
                json!({ "document": plain.get(), "pages": [1], "quarter_turns": 1 }),
            )
            .await
            .unwrap_err();
        assert!(refused.contains("permission"), "{refused}");

        // The user grants edit.
        let me = engine()
            .connected_clients()
            .into_iter()
            .find(|connected| connected.name == "Stand-in")
            .unwrap();
        engine().grant_edit(me.id, true).unwrap();
        client.call("edit_text", edit).await.unwrap();
        client
            .call(
                "rotate_pages",
                json!({ "document": plain.get(), "pages": [1], "quarter_turns": 1 }),
            )
            .await
            .unwrap();
        let history = client
            .call("history", json!({ "document": plain.get() }))
            .await
            .unwrap();
        assert_eq!(history["current"], 2);
        assert!(
            history["steps"]
                .as_array()
                .unwrap()
                .iter()
                .all(|step| step["client"] == "Stand-in")
        );
        assert!(
            asked.try_recv().is_err(),
            "nothing asked on an unsigned file"
        );

        // A signed file: the first change asks the user, even for a page operation.
        client
            .call(
                "rotate_pages",
                json!({ "document": signed.get(), "pages": [1], "quarter_turns": 1 }),
            )
            .await
            .unwrap();
        let request = asked.recv_timeout(Duration::from_secs(5)).unwrap();
        assert_eq!(
            (request.kind, request.document, request.client_name.as_str()),
            (ClientRequestKind::EditSigned, Some(signed), "Stand-in")
        );
        // Asked once for the client.
        client
            .call(
                "rotate_pages",
                json!({ "document": signed.get(), "pages": [1], "quarter_turns": 1 }),
            )
            .await
            .unwrap();
        assert!(asked.try_recv().is_err());
    });
    engine().stop_mcp_host();
    assert!(engine().connected_clients().is_empty());
    let history = block_on(engine().history(signed)).unwrap();
    assert_eq!(history.steps[0].client.as_deref(), Some("Stand-in"));
    block_on(engine().close_discarding(plain)).unwrap();
    block_on(engine().close_discarding(signed)).unwrap();
    std::fs::remove_dir_all(&app_data).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn combine_asks_to_read_each_file_and_sign_shows_the_name_page_and_field() {
    let _turn = ANSWERING
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    let app_data = folder("ask");
    let plain = open(&app_data, "edit-e15-helvetica");
    let input = app_data.join("edit-e15-helvetica.pdf");
    // The user declines every request, and the test hears of each.
    let (requests, incoming) = mpsc::channel::<ClientRequest>();
    let (heard, asked) = mpsc::channel();
    std::thread::spawn(move || {
        for request in incoming {
            assert!(engine().client_request_pending(request.id));
            engine().answer_client_request(request.id, false);
            assert!(!engine().client_request_pending(request.id));
            let _ = heard.send(request);
        }
    });
    engine().watch_client_requests(Box::new(Requests(requests)));
    let mcp = engine().start_mcp_host(app_data.clone()).unwrap();
    runtime().block_on(async {
        let mut client = Client::connect(&mcp, "Asker").await;
        let me = engine()
            .connected_clients()
            .into_iter()
            .find(|connected| connected.name == "Asker")
            .unwrap();
        engine().grant_edit(me.id, true).unwrap();

        // A relative input is refused before anything is asked.
        let output = app_data.join("combined.pdf");
        client
            .call(
                "combine_files",
                json!({ "files": ["relative.pdf"], "output": output }),
            )
            .await
            .unwrap_err();
        assert!(asked.try_recv().is_err());

        // Reading the input is asked first; declined, nothing is written.
        client
            .call(
                "combine_files",
                json!({ "files": [input], "output": output }),
            )
            .await
            .unwrap_err();
        let request = asked.recv_timeout(Duration::from_secs(5)).unwrap();
        assert_eq!(request.kind, ClientRequestKind::ReadFile(input.clone()));
        assert!(
            asked.try_recv().is_err(),
            "no write asked after a declined read"
        );
        assert!(!output.exists());

        // The signing request carries what the dialog shows.
        client
            .call(
                "add_signature",
                json!({
                    "document": plain.get(), "page": 1, "rect": [72, 72, 200, 110],
                    "name": "Jane Smith", "field": "Buyer",
                }),
            )
            .await
            .unwrap_err();
        let request = asked.recv_timeout(Duration::from_secs(5)).unwrap();
        assert_eq!(
            request.kind,
            ClientRequestKind::Sign {
                name: "Jane Smith".to_owned(),
                page: 1,
                field: Some("Buyer".to_owned()),
            }
        );
    });
    engine().stop_mcp_host();
    block_on(engine().close_discarding(plain)).unwrap();
    std::fs::remove_dir_all(&app_data).unwrap();
}
