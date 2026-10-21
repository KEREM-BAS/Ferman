//! The standard security handler (ISO 32000-1 §7.6.3, ISO 32000-2 §7.6.4): passwords, file keys
//! and decryption, for RC4 40 and 128 (revisions 2 and 3), AES-128 (revision 4) and AES-256
//! (revisions 5 and 6), with crypt filters.
//!
//! ferman-core decrypts the objects itself, after lopdf has parsed them as they stand, so the
//! password never reaches lopdf, which would copy it into buffers that are freed without being
//! wiped. A [`Password`] and every buffer derived from it (padded and prepared passwords, hashes,
//! the file key, object keys and cipher states) are wiped from memory when dropped
//! (docs/ARCHITECTURE.md §9.2). Passwords are never logged and never part of an error. PDFium
//! needs the password too, to render the document; what it keeps is
//! [Q22](../../../docs/QUESTIONS.md#q22).
// A parser module: lengths and offsets come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::BTreeMap;
use std::fmt;

use aes::cipher::{BlockCipherDecrypt, BlockCipherEncrypt, KeyInit};
use lopdf::{Dictionary, Object, ObjectId};
use md5::{Digest as _, Md5};
use rc4::{Rc4, StreamCipher};
use sha2::{Sha256, Sha384, Sha512};
use zeroize::Zeroizing;

use crate::limits::Limits;
use crate::text_string;
use crate::{CoreError, Unsupported};

/// The padding string of Algorithm 2 (ISO 32000-1 §7.6.3.3).
const PAD: [u8; 32] = [
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
    0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80, 0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
];

/// The longest password that is prepared; longer input is cut, since revision 6 uses only 127
/// bytes of it.
const MAX_PASSWORD: usize = 4096;

/// A password, wiped from memory when dropped. Its `Debug` output never shows it.
#[derive(Clone, Default)]
pub struct Password(Zeroizing<String>);

impl Password {
    /// Takes `text` as a password. The `String` is moved, not copied, so the only copy is the
    /// one this wipes.
    #[must_use]
    pub fn new(text: String) -> Self {
        Self(Zeroizing::new(text))
    }

    /// The password as text, for handing it to PDFium.
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// Whether the password is empty.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }
}

impl fmt::Debug for Password {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("Password(…)")
    }
}

/// How a document's strings and streams are encrypted.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum Method {
    /// RC4 with a key of `bits` bits (40 to 128).
    Rc4 {
        /// The key length.
        bits: u16,
    },
    /// AES-128 in CBC mode.
    Aes128,
    /// AES-256 in CBC mode.
    Aes256,
    /// Encrypted only in name: the crypt filters are `Identity`.
    Identity,
}

/// The permissions a document grants without its owner password (ISO 32000-2 Table 22).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Permissions {
    /// The `/P` flags.
    bits: u32,
    /// The security handler's revision, which changes what some flags mean.
    revision: u8,
}

impl Permissions {
    /// Every permission, as the owner has them.
    pub const ALL: Self = Self {
        bits: u32::MAX,
        revision: 6,
    };

    fn bit(self, position: u32) -> bool {
        self.bits
            .checked_shr(position.saturating_sub(1))
            .unwrap_or(0)
            & 1
            == 1
    }

    /// Printing.
    #[must_use]
    pub fn print(self) -> bool {
        self.bit(3)
    }

    /// Printing at full quality; without it, printing is limited to a low-resolution image.
    #[must_use]
    pub fn print_high_quality(self) -> bool {
        self.print() && (self.revision < 3 || self.bit(12))
    }

    /// Changing the document other than by the operations below.
    #[must_use]
    pub fn modify(self) -> bool {
        self.bit(4)
    }

    /// Copying or extracting text and graphics.
    #[must_use]
    pub fn copy(self) -> bool {
        self.bit(5)
    }

    /// Adding or changing comments, and filling in form fields.
    #[must_use]
    pub fn annotate(self) -> bool {
        self.bit(6)
    }

    /// Filling in existing form fields, signature fields included.
    #[must_use]
    pub fn fill_forms(self) -> bool {
        self.annotate() || (self.revision >= 3 && self.bit(9))
    }

    /// Extracting text and graphics for accessibility. Always allowed from PDF 2.0, which
    /// deprecates the flag.
    #[must_use]
    pub fn extract_for_accessibility(self) -> bool {
        self.copy() || self.bit(10) || self.revision >= 5
    }

    /// Inserting, rotating and deleting pages and creating bookmarks and thumbnails.
    #[must_use]
    pub fn assemble(self) -> bool {
        self.modify() || (self.revision >= 3 && self.bit(11))
    }

    /// Whether everything is allowed.
    #[must_use]
    pub fn all(self) -> bool {
        self.print_high_quality()
            && self.modify()
            && self.copy()
            && self.annotate()
            && self.fill_forms()
            && self.assemble()
    }
}

