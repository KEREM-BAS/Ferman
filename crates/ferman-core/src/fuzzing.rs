//! Entry points for the fuzz targets in `fuzz/` (docs/ARCHITECTURE.md §13.6), behind the
//! `fuzzing` feature, which nothing else enables. Each runs one parser on arbitrary bytes and
//! checks what it promises, panicking when a promise breaks so libFuzzer reports it.
// Fuzzing helpers: a broken promise panics on purpose.
#![allow(clippy::panic)]

use zeroize::Zeroizing;

use crate::CoreError;
use crate::content;
use crate::document::{OpenOptions, open};
use crate::interpret::{FontResource, TextShow, TextSink};
use crate::limits::Limits;
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
                show.span.end >= show.span.start,
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
