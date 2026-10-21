//! A document's bytes (docs/ARCHITECTURE.md §5.1): the file read once into an owned buffer, with
//! its SHA-256 computed while reading. Ferman never keeps reading the user's file after open, and
//! never memory-maps it; the snapshot of a file over 256 MB waits for Q21 (BACKLOG B105).

use std::fmt;
use std::fs::File;
use std::io::Read;
use std::path::Path;
use std::sync::Arc;

use sha2::{Digest, Sha256};

use crate::CoreError;

/// How much is read at a time while hashing.
const CHUNK: usize = 1 << 20;

/// A document's bytes and their SHA-256.
#[derive(Clone)]
pub struct Source {
    bytes: Arc<[u8]>,
    sha256: [u8; 32],
}

impl fmt::Debug for Source {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Source")
            .field("len", &self.bytes.len())
            .finish_non_exhaustive()
    }
}

impl Source {
    /// Reads the file at `path` into an owned buffer.
    ///
    /// # Errors
    ///
    /// [`CoreError::Io`] when the file cannot be opened or read, and [`CoreError::OutOfMemory`]
    /// when its buffer cannot be reserved.
    pub fn read(path: &Path) -> Result<Self, CoreError> {
        let mut file = File::open(path).map_err(io)?;
        let expected = file.metadata().map_err(io)?.len();
        let expected = usize::try_from(expected).map_err(|_| CoreError::OutOfMemory {
            context: "the file's buffer",
        })?;
        let mut bytes = Vec::new();
        bytes
            .try_reserve_exact(expected)
            .map_err(|_| CoreError::OutOfMemory {
                context: "the file's buffer",
            })?;
        let mut hasher = Sha256::new();
        let mut chunk = vec![0u8; CHUNK];
        loop {
            let read = file.read(&mut chunk).map_err(io)?;
            let Some(part) = chunk.get(..read) else {
                return Err(CoreError::Internal {
                    context: "a read longer than its buffer",
                });
            };
            if part.is_empty() {
                break;
            }
            hasher.update(part);
            // The file may grow while it is read; past the reservation, reserve again.
            bytes
                .try_reserve(part.len())
                .map_err(|_| CoreError::OutOfMemory {
                    context: "the file's buffer",
                })?;
            bytes.extend_from_slice(part);
        }
        Ok(Self {
            bytes: bytes.into(),
            sha256: hasher.finalize().into(),
        })
    }

    /// Bytes that are already in memory: the CLI's standard input, tests, the web later.
    #[must_use]
    pub fn from_bytes(bytes: Arc<[u8]>) -> Self {
        let sha256 = Sha256::digest(&bytes).into();
        Self { bytes, sha256 }
    }

    /// The bytes, shared with the render thread without a copy.
    #[must_use]
    pub fn bytes(&self) -> &Arc<[u8]> {
        &self.bytes
    }

    /// The SHA-256 of the bytes.
    #[must_use]
    pub fn sha256(&self) -> &[u8; 32] {
        &self.sha256
    }

    /// The number of bytes.
    #[must_use]
    pub fn len(&self) -> usize {
        self.bytes.len()
    }

    /// Whether the file is empty.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.bytes.is_empty()
    }
}

fn io(err: std::io::Error) -> CoreError {
    CoreError::Io { kind: err.kind() }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reading_a_file_hashes_what_was_read() {
        let dir = std::env::temp_dir().join(format!("ferman-source-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("a.pdf");
        // Larger than one chunk, so the hash spans several reads.
        let data: Vec<u8> = (0..(CHUNK * 2 + 17)).map(|i| (i % 251) as u8).collect();
        std::fs::write(&path, &data).unwrap();
        let source = Source::read(&path).unwrap();
        assert_eq!(&source.bytes()[..], &data[..]);
        assert_eq!(source.sha256(), &<[u8; 32]>::from(Sha256::digest(&data)));
        assert_eq!(source.sha256(), Source::from_bytes(data.into()).sha256());
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn a_missing_file_is_not_found() {
        let missing = std::env::temp_dir().join("ferman-source-missing/none.pdf");
        assert!(matches!(
            Source::read(&missing),
            Err(CoreError::Io {
                kind: std::io::ErrorKind::NotFound
            })
        ));
    }

    #[test]
    fn the_known_hash_of_abc() {
        let source = Source::from_bytes(Arc::from(&b"abc"[..]));
        assert_eq!(
            source.sha256()[..4],
            [0xBA, 0x78, 0x16, 0xBF],
            "FIPS 180-2 SHA-256(\"abc\")"
        );
        assert_eq!(source.len(), 3);
        assert!(!source.is_empty());
    }
}