/// What a document's encryption is.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EncryptionInfo {
    /// How the strings and streams are encrypted.
    pub method: Method,
    /// The standard security handler's revision, 2 to 6.
    pub revision: u8,
    /// What the document allows without its owner password.
    pub permissions: Permissions,
    /// Whether opening it needs a password: false when the user password is empty and only the
    /// permissions are restricted (a2-10a).
    pub user_password_required: bool,
    /// Whether the document's XMP metadata is encrypted too.
    pub encrypts_metadata: bool,
}

/// Which password opened an encrypted document.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Access {
    /// The user password, or none: the permissions apply.
    User,
    /// The owner password: everything is allowed.
    Owner,
}

/// A cipher for strings or streams.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Cipher {
    Identity,
    Rc4,
    AesV2,
    AesV3,
}

/// The encryption dictionary's values that keys and checks need. None of them is secret.
#[derive(Debug, Clone)]
pub(crate) struct Params {
    revision: u8,
    /// The file key's length in bytes.
    key_length: usize,
    owner: Vec<u8>,
    user: Vec<u8>,
    owner_encrypted: Vec<u8>,
    user_encrypted: Vec<u8>,
    /// `/P` as the four bytes the key derivation hashes.
    p: i32,
    /// The first string of the trailer's `/ID`.
    id: Vec<u8>,
    encrypt_metadata: bool,
    stream: Cipher,
    string: Cipher,
    /// The crypt filters by name, for streams that name one with a `Crypt` filter.
    filters: BTreeMap<Vec<u8>, Cipher>,
}

fn entry_bytes(dict: &Dictionary, key: &[u8]) -> Vec<u8> {
    dict.get(key)
        .ok()
        .and_then(|value| value.as_str().ok())
        .map(<[u8]>::to_vec)
        .unwrap_or_default()
}

fn entry_int(dict: &Dictionary, key: &[u8]) -> Option<i64> {
    dict.get(key).ok().and_then(|value| value.as_i64().ok())
}

fn bad(problem: &'static str) -> CoreError {
    CoreError::Syntax { offset: 0, problem }
}

impl Params {
    /// The parameters of `encrypt`, the trailer's `/Encrypt` dictionary, with `id`, the first
    /// string of the trailer's `/ID`.
    ///
    /// # Errors
    ///
    /// [`CoreError::Unsupported`] for a security handler, revision or crypt filter Ferman does
    /// not support, and [`CoreError::Syntax`] for missing or malformed entries.
    pub(crate) fn new(encrypt: &Dictionary, id: &[u8]) -> Result<Self, CoreError> {
        match encrypt.get(b"Filter").and_then(Object::as_name) {
            Ok(b"Standard") => {}
            Ok(b"Adobe.PubSec") => {
                return Err(CoreError::Unsupported(Unsupported::CertificateSecurity));
            }
            _ => {
                // A certificate handler names its sub-filter; anything else is unknown.
                let certificate = encrypt
                    .get(b"SubFilter")
                    .and_then(Object::as_name)
                    .is_ok_and(|name| name.starts_with(b"adbe.pkcs7"));
                return Err(CoreError::Unsupported(if certificate {
                    Unsupported::CertificateSecurity
                } else {
                    Unsupported::SecurityHandler
                }));
            }
        }
        let unsupported = || CoreError::Unsupported(Unsupported::EncryptionRevision);
        let version = entry_int(encrypt, b"V")
            .and_then(|v| u8::try_from(v).ok())
            .unwrap_or(0);
        let revision = entry_int(encrypt, b"R")
            .and_then(|r| u8::try_from(r).ok())
            .ok_or_else(unsupported)?;
        if !(2..=6).contains(&revision) || !matches!(version, 1 | 2 | 4 | 5) {
            return Err(unsupported());
        }
        let bits = entry_int(encrypt, b"Length");
        let key_length = match version {
            1 => 5,
            2 => {
                let bits = bits.unwrap_or(40);
                if !(40..=128).contains(&bits) || bits % 8 != 0 {
                    return Err(unsupported());
                }
                usize::try_from(bits / 8).map_err(|_| unsupported())?
            }
            4 => 16,
            _ => 32,
        };
        let p = entry_int(encrypt, b"P").ok_or_else(|| bad("an /Encrypt without /P"))?;
        // /P is a 32-bit field that writers store signed or unsigned.
        #[allow(clippy::cast_possible_truncation)]
        let p = p as i32;
        let mut params = Self {
            revision,
            key_length,
            owner: entry_bytes(encrypt, b"O"),
            user: entry_bytes(encrypt, b"U"),
            owner_encrypted: entry_bytes(encrypt, b"OE"),
            user_encrypted: entry_bytes(encrypt, b"UE"),
            p,
            id: id.to_vec(),
            encrypt_metadata: !matches!(
                encrypt.get(b"EncryptMetadata"),
                Ok(Object::Boolean(false))
            ),
            stream: Cipher::Rc4,
            string: Cipher::Rc4,
            filters: BTreeMap::new(),
        };
        let needed = if revision >= 5 { 48 } else { 32 };
        if params.owner.len() < needed || params.user.len() < needed {
            return Err(bad("an /O or /U that is too short"));
        }
        if revision >= 5 && (params.owner_encrypted.len() < 32 || params.user_encrypted.len() < 32)
        {
            return Err(bad("an /OE or /UE that is too short"));
        }
        if version >= 4 {
            if let Ok(filters) = encrypt.get(b"CF").and_then(Object::as_dict) {
                for (name, filter) in filters {
                    let Ok(filter) = filter.as_dict() else {
                        continue;
                    };
                    let cipher = match filter.get(b"CFM").and_then(Object::as_name) {
                        Err(_) | Ok(b"None" | b"Identity") => Cipher::Identity,
                        Ok(b"V2") => Cipher::Rc4,
                        Ok(b"AESV2") => Cipher::AesV2,
                        Ok(b"AESV3") => Cipher::AesV3,
                        Ok(_) => return Err(CoreError::Unsupported(Unsupported::CryptFilter)),
                    };
                    params.filters.insert(name.clone(), cipher);
                }
            }
            let named = |key: &[u8]| -> Result<Cipher, CoreError> {
                match encrypt.get(key).and_then(Object::as_name) {
                    Err(_) | Ok(b"Identity") => Ok(Cipher::Identity),
                    Ok(name) => params
                        .filters
                        .get(name)
                        .copied()
                        .ok_or(CoreError::Unsupported(Unsupported::CryptFilter)),
                }
            };
            params.stream = named(b"StmF")?;
            params.string = named(b"StrF")?;
            if (version == 4 && [params.stream, params.string].contains(&Cipher::AesV3))
                || (version == 5
                    && [params.stream, params.string]
                        .iter()
                        .any(|cipher| matches!(cipher, Cipher::Rc4 | Cipher::AesV2)))
            {
                return Err(CoreError::Unsupported(Unsupported::CryptFilter));
            }
        }
        Ok(params)
    }

