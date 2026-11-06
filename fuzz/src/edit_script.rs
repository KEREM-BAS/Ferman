//! Edit scripts: random operations on random blocks of corpus pages. Besides not panicking, every
//! edit changes the bytes of its splices and no others, and a saved file keeps the original as its
//! prefix, reopens clean and holds the same page content.

use std::sync::Arc;

use ferman_core::revision::{RevisionStore, Splice as CoreSplice};
use ferman_core::{CoreError, Document, OpenOptions, Password, Source, WriteError, open};
use ferman_text::fallback::FontSources;
use ferman_text::{
    Choice, EditContext, Outcome, TextError, rewrite_block_fonts, text_page_revised,
};

/// An object's number and generation.
type ObjectId = (u32, u16);

macro_rules! corpus {
    ($($name:literal),* $(,)?) => {
        [$((
            include_bytes!(concat!("../../tests/corpus/generated/", $name, ".pdf")).as_slice(),
            None,
        )),*, (
            include_bytes!("../../tests/corpus/generated/payslip-aes128.pdf").as_slice(),
            Some("bordro2026"),
        )]
    };
}

/// The corpus files under 30 KB with text to edit, and one encrypted one.
static FILES: [(&[u8], Option<&str>); 24] = corpus![
    "edit-e15-helvetica",
    "edit-cff-cid",
    "he-para",
    "edit-e05-fstype",
    "edit-e04-differences",
    "edit-macroman",
    "ko-para",
    "fa-zwnj",
    "edit-e22-split-contents",
    "edit-e23-shared-contents",
    "edit-e26-inline-image",
    "edit-e20-form-twice",
    "edit-e19-rotate",
    "edit-e21-actualtext",
    "edit-90ms-rksj",
    "edit-e16-type3",
    "zh-hans",
    "zh-hant",
    "xfa-visa",
    "disagree-pages",
    "ocg-plan",
    "fatura-tr",
    "js-openaction",
];

const MAX_OPS: usize = 8;

/// One byte of `script`, zero at its end.
fn byte(script: &mut &[u8]) -> u8 {
    let (&first, rest) = script.split_first().unwrap_or((&0, &[]));
    *script = rest;
    first
}

/// The block's text with a change from `script`: all of it replaced, new text inserted, or a part
/// deleted. The text is the script's own, so any character and any line feed is reachable.
fn new_text(script: &mut &[u8], old: &str) -> String {
    let mode = byte(script);
    let length = usize::from(byte(script));
    let (head, rest) = script.split_at(length.min(script.len()));
    *script = rest;
    let typed = String::from_utf8_lossy(head);
    let chars: Vec<char> = old.chars().collect();
    let at = usize::from(mode >> 2) * chars.len() / 64;
    let (before, after) = chars.split_at(at.min(chars.len()));
    let before: String = before.iter().collect();
    let after: String = after.iter().collect();
    match mode & 0x03 {
        0 => typed.into_owned(),
        1 => format!("{before}{typed}{after}"),
        2 => {
            let kept: String = after.chars().skip(length).collect();
            format!("{before}{kept}")
        }
        _ => old.to_owned(),
    }
}

/// The content of every page, as `store` has it.
fn contents(document: &Document, store: &RevisionStore) -> Vec<Vec<(ObjectId, Vec<u8>)>> {
    (0..document.page_count())
        .map(
            |page| match ferman_core::fuzzing::page_streams(document, store, page) {
                Ok(streams) => streams,
                Err(err) => panic!("reading page {page}: {err}"),
            },
        )
        .collect()
}

/// `data` with the splices of `stream` applied, by a plain walk of the ranges.
fn spliced(data: &[u8], stream: ObjectId, splices: &[CoreSplice]) -> Vec<u8> {
    let mut edits: Vec<&CoreSplice> = splices
        .iter()
        .filter(|splice| {
            matches!(splice.source, ferman_core::interpret::SpanSource::Page { stream: id } if id == stream)
        })
        .collect();
    edits.sort_by_key(|splice| splice.range.start);
    let mut out = Vec::new();
    let mut at = 0;
    for splice in edits {
        out.extend_from_slice(&data[at..splice.range.start]);
        out.extend_from_slice(&splice.bytes);
        at = splice.range.end;
    }
    out.extend_from_slice(&data[at..]);
    out
}

/// Panics on an error malformed input cannot explain: the corpus files are sound.
fn check_text_error(err: &TextError) {
    let allowed = matches!(
        err,
        TextError::Core(CoreError::ResourceLimit { .. }) | TextError::Font(_)
    );
    assert!(allowed, "an edit: {err}");
}

