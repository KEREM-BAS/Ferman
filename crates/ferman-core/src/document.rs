//! Opening a document (docs/ARCHITECTURE.md §5.1 and §5.2): from a [`Source`] to the lopdf
//! model, through ferman-core's own cross-reference reader, repair and security handler.
//!
//! 1. A file without a `%PDF-` header in its first kilobyte is not a PDF ([`CoreError::NotPdf`]).
//! 2. The cross-reference data is read and checked. When it is missing or wrong, the file is
//!    scanned and the table rebuilt ([`RepairReport`]); with no catalog to be found, the file
//!    cannot be opened ([`CoreError::Damaged`]).
//! 3. An encrypted file is unlocked with the empty user password, or the password given
//!    ([`CoreError::PasswordRequired`], [`CoreError::WrongPassword`]).
//! 4. lopdf parses the objects. A healthy unencrypted file is parsed in place; a repaired or
//!    encrypted one through a copy with one clean cross-reference table, and an encrypted one's
//!    objects are decrypted by ferman-core afterwards, object streams included.
//! 5. Objects the cross-reference data names that lopdf could not read are reported as a
//!    repair. The structure scan reads pages, labels, outline, attachments, layers, forms,
//!    signatures, scripts and fonts ([`Structure`]).
//!
//! lopdf may panic on input it does not expect; ferman-api calls [`open`] under `catch_unwind`
//! on a thread with a large stack (ADR 0010), and the fuzz targets look for those panics.

use std::collections::{BTreeMap, BTreeSet};

use lopdf::{Object, ObjectId, Stream};

use crate::limits::Limits;
use crate::repair::{self, Diagnosis, LikelyCause, Repair, RepairReport};
use crate::security::{Access, Decrypter, EncryptionInfo, Params, Password, Permissions};
use crate::sniff;
use crate::source::Source;
use crate::structure::{self, Structure};
use crate::syntax::Parser;
use crate::xref::{self, Entry, Xref};
use crate::{CoreError, Unsupported};

/// How to open a document.
#[derive(Debug, Clone, Default)]
pub struct OpenOptions {
    /// The password, for an encrypted document: the user password, or the owner password, which
    /// lifts its restrictions too.
    pub password: Option<Password>,
    /// The resource limits.
    pub limits: Limits,
}

/// An encrypted document's state once unlocked.
#[derive(Debug)]
struct Encryption {
    info: EncryptionInfo,
    access: Access,
    decrypter: Decrypter,
}

/// An open document: its bytes, the lopdf model and what the open found.
#[derive(Debug)]
pub struct Document {
    source: Source,
    version: String,
    model: lopdf::Document,
    repair: Option<RepairReport>,
    encryption: Option<Encryption>,
    structure: Structure,
}

impl Document {
    /// The bytes the document was opened from.
    #[must_use]
    pub fn source(&self) -> &Source {
        &self.source
    }

    /// The version in the header, such as `1.7`.
    #[must_use]
    pub fn version(&self) -> &str {
        &self.version
    }

    /// What repair did, when the file needed it. A repaired document is read-only until a
    /// repaired copy is saved (M3).
    #[must_use]
    pub fn repair(&self) -> Option<&RepairReport> {
        self.repair.as_ref()
    }

    /// The encryption, when the document is encrypted.
    #[must_use]
    pub fn encryption(&self) -> Option<&EncryptionInfo> {
        self.encryption.as_ref().map(|encryption| &encryption.info)
    }

    /// Which password opened the document; [`Access::Owner`] for one that is not encrypted.
    #[must_use]
    pub fn access(&self) -> Access {
        self.encryption
            .as_ref()
            .map_or(Access::Owner, |encryption| encryption.access)
    }

    /// What the document allows now: everything with owner access.
    #[must_use]
    pub fn permissions(&self) -> Permissions {
        match &self.encryption {
            Some(encryption) if encryption.access == Access::User => encryption.info.permissions,
            _ => Permissions::ALL,
        }
    }

    /// Lifts the restrictions for this session when `password` is the owner password (a2-10b).
    /// Returns whether it was.
    ///
    /// # Errors
    ///
    /// [`CoreError::Internal`] when a cipher cannot be set up.
    pub fn unlock_owner(&mut self, password: &Password) -> Result<bool, CoreError> {
        let Some(encryption) = &mut self.encryption else {
            return Ok(true);
        };
        if encryption.access == Access::Owner {
            return Ok(true);
        }
        if encryption.decrypter.params().is_owner(password.as_str())? {
            encryption.access = Access::Owner;
            return Ok(true);
        }
        Ok(false)
    }

