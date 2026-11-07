//! Form fields through the facade (M4 plan, W3): the list, setting a value, Clear and Finish. Each
//! change is one step of the history behind its gate: `fill_forms` with the fields named for a
//! value or Clear, and what editing asks for Finish, since it changes page content (G35, G47).
//! The app commits on blur, on Tab or at the end of a drag, never per keystroke (decision 16).
//! Geometry crosses in displayed points.

use ferman_core::forms::{DeclaredFormat, Field, FieldKind, FormFields};
use ferman_core::{CoreError, DocumentOp, WriteError};
use ferman_ops::OpsError;
use ferman_ops::forms::{self as ops, FieldProblem, Filled, MissingFont};
use ferman_render::DocumentId;

use super::annotations::rect_to_display;
use super::edit::RevisionInfo;
use super::engine::Engine;
use super::error::ApiError;
use super::guard::guard_async;

/// One widget of a field. Geometry is in displayed points.
#[derive(Debug, Clone, PartialEq)]
pub struct FieldWidget {
    /// Its page's handle ([`PageInfo::handle`](super::PageInfo::handle)).
    pub page: u64,
    /// `[left, top, right, bottom]`.
    pub rect: [f32; 4],
    /// The value that turns a check box or radio button on.
    pub on_state: Option<String>,
}

/// A date, number or percentage format a field declares (decision 17).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FieldFormat {
    /// A date in this `AFDate` pattern.
    Date(String),
    /// A number, with its decimals.
    Number(i32),
    /// A percentage, with its decimals.
    Percent(i32),
}

/// One form field for the panel and the overlay, in tab order.
#[derive(Debug, Clone, PartialEq)]
pub struct FieldInfo {
    /// Its identity for the other calls. It stays through edits, undo and saves.
    pub handle: u64,
    /// Its full name.
    pub name: String,
    /// `/TU`, the name a reader shows.
    pub label: Option<String>,
    /// What it is.
    pub kind: FieldKind,
    /// It cannot be changed.
    pub read_only: bool,
    /// It counts in the required count.
    pub required: bool,
    /// A text field of many lines.
    pub multiline: bool,
    /// A text field that hides what is typed.
    pub password: bool,
    /// A comb's cells: `max_len` when the field is a comb.
    pub comb: bool,
    /// A list box that takes several values.
    pub multi_select: bool,
    /// A combo box that takes any text.
    pub editable: bool,
    /// Its value: text, export values, or the on-state of a button. Empty when it holds none.
    pub values: Vec<String>,
    /// A choice's options, as export and display value.
    pub options: Vec<(String, String)>,
    /// `/MaxLen`.
    pub max_len: Option<u32>,
    /// Its places, in tab order.
    pub widgets: Vec<FieldWidget>,
    /// What its scripts declare.
    pub format: Option<FieldFormat>,
    /// `AFRange_Validate`'s least value.
    pub min: Option<f64>,
    /// `AFRange_Validate`'s greatest value.
    pub max: Option<f64>,
    /// How its value fails what it declares.
    pub problem: Option<FieldProblem>,
    /// A signature field holds a digital signature.
    pub signed: bool,
    /// The stamp of the simple signature on it (decisions 20 and 21).
    pub signature: Option<u64>,
    /// It counts as filled.
    pub filled: bool,
}

/// A document's form.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct FormInfo {
    /// In tab order: by page, then `/Tabs`.
    pub fields: Vec<FieldInfo>,
    /// Required fields.
    pub required: u32,
    /// Required fields not yet filled.
    pub required_left: u32,
    /// Fields whose value fails what they declare: Finish waits for none.
    pub problems: u32,
    /// `/XFA` is there, and the first change removes it with a notice (question 12).
    pub has_xfa: bool,
    /// Whether a limit cut the list short.
    pub truncated: bool,
}

