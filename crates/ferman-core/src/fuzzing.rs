//! Entry points for the fuzz targets in `fuzz/` (docs/ARCHITECTURE.md §13.6), behind the
//! `fuzzing` feature, which nothing else enables. Each runs one parser on arbitrary bytes and
//! checks what it promises, panicking when a promise breaks so libFuzzer reports it.
// Fuzzing helpers: a broken promise panics on purpose.
#![allow(clippy::panic)]

use std::collections::BTreeMap;

use lopdf::{Dictionary, Object, ObjectId, StringFormat};
use zeroize::Zeroizing;

use crate::CoreError;
use crate::content;
use crate::document::{Document, OpenOptions, open};
use crate::interpret::{FontResource, TextShow, TextSink};
use crate::limits::Limits;
use crate::revision::RevisionStore;
use crate::security::{Decrypter, Params, Password};
use crate::source::Source;
use crate::syntax::Parser;
use crate::{repair, xref};

/// Limits small enough that a bomb or a deep structure stops quickly.
#[must_use]
pub fn limits() -> Limits {
    Limits {
        max_stream_decoded: 1 << 20,
        max_revision_decoded: 16 << 20,
        max_xref_sections: 64,
        ..Limits::default()
    }
}

/// The errors a malformed input may cause: anything but an internal error, or running out of
/// memory under the fuzzing limits.
fn expected(err: &CoreError) -> bool {
    !matches!(
        err,
        CoreError::Internal { .. } | CoreError::OutOfMemory { .. }
    )
}

/// The object parser: a direct object, then an indirect one, from the start of `data`.
pub fn syntax_object(data: &[u8]) {
    let limits = limits();
    for result in [
        Parser::new(data, 0, &limits).object().map(drop),
        Parser::new(data, 0, &limits)
            .indirect(&|_| Some(4))
            .map(|indirect| {
                assert!(indirect.end <= data.len(), "an object ends past the data");
                if let Some(range) = indirect.data {
                    assert!(range.start <= range.end && range.end <= data.len());
                }
            }),
    ] {
        if let Err(err) = result {
            assert!(expected(&err), "the object parser: {err}");
        }
    }
}

/// The content-stream lexer: every operator is named, and the spans stay inside the data and in
/// order.
pub fn content_lexer(data: &[u8]) {
    match content::operators(data, &limits()) {
        Ok(operators) => {
            let mut last = 0;
            for operator in &operators {
                assert!(!operator.name.is_empty(), "an operator without a name");
                assert!(
                    last <= operator.span.start
                        && operator.span.start <= operator.span.end
                        && operator.span.end <= data.len(),
                    "a span out of order or past the data"
                );
                last = operator.span.end;
            }
        }
        Err(err) => assert!(expected(&err), "the content lexer: {err}"),
    }
}