    /// What the structure scan found.
    #[must_use]
    pub fn structure(&self) -> &Structure {
        &self.structure
    }

    /// The number of pages, as lopdf's page tree gives them.
    #[must_use]
    pub fn page_count(&self) -> usize {
        self.structure.pages.len()
    }

    /// The lopdf model; it never leaves ferman-core (ADR 0004).
    #[cfg_attr(not(test), allow(dead_code))]
    pub(crate) fn model(&self) -> &lopdf::Document {
        &self.model
    }
}

/// The encryption dictionary named by the trailer, read from the file.
fn encryption_dictionary(
    base: &[u8],
    xref: &Xref,
    limits: &Limits,
) -> Result<Option<(lopdf::Dictionary, Option<ObjectId>)>, CoreError> {
    match xref.trailer.get(b"Encrypt") {
        Err(_) | Ok(Object::Null) => Ok(None),
        Ok(Object::Dictionary(dict)) => Ok(Some((dict.clone(), None))),
        Ok(Object::Reference(id)) => {
            let offset = xref.offset_of(*id).ok_or(CoreError::Syntax {
                offset: 0,
                problem: "an /Encrypt that names no object",
            })?;
            let indirect = Parser::new(base, offset, limits).indirect(&|_| None)?;
            match indirect.object {
                Object::Dictionary(dict) => Ok(Some((dict, Some(*id)))),
                _ => Err(CoreError::Syntax {
                    offset: 0,
                    problem: "an /Encrypt that is not a dictionary",
                }),
            }
        }
        Ok(_) => Err(CoreError::Syntax {
            offset: 0,
            problem: "an /Encrypt that is not a dictionary",
        }),
    }
}

/// The first string of the trailer's `/ID`, or nothing.
fn first_id(xref: &Xref) -> Vec<u8> {
    xref.trailer
        .get(b"ID")
        .ok()
        .and_then(|ids| ids.as_array().ok())
        .and_then(|ids| ids.first())
        .and_then(|id| id.as_str().ok())
        .map(<[u8]>::to_vec)
        .unwrap_or_default()
}

/// Unlocks an encrypted document, or says what it needs.
fn unlock(
    params: Params,
    password: Option<&Password>,
) -> Result<(EncryptionInfo, Access, Decrypter), CoreError> {
    let empty = params.authenticate("")?;
    let user_password_required = empty.is_none();
    let unlocked = match password.filter(|password| !password.is_empty()) {
        Some(password) => params
            .authenticate(password.as_str())?
            .ok_or(CoreError::WrongPassword)?,
        None => empty.ok_or(CoreError::PasswordRequired)?,
    };
    let (key, access) = unlocked;
    let info = params.info(user_password_required);
    Ok((info, access, Decrypter::new(params, key)))
}

