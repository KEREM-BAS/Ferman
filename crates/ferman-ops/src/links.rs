//! Link annotations (a3-6, G145): what creating, changing and deleting one writes, inside the open
//! transaction of a document's [`RevisionStore`], and which targets may be offered at all. Only
//! `http`, `https` and `mailto` are: a link's target is text from an untrusted file. A change sets
//! only what it names, so an action Ferman does not know stays as it came.

use ferman_core::links::LinkLook;
use ferman_core::revision::RevisionStore;
use ferman_core::write::{ObjectRef, Value};
use ferman_core::{CoreError, Document, WriteError};

use crate::OpsError;
use crate::annotations::{Ops, check_coordinates, name, normalized, numbers, plan_error};

/// `/F`: printed.
const PRINT: i64 = 4;

/// A target a link can be given.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NewLinkTarget {
    /// An `http` or `https` address.
    Web(String),
    /// An address, with or without `mailto:`.
    Mail(String),
    /// A page by its index.
    Page(usize),
}

/// What a link change sets; `None` leaves it.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct LinkChange {
    /// A new box, in user space. Its `/QuadPoints` go with the old one.
    pub rect: Option<[f32; 4]>,
    /// A new target, which replaces `/A` and `/Dest`.
    pub target: Option<NewLinkTarget>,
    /// A new border.
    pub look: Option<LinkLook>,
    /// `/C`.
    pub color: Option<[f32; 3]>,
}

/// What kind of address may be offered.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Offered {
    /// `http` or `https`.
    Web,
    /// `mailto`.
    Mail,
}

/// Whether `target` may be offered to the user to open, and as what: `http://` or `https://` with
/// a host, or `mailto:` with an address. Control characters, white space and format characters,
/// the direction controls among them, are refused anywhere: they make a target read as something else in the prompt, and a browser
/// strips some of them before it reads the scheme.
#[must_use]
pub fn offered(target: &str) -> Option<Offered> {
    let tricky = |c: char| {
        c.is_control()
            || c.is_whitespace()
            || matches!(
                c,
                '\u{AD}'
                    | '\u{600}'..='\u{605}'
                    | '\u{61C}'
                    | '\u{6DD}'
                    | '\u{70F}'
                    | '\u{8E2}'
                    | '\u{180E}'
                    | '\u{200B}'..='\u{200F}'
                    | '\u{202A}'..='\u{202E}'
                    | '\u{2060}'..='\u{206F}'
                    | '\u{FEFF}'
                    | '\u{FFF9}'..='\u{FFFB}'
                    | '\u{E0000}'..='\u{E007F}'
            )
    };
    if target.chars().any(tricky) {
        return None;
    }
    let (scheme, rest) = target.split_once(':')?;
    if scheme.eq_ignore_ascii_case("mailto") {
        return (!rest.is_empty()).then_some(Offered::Mail);
    }
    if !(scheme.eq_ignore_ascii_case("http") || scheme.eq_ignore_ascii_case("https")) {
        return None;
    }
    let host = rest.strip_prefix("//")?;
    let end = host.find(['/', '?', '#']).unwrap_or(host.len());
    let authority = host.get(..end).unwrap_or_default();
    let host = authority.rsplit('@').next().unwrap_or_default();
    (!host.is_empty() && !authority.contains('\\')).then_some(Offered::Web)
}