/// One rewrite of a block, in a transaction of its own.
fn rewrite(document: &Document, store: &mut RevisionStore, script: &mut &[u8]) {
    let context = EditContext::default();
    let index = usize::from(byte(script)) % document.page_count().max(1);
    let page = match text_page_revised(document, store, index, &context) {
        Ok(page) => page,
        Err(err) => return check_text_error(&err),
    };
    let which = usize::from(byte(script));
    let Some(block) = page.blocks.get(which % page.blocks.len().max(1)) else {
        return;
    };
    let others: Vec<_> = page
        .blocks
        .iter()
        .filter(|other| other.id != block.id)
        .cloned()
        .collect();
    let choice = match byte(script) % 4 {
        0 => None,
        1 => Some(Choice::Extend),
        2 => Some(Choice::Tighten),
        _ => Some(Choice::Keep),
    };
    let text = new_text(script, &block.text());
    let outcome = rewrite_block_fonts(
        document,
        Some(store),
        index,
        block,
        &text,
        &others,
        choice,
        &FontSources::default(),
    );
    let rewrite = match outcome {
        Ok(Outcome::Rewritten(rewrite)) => rewrite,
        Ok(Outcome::MissingGlyphs(_) | Outcome::Unsupported(_)) => return,
        Err(err) => return check_text_error(&err),
    };
    let splices: Vec<CoreSplice> = rewrite
        .splices
        .into_iter()
        .map(|splice| CoreSplice {
            source: splice.source,
            range: splice.range,
            bytes: splice.bytes,
        })
        .collect();
    let before = contents(document, store);
    let mut working = store.clone();
    let done = working
        .begin()
        .and_then(|()| {
            working.add_new_fonts(
                document,
                index,
                &rewrite.fonts,
                &rewrite.simple_fonts,
                &rewrite.new_fonts,
            )
        })
        .and_then(|()| working.splice(document, index, &splices, &[]))
        .and_then(|()| working.commit().map(drop));
    match done {
        Ok(()) => {}
        // A splice of a form needs a placement, which the facade does not pass either.
        Err(CoreError::Write(WriteError::Placement) | CoreError::ResourceLimit { .. }) => return,
        Err(err) => panic!("applying a rewrite: {err}"),
    }
    let after = contents(document, &working);
    for (page, (old, new)) in before.iter().zip(&after).enumerate() {
        assert_eq!(old.len(), new.len(), "page {page} has other streams");
        for ((id, old), (_, new)) in old.iter().zip(new) {
            let wanted = if page == index {
                spliced(old, *id, &splices)
            } else {
                old.clone()
            };
            assert!(
                *new == wanted,
                "bytes outside the splices of page {page} changed"
            );
        }
    }
    *store = working;
}

/// The save path: the original is a prefix, the file reopens clean, with the same content.
fn check_save(document: &Document, store: &RevisionStore, original: &[u8], password: Option<&str>) {
    let saved = match store.incremental_update(document) {
        Ok(saved) => saved,
        Err(err) => panic!("saving: {err}"),
    };
    assert!(saved.starts_with(original), "the original is not a prefix");
    let reopened = match open_file(&saved, password) {
        Ok(reopened) => reopened,
        Err(err) => panic!("the saved file does not reopen: {err}"),
    };
    assert!(reopened.repair().is_none(), "the saved file needs repair");
    assert_eq!(reopened.page_count(), document.page_count());
    let fresh = RevisionStore::new(&reopened);
    let read: Vec<Vec<Vec<u8>>> = contents(&reopened, &fresh)
        .into_iter()
        .map(|page| page.into_iter().map(|(_, data)| data).collect())
        .collect();
    let kept: Vec<Vec<Vec<u8>>> = contents(document, store)
        .into_iter()
        .map(|page| page.into_iter().map(|(_, data)| data).collect())
        .collect();
    assert!(read == kept, "the saved file holds other content");
}

fn open_file(bytes: &[u8], password: Option<&str>) -> Result<Document, CoreError> {
    let options = OpenOptions {
        password: password.map(|password| Password::new(password.to_owned())),
        ..OpenOptions::default()
    };
    open(&Source::from_bytes(Arc::from(bytes)), &options)
}

/// Runs the script `input`: its first byte chooses a corpus file, then each operation is a rewrite,
/// an undo, a redo or a save. Undoing everything at the end gives back the original bytes.
pub fn run(input: &[u8]) {
    let mut script = input;
    let (original, password) = FILES[usize::from(byte(&mut script)) % FILES.len()];
    let document = match open_file(original, password) {
        Ok(document) => document,
        Err(err) => panic!("a corpus file does not open: {err}"),
    };
    let mut store = RevisionStore::new(&document);
    for _ in 0..MAX_OPS {
        if script.is_empty() {
            break;
        }
        match byte(&mut script) & 0x07 {
            5 => drop(store.undo()),
            6 => drop(store.redo()),
            7 => check_save(&document, &store, original, password),
            _ => rewrite(&document, &mut store, &mut script),
        }
    }
    check_save(&document, &store, original, password);
    while store.current() > 0 {
        if let Err(err) = store.undo() {
            panic!("undoing: {err}");
        }
    }
    match store.incremental_update(&document) {
        Ok(saved) => assert!(saved == original, "undoing everything left a change"),
        Err(err) => panic!("saving: {err}"),
    }
}
