//! Link annotations through the revisions of a document (a3-6, M4 plan W2, decision 13): what each
//! says, with limits on the walk. Nothing here follows anything. What a link does is read, not run:
//! an action Ferman does not offer is named and stays in the file as it came, `/Next` chains too.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::BTreeSet;

use lopdf::{Dictionary, Object};

use crate::annotations::{
    Budget, MAX_NUMBERS, MAX_PER_DOCUMENT, MAX_PER_PAGE, MAX_TEXTS, colour, direct_handle,
    entry_numbers, handle_of,
};
use crate::revision::RevisionStore;
use crate::structure::navigation::Named;
use crate::structure::{Page, Scope};
use crate::{Document, text_string};

/// The longest link target kept, in bytes; a longer one reads as [`LinkAction::Other`].
pub const MAX_TARGET: usize = 8 * 1024;

/// What a link does.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LinkAction {
    /// `/URI`, as the file has it: nothing says it can be opened.
    Uri(String),
    /// A destination in this document, `/Dest` or `/GoTo`, explicit or named.
    Destination {
        /// The page's index, `None` when the destination leads nowhere.
        page: Option<usize>,
        /// The page number, from 1, of an integer destination, which may be past the last page.
        wanted: Option<u64>,
        /// The destination's name, for a named one.
        name: Option<String>,
    },
    /// `/GoToR` or `/GoToE`: another file, as the file names it.
    OtherFile(String),
    /// `/Launch`: a program or a file, as the file names it. It never runs.
    Launch(String),
    /// `/JavaScript`. It never runs.
    Script,
    /// Any other action, by its `/S`.
    Other(String),
    /// No action.
    Nothing,
}

/// A link's border, as far as it is drawn.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LinkLook {
    /// No line.
    Invisible,
    /// A line under it.
    Underline,
    /// A thin box.
    Box,
}

/// One link, in the page's user space.
#[derive(Debug, Clone, PartialEq)]
pub struct Link {
    /// Its identity, as an annotation's.
    pub handle: u64,
    /// Its page's index.
    pub page: usize,
    /// `/Rect`, as left, bottom, right and top.
    pub rect: [f32; 4],
    /// `/QuadPoints`, eight numbers each.
    pub quads: Vec<[f32; 8]>,
    /// What it does.
    pub action: LinkAction,
    /// Its border.
    pub look: LinkLook,
    /// `/C` as red, green and blue.
    pub color: Option<[f32; 3]>,
}

/// A document's links.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct LinkList {
    /// In page order, each page in `/Annots` order.
    pub links: Vec<Link>,
    /// Whether a limit cut the list short.
    pub truncated: bool,
}

/// A string entry within [`MAX_TARGET`], as text.
fn target_text(scope: &Scope<'_>, object: &Object) -> Option<String> {
    match scope.resolve(object)? {
        Object::String(bytes, _) | Object::Name(bytes) if bytes.len() <= MAX_TARGET => {
            Some(text_string::decode(bytes))
        }
        _ => None,
    }
}

/// The file `/F` names: a string, or a file specification's `/UF` or `/F`.
fn file_name(scope: &Scope<'_>, action: &Dictionary) -> String {
    let Some(file) = action.get(b"F").ok().and_then(|file| scope.resolve(file)) else {
        return String::new();
    };
    if let Ok(spec) = file.as_dict() {
        return [&b"UF"[..], b"F"]
            .iter()
            .find_map(|key| target_text(scope, spec.get(key).ok()?))
            .unwrap_or_default();
    }
    target_text(scope, file).unwrap_or_default()
}

fn destination<'a>(
    scope: &Scope<'a>,
    named: &Named<'a>,
    item: &'a Dictionary,
    dest: &'a Object,
) -> LinkAction {
    let page = named
        .target(scope, item)
        .and_then(|page| usize::try_from(page).ok());
    let resolved = scope.resolve(dest);
    let name = resolved.and_then(|dest| match dest {
        Object::Name(_) | Object::String(..) => target_text(scope, dest),
        _ => None,
    });
    let wanted = resolved
        .and_then(|dest| dest.as_array().ok())
        .and_then(|items| items.first())
        .and_then(|first| first.as_i64().ok())
        .and_then(|index| u64::try_from(index).ok())
        .map(|index| index.saturating_add(1));
    LinkAction::Destination { page, wanted, name }
}

