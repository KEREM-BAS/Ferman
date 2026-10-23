//! PDF object syntax (ISO 32000-2 §7.2 and §7.3): a lexer and a parser into lopdf's object types.
//!
//! lopdf parses the document's objects into the model (ADR 0004). This parser reads what
//! ferman-core needs around that: trailers and cross-reference streams, the encryption
//! dictionary, object headers while the cross-reference data is rebuilt, and the object streams
//! of encrypted files. It is bounded by [`Limits::max_nesting`], and every offset is checked.
// A parser module: offsets and sizes come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::ops::Range;

use lopdf::{Dictionary, Object, ObjectId, StringFormat};

use crate::CoreError;
use crate::limits::{LimitKind, Limits};

/// ISO 32000-2 Table 1: the six white-space characters.
pub(crate) fn is_whitespace(byte: u8) -> bool {
    matches!(byte, 0 | 9 | 10 | 12 | 13 | 32)
}

/// ISO 32000-2 Table 2: the delimiter characters.
pub(crate) fn is_delimiter(byte: u8) -> bool {
    matches!(
        byte,
        b'(' | b')' | b'<' | b'>' | b'[' | b']' | b'{' | b'}' | b'/' | b'%'
    )
}

/// A regular character: neither white space nor a delimiter.
pub(crate) fn is_regular(byte: u8) -> bool {
    !is_whitespace(byte) && !is_delimiter(byte)
}

/// The first position at or after `from` where `needle` starts in `haystack`.
pub(crate) fn find(haystack: &[u8], needle: &[u8], from: usize) -> Option<usize> {
    let rest = haystack.get(from..)?;
    let at = rest
        .windows(needle.len().max(1))
        .position(|window| window == needle)?;
    from.checked_add(at)
}

/// The last position before `before` where `needle` starts in `haystack`.
pub(crate) fn rfind(haystack: &[u8], needle: &[u8], before: usize) -> Option<usize> {
    let head = haystack.get(..before.min(haystack.len()))?;
    head.windows(needle.len().max(1))
        .rposition(|window| window == needle)
}

/// A syntax error at `offset`.
fn malformed(offset: usize, problem: &'static str) -> CoreError {
    CoreError::Syntax {
        offset: u64::try_from(offset).unwrap_or(u64::MAX),
        problem,
    }
}

/// One token of PDF object syntax.
#[derive(Debug, Clone, PartialEq)]
pub(crate) enum Token<'a> {
    /// An integer that fits an `i64`.
    Integer(i64),
    /// A real number, or an integer too large for an `i64`.
    Real(f32),
    /// A name, its `#xx` escapes decoded.
    Name(Vec<u8>),
    /// A literal or hexadecimal string, its escapes decoded.
    String(Vec<u8>, StringFormat),
    /// `[`.
    ArrayStart,
    /// `]`.
    ArrayEnd,
    /// `<<`.
    DictStart,
    /// `>>`.
    DictEnd,
    /// A run of regular characters that is not a number: `true`, `null`, `R`, `obj`, `stream`…
    Keyword(&'a [u8]),
}

