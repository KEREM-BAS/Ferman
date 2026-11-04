//! A PAdES baseline signature (`ETSI.CAdES.detached`) with an RFC 3161 signature timestamp, for
//! `kira-tr-signed`. Test material only: a self-made root CA, signer and timestamp authority,
//! each an ECDSA P-256 key derived from a fixed label. The keys are public by construction and
//! sign nothing but the corpus. ECDSA signs deterministically (RFC 6979) and every time is fixed,
//! so each run writes the same bytes.

use cms::cert::{CertificateChoices, IssuerAndSerialNumber};
use cms::content_info::{CmsVersion, ContentInfo};
use cms::signed_data::{
    CertificateSet, EncapsulatedContentInfo, SignedData, SignerIdentifier, SignerInfo, SignerInfos,
};
use der::asn1::{BitString, GeneralizedTime, OctetString, SetOfVec, UtcTime};
use der::oid::ObjectIdentifier as Oid;
use der::{Any, Decode as _, Encode, Sequence};
use lopdf::{Dictionary, Object};
use p256::ecdsa::signature::Signer as _;
use p256::ecdsa::{Signature, SigningKey, VerifyingKey};
use sha2::{Digest as _, Sha256};
use std::str::FromStr as _;
use std::time::Duration;
use x509_cert::attr::Attribute;
use x509_cert::ext::Extension;
use x509_cert::ext::pkix::{BasicConstraints, ExtendedKeyUsage, KeyUsage, KeyUsages};
use x509_cert::name::Name;
use x509_cert::serial_number::SerialNumber;
use x509_cert::spki::{AlgorithmIdentifierOwned, SubjectPublicKeyInfoOwned};
use x509_cert::time::{Time, Validity};
use x509_cert::{Certificate, TbsCertificate, Version};

/// The size of the `/Contents` placeholder in bytes; the CMS takes about 2 KB of it.
pub const CONTENTS_BYTES: usize = 8192;
/// When the document was signed: 2026-10-13 10:15:00 +03:00, as `/M` writes it.
pub const SIGNED_AT: &str = "D:20261013101500+03'00'";
/// The same moment in seconds since 1970.
const SIGNED: u64 = 1_791_875_700;
/// The timestamp authority's time, two seconds later.
pub const STAMPED: u64 = SIGNED + 2;
/// The certificates' validity: 2026-01-01 to 2036-01-01, UTC.
const VALID: (u64, u64) = (1_767_225_600, 2_082_758_400);
const BYTE_RANGE: &[u8] = b"[0 1111111111 2222222222 3333333333]";

/// The root CA's subject.
pub const ROOT: &str = "CN=Ferman Test Root CA,O=Ferman test corpus,C=TR";
const SIGNER: &str = "CN=Mert Kaya,O=Ferman test corpus,C=TR";
const TSA: &str = "CN=Ferman Test TSA,O=Ferman test corpus,C=TR";

/// `id-data`.
pub const ID_DATA: Oid = Oid::new_unwrap("1.2.840.113549.1.7.1");
/// `id-signedData`.
pub const SIGNED_DATA: Oid = Oid::new_unwrap("1.2.840.113549.1.7.2");
/// `id-contentType`.
pub const CONTENT_TYPE: Oid = Oid::new_unwrap("1.2.840.113549.1.9.3");
/// `id-messageDigest`.
pub const MESSAGE_DIGEST: Oid = Oid::new_unwrap("1.2.840.113549.1.9.4");
/// `id-aa-signingCertificateV2` (RFC 5035), required by PAdES baseline.
pub const SIGNING_CERTIFICATE_V2: Oid = Oid::new_unwrap("1.2.840.113549.1.9.16.2.47");
/// `id-aa-signatureTimeStampToken` (RFC 3161 appendix A).
pub const TIME_STAMP_TOKEN: Oid = Oid::new_unwrap("1.2.840.113549.1.9.16.2.14");
/// `id-ct-TSTInfo`.
pub const TST_INFO: Oid = Oid::new_unwrap("1.2.840.113549.1.9.16.1.4");
const SHA256: Oid = Oid::new_unwrap("2.16.840.1.101.3.4.2.1");
const ECDSA_SHA256: Oid = Oid::new_unwrap("1.2.840.10045.4.3.2");
const EC_PUBLIC_KEY: Oid = Oid::new_unwrap("1.2.840.10045.2.1");
const P256: Oid = Oid::new_unwrap("1.2.840.10045.3.1.7");
const BASIC_CONSTRAINTS: Oid = Oid::new_unwrap("2.5.29.19");
const KEY_USAGE: Oid = Oid::new_unwrap("2.5.29.15");
const EXT_KEY_USAGE: Oid = Oid::new_unwrap("2.5.29.37");
const TIME_STAMPING: Oid = Oid::new_unwrap("1.3.6.1.5.5.7.3.8");
/// The TSA's policy, under IANA's enterprise number for documentation (RFC 5612).
pub const TSA_POLICY: Oid = Oid::new_unwrap("1.3.6.1.4.1.32473.1");