/// What setting a value returns.
#[derive(Debug, Clone, PartialEq)]
pub struct FieldCommit {
    /// Where the history stands.
    pub revision: RevisionInfo,
    /// How the new value fails what the field declares.
    pub problem: Option<FieldProblem>,
    /// The families it was drawn in because its font could not (decision 18), to say so once.
    pub fonts: Vec<String>,
    /// What its font cannot draw was left out, under Keep: mark the field.
    // shortcut: the mark is this answer's, not the file's, so a reopen forgets it (B204); keep it
    // in the history step if a reopened form must still show it.
    pub marked: bool,
    /// `/XFA` left the form (question 12): say so.
    pub xfa_removed: bool,
    /// Ask each time: its font cannot draw the value, and nothing was written. Call again with a
    /// choice.
    pub asks_font: bool,
}

fn info(pages: &[ferman_core::structure::Page], field: &Field) -> FieldInfo {
    let problem = field
        .values
        .first()
        .and_then(|value| ops::problem(field, value));
    FieldInfo {
        handle: field.handle,
        name: field.name.clone(),
        label: field.label.clone(),
        kind: field.kind,
        read_only: field.read_only,
        required: field.required,
        multiline: field.multiline,
        password: field.password,
        comb: field.comb,
        multi_select: field.multi_select,
        editable: field.editable,
        values: field.values.clone(),
        options: field
            .options
            .iter()
            .map(|option| (option.export.clone(), option.display.clone()))
            .collect(),
        max_len: field.max_len,
        widgets: field
            .widgets
            .iter()
            .filter_map(|widget| {
                let page = pages.get(widget.page)?;
                Some(FieldWidget {
                    page: page.handle(),
                    rect: rect_to_display(page, widget.rect),
                    on_state: widget
                        .on_state
                        .as_deref()
                        .map(|state| String::from_utf8_lossy(state).into_owned()),
                })
            })
            .collect(),
        format: field.declared.format.as_ref().map(|format| match format {
            DeclaredFormat::Date(pattern) => FieldFormat::Date(pattern.clone()),
            DeclaredFormat::Number { decimals, .. } => FieldFormat::Number(*decimals),
            DeclaredFormat::Percent { decimals, .. } => FieldFormat::Percent(*decimals),
        }),
        min: field.declared.min,
        max: field.declared.max,
        problem,
        signed: field.signed,
        signature: field.signature,
        filled: field.filled(),
    }
}

fn form_info(pages: &[ferman_core::structure::Page], list: &FormFields) -> FormInfo {
    let (required, required_left) = ops::required_count(list);
    let fields: Vec<FieldInfo> = list.fields.iter().map(|field| info(pages, field)).collect();
    FormInfo {
        required,
        required_left,
        problems: u32::try_from(fields.iter().filter(|f| f.problem.is_some()).count())
            .unwrap_or(u32::MAX),
        has_xfa: list.has_xfa,
        truncated: list.truncated,
        fields,
    }
}

impl Engine {
    /// The form as the committed revisions leave it, from a snapshot: this waits for no edit, and
    /// generates nothing, so opening and reading change nothing (decision 19).
    ///
    /// # Errors
    ///
    /// `NotFound` for a document that is not open.
    pub async fn form_fields(&self, document: DocumentId) -> Result<FormInfo, ApiError> {
        guard_async(async move {
            let snapshot = self.job_snapshot(document)?;
            let (base, store) = (snapshot.base(), snapshot.store());
            Ok(form_info(store.pages(base), &store.form_fields(base)))
        })
        .await
    }

