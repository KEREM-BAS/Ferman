//! The only crate the Ferman UI calls.
//!
//! ferman-api has two layers (ADR 0003, docs/ARCHITECTURE.md §2.3 and §3):
//!
//! - [`facade`]: plain Rust, always built. Versions, engine information, [`facade::ApiError`] and
//!   the panic guard today; the `Engine`, its configuration, handles and data types, the document
//!   actors, the job manager and, from M5, the network gateway later. ferman-cli and the
//!   integration tests call this module.
//! - `frb` (feature `frb`, on in the app build): thin wrappers that expose facade functions to
//!   Dart. Nothing else lives there, and flutter_rust_bridge codegen scans only that module.
//!
//! The UI never sees PDF internals. Only plain data crosses the boundary (integers, floats,
//! strings, enums, byte vectors and structs of those, plus opaque `u64` handles), and no localized
//! text leaves the engine: errors carry message keys that Dart formats (ADR 0010, ADR 0014).
//!
//! Unsafe code is denied rather than forbidden in this crate, so that the FRB-generated glue (added
//! in M1 step 3) can be allowed on its own module. It is the only module in Ferman's crates where
//! unsafe code is allowed, and tools/checks fails on any other `allow(unsafe_code)` (ADR 0010).
#![deny(unsafe_code)]

pub mod facade;

#[cfg(feature = "frb")]
pub mod frb;

// M1 step 3 declares the FRB-generated Rust glue here, with these attributes directly on the module
// declaration (rustfmt puts each attribute on its own line; tools/checks accepts that form). The
// allow list names every lint the workspace sets beyond the defaults (Cargo.toml), because
// clippy::all does not cover restriction lints:
// #[cfg(feature = "frb")] #[allow(unsafe_code, missing_docs, clippy::all, clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::todo, clippy::unimplemented, clippy::dbg_macro, clippy::print_stdout, clippy::print_stderr)] mod frb_generated;