/// A lexer over PDF bytes.
#[derive(Debug, Clone)]
pub(crate) struct Lexer<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> Lexer<'a> {
    /// A lexer over `data` starting at `pos`.
    pub(crate) fn new(data: &'a [u8], pos: usize) -> Self {
        Self { data, pos }
    }

    /// The position of the next byte.
    pub(crate) fn pos(&self) -> usize {
        self.pos
    }

    /// Moves to `pos`.
    pub(crate) fn seek(&mut self, pos: usize) {
        self.pos = pos;
    }

    /// The data the lexer reads.
    pub(crate) fn data(&self) -> &'a [u8] {
        self.data
    }

    fn peek_byte(&self) -> Option<u8> {
        self.data.get(self.pos).copied()
    }

    fn bump(&mut self) {
        self.pos = self.pos.saturating_add(1);
    }

    /// Skips white space and comments.
    pub(crate) fn skip_whitespace(&mut self) {
        while let Some(byte) = self.peek_byte() {
            if is_whitespace(byte) {
                self.bump();
            } else if byte == b'%' {
                while let Some(byte) = self.peek_byte() {
                    if byte == b'\n' || byte == b'\r' {
                        break;
                    }
                    self.bump();
                }
            } else {
                break;
            }
        }
    }

    /// The next token and where it starts, or `None` at the end of the data.
    pub(crate) fn next_token(&mut self) -> Result<Option<(Token<'a>, usize)>, CoreError> {
        self.skip_whitespace();
        let start = self.pos;
        let Some(byte) = self.peek_byte() else {
            return Ok(None);
        };
        let token = match byte {
            b'[' => {
                self.bump();
                Token::ArrayStart
            }
            b']' => {
                self.bump();
                Token::ArrayEnd
            }
            b'<' => {
                if self.data.get(start.saturating_add(1)) == Some(&b'<') {
                    self.pos = start.saturating_add(2);
                    Token::DictStart
                } else {
                    self.bump();
                    Token::String(self.hex_string(start)?, StringFormat::Hexadecimal)
                }
            }
            b'>' => {
                if self.data.get(start.saturating_add(1)) == Some(&b'>') {
                    self.pos = start.saturating_add(2);
                    Token::DictEnd
                } else {
                    return Err(malformed(start, "a single '>'"));
                }
            }
            b'(' => {
                self.bump();
                Token::String(self.literal_string(start)?, StringFormat::Literal)
            }
            b'/' => {
                self.bump();
                Token::Name(self.name())
            }
            b')' | b'{' | b'}' => return Err(malformed(start, "an unexpected delimiter")),
            _ => {
                while self.peek_byte().is_some_and(is_regular) {
                    self.bump();
                }
                let word = self.data.get(start..self.pos).unwrap_or_default();
                number(word).unwrap_or(Token::Keyword(word))
            }
        };
        Ok(Some((token, start)))
    }

    /// The bytes of a name after its `/`.
    fn name(&mut self) -> Vec<u8> {
        let mut name = Vec::new();
        while let Some(byte) = self.peek_byte() {
            if !is_regular(byte) {
                break;
            }
            self.bump();
            if byte == b'#' {
                let high = self.peek_byte().and_then(hex_value);
                let low = self
                    .data
                    .get(self.pos.saturating_add(1))
                    .copied()
                    .and_then(hex_value);
                if let (Some(high), Some(low)) = (high, low) {
                    name.push(high.wrapping_shl(4) | low);
                    self.pos = self.pos.saturating_add(2);
                    continue;
                }
            }
            name.push(byte);
        }
        name
    }

    /// A hexadecimal string after its `<`. White space is ignored, and an odd final digit is
    /// followed by 0.
    fn hex_string(&mut self, start: usize) -> Result<Vec<u8>, CoreError> {
        let mut out = Vec::new();
        let mut high: Option<u8> = None;
        loop {
            let Some(byte) = self.peek_byte() else {
                return Err(malformed(start, "a hexadecimal string without its '>'"));
            };
            self.bump();
            if byte == b'>' {
                break;
            }
            if is_whitespace(byte) {
                continue;
            }
            let Some(value) = hex_value(byte) else {
                return Err(malformed(
                    start,
                    "a hexadecimal string with a non-hex digit",
                ));
            };
            match high.take() {
                Some(high) => out.push(high.wrapping_shl(4) | value),
                None => high = Some(value),
            }
        }
        if let Some(high) = high {
            out.push(high.wrapping_shl(4));
        }
        Ok(out)
    }

    /// A literal string after its `(`, with balanced parentheses, escapes and end-of-line
    /// markers decoded (ISO 32000-2 §7.3.4.2).
    fn literal_string(&mut self, start: usize) -> Result<Vec<u8>, CoreError> {
        let mut out = Vec::new();
        let mut depth: usize = 1;
        loop {
            let Some(byte) = self.peek_byte() else {
                return Err(malformed(start, "a literal string without its ')'"));
            };
            self.bump();
            match byte {
                b'(' => {
                    depth = depth.saturating_add(1);
                    out.push(byte);
                }
                b')' => {
                    depth = depth.saturating_sub(1);
                    if depth == 0 {
                        break;
                    }
                    out.push(byte);
                }
                b'\r' => {
                    // An end-of-line marker reads as a line feed.
                    if self.peek_byte() == Some(b'\n') {
                        self.bump();
                    }
                    out.push(b'\n');
                }
                b'\\' => self.escape(&mut out),
                _ => out.push(byte),
            }
        }
        Ok(out)
    }

    /// One escape sequence after its `\`.
    fn escape(&mut self, out: &mut Vec<u8>) {
        let Some(byte) = self.peek_byte() else {
            return;
        };
        self.bump();
        match byte {
            b'n' => out.push(b'\n'),
            b'r' => out.push(b'\r'),
            b't' => out.push(b'\t'),
            b'b' => out.push(0x08),
            b'f' => out.push(0x0C),
            b'\r' => {
                // A line continuation.
                if self.peek_byte() == Some(b'\n') {
                    self.bump();
                }
            }
            b'\n' => {}
            b'0'..=b'7' => {
                let mut value = u32::from(byte.wrapping_sub(b'0'));
                for _ in 0..2 {
                    match self.peek_byte() {
                        Some(digit @ b'0'..=b'7') => {
                            value = value
                                .wrapping_mul(8)
                                .wrapping_add(u32::from(digit.wrapping_sub(b'0')));
                            self.bump();
                        }
                        _ => break,
                    }
                }
                // High-order overflow is ignored (ISO 32000-2 §7.3.4.2).
                out.push(u8::try_from(value & 0xFF).unwrap_or(0));
            }
            // An unknown escape keeps the character; the backslash is dropped.
            other => out.push(other),
        }
    }
}

