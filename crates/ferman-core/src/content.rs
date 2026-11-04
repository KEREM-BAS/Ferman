//! Content streams (ISO 32000-2 §7.8.2 and §8.9.7): the operators of a page or a form, each with
//! its operands and its byte span, read as leniently as viewers read them (docs/ARCHITECTURE.md
//! §6.1).
//!
//! A token that cannot be read is skipped with the operands before it, as PDFium skips it, and
//! data that ends inside an object ends the stream. An inline image (`BI` … `ID` data `EI`) is one
//! operator `BI` whose operand is its dictionary; its data is skipped up to an `EI` with white space
//! before it and white space or the end after it.
// A parser module: offsets come from the data (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::ops::Range;

use lopdf::{Dictionary, Object};

use crate::CoreError;
use crate::limits::{LimitKind, Limits};
use crate::syntax::{ContentItem, Parser, is_whitespace};

/// One operator with its operands.
#[derive(Debug, Clone, PartialEq)]
pub(crate) struct Operator {
    /// The operator, such as `Tj`.
    pub(crate) name: Vec<u8>,
    /// Its operands, in order.
    pub(crate) operands: Vec<Object>,
    /// From its first operand, or the operator when it has none, to the operator's end.
    pub(crate) span: Range<usize>,
    /// Whether operands came from the streams before this one (a page's `/Contents` array may
    /// split between operands and their operator, ISO 32000-2 §7.8.2); `span` then starts at 0.
    pub(crate) carried: bool,
}

/// The operators of `data`.
///
/// # Errors
///
/// [`CoreError::ResourceLimit`] past [`Limits::max_operators_per_page`] or
/// [`Limits::max_nesting`].
pub(crate) fn operators(data: &[u8], limits: &Limits) -> Result<Vec<Operator>, CoreError> {
    Ok(operators_after(data, limits, Vec::new())?.0)
}

/// The operators of `data`, one stream of a page's `/Contents` array, after the `carried`
/// operands the streams before it left; returns them and the operands `data` leaves at its end.
///
/// # Errors
///
/// As [`operators`].
pub(crate) fn operators_after(
    data: &[u8],
    limits: &Limits,
    carried: Vec<Object>,
) -> Result<(Vec<Operator>, Vec<Object>), CoreError> {
    let max = usize::try_from(limits.max_operators_per_page).unwrap_or(usize::MAX);
    let mut parser = Parser::new(data, 0, limits);
    let mut out = Vec::new();
    let mut is_carried = !carried.is_empty();
    let mut first = is_carried.then_some(0);
    let mut operands = carried;
    loop {
        let at = parser.pos();
        let (item, start) = match parser.content_item() {
            Ok(Some(item)) => item,
            Ok(None) => break,
            Err(CoreError::Syntax { offset, .. }) => {
                let offset = usize::try_from(offset).unwrap_or(usize::MAX);
                // A token that runs to the end ends the stream; reading it again from each of
                // its bytes would take quadratic time.
                if offset <= at && parser.pos() >= data.len() {
                    break;
                }
                operands.clear();
                first = None;
                is_carried = false;
                parser.seek(offset.max(at.saturating_add(1)));
                continue;
            }
            Err(err) => return Err(err),
        };
        match item {
            ContentItem::Operand(object) => {
                first.get_or_insert(start);
                operands.push(object);
            }
            ContentItem::Operator(name) => {
                let begin = first.take().unwrap_or(start);
                let (name, operands, end) = if name == b"BI" {
                    let Some((dictionary, end)) = inline_image(&mut parser, data) else {
                        break;
                    };
                    operands.clear();
                    (name, vec![Object::Dictionary(dictionary)], end)
                } else {
                    (name, std::mem::take(&mut operands), parser.pos())
                };
                if out.len() >= max {
                    return Err(CoreError::ResourceLimit {
                        limit: LimitKind::OperatorsPerPage,
                        max: limits.max_operators_per_page,
                    });
                }
                out.push(Operator {
                    name: name.to_vec(),
                    operands,
                    span: begin..end,
                    carried: std::mem::take(&mut is_carried),
                });
            }
        }
    }
    Ok((out, operands))
}

