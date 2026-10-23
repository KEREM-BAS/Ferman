//! Stream filters that ferman-core decodes itself (ISO 32000-2 §7.4).
//!
//! The five general-purpose filters: ASCIIHexDecode, ASCII85Decode, LZWDecode, FlateDecode and
//! RunLengthDecode, with the PNG and TIFF predictors of LZW and Flate. The image codecs (DCT, JPX,
//! CCITTFax, JBIG2) are left to PDFium, which renders them; `Crypt` belongs to the security
//! handler. Every decoder is bounded by [`Limits::max_stream_decoded`], and a filter chain by
//! [`Limits::max_filter_chain`].
//!
//! The policy for damaged data, the same for every filter: data that a filter cannot decode is an
//! error ([`CoreError::DamagedStream`], with the offset into the encoded data), because a guess
//! could put content on the page that the file does not hold. A stream that ends early is not an
//! error: a missing end-of-data marker, a truncated last group, run or row, and a Flate stream
//! without its end block or with a wrong Adler-32 checksum decode to the data they hold, as PDFium
//! decodes them, so the model and the rendered page agree.
// A decoder module: offsets and sizes come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use crate::CoreError;
use crate::limits::{LimitKind, Limits};
use std::fmt;

mod ascii;
mod flate;
mod lzw;
mod predictor;
mod run_length;

/// A stream filter that ferman-core decodes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum Filter {
    /// `ASCIIHexDecode` (`AHx`).
    AsciiHex,
    /// `ASCII85Decode` (`A85`).
    Ascii85,
    /// `LZWDecode` (`LZW`).
    Lzw,
    /// `FlateDecode` (`Fl`).
    Flate,
    /// `RunLengthDecode` (`RL`).
    RunLength,
}

impl Filter {
    /// Every filter ferman-core decodes.
    pub const ALL: [Self; 5] = [
        Self::AsciiHex,
        Self::Ascii85,
        Self::Lzw,
        Self::Flate,
        Self::RunLength,
    ];

    /// The filter a `/Filter` name stands for, including the abbreviations of inline images
    /// (ISO 32000-2 §8.9.7). `None` for a filter ferman-core does not decode.
    #[must_use]
    pub fn from_name(name: &[u8]) -> Option<Self> {
        match name {
            b"ASCIIHexDecode" | b"AHx" => Some(Self::AsciiHex),
            b"ASCII85Decode" | b"A85" => Some(Self::Ascii85),
            b"LZWDecode" | b"LZW" => Some(Self::Lzw),
            b"FlateDecode" | b"Fl" => Some(Self::Flate),
            b"RunLengthDecode" | b"RL" => Some(Self::RunLength),
            _ => None,
        }
    }

    /// The filter's full PDF name, without the slash.
    #[must_use]
    pub fn name(self) -> &'static str {
        match self {
            Self::AsciiHex => "ASCIIHexDecode",
            Self::Ascii85 => "ASCII85Decode",
            Self::Lzw => "LZWDecode",
            Self::Flate => "FlateDecode",
            Self::RunLength => "RunLengthDecode",
        }
    }
}

impl fmt::Display for Filter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.name())
    }
}

/// The `/DecodeParms` entries of the LZW and Flate filters (ISO 32000-2 §7.4.4.4). The other
/// filters take no parameters and ignore these.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DecodeParams {
    /// `/Predictor`: 1 for none, 2 for TIFF predictor 2, 10 to 15 for the PNG predictors.
    pub predictor: u32,
    /// `/Colors`: samples per pixel, 1 to 32.
    pub colors: u32,
    /// `/BitsPerComponent`: 1, 2, 4, 8 or 16.
    pub bits_per_component: u32,
    /// `/Columns`: pixels per row, at least 1.
    pub columns: u32,
    /// `/EarlyChange` of LZWDecode: the code width grows one code early, as in TIFF (the default).
    pub early_change: bool,
}

