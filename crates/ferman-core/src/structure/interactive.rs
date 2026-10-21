//! Layers, form fields and XFA, signatures and certification, and document JavaScript
//! (ISO 32000-2 §8.11, §12.7, §12.8 and §12.6.4.17).
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::BTreeSet;

use lopdf::{Dictionary, Object, ObjectId};

use super::navigation::names;
use super::{PdfDate, Scope};

/// One optional content group (layer), in the order `/Order` shows it (a2-3c).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Layer {
    /// `/Name`.
    pub name: String,
    /// Whether the default configuration shows it.
    pub visible: bool,
    /// Whether the default configuration locks its visibility.
    pub locked: bool,
    /// Its nesting in `/Order`, from 0.
    pub depth: u32,
    /// The group.
    pub(crate) id: ObjectId,
}

/// Form fields and XFA (a11-7c).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Forms {
    /// Terminal fields of the AcroForm.
    pub fields: u32,
    /// Whether the AcroForm carries XFA.
    pub has_xfa: bool,
    /// Whether the form needs an XFA viewer: XFA with no AcroForm fields, or `/NeedsRendering`.
    /// Ferman ships a PDFium without XFA, so such a form opens read-only with an explanation.
    pub xfa_only: bool,
}

/// One signature field (a2-14): shown neutrally until checking arrives (G31).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Signature {
    /// The field's full name.
    pub field: String,
    /// Whether it holds a signature.
    pub signed: bool,
    /// The signer's name as the signature writes it (`/Name`).
    pub signer: Option<String>,
    /// When it was signed (`/M`), as the signature writes it.
    pub signed_at: Option<PdfDate>,
    /// The page of its widget.
    pub page: Option<u32>,
}

/// Document JavaScript (Q13, G100): Ferman never runs it and tells the user it is there.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct Scripts {
    /// Every JavaScript action found.
    pub count: u32,
    /// Those at document level: the `/JavaScript` name tree, `/OpenAction` and the catalog's
    /// `/AA`.
    pub document: u32,
    /// Those in pages' `/AA`.
    pub pages: u32,
    /// Those in annotations, form widgets and fields.
    pub annotations: u32,
}