    /// The permissions without the owner password.
    pub(crate) fn permissions(&self) -> Permissions {
        Permissions {
            bits: u32::from_ne_bytes(self.p.to_ne_bytes()),
            revision: self.revision,
        }
    }

    /// The method, as the strongest cipher used.
    fn method(&self) -> Method {
        let ciphers = [self.stream, self.string];
        if ciphers.contains(&Cipher::AesV3) {
            Method::Aes256
        } else if ciphers.contains(&Cipher::AesV2) {
            Method::Aes128
        } else if ciphers.contains(&Cipher::Rc4) {
            let bits = self.key_length.saturating_mul(8);
            Method::Rc4 {
                bits: u16::try_from(bits).unwrap_or(u16::MAX),
            }
        } else {
            Method::Identity
        }
    }

    /// What the encryption is, given whether the empty user password failed.
    pub(crate) fn info(&self, user_password_required: bool) -> EncryptionInfo {
        EncryptionInfo {
            method: self.method(),
            revision: self.revision,
            permissions: self.permissions(),
            user_password_required,
            encrypts_metadata: self.encrypt_metadata,
        }
    }

    /// The password's bytes as this revision takes them: PDFDocEncoding for revisions 2 to 4,
    /// SASLprep and UTF-8 for 5 and 6; and the plain UTF-8 bytes, which some writers use and
    /// PDFium accepts, when they differ.
    fn candidates(&self, password: &str) -> Vec<Zeroizing<Vec<u8>>> {
        let password = cut(password, MAX_PASSWORD);
        let mut out = Vec::new();
        if self.revision >= 5 {
            if let Some(prepared) = saslprep(password) {
                out.push(Zeroizing::new(cut(&prepared, 127).as_bytes().to_vec()));
            }
        } else {
            let mut encoded = Zeroizing::new(Vec::with_capacity(password.len()));
            if password
                .chars()
                .all(|c| match text_string::pdf_doc_byte(c) {
                    Some(byte) => {
                        encoded.push(byte);
                        true
                    }
                    None => false,
                })
            {
                out.push(encoded);
            }
        }
        let raw = Zeroizing::new(
            cut(password, if self.revision >= 5 { 127 } else { 32 })
                .as_bytes()
                .to_vec(),
        );
        if !out.iter().any(|candidate| **candidate == *raw) {
            out.push(raw);
        }
        out
    }

    /// The file key when `password` is the user password.
    fn user_key(&self, password: &[u8]) -> Result<Option<Zeroizing<Vec<u8>>>, CoreError> {
        if self.revision >= 5 {
            let validation = self.user.get(32..40).unwrap_or_default();
            let key_salt = self.user.get(40..48).unwrap_or_default();
            let hash = self.hash(password, validation, &[])?;
            if Some(hash.as_slice()) != self.user.get(..32) {
                return Ok(None);
            }
            let intermediate = self.hash(password, key_salt, &[])?;
            return aes256_unwrap(&intermediate, &self.user_encrypted).map(Some);
        }
        let padded = pad(password);
        let key = self.legacy_key(&padded);
        Ok(self.legacy_user_matches(&key)?.then_some(key))
    }

