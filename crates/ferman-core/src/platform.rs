//! The file-system calls of the save sequence that the standard library lacks
//! (docs/ARCHITECTURE.md §7.2, ADR 0008): free space, a file's link count on Windows, macOS
//! metadata (`fcopyfile`), and the replace on Windows (`ReplaceFileW`, falling back to
//! `MoveFileExW`). This is ferman-core's only unsafe code, allowed on this module alone (ADR 0010,
//! M3 plan question 1); each call states why it is sound.
//!
//! Everything else the sequence needs is in the standard library: `sync_all` (`fsync`,
//! `F_FULLFSYNC` on Apple platforms, `FlushFileBuffers`), `rename(2)`, mode bits, `fchown`, and
//! the hidden attribute through `OpenOptionsExt`.

use std::fs::{File, OpenOptions};
use std::io;
use std::path::Path;

use crate::SaveError;

/// The free space for this user on the volume of `folder`, or `None` when the system does not
/// say.
#[cfg(unix)]
pub(crate) fn free_space(folder: &Path) -> Option<u64> {
    use std::os::unix::ffi::OsStrExt as _;
    let path = std::ffi::CString::new(folder.as_os_str().as_bytes()).ok()?;
    let mut stats = std::mem::MaybeUninit::<libc::statvfs>::uninit();
    // SAFETY: `path` is a NUL-terminated string that outlives the call, and `stats` points to
    // writable memory of the size `statvfs` writes.
    let status = unsafe { libc::statvfs(path.as_ptr(), stats.as_mut_ptr()) };
    if status != 0 {
        return None;
    }
    // SAFETY: `statvfs` returned 0, so it filled `stats`.
    let stats = unsafe { stats.assume_init() };
    // The field types differ between systems; the conversions are lossless or saturate.
    #[allow(clippy::useless_conversion, clippy::unnecessary_cast)]
    let (available, fragment) = (u64::from(stats.f_bavail), stats.f_frsize as u64);
    Some(available.saturating_mul(fragment))
}

/// The free space for this user on the volume of `folder`, or `None` when the system does not
/// say.
#[cfg(windows)]
pub(crate) fn free_space(folder: &Path) -> Option<u64> {
    use windows_sys::Win32::Storage::FileSystem::GetDiskFreeSpaceExW;
    let path = wide(folder);
    let mut available = 0u64;
    // SAFETY: `path` is a NUL-terminated UTF-16 string that outlives the call; `available` is a
    // valid u64 to write to, and the two other outputs are optional and null.
    let ok = unsafe {
        GetDiskFreeSpaceExW(
            path.as_ptr(),
            &mut available,
            std::ptr::null_mut(),
            std::ptr::null_mut(),
        )
    };
    (ok != 0).then_some(available)
}

/// The free space on other systems: unknown, so the write itself reports a full disk.
#[cfg(not(any(unix, windows)))]
pub(crate) fn free_space(_folder: &Path) -> Option<u64> {
    None
}

/// How many hard links the file at `path` has.
#[cfg(unix)]
pub(crate) fn link_count(path: &Path) -> io::Result<u64> {
    use std::os::unix::fs::MetadataExt as _;
    Ok(std::fs::metadata(path)?.nlink())
}

/// How many hard links the file at `path` has.
#[cfg(windows)]
pub(crate) fn link_count(path: &Path) -> io::Result<u64> {
    use std::os::windows::io::AsRawHandle as _;
    use windows_sys::Win32::Storage::FileSystem::{
        BY_HANDLE_FILE_INFORMATION, GetFileInformationByHandle,
    };
    let file = File::open(path)?;
    let mut info = std::mem::MaybeUninit::<BY_HANDLE_FILE_INFORMATION>::uninit();
    // SAFETY: the handle is the open `file`'s, valid for the call, and `info` points to writable
    // memory of the structure's size.
    let ok = unsafe { GetFileInformationByHandle(file.as_raw_handle(), info.as_mut_ptr()) };
    if ok == 0 {
        return Err(io::Error::last_os_error());
    }
    // SAFETY: the call succeeded, so it filled `info`.
    let info = unsafe { info.assume_init() };
    Ok(u64::from(info.nNumberOfLinks))
}

/// The link count on other systems: one, as nothing can be learned.
#[cfg(not(any(unix, windows)))]
pub(crate) fn link_count(_path: &Path) -> io::Result<u64> {
    Ok(1)
}