fn hex_value(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte.wrapping_sub(b'0')),
        b'a'..=b'f' => Some(byte.wrapping_sub(b'a').wrapping_add(10)),
        b'A'..=b'F' => Some(byte.wrapping_sub(b'A').wrapping_add(10)),
        _ => None,
    }
}

/// `word` as a number token: an optional sign, digits and at most one point.
fn number(word: &[u8]) -> Option<Token<'static>> {
    let digits = word
        .strip_prefix(b"+")
        .or_else(|| word.strip_prefix(b"-"))
        .unwrap_or(word);
    if digits.is_empty() {
        return None;
    }
    let mut points = 0usize;
    let mut any_digit = false;
    for byte in digits {
        match byte {
            b'0'..=b'9' => any_digit = true,
            b'.' => points = points.saturating_add(1),
            _ => return None,
        }
    }
    if !any_digit || points > 1 {
        return None;
    }
    let text = std::str::from_utf8(word).ok()?;
    if points == 0
        && let Ok(value) = text.parse::<i64>()
    {
        return Some(Token::Integer(value));
    }
    // A real such as "4." or "-.5", or an integer beyond i64.
    let text = text.strip_prefix('+').unwrap_or(text);
    let value: f64 = if text.ends_with('.') {
        format!("{text}0").parse().ok()?
    } else if let Some(rest) = text.strip_prefix("-.") {
        format!("-0.{rest}").parse().ok()?
    } else if let Some(rest) = text.strip_prefix('.') {
        format!("0.{rest}").parse().ok()?
    } else {
        text.parse().ok()?
    };
    #[allow(clippy::cast_possible_truncation)]
    let value = value as f32;
    Some(Token::Real(value))
}

/// A parser of PDF objects into lopdf's types, bounded by [`Limits::max_nesting`].
#[derive(Debug, Clone)]
pub(crate) struct Parser<'a> {
    lexer: Lexer<'a>,
    max_nesting: u32,
}

/// An indirect object as it stands in the file.
#[derive(Debug, Clone)]
pub(crate) struct Indirect {
    /// Its object number and generation.
    pub(crate) id: ObjectId,
    /// The object; for a stream, its dictionary.
    pub(crate) object: Object,
    /// For a stream, where its data is in the file.
    pub(crate) data: Option<Range<usize>>,
    /// Whether the stream's `/Length` was there but wrong, so its data was found by `endstream`.
    pub(crate) length_corrected: bool,
    /// Whether the object ends with `endobj`.
    pub(crate) complete: bool,
    /// Where the object ends: after `endobj` when present.
    pub(crate) end: usize,
}

impl<'a> Parser<'a> {
    /// A parser over `data` starting at `pos`.
    pub(crate) fn new(data: &'a [u8], pos: usize, limits: &Limits) -> Self {
        Self {
            lexer: Lexer::new(data, pos),
            max_nesting: limits.max_nesting,
        }
    }

    /// The position of the next byte.
    pub(crate) fn pos(&self) -> usize {
        self.lexer.pos()
    }

    /// The next token, which must exist.
    fn token(&mut self) -> Result<(Token<'a>, usize), CoreError> {
        let at = self.lexer.pos();
        self.lexer
            .next_token()?
            .ok_or_else(|| malformed(at, "the data ends inside an object"))
    }