    /// The file key when `password` is the owner password.
    fn owner_key(&self, password: &[u8]) -> Result<Option<Zeroizing<Vec<u8>>>, CoreError> {
        if self.revision >= 5 {
            let user = self.user.get(..48).unwrap_or_default();
            let validation = self.owner.get(32..40).unwrap_or_default();
            let key_salt = self.owner.get(40..48).unwrap_or_default();
            let hash = self.hash(password, validation, user)?;
            if Some(hash.as_slice()) != self.owner.get(..32) {
                return Ok(None);
            }
            let intermediate = self.hash(password, key_salt, user)?;
            return aes256_unwrap(&intermediate, &self.owner_encrypted).map(Some);
        }
        // Algorithm 7: the owner password decrypts /O into the padded user password.
        let mut hash = Zeroizing::new(md5(&[&pad(password)[..]]));
        let length = self.key_length.min(16);
        if self.revision >= 3 {
            for _ in 0..50 {
                *hash = md5(&[hash.get(..length).unwrap_or_default()]);
            }
        }
        let key = Zeroizing::new(hash.get(..length).unwrap_or_default().to_vec());
        let mut user = Zeroizing::new(self.owner.get(..32).unwrap_or_default().to_vec());
        if self.revision == 2 {
            rc4(&key, &mut user)?;
        } else {
            for round in (0..=19u8).rev() {
                let round_key: Zeroizing<Vec<u8>> =
                    Zeroizing::new(key.iter().map(|byte| byte ^ round).collect());
                rc4(&round_key, &mut user)?;
            }
        }
        let key = self.legacy_key(&pad(&user));
        Ok(self.legacy_user_matches(&key)?.then_some(key))
    }

    /// Algorithm 2: the file key of revisions 2 to 4 from a padded user password.
    fn legacy_key(&self, padded: &[u8; 32]) -> Zeroizing<Vec<u8>> {
        let p = self.p.to_le_bytes();
        let mut parts: Vec<&[u8]> = vec![
            padded,
            self.owner.get(..32).unwrap_or_default(),
            &p,
            &self.id,
        ];
        if self.revision >= 4 && !self.encrypt_metadata {
            parts.push(&[0xFF; 4]);
        }
        let mut hash = Zeroizing::new(md5(&parts));
        let length = self.key_length.min(16);
        if self.revision >= 3 {
            for _ in 0..50 {
                *hash = md5(&[hash.get(..length).unwrap_or_default()]);
            }
        }
        Zeroizing::new(hash.get(..length).unwrap_or_default().to_vec())
    }

    /// Algorithms 4 and 5: whether `key` makes this document's `/U`.
    fn legacy_user_matches(&self, key: &[u8]) -> Result<bool, CoreError> {
        if self.revision == 2 {
            let mut value = PAD;
            rc4(key, &mut value)?;
            return Ok(self.user.get(..32) == Some(&value[..]));
        }
        let mut value = md5(&[&PAD, &self.id]);
        for round in 0..=19u8 {
            let round_key: Zeroizing<Vec<u8>> =
                Zeroizing::new(key.iter().map(|byte| byte ^ round).collect());
            rc4(&round_key, &mut value)?;
        }
        Ok(self.user.get(..16) == Some(&value[..]))
    }

    /// The hash of revision 5 (SHA-256) or 6 (Algorithm 2.B).
    fn hash(
        &self,
        password: &[u8],
        salt: &[u8],
        user: &[u8],
    ) -> Result<Zeroizing<[u8; 32]>, CoreError> {
        let first: [u8; 32] = Sha256::new()
            .chain_update(password)
            .chain_update(salt)
            .chain_update(user)
            .finalize()
            .into();
        let first = Zeroizing::new(first);
        if self.revision == 5 {
            return Ok(first);
        }
        hash_2b(password, &first, user)
    }

    /// The file key and the access `password` gives, or `None` when it is neither password. The
    /// owner password is tried first, so a password that is both gives owner access.
    pub(crate) fn authenticate(&self, password: &str) -> Result<Option<Unlocked>, CoreError> {
        for candidate in self.candidates(password) {
            if let Some(key) = self.owner_key(&candidate)? {
                return Ok(Some((key, Access::Owner)));
            }
            if let Some(key) = self.user_key(&candidate)? {
                return Ok(Some((key, Access::User)));
            }
        }
        Ok(None)
    }

    /// Whether `password` is the owner password.
    pub(crate) fn is_owner(&self, password: &str) -> Result<bool, CoreError> {
        for candidate in self.candidates(password) {
            if self.owner_key(&candidate)?.is_some() {
                return Ok(true);
            }
        }
        Ok(false)
    }
}

/// `text` cut to at most `max` bytes at a character boundary.
fn cut(text: &str, max: usize) -> &str {
    let mut end = text.len().min(max);
    while !text.is_char_boundary(end) {
        end = end.saturating_sub(1);
    }
    text.get(..end).unwrap_or_default()
}

