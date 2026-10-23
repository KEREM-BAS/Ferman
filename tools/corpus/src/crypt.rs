//! The standard security handler, for writing encrypted files: RC4 40 (R2), RC4 128 (R3),
//! AES-128 (R4, `AESV2`) and AES-256 (R6, `AESV3`), after ISO 32000-1 §7.6.3 and ISO 32000-2
//! §7.6.4. lopdf can encrypt too, but it draws its initialisation vectors and salts from the
//! system's random number generator; here they come from SHA-256 of a seed, so the file is the
//! same on every run (ADR 0020).

use crate::pdf::hex;
use aes::cipher::{BlockCipherEncrypt, KeyInit};
use lopdf::{Dictionary, Document, Object, ObjectId, dictionary};
use md5::{Digest as _, Md5};
use rc4::{Rc4, StreamCipher};
use sha2::{Sha256, Sha384, Sha512};

/// The padding string of Algorithm 2 (ISO 32000-1 §7.6.3.3).
const PAD: [u8; 32] = [
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
    0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80, 0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
];

/// An encryption method.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Method {
    /// RC4 with a 40-bit key, revision 2.
    Rc4_40,
    /// RC4 with a 128-bit key, revision 3.
    Rc4_128,
    /// AES-128 in CBC mode, revision 4.
    Aes128,
    /// AES-256 in CBC mode, revision 6.
    Aes256,
}

/// How to encrypt a document.
#[derive(Debug, Clone)]
pub struct Security {
    /// The method.
    pub method: Method,
    /// The user (open) password; empty when anyone may open the file.
    pub user: String,
    /// The owner (permissions) password.
    pub owner: String,
    /// The `/P` permission flags as the signed 32-bit value the file stores.
    pub permissions: i32,
    /// The seed of every salt and initialisation vector.
    pub seed: String,
}

/// Every permission granted.
pub const ALL: i32 = -4;
/// Printing (also at full quality) and extraction for accessibility only: no changes, no
/// copying, no comments, no form filling, no page assembly.
pub const PRINT_ONLY: i32 = -3904 | 4 | 512 | 2048;

fn md5(parts: &[&[u8]]) -> [u8; 16] {
    let mut hasher = Md5::new();
    for part in parts {
        hasher.update(part);
    }
    hasher.finalize().into()
}

fn rc4(key: &[u8], data: &[u8]) -> Result<Vec<u8>, String> {
    let mut cipher = Rc4::new_from_slice(key).map_err(|err| format!("RC4 key: {err}"))?;
    let mut out = data.to_vec();
    cipher.apply_keystream(&mut out);
    Ok(out)
}

/// Bytes from SHA-256 of the seed, a label and a counter.
fn seeded(seed: &str, label: &str, length: usize) -> Vec<u8> {
    let mut out = Vec::with_capacity(length);
    let mut counter = 0u32;
    while out.len() < length {
        let mut hasher = Sha256::new();
        hasher.update(seed.as_bytes());
        hasher.update(label.as_bytes());
        hasher.update(counter.to_be_bytes());
        out.extend_from_slice(&hasher.finalize());
        counter += 1;
    }
    out.truncate(length);
    out
}

/// AES-CBC without padding over whole blocks, with `iv`.
fn aes_cbc(key: &[u8], iv: &[u8], data: &[u8]) -> Result<Vec<u8>, String> {
    if !data.len().is_multiple_of(16) {
        return Err("AES-CBC: not whole blocks".to_owned());
    }
    let mut out = Vec::with_capacity(data.len());
    let mut previous: [u8; 16] = iv
        .try_into()
        .map_err(|_| "AES-CBC: the IV is not 16 bytes")?;
    for chunk in data.chunks(16) {
        let mut block = [0u8; 16];
        for (index, byte) in block.iter_mut().enumerate() {
            *byte = chunk[index] ^ previous[index];
        }
        let block = encrypt_block(key, block)?;
        out.extend_from_slice(&block);
        previous = block;
    }
    Ok(out)
}

/// One AES block with a 16- or 32-byte key.
fn encrypt_block(key: &[u8], block: [u8; 16]) -> Result<[u8; 16], String> {
    let mut block = aes::Block::from(block);
    match key.len() {
        16 => aes::Aes128::new_from_slice(key)
            .map_err(|err| err.to_string())?
            .encrypt_block(&mut block),
        32 => aes::Aes256::new_from_slice(key)
            .map_err(|err| err.to_string())?
            .encrypt_block(&mut block),
        other => return Err(format!("AES: a {other}-byte key")),
    }
    Ok(block.into())
}

