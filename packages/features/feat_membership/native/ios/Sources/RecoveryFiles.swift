import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Fixed app-private anchor/lock only; recovery values belong in Keychain, not these files.
enum RecoveryFiles {
    static func directory(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        try requireRecovery(url.path == path && url.resolvingSymlinksInPath().path == path, "recovery_directory_unavailable")
        var s = stat()
        try requireRecovery(lstat(path, &s) == 0 && (s.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) &&
            s.st_uid == getuid() && (s.st_mode & 0o077) == 0, "recovery_directory_unavailable")
        return path
    }
    static func checkedFile(_ fd: Int32, _ path: String) throws {
        var held = stat(), current = stat()
        try requireRecovery(fstat(fd, &held) == 0 && lstat(path, &current) == 0 &&
            (held.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) && held.st_nlink == 1 && held.st_uid == getuid() &&
            (held.st_mode & 0o077) == 0 && held.st_dev == current.st_dev && held.st_ino == current.st_ino,
            "recovery_lock_lost")
    }
    static func acquire(_ root: String) throws -> Int32? {
        let path = root + "/recovery.lock"
        let fd = open(path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        try requireRecovery(fd >= 0, "recovery_directory_unavailable")
        do {
            try checkedFile(fd, path)
            if flock(fd, LOCK_EX | LOCK_NB) != 0 {
                let code = errno
                if code == EWOULDBLOCK || code == EAGAIN { _ = close(fd); return nil }
                throw RecoveryFailure("recovery_lock_lost")
            }
            try checkedFile(fd, path)
            return fd
        } catch { _ = close(fd); throw error }
    }
    static func release(_ fd: Int32) { _ = flock(fd, LOCK_UN); _ = close(fd) }
    static func syncDirectory(_ root: String) throws {
        let fd = open(root, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        try requireRecovery(fd >= 0, "recovery_directory_unavailable")
        defer { _ = close(fd) }
        try requireRecovery(fsync(fd) == 0, "recovery_write_unknown")
    }
    static func readAnchor(_ root: String) throws -> String? {
        let path = root + "/installation.anchor"
        let fd = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        if fd < 0 && errno == ENOENT { return nil }
        try requireRecovery(fd >= 0, "recovery_state_missing")
        defer { _ = close(fd) }
        try checkedFile(fd, path)
        var s = stat(); try requireRecovery(fstat(fd, &s) == 0 && s.st_size == 36, "recovery_corrupt")
        var bytes = [UInt8](repeating: 0, count: 37)
        let size = bytes.withUnsafeMutableBytes { read(fd, $0.baseAddress, 37) }
        try requireRecovery(size == 36, "recovery_corrupt")
        guard let value = String(bytes: bytes.prefix(36), encoding: .utf8) else { throw RecoveryFailure("recovery_corrupt") }
        do { try RecoveryProtocol.identifier(value) } catch { throw RecoveryFailure("recovery_corrupt") }
        return value
    }
    static func createAnchor(_ root: String, _ identifier: String) throws {
        try RecoveryProtocol.identifier(identifier)
        let path = root + "/installation.anchor"
        let fd = open(path, O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        try requireRecovery(fd >= 0, "recovery_write_unknown")
        defer { _ = close(fd) }
        try checkedFile(fd, path)
        let bytes = Array(identifier.utf8)
        try bytes.withUnsafeBytes { buffer in
            var n = 0
            while n < buffer.count {
                let written = write(fd, buffer.baseAddress!.advanced(by: n), buffer.count - n)
                if written < 0 && errno == EINTR { continue }
                try requireRecovery(written > 0, "recovery_write_unknown"); n += written
            }
        }
        try requireRecovery(fsync(fd) == 0, "recovery_write_unknown")
        try syncDirectory(root)
        try requireRecovery(try readAnchor(root) == identifier, "recovery_write_unknown")
    }
}