/// The `/A` of `target`.
fn action(
    document: &Document,
    revisions: &RevisionStore,
    target: &NewLinkTarget,
) -> Result<Value, OpsError> {
    let uri = |text: &str| {
        Value::Dictionary(vec![
            (b"S".to_vec(), name(b"URI")),
            (b"URI".to_vec(), Value::String(text.as_bytes().to_vec())),
        ])
    };
    match target {
        NewLinkTarget::Web(url) if offered(url) == Some(Offered::Web) => Ok(uri(url)),
        NewLinkTarget::Mail(address) => {
            let address = if address
                .get(..7)
                .is_some_and(|start| start.eq_ignore_ascii_case("mailto:"))
            {
                address.clone()
            } else {
                format!("mailto:{address}")
            };
            if offered(&address) == Some(Offered::Mail) {
                Ok(uri(&address))
            } else {
                Err(plan_error())
            }
        }
        NewLinkTarget::Page(page) => {
            let page = revisions
                .page_refs(document, &[*page])?
                .first()
                .copied()
                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
            Ok(Value::Dictionary(vec![
                (b"S".to_vec(), name(b"GoTo")),
                (
                    b"D".to_vec(),
                    Value::Array(vec![Value::Reference(page), name(b"Fit")]),
                ),
            ]))
        }
        NewLinkTarget::Web(_) => Err(plan_error()),
    }
}

fn border_entries(look: LinkLook) -> [(Vec<u8>, Value); 2] {
    let (width, style): (i64, &[u8]) = match look {
        LinkLook::Invisible => (0, b"S"),
        LinkLook::Underline => (1, b"U"),
        LinkLook::Box => (1, b"S"),
    };
    [
        (
            b"BS".to_vec(),
            Value::Dictionary(vec![
                (b"W".to_vec(), Value::Integer(width)),
                (b"S".to_vec(), name(style)),
            ]),
        ),
        (
            b"Border".to_vec(),
            Value::Array(vec![
                Value::Integer(0),
                Value::Integer(0),
                Value::Integer(width),
            ]),
        ),
    ]
}

/// The appearance of a border, since PDFium draws none from `/BS`; `None` for no line.
fn appearance(
    document: &Document,
    revisions: &mut RevisionStore,
    [l, b, r, t]: [f32; 4],
    look: LinkLook,
    color: [f32; 3],
) -> Result<Option<Value>, OpsError> {
    let mut ops = Ops::default();
    ops.stroke_colour(color).nums(&[1.0], "w");
    match look {
        LinkLook::Invisible => return Ok(None),
        LinkLook::Underline => {
            ops.moved([l, b + 0.5]).line([r, b + 0.5]).op("S");
        }
        LinkLook::Box => {
            ops.nums(&[l + 0.5, b + 0.5, r - l - 1.0, t - b - 1.0], "re")
                .op("S");
        }
    }
    let form = revisions.add_object(
        document,
        Value::Stream {
            dict: vec![
                (b"Type".to_vec(), name(b"XObject")),
                (b"Subtype".to_vec(), name(b"Form")),
                (b"BBox".to_vec(), numbers([l, b, r, t])),
            ],
            data: ops.0.into_bytes(),
        },
    )?;
    Ok(Some(Value::Dictionary(vec![(
        b"N".to_vec(),
        Value::Reference(form),
    )])))
}

/// Creates a link on page `page` over `rect` and returns its handle. `quads` are its text's lines,
/// eight numbers each, in the order [`Annotation::quads`](ferman_core::annotations) reads.
///
/// # Errors
///
/// [`WriteError::AnnotationPlan`] for a target that cannot be offered or a value out of range,
/// and the errors of the transaction.
#[allow(clippy::too_many_arguments)]
pub fn create(
    document: &Document,
    revisions: &mut RevisionStore,
    page: usize,
    rect: [f32; 4],
    quads: &[[f32; 8]],
    target: &NewLinkTarget,
    look: LinkLook,
    color: [f32; 3],
) -> Result<u64, OpsError> {
    check_coordinates(rect)?;
    check_coordinates(quads.iter().flatten().copied())?;
    let rect = normalized(rect);
    let on = revisions
        .page_refs(document, &[page])?
        .first()
        .copied()
        .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
    let mut dict = vec![
        (b"Type".to_vec(), name(b"Annot")),
        (b"Subtype".to_vec(), name(b"Link")),
        (b"P".to_vec(), Value::Reference(on)),
        (b"F".to_vec(), Value::Integer(PRINT)),
        (b"Rect".to_vec(), numbers(rect)),
        (b"C".to_vec(), numbers(color)),
        (b"A".to_vec(), action(document, revisions, target)?),
    ];
    dict.extend(border_entries(look));
    if !quads.is_empty() {
        dict.push((
            b"QuadPoints".to_vec(),
            numbers(quads.iter().flatten().copied()),
        ));
    }
    if let Some(entry) = appearance(document, revisions, rect, look, color)? {
        dict.push((b"AP".to_vec(), entry));
    }
    let link: ObjectRef = revisions.add_object(document, Value::Dictionary(dict))?;
    revisions.append_annotation(document, page, link)?;
    Ok(link.handle())
}