/// SASLprep (RFC 4013) into buffers that are wiped, or `None` for a password with prohibited
/// characters. stringprep's own `saslprep` would return the prepared copy in a plain `String`.
fn saslprep(input: &str) -> Option<Zeroizing<String>> {
    use stringprep::tables;
    use unicode_normalization::UnicodeNormalization as _;
    // §2.1: mapping only drops characters or maps them to one byte, so it never outgrows this.
    let mut mapped = Zeroizing::new(String::with_capacity(input.len()));
    for c in input.chars() {
        if tables::commonly_mapped_to_nothing(c) {
            continue;
        }
        mapped.push(if tables::non_ascii_space_character(c) {
            ' '
        } else {
            c
        });
    }
    // §2.2: NFKC grows a string at most 18 times; reserved up front, the buffer is never moved,
    // which would leave a copy behind.
    let mut normalized = Zeroizing::new(String::with_capacity(
        mapped.len().saturating_mul(18).saturating_add(4),
    ));
    for c in mapped.chars().nfkc() {
        normalized.push(c);
    }
    // §2.3 and §2.5: prohibited and unassigned code points.
    let prohibited = normalized.chars().any(|c| {
        tables::non_ascii_space_character(c)
            || tables::ascii_control_character(c)
            || tables::non_ascii_control_character(c)
            || tables::private_use(c)
            || tables::non_character_code_point(c)
            || tables::surrogate_code(c)
            || tables::inappropriate_for_plain_text(c)
            || tables::inappropriate_for_canonical_representation(c)
            || tables::change_display_properties_or_deprecated(c)
            || tables::tagging_character(c)
            || tables::unassigned_code_point(c)
    });
    // §2.4 (RFC 3454 §6): right-to-left text has no left-to-right characters and starts and
    // ends with right-to-left ones.
    let right_to_left = normalized.chars().any(tables::bidi_r_or_al);
    let bidi_ok = !right_to_left
        || (!normalized.chars().any(tables::bidi_l)
            && normalized.chars().next().is_some_and(tables::bidi_r_or_al)
            && normalized
                .chars()
                .next_back()
                .is_some_and(tables::bidi_r_or_al));
    (!prohibited && bidi_ok).then_some(normalized)
}

/// A password padded or cut to 32 bytes with [`PAD`] (Algorithm 2, step a).
fn pad(password: &[u8]) -> Zeroizing<[u8; 32]> {
    let mut out = Zeroizing::new(PAD);
    let used = password.len().min(32);
    if let (Some(head), Some(source)) = (out.get_mut(..used), password.get(..used)) {
        head.copy_from_slice(source);
    }
    if let (Some(tail), Some(rest)) = (out.get_mut(used..), PAD.get(..32usize.saturating_sub(used)))
    {
        tail.copy_from_slice(rest);
    }
    out
}

fn md5(parts: &[&[u8]]) -> [u8; 16] {
    let mut hasher = Md5::new();
    for part in parts {
        hasher.update(part);
    }
    hasher.finalize().into()
}

/// RC4 over `data` in place.
fn rc4(key: &[u8], data: &mut [u8]) -> Result<(), CoreError> {
    let mut cipher = Rc4::new_from_slice(key).map_err(|_| CoreError::Internal {
        context: "an RC4 key of the wrong length",
    })?;
    cipher.apply_keystream(data);
    Ok(())
}

/// Algorithm 2.B of revision 6, from the first SHA-256 round `first`.
fn hash_2b(
    password: &[u8],
    first: &[u8; 32],
    user: &[u8],
) -> Result<Zeroizing<[u8; 32]>, CoreError> {
    let internal = || CoreError::Internal {
        context: "the revision 6 hash",
    };
    let mut k: Zeroizing<Vec<u8>> = Zeroizing::new(first.to_vec());
    let mut round: u32 = 0;
    loop {
        let unit = password
            .len()
            .checked_add(k.len())
            .and_then(|len| len.checked_add(user.len()))
            .ok_or_else(internal)?;
        let mut k1 = Zeroizing::new(Vec::with_capacity(
            unit.checked_mul(64).ok_or_else(internal)?,
        ));
        for _ in 0..64 {
            k1.extend_from_slice(password);
            k1.extend_from_slice(&k);
            k1.extend_from_slice(user);
        }
        let key = k.get(..16).ok_or_else(internal)?;
        let iv = k.get(16..32).ok_or_else(internal)?;
        let e = Zeroizing::new(aes128_cbc_encrypt(key, iv, &k1)?);
        let sum: u32 = e
            .get(..16)
            .ok_or_else(internal)?
            .iter()
            .fold(0u32, |sum, byte| sum.wrapping_add(u32::from(*byte)));
        *k = match sum % 3 {
            0 => Sha256::digest(&*e).to_vec(),
            1 => Sha384::digest(&*e).to_vec(),
            _ => Sha512::digest(&*e).to_vec(),
        };
        round = round.saturating_add(1);
        let last = u32::from(e.last().copied().unwrap_or(0));
        if round >= 64 && last.saturating_add(32) <= round {
            break;
        }
    }
    let mut out = Zeroizing::new([0u8; 32]);
    out.copy_from_slice(k.get(..32).ok_or_else(internal)?);
    Ok(out)
}

