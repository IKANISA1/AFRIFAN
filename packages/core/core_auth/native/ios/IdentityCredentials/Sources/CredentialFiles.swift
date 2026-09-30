import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Fixed app-private anchor/lock only; credential values belong in Keychain, not these files.
enum CredentialFiles {
    static func directory(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        try requireCredential(url.path == path && url.resolvingSymlinksInPath().path == path, "credential_directory_unavailable")
        var s = stat()
        try requireCredential(lstat(path, &s) == 0 && (s.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) &&
            s.st_uid == getuid() && (s.st_mode & 0o077) == 0, "credential_directory_unavailable")
        return path
    }
    static func checkedFile(_ fd: Int32, _ path: String) throws {
        var held = stat(), current = stat()
        try requireCredential(fstat(fd, &held) == 0 && lstat(path, &current) == 0 &&
            (held.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) && held.st_nlink == 1 && held.st_uid == getuid() &&
            (held.st_mode & 0o077) == 0 && held.st_dev == current.st_dev && held.st_ino == current.st_ino,
            "credential_lock_lost")
#if os(iOS)
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        try requireCredential(attributes[.protectionKey] as? FileProtectionType == .complete, "credential_device_locked")
#endif
    }
    private static func protectNewFile(_ fd: Int32, _ path: String) throws {
#if os(iOS)
        // Only newly created files are assigned policy. Existing weak files are
        // rejected by checkedFile; no silent storage policy migration occurs.
        var held = stat(), current = stat()
        try requireCredential(fstat(fd, &held) == 0 && lstat(path, &current) == 0 &&
            held.st_dev == current.st_dev && held.st_ino == current.st_ino &&
            (current.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG), "credential_lock_lost")
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: path)
#endif
        try checkedFile(fd, path)
    }
    static func acquire(_ root: String) throws -> Int32? {
        let path = root + "/credentials.lock"
        var fd = open(path, O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        let created = fd >= 0
        if fd < 0 && errno == EEXIST { fd = open(path, O_RDWR | O_CLOEXEC | O_NOFOLLOW) }
        try requireCredential(fd >= 0, "credential_directory_unavailable")
        do {
            if created {
                try protectNewFile(fd, path)
                try requireCredential(fsync(fd) == 0, "credential_write_unknown")
                try syncDirectory(root)
            }
            try checkedFile(fd, path)
            if flock(fd, LOCK_EX | LOCK_NB) != 0 {
                let code = errno
                if code == EWOULDBLOCK || code == EAGAIN { _ = close(fd); return nil }
                throw CredentialFailure("credential_lock_lost")
            }
            try checkedFile(fd, path)
            return fd
        } catch { _ = close(fd); throw error }
    }
    static func release(_ fd: Int32) { _ = flock(fd, LOCK_UN); _ = close(fd) }
    static func syncDirectory(_ root: String) throws {
        let fd = open(root, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        try requireCredential(fd >= 0, "credential_directory_unavailable")
        defer { _ = close(fd) }
        try requireCredential(fsync(fd) == 0, "credential_write_unknown")
    }
    static func readAnchor(_ root: String) throws -> String? {
        let path = root + "/installation.anchor"
        let fd = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        if fd < 0 && errno == ENOENT { return nil }
        try requireCredential(fd >= 0, "credential_state_missing")
        defer { _ = close(fd) }
        try checkedFile(fd, path)
        var s = stat(); try requireCredential(fstat(fd, &s) == 0 && s.st_size == 36, "credential_corrupt")
        var bytes = [UInt8](repeating: 0, count: 37)
        let size = bytes.withUnsafeMutableBytes { read(fd, $0.baseAddress, 37) }
        try requireCredential(size == 36, "credential_corrupt")
        guard let value = String(bytes: bytes.prefix(36), encoding: .utf8) else { throw CredentialFailure("credential_corrupt") }
        do { try CredentialProtocol.identifier(value) } catch { throw CredentialFailure("credential_corrupt") }
        return value
    }
    static func createAnchor(_ root: String, _ identifier: String) throws {
        try CredentialProtocol.identifier(identifier)
        let path = root + "/installation.anchor"
        let fd = open(path, O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        try requireCredential(fd >= 0, "credential_write_unknown")
        defer { _ = close(fd) }
        try protectNewFile(fd, path)
        let bytes = Array(identifier.utf8)
        try bytes.withUnsafeBytes { buffer in
            var n = 0
            while n < buffer.count {
                let written = write(fd, buffer.baseAddress!.advanced(by: n), buffer.count - n)
                if written < 0 && errno == EINTR { continue }
                try requireCredential(written > 0, "credential_write_unknown"); n += written
            }
        }
        try requireCredential(fsync(fd) == 0, "credential_write_unknown")
        try syncDirectory(root)
        try requireCredential(try readAnchor(root) == identifier, "credential_write_unknown")
    }
}