/// Opens the document in `source`.
///
/// # Errors
///
/// [`CoreError::NotPdf`], [`CoreError::Damaged`], [`CoreError::PasswordRequired`],
/// [`CoreError::WrongPassword`], [`CoreError::Unsupported`], [`CoreError::ResourceLimit`] and
/// [`CoreError::OutOfMemory`].
pub fn open(source: &Source, options: &OpenOptions) -> Result<Document, CoreError> {
    let limits = &options.limits;
    let bytes: &[u8] = source.bytes();
    let Some(header) = sniff::header_offset(bytes) else {
        return Err(CoreError::NotPdf {
            kind: sniff::kind(bytes),
        });
    };
    // Offsets count from the header, as lopdf and PDFium count them.
    let base = bytes.get(header..).unwrap_or_default();
    if u32::try_from(base.len()).is_err() {
        return Err(CoreError::Unsupported(Unsupported::FileSize));
    }
    let version = header_version(base);

    // The cross-reference data, rebuilt when it is broken.
    let mut scan_object_streams = BTreeSet::new();
    let (xref, mut report) = match xref::read(base, limits)? {
        Ok(xref) => (xref, None),
        Err(problem) => {
            let scan = repair::scan(base, limits)?;
            scan_object_streams.clone_from(&scan.object_streams);
            let (xref, report) = repair::rebuild(&scan, base, problem)
                .map_err(|diagnosis| CoreError::Damaged(Box::new(diagnosis)))?;
            (xref, Some(report))
        }
    };
    let repaired = report.is_some();

    // Encryption.
    let mut encryption = None;
    let mut encrypt_id = None;
    if let Some((dict, id)) = encryption_dictionary(base, &xref, limits)? {
        let params = Params::new(&dict, &first_id(&xref))?;
        let (info, access, decrypter) = unlock(params, options.password.as_ref())?;
        encryption = Some(Encryption {
            info,
            access,
            decrypter,
        });
        encrypt_id = id;
    }

    // The object streams ferman-core reads itself: an encrypted file's, which lopdf would try to
    // decode before they are decrypted.
    let containers: BTreeSet<u32> = if encryption.is_some() {
        if repaired {
            scan_object_streams
        } else {
            xref.containers()
        }
    } else {
        BTreeSet::new()
    };

    let flat;
    let lopdf_bytes: &[u8] = if repaired || encryption.is_some() {
        flat = xref::flatten(base, &xref, &containers)?;
        &flat
    } else {
        base
    };
    let load = lopdf::LoadOptions {
        max_decompressed_size: usize::try_from(limits.max_stream_decoded).ok(),
        ..lopdf::LoadOptions::default()
    };
    let mut model = lopdf::Document::load_mem_with_options(lopdf_bytes, load).map_err(|_| {
        CoreError::Damaged(Box::new(Diagnosis {
            likely_cause: LikelyCause::Unreadable,
            file_size: u64::try_from(base.len()).unwrap_or(u64::MAX),
            expected_size: None,
            last_complete_object: None,
            objects_found: u32::try_from(xref.in_use().count()).unwrap_or(u32::MAX),
            has_trailer: !xref.trailer.is_empty(),
        }))
    })?;

    if let Some(encryption) = &encryption {
        decrypt_model(&mut model, &encryption.decrypter, encrypt_id, limits)?;
        read_object_streams(
            &mut model,
            base,
            &xref,
            &containers,
            repaired,
            &encryption.decrypter,
            limits,
        )?;
    }

    // Objects the cross-reference data names that are not in the model.
    let unreadable: Vec<u32> = xref
        .in_use()
        .filter(|id| Some(*id) != encrypt_id && !model.objects.contains_key(id))
        .map(|(number, _)| number)
        .collect();
    if let Some(&first) = unreadable.first() {
        report
            .get_or_insert_with(RepairReport::default)
            .repairs
            .push(Repair::ObjectsUnreadable {
                objects: u32::try_from(unreadable.len()).unwrap_or(u32::MAX),
                first,
            });
    }

    let structure = structure::scan(&model, limits);
    Ok(Document {
        source: source.clone(),
        version,
        model,
        repair: report,
        encryption,
        structure,
    })
}

/// The version after `%PDF-`, such as `1.7`, or empty when it is unreadable.
fn header_version(base: &[u8]) -> String {
    base.get(5..)
        .unwrap_or_default()
        .iter()
        .take(8)
        .take_while(|byte| byte.is_ascii_digit() || **byte == b'.')
        .map(|&byte| char::from(byte))
        .collect()
}

/// Decrypts every object of `model` but the encryption dictionary, which it removes.
fn decrypt_model(
    model: &mut lopdf::Document,
    decrypter: &Decrypter,
    encrypt_id: Option<ObjectId>,
    limits: &Limits,
) -> Result<(), CoreError> {
    if let Some(id) = encrypt_id {
        model.objects.remove(&id);
    }
    for (id, object) in &mut model.objects {
        decrypter.decrypt_object(*id, object, limits)?;
    }
    Ok(())
}