/// Applies `change` to link `handle` and returns its handle, new for one written directly in
/// `/Annots`. Only the keys it names are written.
///
/// # Errors
///
/// As [`create`], and [`WriteError::NoSuchAnnotation`].
pub fn update(
    document: &Document,
    revisions: &mut RevisionStore,
    handle: u64,
    change: &LinkChange,
) -> Result<u64, OpsError> {
    let list = revisions.links(document, None).links;
    let link = list
        .iter()
        .find(|link| link.handle == handle)
        .ok_or(CoreError::Write(WriteError::NoSuchAnnotation))?;
    let mut entries: Vec<(Vec<u8>, Option<Value>)> = Vec::new();
    let mut rect = link.rect;
    if let Some(new) = change.rect {
        check_coordinates(new)?;
        rect = normalized(new);
        entries.push((b"Rect".to_vec(), Some(numbers(rect))));
        entries.push((b"QuadPoints".to_vec(), None));
    }
    if let Some(target) = &change.target {
        entries.push((b"A".to_vec(), Some(action(document, revisions, target)?)));
        entries.push((b"Dest".to_vec(), None));
    }
    if let Some(color) = change.color {
        entries.push((b"C".to_vec(), Some(numbers(color))));
    }
    if let Some(look) = change.look {
        entries.extend(
            border_entries(look)
                .into_iter()
                .map(|(key, value)| (key, Some(value))),
        );
    }
    let look = change.look.unwrap_or(link.look);
    if change.look.is_some() || change.color.is_some() || change.rect.is_some() {
        let color = change.color.or(link.color).unwrap_or_default();
        let drawn = appearance(document, revisions, rect, look, color)?;
        entries.push((b"AP".to_vec(), drawn));
    }
    Ok(revisions
        .change_annotation(document, link.page, handle, entries)?
        .handle())
}

/// Deletes link `handle`.
///
/// # Errors
///
/// [`WriteError::NoSuchAnnotation`] and the errors of the transaction.
pub fn delete(
    document: &Document,
    revisions: &mut RevisionStore,
    handle: u64,
) -> Result<(), OpsError> {
    let page = revisions
        .links(document, None)
        .links
        .iter()
        .find(|link| link.handle == handle)
        .map(|link| link.page)
        .ok_or(CoreError::Write(WriteError::NoSuchAnnotation))?;
    revisions.drop_annotation(document, page, handle)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_web_and_mail_are_offered() {
        for good in [
            "http://example.org",
            "HTTPS://example.org/a?b=c#d",
            "https://user@example.org/",
        ] {
            assert_eq!(offered(good), Some(Offered::Web), "{good}");
        }
        assert_eq!(offered("mailto:a@example.org"), Some(Offered::Mail));
        for bad in [
            "javascript:alert(1)",
            "JaVaScRiPt:alert(1)",
            " javascript:alert(1)",
            "java\tscript:alert(1)",
            "file:///etc/passwd",
            "FILE://server/share",
            "data:text/html,x",
            "smb://host/share",
            "http:",
            "http://",
            "https:example.org",
            "https://@/",
            "https:\\\\example.org",
            "https://exam\u{202E}ple.org",
            "https://1.2\u{61C}.3.4/",
            "https://exam\u{AD}ple.org",
            "https://example.org/\u{E0041}",
            "https://example.org\n",
            "mailto:",
            "example.org",
            "",
        ] {
            assert_eq!(offered(bad), None, "{bad:?}");
        }
    }
}