fn action_of<'a>(scope: &Scope<'a>, named: &Named<'a>, link: &'a Dictionary) -> LinkAction {
    if let Ok(dest) = link.get(b"Dest") {
        return destination(scope, named, link, dest);
    }
    let Some(action) = scope.get_dict(link, b"A") else {
        return LinkAction::Nothing;
    };
    let kind = scope.get_name(action, b"S").unwrap_or_default();
    match kind {
        b"URI" => action
            .get(b"URI")
            .ok()
            .and_then(|uri| target_text(scope, uri))
            .map_or_else(|| LinkAction::Other("URI".to_owned()), LinkAction::Uri),
        b"GoTo" => match action.get(b"D") {
            Ok(dest) => destination(scope, named, link, dest),
            Err(_) => LinkAction::Destination {
                page: None,
                wanted: None,
                name: None,
            },
        },
        b"GoToR" | b"GoToE" => LinkAction::OtherFile(file_name(scope, action)),
        b"Launch" => LinkAction::Launch(file_name(scope, action)),
        b"JavaScript" => LinkAction::Script,
        other => LinkAction::Other(String::from_utf8_lossy(other).into_owned()),
    }
}

fn look_of(scope: &Scope<'_>, link: &Dictionary, budget: &mut Budget) -> LinkLook {
    if let Some(style) = scope.get_dict(link, b"BS") {
        let width = entry_or_one(scope, style);
        if width <= 0.0 {
            return LinkLook::Invisible;
        }
        return if scope.get_name(style, b"S") == Some(b"U") {
            LinkLook::Underline
        } else {
            LinkLook::Box
        };
    }
    match entry_numbers(scope, link, b"Border", budget).get(2) {
        Some(width) if *width <= 0.0 => LinkLook::Invisible,
        // The default border is a solid line one point wide.
        _ => LinkLook::Box,
    }
}

fn entry_or_one(scope: &Scope<'_>, style: &Dictionary) -> f32 {
    style
        .get(b"W")
        .ok()
        .and_then(|width| scope.resolve(width))
        .and_then(crate::structure::number)
        .unwrap_or(1.0)
}

fn read_one<'a>(
    scope: &Scope<'a>,
    named: &Named<'a>,
    dict: &'a Dictionary,
    (handle, page): (u64, usize),
    budget: &mut Budget,
) -> Link {
    let rect = entry_numbers(scope, dict, b"Rect", budget);
    let rect = if let [x0, y0, x1, y1] = *rect.as_slice() {
        [x0.min(x1), y0.min(y1), x0.max(x1), y0.max(y1)]
    } else {
        [0.0; 4]
    };
    let quads = entry_numbers(scope, dict, b"QuadPoints", budget)
        .as_chunks::<8>()
        .0
        .to_vec();
    let color = colour(&entry_numbers(scope, dict, b"C", budget));
    Link {
        handle,
        page,
        rect,
        quads,
        action: action_of(scope, named, dict),
        look: look_of(scope, dict, budget),
        color,
    }
}

impl Link {
    /// Whether a click at `(x, y)` in user space lands on it: its quads when it has them, as
    /// ISO 32000-2 Table 176 says, else its rectangle.
    // shortcut: a quad counts as its bounding box; test the quad itself if slanted link text is
    // ever seen.
    #[must_use]
    pub fn contains(&self, x: f32, y: f32) -> bool {
        let inside = |[l, b, r, t]: [f32; 4]| x >= l && x <= r && y >= b && y <= t;
        if self.quads.is_empty() {
            return inside(self.rect);
        }
        self.quads.iter().any(|quad| {
            let (xs, ys): (Vec<f32>, Vec<f32>) = quad
                .as_chunks::<2>()
                .0
                .iter()
                .map(|[x, y]| (*x, *y))
                .unzip();
            let least = |values: &[f32]| values.iter().copied().fold(f32::INFINITY, f32::min);
            let most = |values: &[f32]| values.iter().copied().fold(f32::NEG_INFINITY, f32::max);
            inside([least(&xs), least(&ys), most(&xs), most(&ys)])
        })
    }
}