impl Default for DecodeParams {
    fn default() -> Self {
        Self {
            predictor: 1,
            colors: 1,
            bits_per_component: 8,
            columns: 1,
            early_change: true,
        }
    }
}

/// One filter of a stream's filter chain with its parameters.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FilterStep {
    /// The filter.
    pub filter: Filter,
    /// Its `/DecodeParms`.
    pub params: DecodeParams,
}

/// Decodes `data` with one filter, producing at most `max_decoded` bytes.
///
/// # Errors
///
/// [`CoreError::DamagedStream`] for data the filter cannot decode,
/// [`CoreError::InvalidDecodeParams`] for parameters it cannot apply,
/// [`CoreError::ResourceLimit`] when the output would exceed `max_decoded` bytes, and
/// [`CoreError::OutOfMemory`] when the output buffer cannot grow.
pub fn decode(
    filter: Filter,
    params: &DecodeParams,
    data: &[u8],
    max_decoded: u64,
) -> Result<Vec<u8>, CoreError> {
    let mut out = Sink::new(max_decoded);
    match filter {
        Filter::AsciiHex => ascii::decode_hex(data, &mut out)?,
        Filter::Ascii85 => ascii::decode_85(data, &mut out)?,
        Filter::RunLength => run_length::decode(data, &mut out)?,
        Filter::Lzw => {
            predictor::check(filter, params)?;
            lzw::decode(data, params.early_change, &mut out)?;
        }
        Filter::Flate => {
            predictor::check(filter, params)?;
            flate::decode(data, &mut out)?;
        }
    }
    let decoded = out.into_vec();
    match filter {
        Filter::Lzw | Filter::Flate => predictor::apply(filter, params, decoded),
        Filter::AsciiHex | Filter::Ascii85 | Filter::RunLength => Ok(decoded),
    }
}

/// Decodes `data` through a whole filter chain, first filter first.
///
/// # Errors
///
/// [`CoreError::ResourceLimit`] when the chain is longer than [`Limits::max_filter_chain`] or a
/// step's output exceeds [`Limits::max_stream_decoded`], and every error of [`decode`].
pub fn decode_chain(
    steps: &[FilterStep],
    data: &[u8],
    limits: &Limits,
) -> Result<Vec<u8>, CoreError> {
    let too_long = match u32::try_from(steps.len()) {
        Ok(len) => len > limits.max_filter_chain,
        Err(_) => true,
    };
    if too_long {
        return Err(CoreError::ResourceLimit {
            limit: LimitKind::FilterChain,
            max: u64::from(limits.max_filter_chain),
        });
    }
    let Some((first, rest)) = steps.split_first() else {
        return copy(data);
    };
    let mut decoded = decode(first.filter, &first.params, data, limits.max_stream_decoded)?;
    for step in rest {
        decoded = decode(
            step.filter,
            &step.params,
            &decoded,
            limits.max_stream_decoded,
        )?;
    }
    Ok(decoded)
}

/// The filter chain of a stream dictionary: `/Filter` as a name or an array, with `/DecodeParms`
/// as a dictionary or an array of dictionaries and nulls.
///
/// # Errors
///
/// [`CoreError::Unsupported`] for a filter ferman-core does not decode (the image codecs and
/// `Crypt`), and [`CoreError::Syntax`] for entries of the wrong type.
pub(crate) fn chain_of(dict: &lopdf::Dictionary) -> Result<Vec<FilterStep>, CoreError> {
    use lopdf::Object;
    let names: Vec<&[u8]> = match dict.get(b"Filter") {
        Err(_) | Ok(Object::Null) => return Ok(Vec::new()),
        Ok(Object::Name(name)) => vec![name.as_slice()],
        Ok(Object::Array(items)) => items
            .iter()
            .map(|item| item.as_name().map_err(|_| wrong_entry("/Filter")))
            .collect::<Result<_, _>>()?,
        Ok(_) => return Err(wrong_entry("/Filter")),
    };
    let params: Vec<Option<&lopdf::Dictionary>> = match dict.get(b"DecodeParms") {
        Err(_) | Ok(Object::Null) => Vec::new(),
        Ok(Object::Dictionary(params)) => vec![Some(params)],
        Ok(Object::Array(items)) => items.iter().map(|item| item.as_dict().ok()).collect(),
        Ok(_) => return Err(wrong_entry("/DecodeParms")),
    };
    names
        .iter()
        .enumerate()
        .map(|(index, name)| {
            let filter = Filter::from_name(name)
                .ok_or(CoreError::Unsupported(crate::Unsupported::Filter))?;
            let params = params
                .get(index)
                .copied()
                .flatten()
                .map(decode_params)
                .unwrap_or_default();
            Ok(FilterStep { filter, params })
        })
        .collect()
}