    /// The next token without consuming it.
    fn peek(&mut self) -> Result<Option<Token<'a>>, CoreError> {
        let at = self.lexer.pos();
        let token = self.lexer.next_token()?.map(|(token, _)| token);
        self.lexer.seek(at);
        Ok(token)
    }

    /// One direct object, with `n g R` read as a reference.
    pub(crate) fn object(&mut self) -> Result<Object, CoreError> {
        self.object_at(0)
    }

    fn object_at(&mut self, depth: u32) -> Result<Object, CoreError> {
        let (token, start) = self.token()?;
        self.object_from(token, start, depth)
    }

    fn object_from(
        &mut self,
        token: Token<'a>,
        start: usize,
        depth: u32,
    ) -> Result<Object, CoreError> {
        Ok(match token {
            Token::Integer(number) => self.integer_or_reference(number),
            Token::Real(value) => Object::Real(value),
            Token::Name(name) => Object::Name(name),
            Token::String(bytes, format) => Object::String(bytes, format),
            Token::ArrayStart => Object::Array(self.array(self.deeper(depth)?)?),
            Token::DictStart => Object::Dictionary(self.dictionary(self.deeper(depth)?)?),
            Token::Keyword(b"true") => Object::Boolean(true),
            Token::Keyword(b"false") => Object::Boolean(false),
            Token::Keyword(b"null") => Object::Null,
            Token::ArrayEnd | Token::DictEnd | Token::Keyword(_) => {
                return Err(malformed(start, "not an object"));
            }
        })
    }

    /// One level deeper, or [`CoreError::ResourceLimit`] past [`Limits::max_nesting`].
    fn deeper(&self, depth: u32) -> Result<u32, CoreError> {
        let depth = depth.saturating_add(1);
        if depth > self.max_nesting {
            return Err(CoreError::ResourceLimit {
                limit: LimitKind::Nesting,
                max: u64::from(self.max_nesting),
            });
        }
        Ok(depth)
    }

    fn integer_or_reference(&mut self, number: i64) -> Object {
        let at = self.lexer.pos();
        if let (Ok(number), Ok(Some((Token::Integer(generation), _)))) =
            (u32::try_from(number), self.lexer.next_token())
            && let Ok(generation) = u16::try_from(generation)
            && let Ok(Some((Token::Keyword(b"R"), _))) = self.lexer.next_token()
        {
            return Object::Reference((number, generation));
        }
        self.lexer.seek(at);
        Object::Integer(number)
    }

    fn array(&mut self, depth: u32) -> Result<Vec<Object>, CoreError> {
        let mut items = Vec::new();
        loop {
            let (token, start) = self.token()?;
            if token == Token::ArrayEnd {
                return Ok(items);
            }
            items.push(self.object_from(token, start, depth)?);
        }
    }

    fn dictionary(&mut self, depth: u32) -> Result<Dictionary, CoreError> {
        let mut dict = Dictionary::new();
        loop {
            let (token, start) = self.token()?;
            match token {
                Token::DictEnd => return Ok(dict),
                Token::Name(key) => {
                    let (token, start) = self.token()?;
                    // A key without a value before `>>` is dropped, as PDFium drops it.
                    if token == Token::DictEnd {
                        return Ok(dict);
                    }
                    let value = self.object_from(token, start, depth)?;
                    dict.set(key, value);
                }
                _ => return Err(malformed(start, "a dictionary key that is not a name")),
            }
        }
    }

    /// The indirect object `n g obj … endobj` at the parser's position. A stream's `/Length` is
    /// read directly, or through `length` for a reference; when it does not end at `endstream`,
    /// the data runs to the next `endstream` instead.
    pub(crate) fn indirect(
        &mut self,
        length: &dyn Fn(ObjectId) -> Option<i64>,
    ) -> Result<Indirect, CoreError> {
        let (token, start) = self.token()?;
        let Token::Integer(number) = token else {
            return Err(malformed(start, "an object without its number"));
        };
        let (token, at) = self.token()?;
        let Token::Integer(generation) = token else {
            return Err(malformed(at, "an object without its generation"));
        };
        let (token, at) = self.token()?;
        if token != Token::Keyword(b"obj") {
            return Err(malformed(at, "an object header without 'obj'"));
        }
        let id = (
            u32::try_from(number).map_err(|_| malformed(start, "an object number out of range"))?,
            u16::try_from(generation).map_err(|_| malformed(start, "a generation out of range"))?,
        );
        let object = self.object()?;
        let mut indirect = Indirect {
            id,
            object,
            data: None,
            length_corrected: false,
            complete: false,
            end: self.lexer.pos(),
        };
        let after_object = self.lexer.pos();
        match self.lexer.next_token() {
            Ok(Some((Token::Keyword(b"stream"), keyword))) => {
                let Object::Dictionary(dict) = &indirect.object else {
                    return Err(malformed(keyword, "a stream without a dictionary"));
                };
                let (data, corrected) = self.stream_data(dict, keyword, length)?;
                indirect.data = Some(data);
                indirect.length_corrected = corrected;
                indirect.end = self.lexer.pos();
                let after_stream = self.lexer.pos();
                match self.lexer.next_token() {
                    Ok(Some((Token::Keyword(b"endobj"), _))) => {
                        indirect.complete = true;
                        indirect.end = self.lexer.pos();
                    }
                    _ => self.lexer.seek(after_stream),
                }
            }
            Ok(Some((Token::Keyword(b"endobj"), _))) => {
                indirect.complete = true;
                indirect.end = self.lexer.pos();
            }
            // A missing `endobj`: the object ends where it ends.
            _ => self.lexer.seek(after_object),
        }
        Ok(indirect)
    }

    /// Where a stream's data is, given its dictionary and the position of `stream`, and whether
    /// its `/Length` had to be corrected. Leaves the lexer after `endstream`.
    fn stream_data(
        &mut self,
        dict: &Dictionary,
        keyword: usize,
        length: &dyn Fn(ObjectId) -> Option<i64>,
    ) -> Result<(Range<usize>, bool), CoreError> {
        let data = self.lexer.data();
        // `stream` is followed by CR LF or LF; a lone CR is tolerated.
        let mut start = keyword
            .checked_add(6)
            .ok_or_else(|| malformed(keyword, "an offset out of range"))?;
        match data.get(start) {
            Some(b'\r') => {
                start = start.saturating_add(1);
                if data.get(start) == Some(&b'\n') {
                    start = start.saturating_add(1);
                }
            }
            Some(b'\n') => start = start.saturating_add(1),
            _ => {}
        }
        let declared = match dict.get(b"Length") {
            Ok(Object::Integer(value)) => Some(*value),
            Ok(Object::Reference(id)) => length(*id),
            _ => None,
        };
        if let Some(declared) = declared.and_then(|value| usize::try_from(value).ok())
            && let Some(end) = start.checked_add(declared)
            && end <= data.len()
        {
            let mut after = Lexer::new(data, end);
            after.skip_whitespace();
            if data
                .get(after.pos()..)
                .is_some_and(|rest| rest.starts_with(b"endstream"))
            {
                self.lexer.seek(after.pos().saturating_add(9));
                return Ok((start..end, false));
            }
        }
        // The length is missing, unresolved or wrong: the data runs to the next `endstream`,
        // without the end-of-line marker before it. Only a length that was there counts as
        // corrected.
        let Some(at) = find(data, b"endstream", start) else {
            return Err(malformed(keyword, "a stream without 'endstream'"));
        };
        let mut end = at;
        if end > start && data.get(end.saturating_sub(1)) == Some(&b'\n') {
            end = end.saturating_sub(1);
        }
        if end > start && data.get(end.saturating_sub(1)) == Some(&b'\r') {
            end = end.saturating_sub(1);
        }
        self.lexer.seek(at.saturating_add(9));
        Ok((start..end, declared.is_some()))
    }

    /// Whether the next token is `keyword`; it is consumed only when it is.
    pub(crate) fn eat_keyword(&mut self, keyword: &[u8]) -> Result<bool, CoreError> {
        if self.peek()? == Some(Token::Keyword(keyword)) {
            let _ = self.token()?;
            return Ok(true);
        }
        Ok(false)
    }

    /// The next token if it is an integer; it is consumed only when it is.
    pub(crate) fn integer(&mut self) -> Result<Option<i64>, CoreError> {
        if let Some(Token::Integer(value)) = self.peek()? {
            let _ = self.token()?;
            return Ok(Some(value));
        }
        Ok(None)
    }
}