impl RevisionStore {
    /// The links of every page, or of page `only`, as these revisions leave them.
    #[must_use]
    pub fn links(&self, doc: &Document, only: Option<usize>) -> LinkList {
        let pages: &[Page] = self.pages(doc);
        let mut scope = self.scope(doc);
        scope.page_of = pages
            .iter()
            .enumerate()
            .filter_map(|(index, page)| Some((page.id, u32::try_from(index).ok()?)))
            .rev()
            .collect();
        let named = Named::new(&scope);
        let mut budget = Budget {
            numbers: MAX_NUMBERS,
            text: MAX_TEXTS,
            truncated: false,
        };
        let mut list = LinkList::default();
        let mut seen = BTreeSet::new();
        'pages: for (index, page) in pages.iter().enumerate() {
            if only.is_some_and(|only| only != index) {
                continue;
            }
            let Some(items) = scope
                .dictionary(page.id)
                .and_then(|dict| scope.get_array(dict, b"Annots"))
            else {
                continue;
            };
            budget.truncated |= items.len() > MAX_PER_PAGE;
            let mut direct = 0usize;
            for item in items.iter().take(MAX_PER_PAGE) {
                if list.links.len() >= MAX_PER_DOCUMENT {
                    budget.truncated = true;
                    break 'pages;
                }
                let handle = if let Ok(id) = item.as_reference() {
                    if !seen.insert(id) {
                        continue;
                    }
                    handle_of(id)
                } else {
                    direct = direct.saturating_add(1);
                    direct_handle(page.id, direct.saturating_sub(1))
                };
                let Some(dict) = scope.dict(item) else {
                    continue;
                };
                if scope.get_name(dict, b"Subtype") != Some(b"Link") {
                    continue;
                }
                let link = read_one(&scope, &named, dict, (handle, index), &mut budget);
                let spent = match &link.action {
                    LinkAction::Uri(text)
                    | LinkAction::OtherFile(text)
                    | LinkAction::Launch(text)
                    | LinkAction::Other(text) => text.len(),
                    LinkAction::Destination { name, .. } => name.as_ref().map_or(0, String::len),
                    LinkAction::Script | LinkAction::Nothing => 0,
                };
                let Some(left) = budget.text.checked_sub(spent) else {
                    budget.truncated = true;
                    break 'pages;
                };
                budget.text = left;
                list.links.push(link);
            }
        }
        list.truncated = budget.truncated;
        list
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::{Dictionary, StringFormat, dictionary};

    use super::*;
    use crate::structure::tests::doc_with;
    use crate::{OpenOptions, Source, open};

    fn string(text: &str) -> Object {
        Object::String(text.as_bytes().to_vec(), StringFormat::Literal)
    }

    fn opened(annots: Vec<Object>, page_two: Dictionary) -> Document {
        let mut doc = doc_with(
            vec![dictionary! { "Annots" => annots }, page_two],
            dictionary! {},
        );
        let mut bytes = Vec::new();
        doc.save_to(&mut bytes).unwrap();
        open(
            &Source::from_bytes(Arc::from(&bytes[..])),
            &OpenOptions::default(),
        )
        .unwrap()
    }

    fn link(action: Dictionary) -> Object {
        Object::Dictionary(dictionary! {
            "Subtype" => "Link",
            "Rect" => vec![10.into(), 10.into(), 50.into(), 30.into()],
            "A" => action,
        })
    }

    #[test]
    fn each_action_is_named_and_nothing_else_is_listed() {
        let doc = opened(
            vec![
                link(dictionary! { "S" => "URI", "URI" => string("https://example.org/a") }),
                link(dictionary! { "S" => "JavaScript", "JS" => string("app.alert(1)") }),
                link(dictionary! { "S" => "Launch", "F" => string("calc.exe") }),
                link(
                    dictionary! { "S" => "GoToR", "F" => dictionary! { "UF" => string("b.pdf") } },
                ),
                link(dictionary! { "S" => "Named", "N" => "NextPage" }),
                link(dictionary! { "S" => "GoTo", "D" => vec![Object::Integer(7), "Fit".into()] }),
                link(dictionary! { "S" => "GoTo", "D" => vec![Object::Integer(1), "Fit".into()] }),
                link(dictionary! { "S" => "URI", "URI" => string(&"x".repeat(MAX_TARGET + 1)) }),
                Object::Dictionary(dictionary! { "Subtype" => "Text" }),
            ],
            dictionary! {},
        );
        let actions: Vec<LinkAction> = RevisionStore::new(&doc)
            .links(&doc, None)
            .links
            .into_iter()
            .map(|link| link.action)
            .collect();
        assert_eq!(
            actions,
            [
                LinkAction::Uri("https://example.org/a".to_owned()),
                LinkAction::Script,
                LinkAction::Launch("calc.exe".to_owned()),
                LinkAction::OtherFile("b.pdf".to_owned()),
                LinkAction::Other("Named".to_owned()),
                LinkAction::Destination {
                    page: None,
                    wanted: Some(8),
                    name: None
                },
                LinkAction::Destination {
                    page: Some(1),
                    wanted: Some(2),
                    name: None
                },
                LinkAction::Other("URI".to_owned()),
            ]
        );
    }

    #[test]
    fn a_click_lands_on_the_quads_when_there_are_some() {
        let mut one = Link {
            handle: 1,
            page: 0,
            rect: [0.0, 0.0, 100.0, 100.0],
            quads: Vec::new(),
            action: LinkAction::Nothing,
            look: LinkLook::Invisible,
            color: None,
        };
        assert!(one.contains(50.0, 50.0));
        one.quads
            .push([10.0, 20.0, 30.0, 20.0, 10.0, 10.0, 30.0, 10.0]);
        assert!(!one.contains(50.0, 50.0));
        assert!(one.contains(20.0, 15.0));
    }
}