/// `ESSCertIDv2` without its optional parts; the hash algorithm defaults to SHA-256.
#[derive(Debug, Clone, Sequence)]
pub struct EssCertIdV2 {
    /// SHA-256 of the certificate's DER.
    pub cert_hash: OctetString,
}

/// `SigningCertificateV2` (RFC 5035).
#[derive(Debug, Clone, Sequence)]
pub struct SigningCertificateV2 {
    /// The signer's certificate first.
    pub certs: Vec<EssCertIdV2>,
}

/// `MessageImprint` (RFC 3161).
#[derive(Debug, Clone, Sequence)]
pub struct MessageImprint {
    /// SHA-256.
    pub hash_algorithm: AlgorithmIdentifierOwned,
    /// The hash of the timestamped data.
    pub hashed_message: OctetString,
}

/// `TSTInfo` (RFC 3161) with its required fields only.
#[derive(Debug, Clone, Sequence)]
pub struct TstInfo {
    /// 1.
    pub version: u8,
    /// [`TSA_POLICY`].
    pub policy: Oid,
    /// The hash of the signature value.
    pub message_imprint: MessageImprint,
    /// The token's serial number.
    pub serial_number: u32,
    /// [`STAMPED`].
    pub gen_time: GeneralizedTime,
}

fn err(error: impl std::fmt::Display) -> String {
    error.to_string()
}

/// A key and its certificate.
struct Party {
    key: SigningKey,
    cert: Certificate,
}

/// The test key of `label`: its SHA-256 as the scalar.
fn key(label: &str) -> Result<SigningKey, String> {
    SigningKey::from_slice(&Sha256::digest(label.as_bytes())).map_err(err)
}

fn algorithm(oid: Oid) -> AlgorithmIdentifierOwned {
    AlgorithmIdentifierOwned {
        oid,
        parameters: None,
    }
}

fn octets(bytes: &[u8]) -> Result<OctetString, String> {
    OctetString::new(bytes).map_err(err)
}

fn extension(extn_id: Oid, critical: bool, value: &impl Encode) -> Result<Extension, String> {
    Ok(Extension {
        extn_id,
        critical,
        extn_value: octets(&value.to_der().map_err(err)?)?,
    })
}

fn utc(seconds: u64) -> Result<Time, String> {
    Ok(Time::UtcTime(
        UtcTime::from_unix_duration(Duration::from_secs(seconds)).map_err(err)?,
    ))
}

/// A certificate for `key`, signed by `issuer`.
fn certificate(
    serial: u8,
    subject: &str,
    key: &VerifyingKey,
    (issuer, issuer_key): (&str, &SigningKey),
    extensions: Vec<Extension>,
) -> Result<Certificate, String> {
    let tbs = TbsCertificate {
        version: Version::V3,
        serial_number: SerialNumber::new(&[serial]).map_err(err)?,
        signature: algorithm(ECDSA_SHA256),
        issuer: Name::from_str(issuer).map_err(err)?,
        validity: Validity {
            not_before: utc(VALID.0)?,
            not_after: utc(VALID.1)?,
        },
        subject: Name::from_str(subject).map_err(err)?,
        subject_public_key_info: SubjectPublicKeyInfoOwned {
            algorithm: AlgorithmIdentifierOwned {
                oid: EC_PUBLIC_KEY,
                parameters: Some(Any::encode_from(&P256).map_err(err)?),
            },
            subject_public_key: BitString::from_bytes(key.to_sec1_point(false).as_bytes())
                .map_err(err)?,
        },
        issuer_unique_id: None,
        subject_unique_id: None,
        extensions: Some(extensions),
    };
    let signature: Signature = issuer_key.sign(&tbs.to_der().map_err(err)?);
    Ok(Certificate {
        tbs_certificate: tbs,
        signature_algorithm: algorithm(ECDSA_SHA256),
        signature: BitString::from_bytes(signature.to_der().as_bytes()).map_err(err)?,
    })
}