/// Reads the object streams `containers` from the file, decrypts them and adds their objects:
/// those the cross-reference data places in them, or for a repaired file every one the model
/// lacks.
fn read_object_streams(
    model: &mut lopdf::Document,
    base: &[u8],
    xref: &Xref,
    containers: &BTreeSet<u32>,
    repaired: bool,
    decrypter: &Decrypter,
    limits: &Limits,
) -> Result<(), CoreError> {
    let max = usize::try_from(limits.max_stream_decoded).ok();
    for &container in containers {
        let Some(Entry::Normal { offset, generation }) = xref.entries.get(&container).copied()
        else {
            continue;
        };
        let length = |id: ObjectId| model.objects.get(&id).and_then(|value| value.as_i64().ok());
        let Ok(indirect) = Parser::new(base, offset, limits).indirect(&length) else {
            continue;
        };
        let (Object::Dictionary(dict), Some(range)) = (indirect.object, indirect.data) else {
            continue;
        };
        let content = base.get(range).unwrap_or_default().to_vec();
        let mut stream = Object::Stream(Stream::new(dict, content));
        let id = (container, generation);
        decrypter.decrypt_object(id, &mut stream, limits)?;
        let Object::Stream(stream) = stream else {
            continue;
        };
        // A damaged object stream is left out; its objects count as unreadable.
        let Ok(members) = lopdf::ObjectStream::new_with_limit(&stream, max) else {
            continue;
        };
        let mut members: BTreeMap<ObjectId, Object> = members.objects;
        for (member, object) in std::mem::take(&mut members) {
            let belongs = if repaired {
                !model.objects.contains_key(&member)
            } else {
                matches!(
                    xref.entries.get(&member.0),
                    Some(Entry::Compressed { container: c, .. }) if *c == container
                )
            };
            if belongs {
                model.objects.insert(member, object);
            }
        }
        model.objects.insert(id, Object::Stream(stream));
    }
    Ok(())
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;
    use std::sync::Arc;

    fn source(bytes: &[u8]) -> Source {
        Source::from_bytes(Arc::from(bytes))
    }

    #[test]
    fn a_file_without_a_header_is_not_a_pdf() {
        assert!(matches!(
            open(&source(b"PK\x03\x04docx"), &OpenOptions::default()),
            Err(CoreError::NotPdf {
                kind: crate::FileKind::Zip
            })
        ));
        assert!(matches!(
            open(&source(b""), &OpenOptions::default()),
            Err(CoreError::NotPdf {
                kind: crate::FileKind::Empty
            })
        ));
    }

    #[test]
    fn a_healthy_file_opens_without_repair() {
        let data = crate::xref::tests::simple(|offset| offset);
        let document = open(&source(&data), &OpenOptions::default()).unwrap();
        assert_eq!(document.page_count(), 1);
        assert_eq!(document.model().objects.len(), 3);
        assert!(document.repair().is_none());
        assert!(document.encryption().is_none());
        assert_eq!(document.access(), Access::Owner);
        assert_eq!(document.version(), "1.7");
    }

    #[test]
    fn junk_before_the_header_shifts_the_offsets() {
        let mut data = b"junk junk\n".to_vec();
        data.extend(crate::xref::tests::simple(|offset| offset));
        let document = open(&source(&data), &OpenOptions::default()).unwrap();
        assert_eq!(document.page_count(), 1);
        assert!(document.repair().is_none());
    }

    #[test]
    fn wrong_offsets_are_repaired() {
        let data = crate::xref::tests::simple(|offset| offset - 2);
        let document = open(&source(&data), &OpenOptions::default()).unwrap();
        assert_eq!(document.page_count(), 1);
        let report = document.repair().unwrap();
        assert!(matches!(
            report.repairs[0],
            Repair::CrossReferenceRebuilt { objects: 3, .. }
        ));
    }

    #[test]
    fn encrypted_streams_decrypt_and_decode() {
        let dir =
            std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../tests/corpus/generated");
        for (name, password) in [
            ("payslip-rc4-40", "bordro2026"),
            ("payslip-rc4-128", "bordro2026"),
            ("payslip-aes128", "bordro2026"),
            ("payslip-aes256", "Eylül2026maaşı"),
            ("kira-tr-restricted", ""),
        ] {
            let source = Source::read(&dir.join(format!("{name}.pdf"))).unwrap();
            let options = OpenOptions {
                password: Some(Password::new(password.to_owned())),
                ..OpenOptions::default()
            };
            let document = open(&source, &options).unwrap();
            for page in document.model().page_iter() {
                // Flate decodes only what was decrypted right.
                let content = document.model().get_page_content(page);
                let text = String::from_utf8_lossy(&content);
                assert!(
                    text.contains("BT") && text.contains("ET"),
                    "{name}: {text:.80}"
                );
            }
            assert!(!document.model().objects.values().any(|object| {
                object.as_dict().is_ok_and(|dict| {
                    dict.has(b"CF")
                        || dict.get(b"Filter").and_then(Object::as_name).ok()
                            == Some(&b"Standard"[..])
                })
            }));
        }
    }

    /// `simple`'s three objects with `extra` as a fourth object referenced from the page.
    fn with_object(extra: &str) -> Vec<u8> {
        use std::fmt::Write as _;
        let mut out = String::from("%PDF-1.7\n");
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R >>".to_owned(),
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>".to_owned(),
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>".to_owned(),
            extra.to_owned(),
        ];
        let mut offsets = Vec::new();
        for (index, body) in objects.iter().enumerate() {
            offsets.push(out.len());
            let _ = write!(out, "{} 0 obj\n{body}\nendobj\n", index + 1);
        }
        let start = out.len();
        out.push_str("xref\n0 5\n0000000000 65535 f\r\n");
        for offset in offsets {
            let _ = write!(out, "{offset:010} 00000 n\r\n");
        }
        let _ = write!(
            out,
            "trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n{start}\n%%EOF\n"
        );
        out.into_bytes()
    }

    #[test]
    fn nesting_past_lopdfs_own_bound_makes_an_unreadable_object() {
        // lopdf 0.45 stops at a depth of 100 by itself, below Limits::max_nesting; the object
        // counts as unreadable and the document opens repaired, read-only.
        for depth in [150, 100_000] {
            let deep = format!("{}1{}", "[".repeat(depth), "]".repeat(depth));
            let document = open(&source(&with_object(&deep)), &OpenOptions::default()).unwrap();
            assert_eq!(
                document.repair().unwrap().repairs,
                [Repair::ObjectsUnreadable {
                    objects: 1,
                    first: 4
                }]
            );
        }
    }

    #[test]
    fn a_wrong_stream_length_still_reads_to_endstream() {
        let wrong = "<< /Length 999 >>\nstream\nBT ET\nendstream";
        let document = open(&source(&with_object(wrong)), &OpenOptions::default()).unwrap();
        assert!(document.repair().is_none());
        let page = document.model().page_iter().next().unwrap();
        assert!(
            document
                .model()
                .get_page_content(page)
                .starts_with(b"BT ET")
        );
    }

    #[test]
    fn a_long_prev_chain_stops_the_open() {
        let limits = Limits {
            max_xref_sections: 10,
            ..Limits::default()
        };
        let options = OpenOptions {
            limits,
            ..OpenOptions::default()
        };
        assert!(matches!(
            open(&source(&crate::xref::tests::chain(11, false)), &options),
            Err(CoreError::ResourceLimit {
                limit: crate::limits::LimitKind::XrefSections,
                max: 10
            })
        ));
    }

    #[test]
    fn a_decompression_bomb_in_an_xref_stream_stops_the_open() {
        use std::io::Write as _;
        // Objects 1 to 3, then an xref stream whose rows are followed by 2 MiB of zeros.
        let base = crate::xref::tests::simple(|offset| offset);
        let cut = base
            .windows(4)
            .position(|window| window == b"xref")
            .unwrap();
        let mut file = base[..cut].to_vec();
        let mut rows = Vec::new();
        for offset in [0u32, 9, 0, 0] {
            rows.push(u8::from(offset != 0));
            rows.extend_from_slice(&offset.to_be_bytes());
        }
        rows.resize(2 * 1024 * 1024, 0);
        let mut encoder = flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::best());
        encoder.write_all(&rows).unwrap();
        let compressed = encoder.finish().unwrap();
        let at = file.len();
        file.extend_from_slice(
            format!(
                "5 0 obj\n<< /Type /XRef /Size 6 /W [1 4 0] /Root 1 0 R /Filter /FlateDecode /Length {} >>\nstream\n",
                compressed.len()
            )
            .as_bytes(),
        );
        file.extend_from_slice(&compressed);
        file.extend_from_slice(format!("\nendstream\nendobj\nstartxref\n{at}\n%%EOF\n").as_bytes());
        let limits = Limits {
            max_stream_decoded: 1024 * 1024,
            ..Limits::default()
        };
        let options = OpenOptions {
            limits,
            ..OpenOptions::default()
        };
        assert!(matches!(
            open(&source(&file), &options),
            Err(CoreError::ResourceLimit {
                limit: crate::limits::LimitKind::StreamDecodedSize,
                ..
            })
        ));
    }

    #[test]
    fn header_versions_read_as_written() {
        assert_eq!(header_version(b"%PDF-1.4\n"), "1.4");
        assert_eq!(header_version(b"%PDF-2.0\r"), "2.0");
        assert_eq!(header_version(b"%PDF-"), "");
    }
}