/// AES-128-CBC encryption without padding over whole blocks.
fn aes128_cbc_encrypt(key: &[u8], iv: &[u8], data: &[u8]) -> Result<Vec<u8>, CoreError> {
    let cipher = aes::Aes128::new_from_slice(key).map_err(|_| CoreError::Internal {
        context: "an AES-128 key of the wrong length",
    })?;
    let mut previous = aes::Block::default();
    previous.copy_from_slice(iv.get(..16).unwrap_or(&[0; 16]));
    let mut out = Vec::with_capacity(data.len());
    for chunk in data.as_chunks::<16>().0 {
        let mut block = aes::Block::default();
        for ((out, a), b) in block.iter_mut().zip(chunk).zip(previous.iter()) {
            *out = a ^ b;
        }
        cipher.encrypt_block(&mut block);
        out.extend_from_slice(&block);
        previous = block;
    }
    Ok(out)
}

/// The file key of revisions 5 and 6: `/UE` or `/OE` decrypted with AES-256-CBC, a zero IV and
/// no padding.
fn aes256_unwrap(key: &[u8; 32], wrapped: &[u8]) -> Result<Zeroizing<Vec<u8>>, CoreError> {
    let cipher = aes::Aes256::new_from_slice(key).map_err(|_| CoreError::Internal {
        context: "an AES-256 key of the wrong length",
    })?;
    let mut out = Zeroizing::new(Vec::with_capacity(32));
    let mut previous = aes::Block::default();
    for chunk in wrapped.get(..32).unwrap_or_default().as_chunks::<16>().0 {
        let mut block = aes::Block::from(*chunk);
        let saved = block;
        cipher.decrypt_block(&mut block);
        for (byte, prev) in block.iter_mut().zip(previous.iter()) {
            *byte ^= prev;
        }
        out.extend_from_slice(&block);
        previous = saved;
    }
    Ok(out)
}

/// A file key and the access its password gives.
pub(crate) type Unlocked = (Zeroizing<Vec<u8>>, Access);

/// An unlocked document's decrypter: the file key and the ciphers.
pub(crate) struct Decrypter {
    params: Params,
    key: Zeroizing<Vec<u8>>,
}

impl fmt::Debug for Decrypter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Decrypter")
            .field("revision", &self.params.revision)
            .finish_non_exhaustive()
    }
}

impl Decrypter {
    /// A decrypter with the file key `key`.
    pub(crate) fn new(params: Params, key: Zeroizing<Vec<u8>>) -> Self {
        Self { params, key }
    }

    /// The parameters, for checking an owner password later.
    pub(crate) fn params(&self) -> &Params {
        &self.params
    }

    /// The key for object `id` (Algorithm 1); AES-256 uses the file key itself.
    fn object_key(&self, id: ObjectId, cipher: Cipher) -> Zeroizing<Vec<u8>> {
        if cipher == Cipher::AesV3 {
            return self.key.clone();
        }
        let number = id.0.to_le_bytes();
        let generation = id.1.to_le_bytes();
        let mut parts: Vec<&[u8]> =
            vec![&self.key, number.get(..3).unwrap_or_default(), &generation];
        if cipher == Cipher::AesV2 {
            parts.push(b"sAlT");
        }
        let hash = Zeroizing::new(md5(&parts));
        let length = self.key.len().saturating_add(5).min(16);
        Zeroizing::new(hash.get(..length).unwrap_or_default().to_vec())
    }

    /// `data` of object `id` decrypted with `cipher`. AES data whose IV is missing decrypts to
    /// nothing, a partial last block is dropped, and padding that is not valid is kept, as PDFium
    /// reads them.
    fn decrypt(&self, id: ObjectId, cipher: Cipher, data: &mut Vec<u8>) -> Result<(), CoreError> {
        match cipher {
            Cipher::Identity => Ok(()),
            Cipher::Rc4 => rc4(&self.object_key(id, cipher), data),
            Cipher::AesV2 | Cipher::AesV3 => {
                let key = self.object_key(id, cipher);
                let plain = aes_cbc_decrypt(&key, data)?;
                *data = plain;
                Ok(())
            }
        }
    }

    /// Decrypts every string and stream of object `id` in place (ISO 32000-2 §7.6.2): not the
    /// encryption dictionary, cross-reference streams, a signature's `/Contents`, or unencrypted
    /// metadata.
    pub(crate) fn decrypt_object(
        &self,
        id: ObjectId,
        object: &mut Object,
        limits: &Limits,
    ) -> Result<(), CoreError> {
        self.walk(id, object, 0, limits)
    }