/// The root CA, the signer and the timestamp authority.
fn parties() -> Result<[Party; 3], String> {
    let root_key = key("Ferman test corpus: root CA")?;
    let ca_usage = KeyUsage(KeyUsages::KeyCertSign | KeyUsages::CRLSign);
    let root = certificate(
        1,
        ROOT,
        root_key.verifying_key(),
        (ROOT, &root_key),
        vec![
            extension(
                BASIC_CONSTRAINTS,
                true,
                &BasicConstraints {
                    ca: true,
                    path_len_constraint: None,
                },
            )?,
            extension(KEY_USAGE, true, &ca_usage)?,
        ],
    )?;
    let signer_key = key("Ferman test corpus: signer")?;
    let signer = certificate(
        2,
        SIGNER,
        signer_key.verifying_key(),
        (ROOT, &root_key),
        vec![extension(
            KEY_USAGE,
            true,
            &KeyUsage(KeyUsages::DigitalSignature | KeyUsages::NonRepudiation),
        )?],
    )?;
    let tsa_key = key("Ferman test corpus: timestamp authority")?;
    let tsa = certificate(
        3,
        TSA,
        tsa_key.verifying_key(),
        (ROOT, &root_key),
        vec![
            extension(
                KEY_USAGE,
                true,
                &KeyUsage(KeyUsages::DigitalSignature.into()),
            )?,
            // RFC 3161 §2.3: the only extended key usage, critical.
            extension(EXT_KEY_USAGE, true, &ExtendedKeyUsage(vec![TIME_STAMPING]))?,
        ],
    )?;
    Ok([
        Party {
            key: root_key,
            cert: root,
        },
        Party {
            key: signer_key,
            cert: signer,
        },
        Party {
            key: tsa_key,
            cert: tsa,
        },
    ])
}

fn attribute(oid: Oid, value: &impl Encode) -> Result<Attribute, String> {
    Ok(Attribute {
        oid,
        values: SetOfVec::try_from(vec![
            Any::from_der(&value.to_der().map_err(err)?).map_err(err)?,
        ])
        .map_err(err)?,
    })
}

/// A signer info over signed attributes: content type, message digest, signing certificate.
fn signer_info(party: &Party, content_type: Oid, digest: &[u8]) -> Result<SignerInfo, String> {
    let cert_hash = Sha256::digest(party.cert.to_der().map_err(err)?);
    let attrs = SetOfVec::try_from(vec![
        attribute(CONTENT_TYPE, &content_type)?,
        attribute(MESSAGE_DIGEST, &octets(digest)?)?,
        attribute(
            SIGNING_CERTIFICATE_V2,
            &SigningCertificateV2 {
                certs: vec![EssCertIdV2 {
                    cert_hash: octets(&cert_hash)?,
                }],
            },
        )?,
    ])
    .map_err(err)?;
    let signature: Signature = party.key.sign(&attrs.to_der().map_err(err)?);
    Ok(SignerInfo {
        version: CmsVersion::V1,
        sid: SignerIdentifier::IssuerAndSerialNumber(IssuerAndSerialNumber {
            issuer: party.cert.tbs_certificate.issuer.clone(),
            serial_number: party.cert.tbs_certificate.serial_number.clone(),
        }),
        digest_alg: algorithm(SHA256),
        signed_attrs: Some(attrs),
        signature_algorithm: algorithm(ECDSA_SHA256),
        signature: octets(signature.to_der().as_bytes())?,
        unsigned_attrs: None,
    })
}

