package com.africlub.identity

/** Admission is separate from the FIFO executor. Cleanup has two reserved slots,
 * remains behind issued work, and cannot create an unbounded queue. */
internal class CredentialQueueAdmission {
    private var users = 0
    private var cleanup = 0
    private var stopped = false
    private fun cleanup(method: String) = method == "drain" || method == "release"
    @Synchronized fun enqueue(method: String): Boolean {
        if (stopped) return false
        if (cleanup(method)) {
            if (cleanup >= 2) return false
            cleanup++
        } else {
            if (users >= 32) return false
            users++
        }
        return true
    }
    @Synchronized fun finished(method: String) {
        if (cleanup(method)) { check(cleanup > 0); cleanup-- }
        else { check(users > 0); users-- }
    }
    @Synchronized fun stop() { stopped = true }
}