    fn walk(
        &self,
        id: ObjectId,
        object: &mut Object,
        depth: u32,
        limits: &Limits,
    ) -> Result<(), CoreError> {
        if depth > limits.max_nesting {
            return Err(CoreError::ResourceLimit {
                limit: crate::limits::LimitKind::Nesting,
                max: u64::from(limits.max_nesting),
            });
        }
        let deeper = depth.saturating_add(1);
        match object {
            Object::String(bytes, _) => self.decrypt(id, self.params.string, bytes)?,
            Object::Array(items) => {
                for item in items {
                    self.walk(id, item, deeper, limits)?;
                }
            }
            Object::Dictionary(dict) => self.walk_dict(id, dict, deeper, limits)?,
            Object::Stream(stream) => {
                self.walk_dict(id, &mut stream.dict, deeper, limits)?;
                let kind = stream.dict.get(b"Type").and_then(Object::as_name).ok();
                if kind == Some(b"XRef")
                    || (kind == Some(b"Metadata") && !self.params.encrypt_metadata)
                {
                    return Ok(());
                }
                let cipher = self.stream_cipher(&mut stream.dict)?;
                let mut content = std::mem::take(&mut stream.content);
                self.decrypt(id, cipher, &mut content)?;
                stream.set_content(content);
            }
            _ => {}
        }
        Ok(())
    }

    fn walk_dict(
        &self,
        id: ObjectId,
        dict: &mut Dictionary,
        depth: u32,
        limits: &Limits,
    ) -> Result<(), CoreError> {
        let signature = dict.get(b"Type").and_then(Object::as_name).ok() == Some(b"Sig");
        for (key, value) in dict.iter_mut() {
            if signature && key.as_slice() == b"Contents" {
                continue;
            }
            self.walk(id, value, depth, limits)?;
        }
        Ok(())
    }

    /// The cipher of a stream: its own crypt filter, which is removed from its filter chain so
    /// the chain decodes, or the default stream cipher.
    fn stream_cipher(&self, dict: &mut Dictionary) -> Result<Cipher, CoreError> {
        let first_is_crypt = match dict.get(b"Filter") {
            Ok(Object::Name(name)) => name.as_slice() == b"Crypt",
            Ok(Object::Array(items)) => items
                .first()
                .and_then(|item| item.as_name().ok())
                .is_some_and(|name| name == b"Crypt"),
            _ => false,
        };
        if !first_is_crypt {
            return Ok(self.params.stream);
        }
        let params = match dict.get(b"DecodeParms") {
            Ok(Object::Dictionary(params)) => Some(params.clone()),
            Ok(Object::Array(items)) => items.first().and_then(|item| item.as_dict().ok()).cloned(),
            _ => None,
        };
        let name = params
            .as_ref()
            .and_then(|params| params.get(b"Name").and_then(Object::as_name).ok())
            .unwrap_or(b"Identity");
        let cipher = if name == b"Identity" {
            Cipher::Identity
        } else {
            self.params
                .filters
                .get(name)
                .copied()
                .ok_or(CoreError::Unsupported(Unsupported::CryptFilter))?
        };
        // Remove the Crypt step and its parameters.
        match dict.get_mut(b"Filter") {
            Ok(Object::Array(items)) if items.len() > 1 => {
                items.remove(0);
            }
            _ => {
                dict.remove(b"Filter");
            }
        }
        match dict.get_mut(b"DecodeParms") {
            Ok(Object::Array(items)) if items.len() > 1 => {
                items.remove(0);
            }
            _ => {
                dict.remove(b"DecodeParms");
            }
        }
        Ok(cipher)
    }
}

/// AES-CBC decryption of data stored as IV then ciphertext, with PKCS #7 padding removed.
fn aes_cbc_decrypt(key: &[u8], data: &[u8]) -> Result<Vec<u8>, CoreError> {
    let Some((iv, body)) = data.split_at_checked(16) else {
        return Ok(Vec::new());
    };
    let mut out = Vec::new();
    out.try_reserve_exact(body.len())
        .map_err(|_| CoreError::OutOfMemory {
            context: "decrypting a stream",
        })?;
    let mut previous = aes::Block::default();
    previous.copy_from_slice(iv);
    let mut run = |decrypt: &dyn Fn(&mut aes::Block)| {
        for chunk in body.as_chunks::<16>().0 {
            let mut block = aes::Block::from(*chunk);
            let saved = block;
            decrypt(&mut block);
            for (byte, prev) in block.iter_mut().zip(previous.iter()) {
                *byte ^= prev;
            }
            out.extend_from_slice(&block);
            previous = saved;
        }
    };
    match key.len() {
        16 => {
            let cipher = aes::Aes128::new_from_slice(key).map_err(|_| aes_key())?;
            run(&|block| cipher.decrypt_block(block));
        }
        32 => {
            let cipher = aes::Aes256::new_from_slice(key).map_err(|_| aes_key())?;
            run(&|block| cipher.decrypt_block(block));
        }
        _ => return Err(aes_key()),
    }
    if let Some(&padding) = out.last() {
        let padding = usize::from(padding);
        if (1..=16).contains(&padding) && padding <= out.len() {
            out.truncate(out.len().saturating_sub(padding));
        }
    }
    Ok(out)
}

