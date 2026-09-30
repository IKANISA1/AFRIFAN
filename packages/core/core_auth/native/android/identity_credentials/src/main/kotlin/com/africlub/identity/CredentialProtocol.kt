package com.africlub.identity

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets.UTF_8

/** Dedicated protected identity journal, never payment markers or authentication authority. */
class CredentialFailure(code: String) : RuntimeException(CredentialProtocol.safeCode(code)) {
    val code = CredentialProtocol.safeCode(code)
}
internal fun requireCredential(ok: Boolean, code: String = "credential_invalid_request") {
    if (!ok) throw CredentialFailure(code)
}
internal object CredentialProtocol {
    const val MAX_VALUE_BYTES = 8192
    const val MAX_SCOPES = 64
    const val MAX_PLAINTEXT_BYTES = 600_000
    const val MAX_FILE_BYTES = MAX_PLAINTEXT_BYTES + 64
    private val errors = setOf("credential_unavailable", "credential_disabled", "credential_invalid_request",
        "credential_invalid_scope", "credential_invalid_value", "credential_binding_mismatch", "credential_corrupt",
        "credential_capacity", "credential_crypto_unavailable", "credential_directory_unavailable", "credential_lock_lost",
        "credential_lock_required", "credential_key_unavailable", "credential_key_conflict", "credential_state_missing",
        "credential_write_unknown", "credential_platform_unsupported", "credential_device_locked", "credential_busy",
        "credential_channel_unavailable")
    fun safeCode(value: String): String = if (value in errors) value else "credential_unavailable"
    val uuid = Regex("[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}")
    private val application = Regex("[A-Za-z][A-Za-z0-9_]*(?:[.][A-Za-z][A-Za-z0-9_]*)+")
    private val origin = Regex("https://[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:[.][a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+(?:[:]443)?")
    fun requestShape(method: String, arguments: Any?) {
        requireCredential(method in setOf("describe", "tryAcquire", "read", "compareAndSet", "drain", "release"))
        val map = arguments as? Map<*, *> ?: throw CredentialFailure("credential_invalid_request")
        requireCredential(map.size in 1..4 && map.keys.all { it is String } &&
            map.values.all { it == null || (it is String && it.toByteArray(UTF_8).size <= MAX_VALUE_BYTES) })
    }
    fun checkId(value: String) = requireCredential(uuid.matches(value))
    fun checkApplication(value: String) = requireCredential(value.length <= 128 && application.matches(value), "credential_invalid_scope")
    fun checkScope(value: String) {
        val parts = value.split('|')
        requireCredential(value.length <= 512 && parts.size == 3, "credential_invalid_scope")
        checkApplication(parts[0])
        requireCredential(origin.matches(parts[1]) && !parts[1].removePrefix("https://").substringBefore(':').matches(Regex("[0-9.]+")), "credential_invalid_scope")
        requireCredential(parts[1].removePrefix("https://").substringBefore(':').length <= 253 && Regex("[1-9][0-9]{0,9}").matches(parts[2]), "credential_invalid_scope")
    }
    fun bind(value: String, applicationId: String) {
        checkScope(value)
        requireCredential(value.substringBefore('|') == applicationId, "credential_binding_mismatch")
    }
    fun utf8(bytes: ByteArray): String = try {
        UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString()
    } catch (_: Exception) { throw CredentialFailure("credential_corrupt") }
    fun value(value: String) {
        val b = value.toByteArray(UTF_8)
        requireCredential(b.size <= MAX_VALUE_BYTES && b.isNotEmpty() && utf8(b) == value, "credential_invalid_value")
    }
}
internal data class Snapshot(val revision: Long, val values: Map<String, String>)
internal object SnapshotCodec {
    fun encode(snapshot: Snapshot): ByteArray {
        requireCredential(snapshot.revision >= 0 && snapshot.values.size <= CredentialProtocol.MAX_SCOPES)
        val out = ByteArrayOutputStream()
        DataOutputStream(out).use { d ->
            d.writeInt(1); d.writeLong(snapshot.revision); d.writeInt(snapshot.values.size)
            snapshot.values.toSortedMap().forEach { (scope, value) ->
                CredentialProtocol.checkScope(scope); CredentialProtocol.value(value)
                for (s in listOf(scope, value)) { val bytes=s.toByteArray(UTF_8); d.writeInt(bytes.size); d.write(bytes) }
            }
        }
        return out.toByteArray().also { requireCredential(it.size <= CredentialProtocol.MAX_PLAINTEXT_BYTES) }
    }
    fun decode(bytes: ByteArray): Snapshot = try {
        requireCredential(bytes.size <= CredentialProtocol.MAX_PLAINTEXT_BYTES, "credential_corrupt")
        DataInputStream(ByteArrayInputStream(bytes)).use { d ->
            requireCredential(d.readInt()==1, "credential_corrupt")
            val rev=d.readLong(); val count=d.readInt()
            requireCredential(rev>=0 && count in 0..CredentialProtocol.MAX_SCOPES, "credential_corrupt")
            val values=linkedMapOf<String,String>()
            repeat(count) {
                fun text(max: Int): String {
                    val n=d.readInt(); requireCredential(n in 1..max && n<=d.available(), "credential_corrupt")
                    return CredentialProtocol.utf8(ByteArray(n).also(d::readFully))
                }
                val scope=text(512); val value=text(CredentialProtocol.MAX_VALUE_BYTES)
                CredentialProtocol.checkScope(scope); CredentialProtocol.value(value)
                requireCredential(!values.containsKey(scope), "credential_corrupt"); values[scope]=value
            }
            requireCredential(d.available()==0, "credential_corrupt"); Snapshot(rev,values)
        }
    } catch (_: Exception) { throw CredentialFailure("credential_corrupt") }
}

/** Exact host configuration, never populated from Dart, user data or Supabase.
 * Default policy authorizes nothing and creates no credential key or file. */
internal class CredentialPolicy(val applicationId: String, val enabled: Boolean = false,
                                approvedScopes: Set<String> = emptySet()) {
    private val scopes = approvedScopes.toSet()
    init { CredentialProtocol.checkApplication(applicationId); scopes.forEach { CredentialProtocol.bind(it, applicationId) } }
    fun authorize(scope: String) {
        requireCredential(enabled && scopes.isNotEmpty(), "credential_disabled")
        CredentialProtocol.bind(scope, applicationId)
        requireCredential(scope in scopes, "credential_binding_mismatch")
    }
}