/// After `BI`: the image dictionary up to `ID`, then the data skipped past its `EI`. Returns the
/// dictionary and where `EI` ends, or `None` when the data ends first.
fn inline_image(parser: &mut Parser<'_>, data: &[u8]) -> Option<(Dictionary, usize)> {
    let mut dictionary = Dictionary::new();
    let mut key = None;
    loop {
        match parser.content_item().ok()?? {
            (ContentItem::Operator(b"ID"), _) => break,
            (ContentItem::Operand(Object::Name(name)), _) if key.is_none() => key = Some(name),
            (ContentItem::Operand(value), _) => {
                if let Some(key) = key.take() {
                    dictionary.set(key, value);
                }
            }
            (ContentItem::Operator(_), _) => key = None,
        }
    }
    // One white-space byte separates `ID` from the data.
    let mut at = parser.pos().checked_add(1)?;
    loop {
        let found = crate::syntax::find(data, b"EI", at)?;
        let end = found.checked_add(2)?;
        let before = found.checked_sub(1).and_then(|i| data.get(i)).copied();
        let after = data.get(end).copied();
        if before.is_some_and(is_whitespace) && after.is_none_or(is_whitespace) {
            parser.seek(end);
            return Some((dictionary, end));
        }
        at = found.checked_add(1)?;
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    fn names(data: &[u8]) -> Vec<String> {
        operators(data, &Limits::default())
            .unwrap()
            .iter()
            .map(|op| String::from_utf8_lossy(&op.name).into_owned())
            .collect()
    }

    #[test]
    fn operators_carry_their_operands_and_spans() {
        let data = b"BT /F1 12 Tf 72 700 Td [(Kira) -250 (bedeli)] TJ ET";
        let ops = operators(data, &Limits::default()).unwrap();
        let summary: Vec<(&[u8], usize, &[u8])> = ops
            .iter()
            .map(|op| (&op.name[..], op.operands.len(), &data[op.span.clone()]))
            .collect();
        assert_eq!(
            summary,
            [
                (&b"BT"[..], 0, &b"BT"[..]),
                (b"Tf", 2, b"/F1 12 Tf"),
                (b"Td", 2, b"72 700 Td"),
                (b"TJ", 1, b"[(Kira) -250 (bedeli)] TJ"),
                (b"ET", 0, b"ET"),
            ]
        );
        assert_eq!(ops[1].operands[0], Object::Name(b"F1".to_vec()));
    }

    #[test]
    fn bad_tokens_are_skipped_with_their_operands() {
        assert_eq!(names(b"1 0 0 1 0 0 cm ) 5 > Tz (a) Tj"), ["cm", "Tz", "Tj"]);
        let ops = operators(b"5 ) Tz", &Limits::default()).unwrap();
        assert!(
            ops[0].operands.is_empty(),
            "the operand before a bad token goes"
        );
        // Data that ends inside a string or an array ends the stream.
        assert_eq!(names(b"(a) Tj (unterminated"), ["Tj"]);
        assert_eq!(names(b"(a) Tj [ (b"), ["Tj"]);
        // A keyword inside an array is the operator that follows it.
        assert_eq!(names(b"[ (a) Tj"), ["Tj"]);
    }

    #[test]
    fn an_inline_image_is_one_operator_and_its_data_is_skipped() {
        let data = b"q BI /W 2 /H 1 /BPC 8 /CS /G ID \x00EI)(\xff EI Q (x) Tj";
        let ops = operators(data, &Limits::default()).unwrap();
        let found: Vec<&[u8]> = ops.iter().map(|op| &op.name[..]).collect();
        assert_eq!(found, [&b"q"[..], b"BI", b"Q", b"Tj"]);
        let Object::Dictionary(dict) = &ops[1].operands[0] else {
            panic!("{:?}", ops[1].operands)
        };
        assert_eq!(dict.get(b"W").unwrap(), &Object::Integer(2));
        assert_eq!(dict.get(b"CS").unwrap(), &Object::Name(b"G".to_vec()));
        assert!(data[ops[1].span.clone()].ends_with(b" EI"));
        assert_eq!(names(b"BI /W 1 ID xx"), Vec::<String>::new());
    }

    #[test]
    fn operands_carry_into_the_next_stream() {
        let limits = Limits::default();
        let (ops, left) = operators_after(b"BT /F1", &limits, Vec::new()).unwrap();
        assert_eq!(ops.len(), 1);
        assert_eq!(left, [Object::Name(b"F1".to_vec())]);
        let data = b" 12 Tf (a) Tj";
        let (ops, left) = operators_after(data, &limits, left).unwrap();
        assert!(left.is_empty());
        assert_eq!((&ops[0].name[..], ops[0].operands.len()), (&b"Tf"[..], 2));
        assert!(ops[0].carried && !ops[1].carried);
        assert_eq!(&data[ops[0].span.clone()], b" 12 Tf");
        // A bad token drops the carried operands with the others.
        let (ops, _) = operators_after(b") Tz", &limits, vec![Object::Integer(5)]).unwrap();
        assert!(ops[0].operands.is_empty() && !ops[0].carried);
    }

    #[test]
    fn the_operator_limit_holds() {
        let limits = Limits {
            max_operators_per_page: 2,
            ..Limits::default()
        };
        assert!(operators(b"q Q", &limits).is_ok());
        assert!(matches!(
            operators(b"q Q q", &limits),
            Err(CoreError::ResourceLimit {
                limit: LimitKind::OperatorsPerPage,
                ..
            })
        ));
    }
}