/// Makes the temp file hidden on Windows (`.<name>.ferman-<random>.tmp` is hidden by its dot
/// elsewhere).
pub(crate) fn hidden(options: &mut OpenOptions) -> &mut OpenOptions {
    #[cfg(windows)]
    {
        use std::os::windows::fs::OpenOptionsExt as _;
        use windows_sys::Win32::Storage::FileSystem::FILE_ATTRIBUTE_HIDDEN;
        options.attributes(FILE_ATTRIBUTE_HIDDEN)
    }
    #[cfg(not(windows))]
    options
}

/// Gives `to` the macOS metadata of `from` that the mode bits do not cover: ACLs and extended
/// attributes, Finder tags among them (`fcopyfile` with `COPYFILE_ACL | COPYFILE_XATTR`; not
/// `COPYFILE_METADATA`, whose `COPYFILE_STAT` would give the new file the old modification time).
/// Elsewhere nothing: Unix mode bits and owner are copied by the caller, and `ReplaceFileW` keeps
/// Windows'.
#[cfg(target_vendor = "apple")]
pub(crate) fn copy_metadata(from: &File, to: &File) -> io::Result<()> {
    use std::os::fd::AsRawFd as _;
    // SAFETY: both descriptors belong to files open for the whole call; a null state is
    // allowed and makes the call allocate and free its own.
    let status = unsafe {
        libc::fcopyfile(
            from.as_raw_fd(),
            to.as_raw_fd(),
            std::ptr::null_mut(),
            libc::COPYFILE_ACL | libc::COPYFILE_XATTR,
        )
    };
    if status != 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

/// Elsewhere the caller copies what the system has (see the Apple version).
#[cfg(not(target_vendor = "apple"))]
pub(crate) fn copy_metadata(_from: &File, _to: &File) -> io::Result<()> {
    Ok(())
}

/// Moves the verified `temp` over `target` in one step: `rename(2)`.
#[cfg(not(windows))]
pub(crate) fn replace(temp: &Path, target: &Path, _exists: bool) -> io::Result<()> {
    std::fs::rename(temp, target)
}

/// Moves the verified `temp` over `target` in one step. An existing target is replaced with
/// `ReplaceFileW`, which keeps its attributes, ACLs and creation time; where that fails (some
/// network shares and FAT volumes) or for a new file, `MoveFileExW` with
/// `MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH`. A sharing violation is returned as is,
/// so the caller retries.
#[cfg(windows)]
pub(crate) fn replace(temp: &Path, target: &Path, exists: bool) -> io::Result<()> {
    use windows_sys::Win32::Storage::FileSystem::{
        FILE_ATTRIBUTE_NORMAL, MOVEFILE_REPLACE_EXISTING, MOVEFILE_WRITE_THROUGH, MoveFileExW,
        REPLACEFILE_IGNORE_MERGE_ERRORS, ReplaceFileW, SetFileAttributesW,
    };
    let (temp, target) = (wide(temp), wide(target));
    // The new file must not keep the temp file's hidden attribute.
    // SAFETY: `temp` is a NUL-terminated UTF-16 string that outlives the call.
    unsafe { SetFileAttributesW(temp.as_ptr(), FILE_ATTRIBUTE_NORMAL) };
    if exists {
        // SAFETY: both names are NUL-terminated UTF-16 strings that outlive the call; there is
        // no backup file, and the two reserved pointers are null as documented.
        let ok = unsafe {
            ReplaceFileW(
                target.as_ptr(),
                temp.as_ptr(),
                std::ptr::null(),
                REPLACEFILE_IGNORE_MERGE_ERRORS,
                std::ptr::null(),
                std::ptr::null(),
            )
        };
        if ok != 0 {
            return Ok(());
        }
        let err = io::Error::last_os_error();
        if err
            .raw_os_error()
            .and_then(classify)
            .is_some_and(|kind| kind == SaveError::FileLocked)
        {
            return Err(err);
        }
    }
    // SAFETY: both names are NUL-terminated UTF-16 strings that outlive the call.
    let ok = unsafe {
        MoveFileExW(
            temp.as_ptr(),
            target.as_ptr(),
            MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
        )
    };
    if ok == 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

/// `path` as a NUL-terminated UTF-16 string.
#[cfg(windows)]
fn wide(path: &Path) -> Vec<u16> {
    use std::os::windows::ffi::OsStrExt as _;
    path.as_os_str().encode_wide().chain([0]).collect()
}

/// The save failure a system error code stands for, if it has one of its own.
#[cfg(unix)]
pub(crate) fn classify(code: i32) -> Option<SaveError> {
    Some(match code {
        libc::ENOSPC | libc::EDQUOT => SaveError::DiskFull,
        libc::EACCES | libc::EPERM | libc::EROFS => SaveError::PermissionDenied,
        libc::EBUSY | libc::ETXTBSY => SaveError::FileLocked,
        libc::EIO | libc::ENODEV | libc::ENXIO | libc::ESTALE | libc::ENOTCONN => {
            SaveError::VolumeGone
        }
        _ => return None,
    })
}

/// The save failure a system error code stands for, if it has one of its own.
#[cfg(windows)]
pub(crate) fn classify(code: i32) -> Option<SaveError> {
    use windows_sys::Win32::Foundation::{
        ERROR_ACCESS_DENIED, ERROR_BAD_NETPATH, ERROR_DEV_NOT_EXIST, ERROR_DEVICE_NOT_CONNECTED,
        ERROR_DISK_FULL, ERROR_HANDLE_DISK_FULL, ERROR_LOCK_VIOLATION, ERROR_NETNAME_DELETED,
        ERROR_NOT_READY, ERROR_SHARING_VIOLATION, ERROR_UNABLE_TO_MOVE_REPLACEMENT,
        ERROR_UNABLE_TO_MOVE_REPLACEMENT_2, ERROR_UNABLE_TO_REMOVE_REPLACED, ERROR_UNEXP_NET_ERR,
        ERROR_WRITE_PROTECT,
    };
    let code = u32::try_from(code).ok()?;
    Some(match code {
        ERROR_DISK_FULL | ERROR_HANDLE_DISK_FULL => SaveError::DiskFull,
        ERROR_ACCESS_DENIED | ERROR_WRITE_PROTECT => SaveError::PermissionDenied,
        // The replaced file could not be deleted: another app holds it.
        ERROR_SHARING_VIOLATION | ERROR_LOCK_VIOLATION | ERROR_UNABLE_TO_REMOVE_REPLACED => {
            SaveError::FileLocked
        }
        ERROR_DEV_NOT_EXIST
        | ERROR_DEVICE_NOT_CONNECTED
        | ERROR_NOT_READY
        | ERROR_NETNAME_DELETED
        | ERROR_UNEXP_NET_ERR
        | ERROR_BAD_NETPATH => SaveError::VolumeGone,
        ERROR_UNABLE_TO_MOVE_REPLACEMENT | ERROR_UNABLE_TO_MOVE_REPLACEMENT_2 => {
            SaveError::RenameFailed
        }
        _ => return None,
    })
}

/// No codes of its own elsewhere.
#[cfg(not(any(unix, windows)))]
pub(crate) fn classify(_code: i32) -> Option<SaveError> {
    None
}

#[cfg(test)]
mod tests {
    use std::fs;

    use super::*;

    #[test]
    fn a_folder_has_free_space_and_a_new_file_one_link() {
        let dir = std::env::temp_dir();
        assert!(free_space(&dir).is_some_and(|free| free > 0));
        let path = dir.join(format!("ferman-platform-{}", std::process::id()));
        fs::write(&path, b"x").unwrap();
        assert_eq!(link_count(&path).unwrap(), 1);
        let other = dir.join(format!("ferman-platform-link-{}", std::process::id()));
        let _ = fs::remove_file(&other);
        fs::hard_link(&path, &other).unwrap();
        assert_eq!(link_count(&path).unwrap(), 2);
        fs::remove_file(&other).unwrap();
        fs::remove_file(&path).unwrap();
    }

    #[cfg(unix)]
    #[test]
    fn system_codes_name_their_failures() {
        assert_eq!(classify(libc::ENOSPC), Some(SaveError::DiskFull));
        assert_eq!(classify(libc::EROFS), Some(SaveError::PermissionDenied));
        assert_eq!(classify(libc::ETXTBSY), Some(SaveError::FileLocked));
        assert_eq!(classify(libc::ENXIO), Some(SaveError::VolumeGone));
        assert_eq!(classify(libc::ENOENT), None);
    }

    #[cfg(target_vendor = "apple")]
    #[test]
    fn extended_attributes_reach_the_new_file() {
        let dir =
            std::env::temp_dir().join(format!("ferman-platform-xattr-{}", std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        let (from, to) = (dir.join("from"), dir.join("to"));
        fs::write(&from, b"a").unwrap();
        fs::write(&to, b"b").unwrap();
        let status = std::process::Command::new("xattr")
            .args(["-w", "com.fermanpdf.Ferman.test", "kept"])
            .arg(&from)
            .status()
            .unwrap();
        assert!(status.success());
        copy_metadata(&File::open(&from).unwrap(), &File::open(&to).unwrap()).unwrap();
        let out = std::process::Command::new("xattr")
            .args(["-p", "com.fermanpdf.Ferman.test"])
            .arg(&to)
            .output()
            .unwrap();
        assert_eq!(out.stdout.as_slice().trim_ascii(), b"kept");
        fs::remove_dir_all(&dir).unwrap();
    }
}