/// `data` padded with PKCS #7 and encrypted with AES-CBC, the IV first, as PDF stores it.
fn aes_padded(key: &[u8], iv: &[u8], data: &[u8]) -> Result<Vec<u8>, String> {
    let pad = 16 - data.len() % 16;
    let mut padded = data.to_vec();
    padded.extend(std::iter::repeat_n(u8::try_from(pad).unwrap_or(16), pad));
    let mut out = iv.to_vec();
    out.extend(aes_cbc(key, iv, &padded)?);
    Ok(out)
}

/// A password padded or cut to 32 bytes (Algorithm 2, step a). Revisions 2 to 4 take
/// PDFDocEncoding; the passwords here are ASCII or Latin-1.
fn padded_password(password: &str) -> Result<[u8; 32], String> {
    let mut bytes = Vec::new();
    for c in password.chars() {
        bytes.push(u8::try_from(u32::from(c)).map_err(|_| {
            format!("{c:?} is not in PDFDocEncoding; revisions 2 to 4 cannot use it")
        })?);
    }
    bytes.truncate(32);
    let mut out = PAD;
    out[..bytes.len()].copy_from_slice(&bytes);
    let mut result = [0u8; 32];
    result[..bytes.len()].copy_from_slice(&bytes);
    result[bytes.len()..].copy_from_slice(&PAD[..32 - bytes.len()]);
    Ok(result)
}

/// The key length in bytes and the revision of an RC4 or AES-128 method.
fn legacy(method: Method) -> (usize, i64) {
    match method {
        Method::Rc4_40 => (5, 2),
        Method::Rc4_128 => (16, 3),
        Method::Aes128 | Method::Aes256 => (16, 4),
    }
}

/// Algorithm 3: the `/O` value of revisions 2 to 4.
fn owner_value(security: &Security) -> Result<[u8; 32], String> {
    let (length, revision) = legacy(security.method);
    let owner = if security.owner.is_empty() {
        &security.user
    } else {
        &security.owner
    };
    let mut hash = md5(&[&padded_password(owner)?]);
    if revision >= 3 {
        for _ in 0..50 {
            hash = md5(&[&hash[..length]]);
        }
    }
    let key = &hash[..length];
    let mut value = rc4(key, &padded_password(&security.user)?)?;
    if revision >= 3 {
        for round in 1..=19u8 {
            let round_key: Vec<u8> = key.iter().map(|byte| byte ^ round).collect();
            value = rc4(&round_key, &value)?;
        }
    }
    value.try_into().map_err(|_| "O: not 32 bytes".to_owned())
}

/// Algorithm 2: the file key of revisions 2 to 4.
fn legacy_key(security: &Security, owner: &[u8; 32], id: &[u8]) -> Result<Vec<u8>, String> {
    let (length, revision) = legacy(security.method);
    let permissions = security.permissions.to_le_bytes();
    let mut hash = md5(&[&padded_password(&security.user)?, owner, &permissions, id]);
    if revision >= 3 {
        for _ in 0..50 {
            hash = md5(&[&hash[..length]]);
        }
    }
    Ok(hash[..length].to_vec())
}

/// Algorithms 4 and 5: the `/U` value of revisions 2 to 4.
fn user_value(security: &Security, key: &[u8], id: &[u8]) -> Result<Vec<u8>, String> {
    let (_, revision) = legacy(security.method);
    if revision == 2 {
        return rc4(key, &PAD);
    }
    let mut value = rc4(key, &md5(&[&PAD, id]))?;
    for round in 1..=19u8 {
        let round_key: Vec<u8> = key.iter().map(|byte| byte ^ round).collect();
        value = rc4(&round_key, &value)?;
    }
    value.extend_from_slice(&[0u8; 16]);
    Ok(value)
}

/// Algorithm 2.B (ISO 32000-2 §7.6.4.3.4): the hash of revision 6.
fn hash_r6(password: &[u8], salt: &[u8], user: &[u8]) -> Result<[u8; 32], String> {
    let mut k: Vec<u8> = Sha256::new()
        .chain_update(password)
        .chain_update(salt)
        .chain_update(user)
        .finalize()
        .to_vec();
    let mut round = 0u32;
    loop {
        let mut k1 = Vec::with_capacity(64 * (password.len() + k.len() + user.len()));
        for _ in 0..64 {
            k1.extend_from_slice(password);
            k1.extend_from_slice(&k);
            k1.extend_from_slice(user);
        }
        let e = aes_cbc(&k[..16], &k[16..32], &k1)?;
        let remainder = e[..16].iter().map(|byte| u32::from(*byte)).sum::<u32>() % 3;
        k = match remainder {
            0 => Sha256::digest(&e).to_vec(),
            1 => Sha384::digest(&e).to_vec(),
            _ => Sha512::digest(&e).to_vec(),
        };
        round += 1;
        let last = u32::from(e.last().copied().unwrap_or(0));
        if round >= 64 && last + 32 <= round {
            break;
        }
    }
    k[..32]
        .try_into()
        .map_err(|_| "R6 hash: too short".to_owned())
}