fn aes_key() -> CoreError {
    CoreError::Internal {
        context: "an AES key of the wrong length",
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    #[test]
    fn a_password_never_shows_in_debug_output() {
        let password = Password::new("Eylül2026maaşı".to_owned());
        assert_eq!(format!("{password:?}"), "Password(…)");
        assert_eq!(password.as_str(), "Eylül2026maaşı");
    }

    #[test]
    fn passwords_and_keys_are_wiped_when_dropped() {
        // The types that hold secrets wipe themselves (zeroize's ZeroizeOnDrop); the hash and
        // cipher crates are built with their zeroize features (Cargo.toml).
        fn wipes<T: zeroize::ZeroizeOnDrop>() {}
        wipes::<Zeroizing<String>>();
        wipes::<Zeroizing<Vec<u8>>>();
        wipes::<Zeroizing<[u8; 32]>>();
        wipes::<Rc4>();
        wipes::<aes::Aes128>();
        wipes::<aes::Aes256>();
        fn wiped_password(password: Password) -> Zeroizing<String> {
            password.0
        }
        let _ = wiped_password(Password::default());
    }

    #[test]
    fn rc4_matches_the_published_vector() {
        let mut data = *b"Plaintext";
        rc4(b"Key", &mut data).unwrap();
        assert_eq!(data, [0xBB, 0xF3, 0x16, 0xE8, 0xD9, 0x40, 0xAF, 0x0A, 0xD3]);
    }

    #[test]
    fn aes_cbc_round_trips_with_padding() {
        let key = [7u8; 16];
        let iv = [9u8; 16];
        let mut padded = b"hello, world".to_vec();
        padded.extend([4u8; 4]);
        let encrypted = aes128_cbc_encrypt(&key, &iv, &padded).unwrap();
        let mut stored = iv.to_vec();
        stored.extend(encrypted);
        assert_eq!(aes_cbc_decrypt(&key, &stored).unwrap(), b"hello, world");
        // No IV, and a partial last block.
        assert!(aes_cbc_decrypt(&key, &[1, 2, 3]).unwrap().is_empty());
        stored.extend([1, 2, 3]);
        assert_eq!(aes_cbc_decrypt(&key, &stored).unwrap(), b"hello, world");
    }

    #[test]
    fn padding_fills_to_32_bytes() {
        let padded = pad(b"ab");
        assert_eq!(&padded[..2], b"ab");
        assert_eq!(&padded[2..], &PAD[..30]);
        assert_eq!(&pad(&[1u8; 40])[..], &[1u8; 32]);
    }

    #[test]
    fn saslprep_maps_and_refuses_as_rfc_4013_says() {
        // RFC 4013 §3 examples.
        assert_eq!(
            saslprep("I\u{00AD}X").as_deref().map(String::as_str),
            Some("IX")
        );
        assert_eq!(
            saslprep("user").as_deref().map(String::as_str),
            Some("user")
        );
        assert_eq!(
            saslprep("\u{00AA}").as_deref().map(String::as_str),
            Some("a")
        );
        assert_eq!(
            saslprep("\u{2168}").as_deref().map(String::as_str),
            Some("IX")
        );
        assert!(saslprep("\u{0007}").is_none());
        assert!(saslprep("\u{0627}1").is_none());
        assert_eq!(
            saslprep("Eylül2026maaşı").as_deref().map(String::as_str),
            Some("Eylül2026maaşı")
        );
        assert_eq!(
            saslprep("a\u{00A0}b").as_deref().map(String::as_str),
            Some("a b")
        );
    }

    #[test]
    fn permissions_read_the_p_flags() {
        // The corpus's print-only flags: printing at full quality and accessibility.
        let p: i32 = -3904 | 4 | 512 | 2048;
        let permissions = Permissions {
            bits: u32::from_ne_bytes(p.to_ne_bytes()),
            revision: 4,
        };
        assert!(permissions.print() && permissions.print_high_quality());
        assert!(permissions.extract_for_accessibility());
        assert!(!permissions.modify() && !permissions.copy() && !permissions.annotate());
        assert!(!permissions.fill_forms() && !permissions.assemble());
        assert!(!permissions.all());
        assert!(Permissions::ALL.all());
        // Revision 2 has no bits 9 to 12: annotation implies filling.
        let r2 = Permissions {
            bits: 0b10_0000 | 0b100,
            revision: 2,
        };
        assert!(r2.fill_forms() && r2.print_high_quality() && !r2.assemble());
    }

    #[test]
    fn cut_keeps_characters_whole() {
        assert_eq!(cut("aş", 2), "a");
        assert_eq!(cut("aş", 3), "aş");
        assert_eq!(cut("", 5), "");
    }
}
