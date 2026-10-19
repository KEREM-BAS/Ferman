//! The only crate the Ferman UI calls.
//!
//! ferman-api has two layers (ADR 0003, docs/ARCHITECTURE.md §2.3 and §3):
//!
//! - [`facade`]: plain Rust, always built. Today: versions, the [`facade::Engine`] with its
//!   configuration and the render thread that loads PDFium, engine information,
//!   [`facade::ApiError`], the panic guards and two test-only calls for the bridge. Later: handles
//!   and data types, the document actors, the job manager and, from M5, the network gateway.
//!   ferman-cli and the integration tests call this module.
//! - `frb` (feature `frb`, on in the app build): thin wrappers that expose facade functions to
//!   Dart, and plain mirrors of the facade's data types. Nothing else lives there, and
//!   flutter_rust_bridge codegen scans only that module: the facade carries `frb(ignore)`, because
//!   codegen matches types by bare name across the whole crate and would otherwise take the
//!   facade's `EngineInfo` or `ApiError` for the mirror of the same name.
//!
//! The UI never sees PDF internals. Only plain data crosses the boundary (integers, floats,
//! strings, enums, byte vectors and structs of those, plus opaque `u64` handles), and no localized
//! text leaves the engine: errors carry message keys that Dart formats (ADR 0010, ADR 0014).
//!
//! Unsafe code is denied rather than forbidden in this crate, so that the FRB-generated glue (added
//! in M1 step 3) can be allowed on its own module. It is the only module in Ferman's crates where
//! unsafe code is allowed, and tools/checks fails on any other `allow(unsafe_code)` (ADR 0010).
#![deny(unsafe_code)]

// Hidden from flutter_rust_bridge codegen, so it reads only `crate::frb` (see above), and from the
// cbindgen pass of its Dco codec (`full_dep: true`), which reads the whole crate: without the
// `cbindgen:ignore` line below, the public constant `API_VERSION` made it declare the facade's
// `ApiVersion` as an opaque C struct, and ffigen turned that into a Dart class that clashes with
// the mirror of the same name. cbindgen reads only doc attributes for this.
#[cfg_attr(feature = "frb", flutter_rust_bridge::frb(ignore))]
#[doc = "cbindgen:ignore"]
pub mod facade;

#[cfg(feature = "frb")]
pub mod frb;

// The FRB-generated Rust glue (flutter_rust_bridge 2.13.0, `app/flutter_rust_bridge.yaml`, which
// sets `add_mod_to_lib: false` so this hand-written declaration keeps its attributes). It is the only
// place in Ferman's own crates where unsafe code is allowed (ADR 0002, tools/checks unsafe_roots).
// The allow list names every lint the workspace sets beyond the defaults, because clippy::all does
// not cover restriction lints. Never edit frb_generated.rs by hand.
#[cfg(feature = "frb")]
#[allow(
    unsafe_code,
    missing_docs,
    clippy::all,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::todo,
    clippy::unimplemented,
    clippy::dbg_macro,
    clippy::print_stdout,
    clippy::print_stderr
)]
mod frb_generated;
