import Foundation

/// Portable admission/lifecycle policy. The host executes every admitted call in
/// one FIFO; two bounded cleanup slots cannot jump ahead of a pending CAS.
final class CredentialHostGate: @unchecked Sendable {
    private let mutex = NSLock()
    private var foreground = false
    private var protectedData = false
    private var stopped = false
    private var users = 0
    private var cleanup = 0
    func update(foreground: Bool, protectedData: Bool) {
        mutex.lock(); defer { mutex.unlock() }
        self.foreground = foreground; self.protectedData = protectedData
    }
    func usable() -> Bool { mutex.lock(); defer { mutex.unlock() }; return !stopped && foreground && protectedData }
    private func isCleanup(_ method: String) -> Bool { method == "drain" || method == "release" }
    func enqueue(_ method: String) -> Bool {
        mutex.lock(); defer { mutex.unlock() }
        guard !stopped else { return false }
        if isCleanup(method) {
            guard cleanup < 2 else { return false }; cleanup += 1
        } else {
            guard users < 32 else { return false }; users += 1
        }
        return true
    }
    func finished(_ method: String) {
        mutex.lock(); defer { mutex.unlock() }
        if isCleanup(method) { precondition(cleanup > 0); cleanup -= 1 }
        else { precondition(users > 0); users -= 1 }
    }
    func stop() { mutex.lock(); stopped = true; mutex.unlock() }
}