/// Whether `data` at `offset`, after white space, starts the header `number generation obj`.
pub(crate) fn header_at(data: &[u8], offset: usize, id: ObjectId) -> bool {
    let mut lexer = Lexer::new(data, offset);
    matches!(lexer.next_token(), Ok(Some((Token::Integer(n), _))) if i64::from(id.0) == n)
        && matches!(lexer.next_token(), Ok(Some((Token::Integer(g), _))) if i64::from(id.1) == g)
        && matches!(lexer.next_token(), Ok(Some((Token::Keyword(b"obj"), _))))
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    fn parse(text: &str) -> Result<Object, CoreError> {
        Parser::new(text.as_bytes(), 0, &Limits::default()).object()
    }

    fn tokens(text: &str) -> Vec<Token<'_>> {
        let mut lexer = Lexer::new(text.as_bytes(), 0);
        let mut out = Vec::new();
        while let Some((token, _)) = lexer.next_token().unwrap() {
            out.push(token);
        }
        out
    }

    #[test]
    fn numbers_read_as_iso_32000_writes_them() {
        assert_eq!(
            tokens("1 -2 +3 4. -.5 .25 0.0 1.2.3 99999999999999999999"),
            [
                Token::Integer(1),
                Token::Integer(-2),
                Token::Integer(3),
                Token::Real(4.0),
                Token::Real(-0.5),
                Token::Real(0.25),
                Token::Real(0.0),
                Token::Keyword(b"1.2.3"),
                Token::Real(1e20),
            ]
        );
    }

    #[test]
    fn names_decode_their_escapes() {
        assert_eq!(
            tokens("/Name /A#20B /Lime#20Green /#2F /"),
            [
                Token::Name(b"Name".to_vec()),
                Token::Name(b"A B".to_vec()),
                Token::Name(b"Lime Green".to_vec()),
                Token::Name(b"/".to_vec()),
                Token::Name(Vec::new()),
            ]
        );
    }

    #[test]
    fn literal_strings_decode_escapes_and_balance_parentheses() {
        let tokens =
            tokens("(a(b)c) (\\n\\r\\t\\b\\f\\(\\)\\\\) (\\101\\0612) (line\\\ncont) (cr\r\nlf)");
        assert_eq!(
            tokens,
            [
                Token::String(b"a(b)c".to_vec(), StringFormat::Literal),
                Token::String(b"\n\r\t\x08\x0C()\\".to_vec(), StringFormat::Literal),
                Token::String(b"A12".to_vec(), StringFormat::Literal),
                Token::String(b"linecont".to_vec(), StringFormat::Literal),
                Token::String(b"cr\nlf".to_vec(), StringFormat::Literal),
            ]
        );
    }

    #[test]
    fn hex_strings_ignore_white_space_and_pad_an_odd_digit() {
        assert_eq!(
            tokens("<48 65 6C6c6F> <901FA>"),
            [
                Token::String(b"Hello".to_vec(), StringFormat::Hexadecimal),
                Token::String(vec![0x90, 0x1F, 0xA0], StringFormat::Hexadecimal),
            ]
        );
        assert!(parse("<12 zz>").is_err());
        assert!(parse("<12").is_err());
        assert!(parse("(open").is_err());
    }

    #[test]
    fn comments_are_white_space() {
        assert_eq!(
            tokens("1 % a comment\n2"),
            [Token::Integer(1), Token::Integer(2)]
        );
    }

    #[test]
    fn objects_parse_into_lopdf_types() {
        let object =
            parse("<< /Type /Page /Kids [1 0 R 2 0 R] /Count 2 /Ok true /N null /R 1.5 /S (x) >>")
                .unwrap();
        let dict = object.as_dict().unwrap();
        assert_eq!(dict.get(b"Type").unwrap().as_name().unwrap(), b"Page");
        assert_eq!(
            dict.get(b"Kids").unwrap().as_array().unwrap(),
            &vec![Object::Reference((1, 0)), Object::Reference((2, 0))]
        );
        assert_eq!(dict.get(b"Count").unwrap().as_i64().unwrap(), 2);
        assert_eq!(dict.get(b"Ok").unwrap(), &Object::Boolean(true));
        assert_eq!(dict.get(b"N").unwrap(), &Object::Null);
        assert_eq!(dict.get(b"R").unwrap(), &Object::Real(1.5));
        assert_eq!(dict.get(b"S").unwrap().as_str().unwrap(), b"x");
    }

    #[test]
    fn two_integers_without_r_stay_integers() {
        assert_eq!(
            parse("[1 2 3 R 4]").unwrap(),
            Object::Array(vec![
                Object::Integer(1),
                Object::Reference((2, 3)),
                Object::Integer(4)
            ])
        );
        // A negative number cannot be an object number, so `R` stands alone.
        assert!(parse("[-1 0 R]").is_err());
    }

    #[test]
    fn nesting_past_the_limit_is_a_resource_limit() {
        let limits = Limits {
            max_nesting: 4,
            ..Limits::default()
        };
        let ok = "[[[[1]]]]";
        let deep = "[[[[[1]]]]]";
        assert!(Parser::new(ok.as_bytes(), 0, &limits).object().is_ok());
        assert!(matches!(
            Parser::new(deep.as_bytes(), 0, &limits).object(),
            Err(CoreError::ResourceLimit {
                limit: LimitKind::Nesting,
                max: 4
            })
        ));
        // The default limit holds for a deep array without exhausting the stack.
        let deep = format!("{}1{}", "[".repeat(300), "]".repeat(300));
        assert!(matches!(
            parse(&deep),
            Err(CoreError::ResourceLimit {
                limit: LimitKind::Nesting,
                ..
            })
        ));
    }

    #[test]
    fn errors_name_the_offset() {
        match parse("<< /A 1 2 >>") {
            // "1" is the value of /A; "2" stands where a key belongs.
            Err(CoreError::Syntax { offset, .. }) => assert_eq!(offset, 8),
            other => panic!("{other:?}"),
        }
        assert!(parse("<< 1 2 >>").is_err());
        assert!(parse(")").is_err());
        assert!(parse("").is_err());
    }

    #[test]
    fn an_indirect_stream_uses_its_length_or_finds_endstream() {
        let data = b"12 0 obj\n<< /Length 5 >>\nstream\nhello\nendstream\nendobj\n";
        let indirect = Parser::new(data, 0, &Limits::default())
            .indirect(&|_| None)
            .unwrap();
        assert_eq!(indirect.id, (12, 0));
        let range = indirect.data.clone().unwrap();
        assert_eq!(&data[range], b"hello");
        assert!(!indirect.length_corrected);
        assert!(indirect.complete);
        assert_eq!(indirect.end, data.len() - 1);

        let wrong = b"3 0 obj << /Length 99 >> stream\r\nhello world\r\nendstream endobj";
        let indirect = Parser::new(wrong, 0, &Limits::default())
            .indirect(&|_| None)
            .unwrap();
        assert_eq!(&wrong[indirect.data.unwrap()], b"hello world");
        assert!(indirect.length_corrected);

        let referenced = b"4 0 obj << /Length 9 0 R >> stream\nabc\nendstream\nendobj";
        let indirect = Parser::new(referenced, 0, &Limits::default())
            .indirect(&|id| (id == (9, 0)).then_some(3))
            .unwrap();
        assert_eq!(&referenced[indirect.data.unwrap()], b"abc");
        assert!(!indirect.length_corrected);
    }

    #[test]
    fn an_object_without_endobj_is_incomplete() {
        let data = b"7 0 obj (cut";
        assert!(
            Parser::new(data, 0, &Limits::default())
                .indirect(&|_| None)
                .is_err()
        );
        let data = b"7 0 obj 42\n8 0 obj";
        let indirect = Parser::new(data, 0, &Limits::default())
            .indirect(&|_| None)
            .unwrap();
        assert_eq!(indirect.object, Object::Integer(42));
        assert!(!indirect.complete);
    }

    #[test]
    fn headers_are_recognised_after_white_space() {
        let data = b"xx\n 5 0 obj << >>";
        assert!(header_at(data, 2, (5, 0)));
        assert!(header_at(data, 4, (5, 0)));
        assert!(!header_at(data, 0, (5, 0)));
        assert!(!header_at(data, 4, (5, 1)));
        assert!(!header_at(data, 400, (5, 0)));
    }

    #[test]
    fn find_and_rfind_stay_in_bounds() {
        assert_eq!(find(b"abcabc", b"bc", 0), Some(1));
        assert_eq!(find(b"abcabc", b"bc", 2), Some(4));
        assert_eq!(find(b"abc", b"bc", 9), None);
        assert_eq!(rfind(b"abcabc", b"bc", 6), Some(4));
        assert_eq!(rfind(b"abcabc", b"bc", 4), Some(1));
        assert_eq!(rfind(b"abc", b"x", 99), None);
    }
}