/// The text interpreter: `data` as a page's content and as a form the page can draw, which can
/// draw itself, with a simple font; the sink gives every show a fixed advance. Only a limit may
/// stop it.
pub fn interpreter(data: &[u8]) {
    use lopdf::{Object, Stream, dictionary};

    struct Fixed;
    impl TextSink for Fixed {
        fn font(&mut self, _: &FontResource) {}
        fn show(&mut self, show: &TextShow<'_>) -> (f32, f32) {
            assert!(
                show.span.range.end >= show.span.range.start,
                "a span that ends before it starts"
            );
            (1.0, 0.0)
        }
    }

    let mut doc = lopdf::Document::with_version("1.7");
    let (pages, form) = (doc.new_object_id(), doc.new_object_id());
    let font = doc.add_object(dictionary! {
        "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "Helvetica",
        "FirstChar" => 32, "Widths" => vec![250.into()],
    });
    let resources = dictionary! {
        "Font" => dictionary! { "F1" => font },
        "XObject" => dictionary! { "X1" => form },
    };
    let form_dict = dictionary! { "Subtype" => "Form", "Resources" => resources.clone() };
    doc.objects
        .insert(form, Object::Stream(Stream::new(form_dict, data.to_vec())));
    let contents = doc.add_object(Stream::new(dictionary! {}, data.to_vec()));
    let page = doc.add_object(dictionary! {
        "Type" => "Page", "Parent" => pages, "Resources" => resources, "Contents" => contents,
        "MediaBox" => vec![0.into(), 0.into(), 612.into(), 792.into()],
    });
    let kids = dictionary! { "Type" => "Pages", "Kids" => vec![page.into()], "Count" => 1 };
    doc.objects.insert(pages, Object::Dictionary(kids));
    let catalog = doc.add_object(dictionary! { "Type" => "Catalog", "Pages" => pages });
    doc.trailer.set("Root", catalog);
    let mut bytes = Vec::new();
    if doc.save_to(&mut bytes).is_err() {
        return;
    }
    let options = OpenOptions {
        limits: limits(),
        ..OpenOptions::default()
    };
    let Ok(document) = open(&Source::from_bytes(bytes.into()), &options) else {
        return;
    };
    if let Err(err) = document.page_text(0, &mut Fixed) {
        assert!(
            matches!(err, CoreError::ResourceLimit { .. }),
            "the interpreter: {err}"
        );
    }
}

/// Cross-reference data and repair. When the file's own data is broken, the table rebuilt from a
/// scan must read back clean from the flat copy lopdf gets.
pub fn xref_repair(data: &[u8]) {
    let limits = limits();
    let problem = match xref::read(data, &limits) {
        Ok(Ok(xref)) => {
            assert!(xref.sections >= 1 && xref.sections <= limits.max_xref_sections);
            return;
        }
        Ok(Err(problem)) => problem,
        Err(err) => {
            assert!(expected(&err), "reading the cross-reference data: {err}");
            return;
        }
    };
    let scan = match repair::scan(data, &limits) {
        Ok(scan) => scan,
        Err(err) => panic!("the repair scan: {err}"),
    };
    let Ok((rebuilt, _)) = repair::rebuild(&scan, data, problem) else {
        return;
    };
    let flat = match xref::flatten(data, &rebuilt, &std::collections::BTreeSet::new()) {
        Ok(flat) => flat,
        Err(err) => panic!("flattening: {err}"),
    };
    match xref::read(&flat, &limits) {
        Ok(Ok(reread)) => assert_eq!(
            reread.in_use().count(),
            rebuilt.in_use().count(),
            "the flat copy lost entries"
        ),
        other => panic!("the rebuilt table does not read back: {other:?}"),
    }
}

/// The standard security handler. `input` is a password length byte, the password, then an
/// encryption dictionary, then data to decrypt as a string and a stream, with the file key the
/// password gives or, when it gives none, one taken from the input.
pub fn security_handler(input: &[u8]) {
    let limits = limits();
    let Some((&length, rest)) = input.split_first() else {
        return;
    };
    let (password, rest) = rest.split_at(usize::from(length % 64).min(rest.len()));
    let password = Password::new(String::from_utf8_lossy(password).into_owned());
    let mut parser = Parser::new(rest, 0, &limits);
    let Ok(lopdf::Object::Dictionary(dict)) = parser.object() else {
        return;
    };
    let data = rest.get(parser.pos()..).unwrap_or_default();
    let params = match Params::new(&dict, b"0123456789abcdef") {
        Ok(params) => params,
        Err(err) => {
            assert!(expected(&err), "reading the encryption dictionary: {err}");
            return;
        }
    };
    let _ = params.info(true).permissions.all();
    let key = match params.authenticate(password.as_str()) {
        Ok(Some((key, _))) => key,
        Ok(None) => Zeroizing::new(data.iter().copied().take(32).collect()),
        Err(err) => panic!("authenticating: {err}"),
    };
    if key.len() < 5 {
        return;
    }
    let decrypter = Decrypter::new(params, key);
    let mut string = lopdf::Object::String(data.to_vec(), lopdf::StringFormat::Literal);
    let mut stream = lopdf::Object::Stream(lopdf::Stream::new(dict, data.to_vec()));
    for object in [&mut string, &mut stream] {
        if let Err(err) = decrypter.decrypt_object((7, 0), object, &limits) {
            assert!(expected(&err), "decrypting: {err}");
        }
    }
}