    /// Sets field `handle` to `values`, as one step `name`: text, export values or a button's
    /// on-state, none to empty it. Same-name widgets and radio kids change with it. The same values
    /// add no step. `missing` answers Ask each time; with `None` the font settings decide
    /// (decision 18).
    ///
    /// # Errors
    ///
    /// `NotEditable` with the reason for a document whose permissions forbid filling or that cannot
    /// be changed, `ConfirmationRequired` for a signed document before its confirmation,
    /// `InvalidInput` for a field that is read-only or takes no value, values it cannot hold, a
    /// field it does not have or while a transaction is open, `Unsupported` for text no font here
    /// has, and `NotFound` for a document that is not open.
    pub async fn set_field_value(
        &self,
        document: DocumentId,
        handle: u64,
        values: Vec<String>,
        missing: Option<MissingFont>,
        name: String,
    ) -> Result<FieldCommit, ApiError> {
        guard_async(async move {
            let (current, reload, filled, problem, asks_font) = self
                .ask(document, move |session| {
                    let field = session
                        .form()
                        .fields
                        .into_iter()
                        .find(|field| field.handle == handle)
                        .ok_or(CoreError::Write(WriteError::AnnotationPlan))?;
                    let problem = values.first().and_then(|value| ops::problem(&field, value));
                    let mut pages: Vec<usize> = field.widgets.iter().map(|w| w.page).collect();
                    pages.sort_unstable();
                    pages.dedup();
                    let library = session.font_library();
                    let missing = missing.unwrap_or_else(|| session.missing_font());
                    let mut filled = Filled::default();
                    let mut asks_font = false;
                    let done = session.commit_change(
                        DocumentOp::Fill,
                        std::slice::from_ref(&field.name),
                        name,
                        &pages,
                        (String::new(), String::new()),
                        |doc, working| match ops::set_value(
                            doc, working, handle, &values, &library, missing,
                        ) {
                            Ok(done) => {
                                filled = done;
                                Ok(())
                            }
                            Err(OpsError::FontChoiceNeeded) => {
                                asks_font = true;
                                Err(CoreError::Write(WriteError::AnnotationPlan).into())
                            }
                            Err(err) => Err(err.into()),
                        },
                    );
                    let (current, reload) = match done {
                        Err(_) if asks_font => (session.current(), None),
                        other => other?,
                    };
                    Ok((current, reload, filled, problem, asks_font))
                })
                .await?;
            Ok(FieldCommit {
                revision: self.revision_info(document, current, reload).await,
                problem,
                fonts: filled.fonts,
                marked: filled.marked,
                xfa_removed: filled.xfa_removed,
                asks_font,
            })
        })
        .await
    }

    /// Empties every field that holds a value and can change, as one step `name`. Signatures stay.
    ///
    /// # Errors
    ///
    /// As [`set_field_value`](Self::set_field_value).
    pub async fn clear_form(
        &self,
        document: DocumentId,
        name: String,
    ) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let (current, reload) = self
                .ask(document, move |session| {
                    let list = session.form();
                    let fields = ops::clearable(&list);
                    let names: Vec<String> = fields.iter().map(|f| f.name.clone()).collect();
                    let mut pages: Vec<usize> = fields
                        .iter()
                        .flat_map(|field| field.widgets.iter().map(|w| w.page))
                        .collect();
                    pages.sort_unstable();
                    pages.dedup();
                    let library = session.font_library();
                    session.commit_change(
                        DocumentOp::Fill,
                        &names,
                        name,
                        &pages,
                        (String::new(), String::new()),
                        |doc, working| {
                            ops::clear(doc, working, &library)?;
                            Ok(())
                        },
                    )
                })
                .await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }

    /// Finish (G47): every field becomes page content as it looks, with its simple signature, as
    /// one step `name`; a digitally signed field stays. It changes page content, so it asks what
    /// editing asks and a signed document's confirmation. Undo brings the fields back.
    ///
    /// # Errors
    ///
    /// As [`set_field_value`](Self::set_field_value), and `Unsupported` on a page whose content
    /// leaks a state past a `Q` too many (B202).
    pub async fn finish_form(
        &self,
        document: DocumentId,
        name: String,
    ) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let (current, reload) = self
                .ask(document, move |session| {
                    let pages = ops::pages_of(&session.form());
                    let library = session.font_library();
                    session.commit_change(
                        DocumentOp::EditText,
                        &[],
                        name,
                        &pages,
                        (String::new(), String::new()),
                        |doc, working| Ok(ops::finish(doc, working, &library)?),
                    )
                })
                .await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }
}