/// A revision 6 password: SASLprep, then UTF-8 cut to 127 bytes.
fn password_r6(password: &str) -> Result<Vec<u8>, String> {
    let prepared = stringprep::saslprep(password).map_err(|err| format!("SASLprep: {err}"))?;
    let mut bytes = prepared.as_bytes().to_vec();
    bytes.truncate(127);
    Ok(bytes)
}

/// The encryption dictionary and the file key.
fn dictionary_and_key(security: &Security, id: &[u8]) -> Result<(Dictionary, Vec<u8>), String> {
    let permissions = i64::from(security.permissions);
    match security.method {
        Method::Rc4_40 | Method::Rc4_128 | Method::Aes128 => {
            let (length, revision) = legacy(security.method);
            let owner = owner_value(security)?;
            let key = legacy_key(security, &owner, id)?;
            let user = user_value(security, &key, id)?;
            let bits = i64::try_from(length * 8).map_err(|err| err.to_string())?;
            let mut dict = dictionary! {
                "Filter" => "Standard",
                "V" => match security.method { Method::Rc4_40 => 1, Method::Rc4_128 => 2, _ => 4 },
                "R" => revision,
                "Length" => bits,
                "O" => hex(&owner),
                "U" => hex(&user),
                "P" => permissions,
            };
            if security.method == Method::Aes128 {
                dict.set(
                    "CF",
                    dictionary! { "StdCF" => dictionary! {
                        "Type" => "CryptFilter", "AuthEvent" => "DocOpen", "CFM" => "AESV2", "Length" => 16,
                    }},
                );
                dict.set("StmF", "StdCF");
                dict.set("StrF", "StdCF");
                dict.set("EncryptMetadata", true);
            }
            Ok((dict, key))
        }
        Method::Aes256 => {
            let key = seeded(&security.seed, "file key", 32);
            let salts = seeded(&security.seed, "salts", 32);
            let user_password = password_r6(&security.user)?;
            let owner_password = password_r6(&security.owner)?;
            let mut user = hash_r6(&user_password, &salts[0..8], &[])?.to_vec();
            user.extend_from_slice(&salts[0..16]);
            let user_key = hash_r6(&user_password, &salts[8..16], &[])?;
            let user_encrypted = aes_cbc(&user_key, &[0u8; 16], &key)?;
            let mut owner = hash_r6(&owner_password, &salts[16..24], &user)?.to_vec();
            owner.extend_from_slice(&salts[16..32]);
            let owner_key = hash_r6(&owner_password, &salts[24..32], &user)?;
            let owner_encrypted = aes_cbc(&owner_key, &[0u8; 16], &key)?;
            let mut perms = [0u8; 16];
            perms[..4].copy_from_slice(&security.permissions.to_le_bytes());
            perms[4..8].copy_from_slice(&[0xFF; 4]);
            perms[8..12].copy_from_slice(b"Tadb");
            perms[12..].copy_from_slice(&seeded(&security.seed, "perms", 4));
            let perms = encrypt_block(&key, perms)?;
            let dict = dictionary! {
                "Filter" => "Standard",
                "V" => 5,
                "R" => 6,
                "Length" => 256,
                "CF" => dictionary! { "StdCF" => dictionary! {
                    "Type" => "CryptFilter", "AuthEvent" => "DocOpen", "CFM" => "AESV3", "Length" => 32,
                }},
                "StmF" => "StdCF",
                "StrF" => "StdCF",
                "O" => hex(&owner),
                "U" => hex(&user),
                "OE" => hex(&owner_encrypted),
                "UE" => hex(&user_encrypted),
                "Perms" => hex(&perms),
                "P" => permissions,
                "EncryptMetadata" => true,
            };
            Ok((dict, key))
        }
    }
}

/// Encrypts one string or stream of object `id`.
struct Encrypter<'a> {
    security: &'a Security,
    key: Vec<u8>,
    counter: u32,
}