/// The whole open path on arbitrary bytes, with the password `"fuzz"` when the first byte is odd.
pub fn open_document(input: &[u8]) {
    let password = input
        .first()
        .filter(|byte| *byte % 2 == 1)
        .map(|_| Password::new("fuzz".to_owned()));
    let options = OpenOptions {
        password,
        limits: limits(),
    };
    match open(&Source::from_bytes(input.into()), &options) {
        Ok(document) => {
            assert_eq!(document.page_count(), document.structure().pages.len());
        }
        Err(err) => assert!(expected(&err), "opening: {err}"),
    }
}

/// The assembler's walk: the input as a file, and as objects from 10 on under a two-page file whose
/// first page's resources, annotations, field and bookmark are those objects, so the walk starts in
/// the input with no file to get past. Each page weighed and copied alone, then all of them; the
/// new file opens with the pages it was given. Any cycle or depth must stop at a limit.
pub fn assembler(input: &[u8]) {
    const HEAD: &[u8] = b"%PDF-1.7\n\
1 0 obj<</Type/Catalog/Pages 2 0 R/Outlines 10 0 R/AcroForm 11 0 R/OCProperties 12 0 R/Names 13 0 R>>endobj\n\
2 0 obj<</Type/Pages/Count 2/Kids[3 0 R 4 0 R]>>endobj\n\
3 0 obj<</Type/Page/Parent 2 0 R/Resources 14 0 R/Annots 15 0 R/Contents 16 0 R>>endobj\n\
4 0 obj<</Type/Page/Parent 2 0 R/Annots[17 0 R]>>endobj\n";
    let mut wrapped = HEAD.to_vec();
    wrapped.extend_from_slice(input);
    wrapped.extend_from_slice(b"\ntrailer<</Root 1 0 R>>\n");
    for file in [input, &wrapped] {
        let options = OpenOptions {
            password: None,
            limits: limits(),
        };
        let Ok(source) = open(&Source::from_bytes(file.into()), &options) else {
            continue;
        };
        let revisions = RevisionStore::new(&source);
        let count = revisions.pages(&source).len().min(16);
        let all: Vec<usize> = (0..count).collect();
        let parts = crate::assemble::ImportOptions {
            keep_forms: true,
            document_parts: true,
        };
        if count == 0 {
            continue;
        }
        check_assembly(&source, &revisions, &all, parts);
        for page in &all {
            check_assembly(&source, &revisions, std::slice::from_ref(page), parts);
        }
    }
}

fn check_assembly(
    source: &Document,
    revisions: &RevisionStore,
    pages: &[usize],
    options: crate::assemble::ImportOptions,
) {
    let run = || -> Result<Vec<u8>, CoreError> {
        let mut weighing = crate::assemble::PageImport::new(source, revisions, pages, options)?;
        for position in 0..pages.len() {
            weighing.weigh(position)?;
        }
        weighing.weigh_attachments()?;
        crate::assemble::assembled_size(source, revisions, pages, options)?;

        let doc = crate::assemble::new_document(&limits())?;
        let mut store = RevisionStore::new(&doc);
        store.begin()?;
        let mut import = crate::assemble::PageImport::new(source, revisions, pages, options)?;
        let targets = import.start(&mut store, &[])?;
        for position in 0..pages.len() {
            import.copy_page(&doc, &mut store, position)?;
        }
        import.finish(&doc, &mut store, Some("file"))?;
        let order: Vec<crate::pages::PageSlot> = targets
            .into_iter()
            .map(crate::pages::PageSlot::New)
            .collect();
        store.arrange_pages(&doc, &order)?;
        store.commit()?;
        store.full_rewrite(&doc)
    };
    match run() {
        Ok(bytes) => {
            let options = OpenOptions {
                password: None,
                limits: limits(),
            };
            match open(&Source::from_bytes(bytes.into()), &options) {
                Ok(out) => assert_eq!(out.page_count(), pages.len(), "pages of the new file"),
                Err(err) => assert!(
                    matches!(err, CoreError::ResourceLimit { .. }),
                    "reopening: {err}"
                ),
            }
        }
        Err(err) => assert!(expected(&err), "assembling: {err}"),
    }
}

