# fuzz

Ferman's [cargo-fuzz](https://github.com/rust-fuzz/cargo-fuzz) targets: one per parser, from the
first parser in M2 ([ARCHITECTURE.md §13.6](../docs/ARCHITECTURE.md#136-fuzz-targets)). Every PDF
is untrusted input, and a target is how a parser proves it fails with an error, never a crash.

This is a Cargo workspace of its own, which the root `Cargo.toml` excludes. libfuzzer-sys vendors
LLVM's libFuzzer under NCSA, which the owner approved for this workspace only
([Q17](../docs/QUESTIONS.md#q17)), so it never enters the shipped dependency graph. Nothing here
ships.

## Requirements

- **The pinned nightly:** `rust-toolchain.toml` in this folder names it, and rustup installs it on
  first use. cargo-fuzz needs nightly for the sanitizers.
- **cargo-fuzz 0.13.2:** `cargo install --locked cargo-fuzz@0.13.2`.
- **A system:** Linux or macOS. cargo-fuzz's Windows support needs MSVC's AddressSanitizer and has
  limits, so CI fuzzes on Linux.

## Commands

Run them from this folder, so rustup picks the nightly:

```sh
cargo fuzz list                                         # the targets
cargo fuzz run filter_flate -- -max_total_time=60       # fuzz one target for 60 s
cargo fuzz run filter_flate artifacts/filter_flate/<file>   # replay a crash
cargo fuzz build                                        # build every target (AddressSanitizer)
```

From the repository root, formatting and Clippy use the stable toolchain:

```sh
cargo fmt --manifest-path fuzz/Cargo.toml --check
cargo clippy --manifest-path fuzz/Cargo.toml --all-targets --locked -- -D warnings
cargo deny --manifest-path fuzz/Cargo.toml check
```

`corpus/`, `artifacts/` and `coverage/` here are cargo-fuzz's working folders and are gitignored.

## Targets

| Target | Parser | Input |
|---|---|---|
| `filter_ascii_hex` | ASCIIHexDecode (`ferman_core::filters`) | the stream data |
| `filter_ascii85` | ASCII85Decode | the stream data |
| `filter_lzw` | LZWDecode and its predictors | `/DecodeParms` from the first four bytes, then the data |
| `filter_flate` | FlateDecode and its predictors | `/DecodeParms` from the first four bytes, then the data |
| `filter_run_length` | RunLengthDecode | the stream data |
| `syntax_object` | ferman-core's object parser: a direct object, then an indirect one with its stream | arbitrary bytes |
| `xref_repair` | cross-reference tables and streams, `/Prev` chains, and repair by scanning | arbitrary bytes, as a file from its `%PDF-` header |
| `security_handler` | the standard security handler: the encryption dictionary, passwords for revisions 2 to 6, decryption | a length byte, the password, an encryption dictionary, then the data to decrypt |
| `open_document` | the whole open path: header, cross-reference data, repair, security, lopdf and the structure scan | arbitrary bytes as a file; the password `fuzz` when the first byte is odd |

The filter targets' checks are in `src/lib.rs`:

- the code under test must not panic;
- it must not decode more than the limit (1 MiB, so a decompression bomb stops quickly);
- it may fail only with the errors a damaged stream can cause.

The open-path targets call ferman-core's hidden `fuzzing` module, behind the `fuzzing` feature
that only this workspace enables, with small limits (1 MiB per stream, 64 cross-reference
sections). Besides not panicking, they may fail with any error but an internal one or running out of
memory, and `xref_repair` checks that a rebuilt table reads back clean from the flat copy lopdf
gets. `open_document` runs lopdf too, so it finds lopdf's panics, which ferman-api catches as a
last resort; a panic found there is reported upstream and worked around in ferman-core where it
can be. Seed `corpus/open_document` and `corpus/xref_repair` with the PDFs of `tests/corpus/`.

AddressSanitizer and libFuzzer's time and memory limits catch the rest.

## A crash

A crash becomes a regression test before it is fixed:

1. The input goes into `tests/corpus/` with a row in its README (source: the target and the date it
   was found).
2. A test in the crate replays it.
3. The fix makes that test pass.

## CI

Every pull request runs each target for 60 s on Linux (**Proposed** with the M2 plan). A nightly
run of one hour per target follows with M2's CI commit.