/// A `ContentInfo` with one signer.
fn signed_data(
    version: CmsVersion,
    encap_content_info: EncapsulatedContentInfo,
    certs: &[&Certificate],
    signer: SignerInfo,
) -> Result<Vec<u8>, String> {
    let certs = certs
        .iter()
        .map(|cert| CertificateChoices::Certificate((*cert).clone()))
        .collect::<Vec<_>>();
    let signed = SignedData {
        version,
        digest_algorithms: SetOfVec::try_from(vec![algorithm(SHA256)]).map_err(err)?,
        encap_content_info,
        certificates: Some(CertificateSet(SetOfVec::try_from(certs).map_err(err)?)),
        crls: None,
        signer_infos: SignerInfos(SetOfVec::try_from(vec![signer]).map_err(err)?),
    };
    ContentInfo {
        content_type: SIGNED_DATA,
        content: Any::encode_from(&signed).map_err(err)?,
    }
    .to_der()
    .map_err(err)
}

/// The TSA's token over `signature`, the signer's signature value.
fn timestamp(tsa: &Party, root: &Certificate, signature: &[u8]) -> Result<Vec<u8>, String> {
    let info = TstInfo {
        version: 1,
        policy: TSA_POLICY,
        message_imprint: MessageImprint {
            hash_algorithm: algorithm(SHA256),
            hashed_message: octets(&Sha256::digest(signature))?,
        },
        serial_number: 1,
        gen_time: GeneralizedTime::from_unix_duration(Duration::from_secs(STAMPED)).map_err(err)?,
    }
    .to_der()
    .map_err(err)?;
    let signer = signer_info(tsa, TST_INFO, &Sha256::digest(&info))?;
    let encap = EncapsulatedContentInfo {
        econtent_type: TST_INFO,
        econtent: Some(Any::encode_from(&octets(&info)?).map_err(err)?),
    };
    // RFC 5652 §5.1: version 3 when the content is not id-data.
    signed_data(CmsVersion::V3, encap, &[&tsa.cert, root], signer)
}

/// The detached CMS over a document whose byte ranges hash to `digest`.
fn cms(digest: &[u8]) -> Result<Vec<u8>, String> {
    let [root, signer, tsa] = parties()?;
    let mut info = signer_info(&signer, ID_DATA, digest)?;
    let token = timestamp(&tsa, &root.cert, info.signature.as_bytes())?;
    info.unsigned_attrs = Some(
        SetOfVec::try_from(vec![Attribute {
            oid: TIME_STAMP_TOKEN,
            values: SetOfVec::try_from(vec![Any::from_der(&token).map_err(err)?]).map_err(err)?,
        }])
        .map_err(err)?,
    );
    let encap = EncapsulatedContentInfo {
        econtent_type: ID_DATA,
        econtent: None,
    };
    signed_data(CmsVersion::V1, encap, &[&signer.cert, &root.cert], info)
}

/// `value` as a signature value: `/ByteRange` and `/Contents` placeholders that [`sign`] fills.
#[must_use]
pub fn value(mut value: Dictionary) -> Dictionary {
    value.set("Type", Object::Name(b"Sig".to_vec()));
    value.set("Filter", Object::Name(b"Adobe.PPKLite".to_vec()));
    value.set("SubFilter", Object::Name(b"ETSI.CAdES.detached".to_vec()));
    value.set(
        "ByteRange",
        vec![
            Object::Integer(0),
            Object::Integer(1_111_111_111),
            Object::Integer(2_222_222_222),
            Object::Integer(3_333_333_333),
        ],
    );
    value.set("Contents", crate::pdf::hex(&[0u8; CONTENTS_BYTES]));
    value
}

fn find(file: &[u8], needle: &[u8]) -> Result<usize, String> {
    file.windows(needle.len())
        .position(|window| window == needle)
        .ok_or_else(|| format!("no {} placeholder", String::from_utf8_lossy(&needle[..2])))
}