/// `/DecodeParms` as [`DecodeParams`]; entries of the wrong type keep their defaults, and values
/// out of range are left for [`decode`] to refuse.
fn decode_params(dict: &lopdf::Dictionary) -> DecodeParams {
    let get = |key: &[u8], default: u32| {
        dict.get(key)
            .ok()
            .and_then(|value| value.as_i64().ok())
            .map_or(default, |value| u32::try_from(value).unwrap_or(u32::MAX))
    };
    let defaults = DecodeParams::default();
    DecodeParams {
        predictor: get(b"Predictor", defaults.predictor),
        colors: get(b"Colors", defaults.colors),
        bits_per_component: get(b"BitsPerComponent", defaults.bits_per_component),
        columns: get(b"Columns", defaults.columns),
        early_change: get(b"EarlyChange", 1) != 0,
    }
}

fn wrong_entry(entry: &'static str) -> CoreError {
    CoreError::Syntax {
        offset: 0,
        problem: match entry {
            "/Filter" => "a /Filter that is not a name or an array of names",
            _ => "/DecodeParms that are not a dictionary or an array",
        },
    }
}

/// `data` as an owned buffer, or [`CoreError::OutOfMemory`].
fn copy(data: &[u8]) -> Result<Vec<u8>, CoreError> {
    let mut out = Vec::new();
    out.try_reserve_exact(data.len())
        .map_err(|_| out_of_memory())?;
    out.extend_from_slice(data);
    Ok(out)
}

fn out_of_memory() -> CoreError {
    CoreError::OutOfMemory {
        context: "decoding a stream",
    }
}

fn damaged(filter: Filter, offset: usize, problem: &'static str) -> CoreError {
    CoreError::DamagedStream {
        filter,
        offset,
        problem,
    }
}

/// A decoder's output, bounded by the decoded-size limit.
struct Sink {
    bytes: Vec<u8>,
    /// The limit as given, for the error.
    limit: u64,
    /// The limit as a length; `usize::MAX` when the limit does not fit.
    max: usize,
}

impl Sink {
    fn new(limit: u64) -> Self {
        Self {
            bytes: Vec::new(),
            limit,
            max: usize::try_from(limit).unwrap_or(usize::MAX),
        }
    }

    /// Room left under the limit.
    fn room(&self) -> usize {
        self.max.saturating_sub(self.bytes.len())
    }

    fn over_limit(&self) -> CoreError {
        CoreError::ResourceLimit {
            limit: LimitKind::StreamDecodedSize,
            max: self.limit,
        }
    }

    /// Makes sure `additional` more bytes fit under the limit and in memory.
    fn reserve(&mut self, additional: usize) -> Result<(), CoreError> {
        if additional > self.room() {
            return Err(self.over_limit());
        }
        self.bytes
            .try_reserve(additional)
            .map_err(|_| out_of_memory())
    }

    fn push(&mut self, byte: u8) -> Result<(), CoreError> {
        self.reserve(1)?;
        self.bytes.push(byte);
        Ok(())
    }

    fn extend(&mut self, bytes: &[u8]) -> Result<(), CoreError> {
        self.reserve(bytes.len())?;
        self.bytes.extend_from_slice(bytes);
        Ok(())
    }