/// The recovery journal's reader on `data` as it is, framed as one record (a checksum random bytes
/// never pass) and as a record's objects, and the manifest parser: records stay inside the data,
/// their objects parse or fail with an expected error, and a manifest it accepts reads back the
/// same from the JSON it writes.
pub fn recovery_journal(data: &[u8]) {
    let limits = limits();
    let parse = |body: &[u8]| {
        if let Err(err) = crate::recovery::parse_objects(body, &limits) {
            assert!(expected(&err), "the journal reader: {err}");
        }
    };
    parse(data);
    let framed = match crate::recovery::frame(data) {
        Ok(framed) => framed,
        Err(err) => panic!("framing: {err}"),
    };
    for bytes in [data, &framed] {
        let mut total = 0usize;
        for record in crate::recovery::records(bytes) {
            total = total.saturating_add(record.body().len());
            assert!(total <= bytes.len(), "records longer than the data");
            parse(record.body());
        }
    }
    if let Some(manifest) = crate::recovery::Manifest::parse(data) {
        assert_eq!(
            crate::recovery::Manifest::parse(manifest.to_json().as_bytes()),
            Some(manifest),
            "a manifest does not read back"
        );
    }
}

/// Each stream of page `index`'s `/Contents` as `store` has it, with its decoded data, for the
/// `edit_script` target.
///
/// # Errors
///
/// [`WriteError::NoSuchPage`](crate::WriteError::NoSuchPage), and the errors of decoding a stream.
pub fn page_streams(
    doc: &Document,
    store: &RevisionStore,
    index: usize,
) -> Result<Vec<(ObjectId, Vec<u8>)>, CoreError> {
    store.page_streams(doc, index)
}

/// The first `count` bytes of `script`, or all it has, moved past them.
fn take<'a>(script: &mut &'a [u8], count: usize) -> &'a [u8] {
    let (head, tail) = script.split_at(count.min(script.len()));
    *script = tail;
    head
}

/// A little-endian array from `script`, padded with zeros.
fn take_array<const N: usize>(script: &mut &[u8]) -> [u8; N] {
    let mut bytes = [0; N];
    for (to, from) in bytes.iter_mut().zip(take(script, N)) {
        *to = *from;
    }
    bytes
}

/// A direct object for the writer from `script`, of any kind.
fn script_object(script: &mut &[u8], depth: u32) -> Object {
    let [tag] = take_array(script);
    let length = usize::from(tag >> 4);
    // A name holds no NUL (ISO 32000-2 §7.3.5), and it is never empty.
    let name = |script: &mut &[u8]| {
        let mut name = vec![b'K'];
        name.extend(take(script, length).iter().filter(|byte| **byte != 0));
        name
    };
    let deeper = depth.saturating_add(1);
    match tag & 0x0F {
        1 => Object::Boolean(length % 2 == 1),
        2 => Object::Integer(i64::from_le_bytes(take_array(script))),
        3 => Object::Real(f32::from(i16::from_le_bytes(take_array(script))) / 4.0),
        4 => Object::Name(name(script)),
        5 => Object::String(take(script, length).to_vec(), StringFormat::Literal),
        6 => Object::String(
            take(script, length.saturating_mul(16)).to_vec(),
            StringFormat::Hexadecimal,
        ),
        7 if depth < 4 => Object::Array(
            (0..length % 5)
                .map(|_| script_object(script, deeper))
                .collect(),
        ),
        8 if depth < 4 => {
            let mut dict = Dictionary::new();
            for _ in 0..length % 5 {
                let key = name(script);
                dict.set(key, script_object(script, deeper));
            }
            Object::Dictionary(dict)
        }
        9 => Object::Reference((u32::from(tag).saturating_add(1), u16::from(tag & 1))),
        _ => Object::Null,
    }
}