/// Signs the written `file`: fills in the `/ByteRange` around the `/Contents` placeholder and
/// writes the CMS, hex, into it. The rest stays zeros.
///
/// # Errors
///
/// A message when a placeholder is missing or the CMS does not fit.
pub fn sign(mut file: Vec<u8>) -> Result<Vec<u8>, String> {
    let range_at = find(&file, BYTE_RANGE)?;
    let contents = format!("<{}>", "0".repeat(CONTENTS_BYTES * 2));
    let start = find(&file, contents.as_bytes())?;
    let end = start + contents.len();
    let rest = file.len() - end;
    let filled = format!("[0 {start:<10} {end:<10} {rest:<10}]");
    if filled.len() != BYTE_RANGE.len() {
        return Err("the /ByteRange does not fit its placeholder".to_owned());
    }
    file[range_at..range_at + BYTE_RANGE.len()].copy_from_slice(filled.as_bytes());
    let mut digest = Sha256::new();
    digest.update(&file[..start]);
    digest.update(&file[end..]);
    let cms = cms(&digest.finalize())?;
    if cms.len() > CONTENTS_BYTES {
        return Err(format!("the CMS takes {} bytes", cms.len()));
    }
    let hex: String = cms.iter().map(|byte| format!("{byte:02x}")).collect();
    file[start + 1..start + 1 + hex.len()].copy_from_slice(hex.as_bytes());
    Ok(file)
}

#[cfg(test)]
mod tests {
    use super::*;
    use der::{Decode, Reader as _, SliceReader};
    use p256::ecdsa::signature::Verifier as _;
    use std::path::Path;

    fn public_key(cert: &Certificate) -> VerifyingKey {
        let key = &cert
            .tbs_certificate
            .subject_public_key_info
            .subject_public_key;
        VerifyingKey::from_sec1_bytes(key.raw_bytes()).unwrap()
    }

    fn signed(content_info: &[u8]) -> SignedData {
        let info = ContentInfo::from_der(content_info).unwrap();
        assert_eq!(info.content_type, SIGNED_DATA);
        info.content.decode_as().unwrap()
    }

    fn certs(signed: &SignedData) -> Vec<Certificate> {
        let set = signed.certificates.as_ref().unwrap();
        set.0
            .iter()
            .map(|choice| match choice {
                CertificateChoices::Certificate(cert) => cert.clone(),
                CertificateChoices::Other(_) => panic!("another certificate format"),
            })
            .collect()
    }