    fn repeat(&mut self, byte: u8, count: usize) -> Result<(), CoreError> {
        self.reserve(count)?;
        self.bytes.extend(std::iter::repeat_n(byte, count));
        Ok(())
    }

    /// Takes a whole buffer as output: moved in when nothing was written yet, so a large stream is
    /// not held twice, else appended.
    fn adopt(&mut self, buffer: Vec<u8>) -> Result<(), CoreError> {
        if !self.bytes.is_empty() {
            return self.extend(&buffer);
        }
        if buffer.len() > self.max {
            return Err(self.over_limit());
        }
        self.bytes = buffer;
        Ok(())
    }

    fn into_vec(self) -> Vec<u8> {
        self.bytes
    }
}

/// PDF whitespace (ISO 32000-2 §7.2.3): NUL, tab, line feed, form feed, carriage return, space.
fn is_whitespace(byte: u8) -> bool {
    matches!(byte, 0x00 | 0x09 | 0x0A | 0x0C | 0x0D | 0x20)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_and_abbreviations_map_to_filters() {
        for filter in Filter::ALL {
            assert_eq!(Filter::from_name(filter.name().as_bytes()), Some(filter));
        }
        assert_eq!(Filter::from_name(b"AHx"), Some(Filter::AsciiHex));
        assert_eq!(Filter::from_name(b"A85"), Some(Filter::Ascii85));
        assert_eq!(Filter::from_name(b"LZW"), Some(Filter::Lzw));
        assert_eq!(Filter::from_name(b"Fl"), Some(Filter::Flate));
        assert_eq!(Filter::from_name(b"RL"), Some(Filter::RunLength));
        for left_to_pdfium in [&b"DCTDecode"[..], b"JPXDecode", b"CCITTFaxDecode", b"Crypt"] {
            assert_eq!(Filter::from_name(left_to_pdfium), None);
        }
    }

    #[test]
    fn a_chain_runs_first_filter_first() {
        let steps = [
            FilterStep {
                filter: Filter::AsciiHex,
                params: DecodeParams::default(),
            },
            FilterStep {
                filter: Filter::RunLength,
                params: DecodeParams::default(),
            },
        ];
        // RunLength [2 'a' 'b' 'c' 254 'x' 128], written in hex.
        let decoded = decode_chain(&steps, b"02 616263 FE78 80>", &Limits::default()).unwrap();
        assert_eq!(decoded, b"abcxxx");
    }

    #[test]
    fn an_empty_chain_copies_the_data() {
        assert_eq!(
            decode_chain(&[], b"raw", &Limits::default()).unwrap(),
            b"raw"
        );
    }

    #[test]
    fn a_chain_longer_than_the_limit_stops() {
        let step = FilterStep {
            filter: Filter::AsciiHex,
            params: DecodeParams::default(),
        };
        let limits = Limits {
            max_filter_chain: 2,
            ..Limits::default()
        };
        let err = decode_chain(&[step; 3], b"", &limits).unwrap_err();
        assert!(matches!(
            err,
            CoreError::ResourceLimit {
                limit: LimitKind::FilterChain,
                max: 2
            }
        ));
    }

    #[test]
    fn every_filter_stops_at_the_decoded_size_limit() {
        let cases: [(Filter, &[u8]); 3] = [
            (Filter::AsciiHex, b"41414141>"),
            (Filter::Ascii85, b"zz~>"),
            (Filter::RunLength, &[129, b'x', 128]),
        ];
        for (filter, data) in cases {
            let err = decode(filter, &DecodeParams::default(), data, 3).unwrap_err();
            assert!(
                matches!(
                    err,
                    CoreError::ResourceLimit {
                        limit: LimitKind::StreamDecodedSize,
                        max: 3
                    }
                ),
                "{filter}: {err}"
            );
        }
    }

    #[test]
    fn the_limit_itself_is_allowed() {
        let decoded = decode(Filter::AsciiHex, &DecodeParams::default(), b"414243>", 3).unwrap();
        assert_eq!(decoded, b"ABC");
    }
}