/// Whether two dictionaries hold the same entries, but for the `/Length` the writer sets.
fn same_entries(written: &Dictionary, read: &Dictionary) -> bool {
    let entries = |dict: &Dictionary| dict.iter().filter(|(key, _)| *key != b"Length").count();
    entries(written) == entries(read)
        && written
            .iter()
            .filter(|(key, _)| *key != b"Length")
            .all(|(key, value)| read.get(key).is_ok_and(|other| same_object(value, other)))
}

/// Whether the object read back is the one written: a string in either form, a number whichever
/// way it reads (a real without a fraction is written as an integer).
fn same_object(written: &Object, read: &Object) -> bool {
    let number = |object: &Object| match object {
        Object::Integer(value) => Some(value.to_string()),
        Object::Real(value) => Some(value.to_string()),
        _ => None,
    };
    match (written, read) {
        (Object::String(a, _), Object::String(b, _)) => a == b,
        (Object::Array(a), Object::Array(b)) => {
            a.len() == b.len() && a.iter().zip(b).all(|(a, b)| same_object(a, b))
        }
        (Object::Dictionary(a), Object::Dictionary(b)) => same_entries(a, b),
        (Object::Stream(a), Object::Stream(b)) => {
            a.content == b.content && same_entries(&a.dict, &b.dict)
        }
        (Object::Real(_), _) | (_, Object::Real(_)) => number(written) == number(read),
        _ => written == read,
    }
}

/// A file of one empty page in the classic form or the modern one (object streams and a
/// cross-reference stream).
fn built_file(modern: bool) -> Vec<u8> {
    use lopdf::dictionary;

    let mut doc = lopdf::Document::with_version("1.7");
    let pages = doc.new_object_id();
    let page = doc.add_object(dictionary! {
        "Type" => "Page", "Parent" => pages,
        "MediaBox" => vec![0.into(), 0.into(), 612.into(), 792.into()],
    });
    let kids = dictionary! { "Type" => "Pages", "Kids" => vec![page.into()], "Count" => 1 };
    doc.objects.insert(pages, Object::Dictionary(kids));
    let catalog = doc.add_object(dictionary! { "Type" => "Catalog", "Pages" => pages });
    doc.trailer.set("Root", catalog);
    let mut bytes = Vec::new();
    let saved = if modern {
        doc.save_modern(&mut bytes).map(drop)
    } else {
        doc.save_to(&mut bytes).map(drop)
    };
    if let Err(err) = saved {
        panic!("building a file: {err}");
    }
    bytes
}

/// `bytes` opened with `password` under the fuzzing limits.
fn open_with(bytes: &[u8], password: Option<&str>) -> Result<Document, CoreError> {
    let options = OpenOptions {
        password: password.map(|password| Password::new(password.to_owned())),
        limits: limits(),
    };
    open(&Source::from_bytes(bytes.into()), &options)
}