impl Encrypter<'_> {
    fn object_key(&self, id: ObjectId) -> Vec<u8> {
        if self.security.method == Method::Aes256 {
            return self.key.clone();
        }
        let number = id.0.to_le_bytes();
        let generation = id.1.to_le_bytes();
        let mut parts: Vec<&[u8]> = vec![&self.key, &number[..3], &generation[..2]];
        if self.security.method == Method::Aes128 {
            parts.push(b"sAlT");
        }
        let hash = md5(&parts);
        let length = (self.key.len() + 5).min(16);
        hash[..length].to_vec()
    }

    fn encrypt(&mut self, id: ObjectId, data: &[u8]) -> Result<Vec<u8>, String> {
        let key = self.object_key(id);
        match self.security.method {
            Method::Rc4_40 | Method::Rc4_128 => rc4(&key, data),
            Method::Aes128 | Method::Aes256 => {
                self.counter += 1;
                let label = format!("iv {} {} {}", id.0, id.1, self.counter);
                let iv = seeded(&self.security.seed, &label, 16);
                aes_padded(&key, &iv, data)
            }
        }
    }

    fn object(&mut self, id: ObjectId, object: &mut Object) -> Result<(), String> {
        match object {
            Object::String(bytes, format) => {
                *bytes = self.encrypt(id, bytes)?;
                *format = lopdf::StringFormat::Hexadecimal;
            }
            Object::Array(items) => {
                for item in items {
                    self.object(id, item)?;
                }
            }
            Object::Dictionary(dict) => {
                for (_, value) in dict.iter_mut() {
                    self.object(id, value)?;
                }
            }
            Object::Stream(stream) => {
                for (_, value) in stream.dict.iter_mut() {
                    self.object(id, value)?;
                }
                let content = self.encrypt(id, &stream.content)?;
                stream.set_content(content);
            }
            _ => {}
        }
        Ok(())
    }
}

/// Encrypts every string and stream of `doc` and adds the encryption dictionary to its trailer.
/// The trailer's `/ID` must already be set.
///
/// # Errors
///
/// A message when the `/ID` is missing or a password cannot be used with the method.
pub fn encrypt(doc: &mut Document, security: &Security) -> Result<(), String> {
    let id = doc
        .trailer
        .get(b"ID")
        .and_then(Object::as_array)
        .ok()
        .and_then(|ids| ids.first())
        .and_then(|first| first.as_str().ok())
        .map(<[u8]>::to_vec)
        .ok_or("encrypt: the trailer has no /ID")?;
    let (dict, key) = dictionary_and_key(security, &id)?;
    let mut encrypter = Encrypter {
        security,
        key,
        counter: 0,
    };
    let ids: Vec<ObjectId> = doc.objects.keys().copied().collect();
    for object_id in ids {
        if let Some(object) = doc.objects.get_mut(&object_id) {
            encrypter.object(object_id, object)?;
        }
    }
    let encrypt_id = doc.add_object(dict);
    doc.trailer.set("Encrypt", encrypt_id);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rc4_matches_the_published_vector() {
        // "Key" / "Plaintext" from the RC4 test vectors.
        let out = rc4(b"Key", b"Plaintext").unwrap_or_default();
        assert_eq!(out, [0xBB, 0xF3, 0x16, 0xE8, 0xD9, 0x40, 0xAF, 0x0A, 0xD3]);
    }

    #[test]
    fn aes_matches_fips_197() {
        let key: Vec<u8> = (0u8..16).collect();
        let block: [u8; 16] = [
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD,
            0xEE, 0xFF,
        ];
        let out = encrypt_block(&key, block).unwrap_or_default();
        assert_eq!(
            out,
            [
                0x69, 0xC4, 0xE0, 0xD8, 0x6A, 0x7B, 0x04, 0x30, 0xD8, 0xCD, 0xB7, 0x80, 0x70, 0xB4,
                0xC5, 0x5A
            ]
        );
    }

    #[test]
    fn padding_fills_to_32_bytes_with_the_pad_string() {
        let padded = padded_password("ab").unwrap_or([0; 32]);
        assert_eq!(&padded[..2], b"ab");
        assert_eq!(&padded[2..], &PAD[..30]);
        assert!(padded_password("ş").is_err());
    }

    #[test]
    fn seeded_bytes_are_stable_and_distinct() {
        assert_eq!(seeded("a", "iv", 16), seeded("a", "iv", 16));
        assert_ne!(seeded("a", "iv", 16), seeded("b", "iv", 16));
        assert_eq!(seeded("a", "x", 40).len(), 40);
    }
}
