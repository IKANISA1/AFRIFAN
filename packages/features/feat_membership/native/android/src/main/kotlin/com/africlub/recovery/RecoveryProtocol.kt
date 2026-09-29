package com.africlub.recovery

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets.UTF_8

/** Recovery markers only. Neither this store nor possession of a lease authorizes payment. */
class RecoveryFailure(val code: String) : RuntimeException(code)
internal fun requireRecovery(ok: Boolean, code: String = "recovery_invalid_request") {
    if (!ok) throw RecoveryFailure(code)
}
internal object RecoveryProtocol {
    const val MAX_VALUE_BYTES = 2048
    const val MAX_SCOPES = 64
    const val MAX_PLAINTEXT_BYTES = 160_000
    const val MAX_FILE_BYTES = MAX_PLAINTEXT_BYTES + 64
    val uuid = Regex("[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}")
    private val scope = Regex("africlub-(membership|payment-handoff)-v1:([1-9][0-9]{0,14}):([0-9a-f-]{36})")
    fun checkId(value: String) = requireRecovery(uuid.matches(value))
    fun checkScope(value: String) {
        val m = scope.matchEntire(value) ?: throw RecoveryFailure("recovery_invalid_scope")
        requireRecovery(uuid.matches(m.groupValues[3]), "recovery_invalid_scope")
    }
    fun utf8(bytes: ByteArray): String = try {
        UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString()
    } catch (_: Exception) { throw RecoveryFailure("recovery_corrupt") }
    fun value(value: String) {
        val b = value.toByteArray(UTF_8)
        requireRecovery(b.size <= MAX_VALUE_BYTES && b.isNotEmpty() && utf8(b) == value, "recovery_invalid_value")
    }
}
internal data class Snapshot(val revision: Long, val values: Map<String, String>)
internal object SnapshotCodec {
    fun encode(snapshot: Snapshot): ByteArray {
        requireRecovery(snapshot.revision >= 0 && snapshot.values.size <= RecoveryProtocol.MAX_SCOPES)
        val out = ByteArrayOutputStream()
        DataOutputStream(out).use { d ->
            d.writeInt(1); d.writeLong(snapshot.revision); d.writeInt(snapshot.values.size)
            snapshot.values.toSortedMap().forEach { (scope, value) ->
                RecoveryProtocol.checkScope(scope); RecoveryProtocol.value(value)
                for (s in listOf(scope, value)) { val bytes=s.toByteArray(UTF_8); d.writeInt(bytes.size); d.write(bytes) }
            }
        }
        return out.toByteArray().also { requireRecovery(it.size <= RecoveryProtocol.MAX_PLAINTEXT_BYTES) }
    }
    fun decode(bytes: ByteArray): Snapshot = try {
        requireRecovery(bytes.size <= RecoveryProtocol.MAX_PLAINTEXT_BYTES, "recovery_corrupt")
        DataInputStream(ByteArrayInputStream(bytes)).use { d ->
            requireRecovery(d.readInt()==1, "recovery_corrupt")
            val rev=d.readLong(); val count=d.readInt()
            requireRecovery(rev>=0 && count in 0..RecoveryProtocol.MAX_SCOPES, "recovery_corrupt")
            val values=linkedMapOf<String,String>()
            repeat(count) {
                fun text(max: Int): String {
                    val n=d.readInt(); requireRecovery(n in 1..max && n<=d.available(), "recovery_corrupt")
                    return RecoveryProtocol.utf8(ByteArray(n).also(d::readFully))
                }
                val scope=text(128); val value=text(RecoveryProtocol.MAX_VALUE_BYTES)
                RecoveryProtocol.checkScope(scope); RecoveryProtocol.value(value)
                requireRecovery(!values.containsKey(scope), "recovery_corrupt"); values[scope]=value
            }
            requireRecovery(d.available()==0, "recovery_corrupt"); Snapshot(rev,values)
        }
    } catch (_: Exception) { throw RecoveryFailure("recovery_corrupt") }
}