/// One transaction's change from `script`: a new key on a page, a new stream or a new object.
fn script_change(
    script: &mut &[u8],
    doc: &Document,
    store: &mut RevisionStore,
    op: u8,
) -> Result<(), CoreError> {
    let value = script_object(script, 0);
    match op & 0x07 {
        0 | 1 => {
            let pages = &doc.structure().pages;
            let Some(page) = pages.get(usize::from(op >> 3) % pages.len().max(1)) else {
                return Ok(());
            };
            let mut dict = doc
                .model()
                .get_dictionary(page.id)
                .cloned()
                .unwrap_or_default();
            dict.set("FermanFuzz", value);
            store.put(page.id, Object::Dictionary(dict))
        }
        2 | 3 => {
            let [length] = take_array(script);
            let content = take(script, usize::from(length)).to_vec();
            let mut dict = Dictionary::new();
            dict.set("FermanFuzz", value);
            store
                .add(Object::Stream(lopdf::Stream::new(dict, content)))
                .map(drop)
        }
        _ => store.add(value).map(drop),
    }
}

/// The incremental writer: `input` as a file when it opens clean, and as a script of changes to
/// that file or to the built file or encrypted corpus file its first byte chooses. Two generations
/// are written, each on the last: the file before stays an exact prefix, the update reopens without
/// repair and with the same pages, and every object written reads back.
pub fn writer_round_trip(input: &[u8]) {
    const ENCRYPTED: [(&[u8], &str); 3] = [
        (
            include_bytes!("../../../tests/corpus/generated/payslip-aes128.pdf"),
            "bordro2026",
        ),
        (
            include_bytes!("../../../tests/corpus/generated/payslip-aes256.pdf"),
            "Eylül2026maaşı",
        ),
        (
            include_bytes!("../../../tests/corpus/generated/payslip-rc4-40.pdf"),
            "bordro2026",
        ),
    ];

    let mut script = input;
    let opens_clean = open_with(input, None).is_ok_and(|doc| doc.repair().is_none());
    let (mut bytes, password) = if opens_clean {
        (input.to_vec(), None)
    } else {
        let [choice] = take_array(&mut script);
        match usize::from(choice % 5)
            .checked_sub(2)
            .and_then(|at| ENCRYPTED.get(at))
        {
            Some((file, password)) => (file.to_vec(), Some(*password)),
            None => (built_file(choice % 5 == 1), None),
        }
    };

    let mut written = BTreeMap::new();
    for _ in 0..2 {
        let doc = match open_with(&bytes, password) {
            Ok(doc) => doc,
            Err(err) => panic!("a file that opened does not reopen: {err}"),
        };
        let mut store = RevisionStore::new(&doc);
        for _ in 0..8 {
            let [op] = take_array(&mut script);
            match op & 0x07 {
                6 => drop(store.undo()),
                7 => drop(store.redo()),
                _ => {
                    if let Err(err) = store
                        .begin()
                        .and_then(|()| script_change(&mut script, &doc, &mut store, op))
                    {
                        assert!(expected(&err), "a change: {err}");
                    }
                    if op & 0x80 != 0 {
                        store.rollback();
                    } else if let Err(err) = store.commit() {
                        panic!("a commit: {err}");
                    }
                }
            }
        }
        let saved = match store.incremental_update(&doc) {
            Ok(saved) => saved,
            Err(err) => {
                assert!(expected(&err), "the writer: {err}");
                return;
            }
        };
        assert!(saved.starts_with(&bytes), "the file before changed");
        written.extend(
            store
                .committed()
                .into_iter()
                .map(|(id, value)| (id, value.clone())),
        );
        let reopened = match open_with(&saved, password) {
            Ok(reopened) => reopened,
            // The update may be the one cross-reference section past the limit.
            Err(CoreError::ResourceLimit { .. }) => return,
            Err(err) => panic!("the update does not reopen: {err}"),
        };
        assert!(reopened.repair().is_none(), "the update needs repair");
        assert_eq!(reopened.page_count(), doc.page_count(), "the pages changed");
        for (id, value) in &written {
            match reopened.model().objects.get(id).ok_or("missing") {
                Ok(read) => assert!(
                    same_object(value, read),
                    "object {id:?} was written as {value:?} and reads {read:?}"
                ),
                Err(err) => panic!("object {id:?} does not read back: {err}"),
            }
        }
        bytes = saved;
    }
}