    fn by_subject<'a>(certs: &'a [Certificate], subject: &str) -> &'a Certificate {
        let name = Name::from_str(subject).unwrap();
        certs
            .iter()
            .find(|cert| cert.tbs_certificate.subject == name)
            .unwrap()
    }

    fn attr(attrs: &SetOfVec<Attribute>, oid: Oid) -> &Any {
        let found = attrs.iter().find(|attr| attr.oid == oid).unwrap();
        found.values.get(0).unwrap()
    }

    /// Verifies the only signer info of `signed` with `cert`, which `root` issued, and returns
    /// its message digest.
    fn verify(
        signed: &SignedData,
        cert: &Certificate,
        root: &Certificate,
        content: Oid,
    ) -> Vec<u8> {
        let tbs = cert.tbs_certificate.to_der().unwrap();
        let cert_signature = Signature::from_der(cert.signature.raw_bytes()).unwrap();
        public_key(root).verify(&tbs, &cert_signature).unwrap();
        let info = signed.signer_infos.0.get(0).unwrap();
        let SignerIdentifier::IssuerAndSerialNumber(sid) = &info.sid else {
            panic!("not issuer and serial number")
        };
        assert_eq!(sid.serial_number, cert.tbs_certificate.serial_number);
        let attrs = info.signed_attrs.as_ref().unwrap();
        let signature = Signature::from_der(info.signature.as_bytes()).unwrap();
        public_key(cert)
            .verify(&attrs.to_der().unwrap(), &signature)
            .unwrap();
        assert_eq!(
            attr(attrs, CONTENT_TYPE).decode_as::<Oid>().unwrap(),
            content
        );
        let ess: SigningCertificateV2 = attr(attrs, SIGNING_CERTIFICATE_V2).decode_as().unwrap();
        let cert_hash = Sha256::digest(cert.to_der().unwrap());
        assert_eq!(ess.certs[0].cert_hash.as_bytes(), cert_hash.as_slice());
        attr(attrs, MESSAGE_DIGEST)
            .decode_as::<OctetString>()
            .unwrap()
            .into_bytes()
    }

    #[test]
    fn kira_tr_signed_verifies_with_its_timestamp() {
        let root_dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
        let generator = crate::GENERATORS
            .iter()
            .find(|generator| generator.name == "kira-tr-signed")
            .unwrap();
        let (_, file) = generator
            .outputs(&crate::Sources::new(&root_dir))
            .unwrap()
            .swap_remove(0);

        // The byte range covers the whole file but the /Contents hex string.
        let doc = lopdf::Document::load_mem(&file).unwrap();
        let acro = doc.catalog().unwrap().get(b"AcroForm").unwrap();
        assert_eq!(
            acro.as_dict()
                .unwrap()
                .get(b"SigFlags")
                .unwrap()
                .as_i64()
                .unwrap(),
            3
        );
        let at = file.windows(10).position(|w| w == b"/ByteRange").unwrap();
        let at = at + file[at..].iter().position(|&b| b == b'[').unwrap() + 1;
        let close = at + file[at..].iter().position(|&b| b == b']').unwrap();
        let range: Vec<usize> = std::str::from_utf8(&file[at..close])
            .unwrap()
            .split_whitespace()
            .map(|n| n.parse().unwrap())
            .collect();
        let [0, start, end, rest] = range[..] else {
            panic!("{range:?}")
        };
        assert_eq!(end + rest, file.len());
        assert_eq!(end - start, 2 * CONTENTS_BYTES + 2);
        assert_eq!((file[start], file[end - 1]), (b'<', b'>'));
        let sub_filter = b"/SubFilter/ETSI.CAdES.detached";
        assert!(file.windows(sub_filter.len()).any(|w| w == sub_filter));

        let hex = std::str::from_utf8(&file[start + 1..end - 1]).unwrap();
        let bytes: Vec<u8> = (0..hex.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
            .collect();
        // The DER ends where its length says; zeros pad the rest.
        let mut reader = SliceReader::new(&bytes).unwrap();
        ContentInfo::decode(&mut reader).unwrap();
        let rest = usize::try_from(u32::from(reader.remaining_len())).unwrap();
        let total = bytes.len() - rest;
        assert!(bytes[total..].iter().all(|&b| b == 0));
        let cms = signed(&bytes[..total]);

        // The signer's signature over the byte ranges.
        assert_eq!(cms.encap_content_info.econtent_type, ID_DATA);
        assert!(cms.encap_content_info.econtent.is_none());
        let all = certs(&cms);
        let root = by_subject(&all, ROOT);
        let mut digest = Sha256::new();
        digest.update(&file[..start]);
        digest.update(&file[end..]);
        let message_digest = verify(&cms, by_subject(&all, SIGNER), root, ID_DATA);
        assert_eq!(message_digest, digest.finalize().as_slice());

        // The timestamp token over the signature value.
        let info = cms.signer_infos.0.get(0).unwrap();
        let token = attr(info.unsigned_attrs.as_ref().unwrap(), TIME_STAMP_TOKEN);
        let token = signed(&token.to_der().unwrap());
        assert_eq!(token.encap_content_info.econtent_type, TST_INFO);
        let tst = token.encap_content_info.econtent.as_ref().unwrap();
        let tst = tst.decode_as::<OctetString>().unwrap().into_bytes();
        let token_certs = certs(&token);
        let message_digest = verify(&token, by_subject(&token_certs, TSA), root, TST_INFO);
        assert_eq!(message_digest, Sha256::digest(&tst).as_slice());
        let tst = TstInfo::from_der(&tst).unwrap();
        assert_eq!(tst.policy, TSA_POLICY);
        assert_eq!(
            tst.message_imprint.hashed_message.as_bytes(),
            Sha256::digest(info.signature.as_bytes()).as_slice()
        );
        assert_eq!(tst.gen_time.to_unix_duration().as_secs(), STAMPED);
    }
}