/// The layers in `/Order`'s order, or in `/OCGs` order without one.
pub(crate) fn layers(scope: &Scope<'_>) -> Vec<Layer> {
    let Some(properties) = scope
        .catalog()
        .and_then(|catalog| scope.get_dict(catalog, b"OCProperties"))
    else {
        return Vec::new();
    };
    let groups: Vec<ObjectId> = scope
        .get_array(properties, b"OCGs")
        .map(|groups| {
            groups
                .iter()
                .filter_map(|group| group.as_reference().ok())
                .collect()
        })
        .unwrap_or_default();
    let config = scope.get_dict(properties, b"D");
    let ids = |key: &[u8]| -> BTreeSet<ObjectId> {
        config
            .and_then(|config| scope.get_array(config, key))
            .map(|items| {
                items
                    .iter()
                    .filter_map(|item| item.as_reference().ok())
                    .collect()
            })
            .unwrap_or_default()
    };
    let (on, off, locked) = (ids(b"ON"), ids(b"OFF"), ids(b"Locked"));
    let base_off = config.and_then(|config| scope.get_name(config, b"BaseState")) == Some(b"OFF");
    let make = |id: ObjectId, depth: u32| -> Option<Layer> {
        let group = scope.doc.get_dictionary(id).ok()?;
        Some(Layer {
            name: scope.get_text(group, b"Name").unwrap_or_default(),
            visible: if base_off {
                on.contains(&id)
            } else {
                !off.contains(&id)
            },
            locked: locked.contains(&id),
            depth,
            id,
        })
    };
    let known: BTreeSet<ObjectId> = groups.iter().copied().collect();
    let mut out = Vec::new();
    match config.and_then(|config| scope.get_array(config, b"Order")) {
        Some(order) => {
            let mut seen = BTreeSet::new();
            let mut stack: Vec<(std::slice::Iter<'_, Object>, u32)> = vec![(order.iter(), 0)];
            while let Some((items, depth)) = stack.last_mut() {
                let depth = *depth;
                let Some(item) = items.next() else {
                    stack.pop();
                    continue;
                };
                match item {
                    Object::Reference(id) if known.contains(id) => {
                        if seen.insert(*id)
                            && let Some(layer) = make(*id, depth)
                        {
                            out.push(layer);
                        }
                    }
                    Object::Array(children)
                        if u32::try_from(stack.len()).unwrap_or(u32::MAX)
                            < scope.limits.max_nesting =>
                    {
                        stack.push((children.iter(), depth.saturating_add(1)));
                    }
                    _ => {}
                }
            }
        }
        None => out.extend(groups.iter().filter_map(|id| make(*id, 0))),
    }
    out
}

/// The AcroForm's fields, XFA and signature fields.
pub(crate) fn forms(scope: &Scope<'_>) -> (Forms, Vec<Signature>) {
    let Some(form) = scope
        .catalog()
        .and_then(|catalog| scope.get_dict(catalog, b"AcroForm"))
    else {
        return (Forms::default(), Vec::new());
    };
    let mut forms = Forms {
        has_xfa: form.has(b"XFA"),
        ..Forms::default()
    };
    let mut signatures = Vec::new();
    let mut seen = BTreeSet::new();
    // A stack of (field, full name of its parent, inherited /FT, depth).
    let mut stack: Vec<(&Object, String, Option<&[u8]>, u32)> = scope
        .get_array(form, b"Fields")
        .map(|fields| {
            fields
                .iter()
                .rev()
                .map(|field| (field, String::new(), None, 0))
                .collect()
        })
        .unwrap_or_default();
    while let Some((field, parent_name, parent_type, depth)) = stack.pop() {
        if let Ok(id) = field.as_reference()
            && !seen.insert(id)
        {
            continue;
        }
        let Some(dict) = scope.dict(field) else {
            continue;
        };
        let partial = scope.get_text(dict, b"T");
        let name = match (&partial, parent_name.is_empty()) {
            (Some(partial), true) => partial.clone(),
            (Some(partial), false) => format!("{parent_name}.{partial}"),
            (None, _) => parent_name.clone(),
        };
        let kind = scope.get_name(dict, b"FT").or(parent_type);
        // Kids with a /T are fields; kids without are its widgets.
        let kid_fields: Vec<&Object> = scope
            .get_array(dict, b"Kids")
            .map(|kids| {
                kids.iter()
                    .filter(|kid| scope.dict(kid).is_some_and(|kid| kid.has(b"T")))
                    .collect()
            })
            .unwrap_or_default();
        if !kid_fields.is_empty() && depth < scope.limits.max_nesting {
            for kid in kid_fields.into_iter().rev() {
                stack.push((kid, name.clone(), kind, depth.saturating_add(1)));
            }
            continue;
        }
        forms.fields = forms.fields.saturating_add(1);
        if kind == Some(b"Sig") {
            signatures.push(signature(scope, field, dict, name));
        }
    }
    let needs_rendering = scope
        .catalog()
        .is_some_and(|catalog| matches!(catalog.get(b"NeedsRendering"), Ok(Object::Boolean(true))));
    forms.xfa_only = forms.has_xfa && (forms.fields == 0 || needs_rendering);
    (forms, signatures)
}

fn signature(scope: &Scope<'_>, field: &Object, dict: &Dictionary, name: String) -> Signature {
    let value = scope.get_dict(dict, b"V");
    // The widget: the field itself when merged, or its first kid.
    let widget_page = |widget: &Object| -> Option<u32> {
        if let Some(page) = widget
            .as_reference()
            .ok()
            .and_then(|id| scope.annotation_page.get(&id))
        {
            return Some(*page);
        }
        let widget = scope.dict(widget)?;
        let page = widget.get(b"P").ok()?.as_reference().ok()?;
        scope.page_of.get(&page).copied()
    };
    let page =
        widget_page(field).or_else(|| scope.get_array(dict, b"Kids")?.iter().find_map(widget_page));
    Signature {
        field: name,
        signed: value.is_some(),
        signer: value.and_then(|value| scope.get_text(value, b"Name")),
        signed_at: value.and_then(|value| scope.get_date(value, b"M")),
        page,
    }
}

/// The `/DocMDP` level of a certification signature (`/Perms /DocMDP`), 2 by default.
pub(crate) fn certification(scope: &Scope<'_>) -> Option<u8> {
    let signature = scope
        .catalog()
        .and_then(|catalog| scope.get_dict(catalog, b"Perms"))
        .and_then(|perms| scope.get_dict(perms, b"DocMDP"))?;
    let level = scope
        .get_array(signature, b"Reference")
        .into_iter()
        .flatten()
        .filter_map(|reference| scope.dict(reference))
        .find(|reference| scope.get_name(reference, b"TransformMethod") == Some(b"DocMDP"))
        .and_then(|reference| scope.get_dict(reference, b"TransformParams"))
        .and_then(|params| scope.get_int(params, b"P"))
        .and_then(|level| u8::try_from(level).ok())
        .filter(|level| (1..=3).contains(level));
    Some(level.unwrap_or(2))
}

/// The JavaScript actions in `action` and its `/Next` chain.
fn javascript(scope: &Scope<'_>, action: &Object, seen: &mut BTreeSet<ObjectId>) -> u32 {
    let mut count = 0u32;
    let mut stack = vec![(action, 0u32)];
    while let Some((action, depth)) = stack.pop() {
        if let Ok(id) = action.as_reference()
            && !seen.insert(id)
        {
            continue;
        }
        let Some(dict) = scope.dict(action) else {
            continue;
        };
        if scope.get_name(dict, b"S") == Some(b"JavaScript") {
            count = count.saturating_add(1);
        }
        if depth >= scope.limits.max_nesting {
            continue;
        }
        match dict.get(b"Next").ok().and_then(|next| scope.resolve(next)) {
            Some(Object::Array(next)) => {
                stack.extend(next.iter().map(|next| (next, depth.saturating_add(1))));
            }
            Some(_) => {
                if let Ok(next) = dict.get(b"Next") {
                    stack.push((next, depth.saturating_add(1)));
                }
            }
            None => {}
        }
    }
    count
}

/// The JavaScript actions of an additional-actions dictionary.
fn additional(scope: &Scope<'_>, owner: &Dictionary, seen: &mut BTreeSet<ObjectId>) -> u32 {
    scope
        .get_dict(owner, b"AA")
        .map(|actions| {
            actions
                .iter()
                .map(|(_, action)| javascript(scope, action, seen))
                .fold(0u32, u32::saturating_add)
        })
        .unwrap_or(0)
}

/// Every JavaScript action in the document.
pub(crate) fn scripts(scope: &Scope<'_>) -> Scripts {
    let mut seen = BTreeSet::new();
    let mut scripts = Scripts::default();
    let add = |total: &mut u32, count: u32| *total = total.saturating_add(count);
    for (_, action) in names(scope, b"JavaScript") {
        let count = javascript(scope, action, &mut seen);
        add(&mut scripts.document, count);
    }
    if let Some(catalog) = scope.catalog() {
        if let Ok(open) = catalog.get(b"OpenAction")
            && scope.dict(open).is_some()
        {
            let count = javascript(scope, open, &mut seen);
            add(&mut scripts.document, count);
        }
        let count = additional(scope, catalog, &mut seen);
        add(&mut scripts.document, count);
    }
    let mut annotations_seen = BTreeSet::new();
    for page in scope.page_of.keys() {
        let Ok(page) = scope.doc.get_dictionary(*page) else {
            continue;
        };
        let count = additional(scope, page, &mut seen);
        add(&mut scripts.pages, count);
    }
    for annotation in scope.annotation_page.keys() {
        annotations_seen.insert(*annotation);
        let Ok(annotation) = scope.doc.get_dictionary(*annotation) else {
            continue;
        };
        if let Ok(action) = annotation.get(b"A") {
            let count = javascript(scope, action, &mut seen);
            add(&mut scripts.annotations, count);
        }
        let count = additional(scope, annotation, &mut seen);
        add(&mut scripts.annotations, count);
    }
    // Fields that are not also a page's widget: their /AA (calculate, validate, format).
    if let Some(form) = scope
        .catalog()
        .and_then(|catalog| scope.get_dict(catalog, b"AcroForm"))
    {
        let mut stack: Vec<(&Object, u32)> = scope
            .get_array(form, b"Fields")
            .map(|fields| fields.iter().map(|field| (field, 0)).collect())
            .unwrap_or_default();
        let mut fields_seen = BTreeSet::new();
        while let Some((field, depth)) = stack.pop() {
            let Ok(id) = field.as_reference() else {
                continue;
            };
            if !fields_seen.insert(id) {
                continue;
            }
            let Some(dict) = scope.dict(field) else {
                continue;
            };
            if !annotations_seen.contains(&id) {
                let count = additional(scope, dict, &mut seen);
                add(&mut scripts.annotations, count);
            }
            if depth < scope.limits.max_nesting
                && let Some(kids) = scope.get_array(dict, b"Kids")
            {
                stack.extend(kids.iter().map(|kid| (kid, depth.saturating_add(1))));
            }
        }
    }
    scripts.count = scripts
        .document
        .saturating_add(scripts.pages)
        .saturating_add(scripts.annotations);
    scripts
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::super::scan;
    use super::super::tests::doc_with;
    use crate::limits::Limits;
    use lopdf::{Document, Object, dictionary};

    fn catalog_set(doc: &mut Document, key: &str, value: impl Into<Object>) {
        let catalog = doc.trailer.get(b"Root").unwrap().as_reference().unwrap();
        doc.get_dictionary_mut(catalog).unwrap().set(key, value);
    }

    #[test]
    fn layers_follow_the_order_and_the_default_state() {
        let mut doc = doc_with(vec![dictionary! {}], dictionary! {});
        let walls = doc.add_object(
            dictionary! { "Type" => "OCG", "Name" => Object::string_literal("Duvarlar") },
        );
        let pipes = doc.add_object(
            dictionary! { "Type" => "OCG", "Name" => Object::string_literal("Tesisat") },
        );
        let notes = doc.add_object(
            dictionary! { "Type" => "OCG", "Name" => Object::string_literal("Notlar") },
        );
        catalog_set(
            &mut doc,
            "OCProperties",
            dictionary! {
                "OCGs" => vec![walls.into(), pipes.into(), notes.into()],
                "D" => dictionary! {
                    "OFF" => vec![pipes.into()],
                    "Locked" => vec![walls.into()],
                    "Order" => vec![walls.into(), Object::Array(vec![Object::string_literal("Grup"), pipes.into()]), notes.into()],
                },
            },
        );
        let layers = scan(&doc, &Limits::default()).layers;
        let summary: Vec<(&str, bool, bool, u32)> = layers
            .iter()
            .map(|layer| {
                (
                    layer.name.as_str(),
                    layer.visible,
                    layer.locked,
                    layer.depth,
                )
            })
            .collect();
        assert_eq!(
            summary,
            [
                ("Duvarlar", true, true, 0),
                ("Tesisat", false, false, 1),
                ("Notlar", true, false, 0)
            ]
        );
    }

    #[test]
    fn fields_signatures_xfa_and_scripts_are_counted() {
        let mut doc = doc_with(vec![dictionary! {}], dictionary! {});
        let page = doc.page_iter().next().unwrap();
        let js =
            |code: &str| dictionary! { "S" => "JavaScript", "JS" => Object::string_literal(code) };
        let widget_name = doc.add_object(dictionary! {
            "Type" => "Annot", "Subtype" => "Widget", "FT" => "Tx", "T" => Object::string_literal("ad"),
            "P" => page, "AA" => dictionary! { "K" => js("AFDate_KeystrokeEx('dd.mm.yyyy')") },
        });
        let signed = doc.add_object(dictionary! {
            "Type" => "Sig", "Name" => lopdf::text_string("Ayşe Kaya"),
            "M" => Object::string_literal("D:20261005101500+03'00'"),
        });
        let sig_widget =
            doc.add_object(dictionary! { "Type" => "Annot", "Subtype" => "Widget", "P" => page });
        let sig_field = doc.add_object(dictionary! {
            "FT" => "Sig", "T" => Object::string_literal("imza"), "V" => signed, "Kids" => vec![sig_widget.into()],
        });
        let child = doc.add_object(dictionary! { "T" => Object::string_literal("il") });
        let parent = doc.add_object(dictionary! {
            "FT" => "Ch", "T" => Object::string_literal("adres"), "Kids" => vec![child.into()],
            "AA" => dictionary! { "C" => js("hesapla()") },
        });
        doc.get_dictionary_mut(page)
            .unwrap()
            .set("Annots", vec![widget_name.into(), sig_widget.into()]);
        doc.get_dictionary_mut(page)
            .unwrap()
            .set("AA", dictionary! { "O" => js("acildi()") });
        catalog_set(
            &mut doc,
            "AcroForm",
            dictionary! { "Fields" => vec![widget_name.into(), sig_field.into(), parent.into()], "XFA" => Object::Array(vec![]) },
        );
        catalog_set(&mut doc, "OpenAction", js("app.alert(1)"));
        let structure = scan(&doc, &Limits::default());
        assert_eq!(structure.forms.fields, 3);
        assert!(structure.forms.has_xfa);
        assert!(!structure.forms.xfa_only);
        assert_eq!(structure.signatures.len(), 1);
        let signature = &structure.signatures[0];
        assert_eq!(signature.field, "imza");
        assert!(signature.signed);
        assert_eq!(signature.signer.as_deref(), Some("Ayşe Kaya"));
        assert_eq!(signature.page, Some(0));
        assert_eq!(signature.signed_at.map(|date| date.hour), Some(10));
        let scripts = structure.scripts;
        assert_eq!(
            (
                scripts.document,
                scripts.pages,
                scripts.annotations,
                scripts.count
            ),
            (1, 1, 2, 4)
        );
    }

    #[test]
    fn an_xfa_form_without_fields_needs_an_xfa_viewer() {
        let mut doc = doc_with(vec![dictionary! {}], dictionary! {});
        catalog_set(
            &mut doc,
            "AcroForm",
            dictionary! { "Fields" => Object::Array(vec![]), "XFA" => Object::Array(vec![]) },
        );
        catalog_set(&mut doc, "NeedsRendering", true);
        let forms = scan(&doc, &Limits::default()).forms;
        assert!(forms.has_xfa && forms.xfa_only);
        assert_eq!(forms.fields, 0);
    }
}
