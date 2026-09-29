package com.africlub.recovery

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.nio.file.Files
import java.nio.file.LinkOption.NOFOLLOW_LINKS
import java.nio.file.Path
import java.nio.file.StandardCopyOption.ATOMIC_MOVE
import java.nio.file.StandardCopyOption.REPLACE_EXISTING
import java.nio.file.StandardOpenOption.*
import java.nio.charset.StandardCharsets.UTF_8
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Android host supplies a non-exportable AndroidKeyStore SecretKey; JVM tests do not. */
interface RecoveryKeySource {
    fun existing(): SecretKey?
    /** Called only for first initialization while the global process/file lock is held. */
    fun create(): SecretKey
}
/** Directory durability is platform-specific. A failure must propagate as an UNKNOWN write. */
fun interface DirectorySync { fun sync(directory: Path) }
internal class EncryptedRecoveryFile(
    val root: Path,
    private val applicationId: String,
    private val keys: RecoveryKeySource,
    private val directorySync: DirectorySync,
    private val fault: (String) -> Unit = {}
) {
    private val state=root.resolve("recovery.v1")
    private val temporary=root.resolve("recovery.pending")
    private val magic=byteArrayOf(65,70,82,82,69,67,48,49) // AFRREC01
    private val aad=("africlub-recovery-file-v1:"+applicationId).toByteArray(UTF_8)
    init { requireRecovery(Regex("[a-zA-Z][a-zA-Z0-9_.]{2,199}").matches(applicationId)) }
    private fun key(): SecretKey = keys.existing() ?: throw RecoveryFailure("recovery_key_unavailable")
    private fun regular(path: Path) {
        requireRecovery(!Files.isSymbolicLink(path) && Files.isRegularFile(path, NOFOLLOW_LINKS), "recovery_corrupt")
    }
    private fun readFile(): ByteArray {
        regular(state)
        FileChannel.open(state, READ, NOFOLLOW_LINKS).use { c ->
            requireRecovery(c.size() in 37L..RecoveryProtocol.MAX_FILE_BYTES.toLong(), "recovery_corrupt")
            val out=ByteArrayOutputStream();val block=ByteBuffer.allocate(4096)
            while(c.read(block)!=-1) {
                block.flip(); val b=ByteArray(block.remaining());block.get(b);out.write(b);block.clear()
                requireRecovery(out.size()<=RecoveryProtocol.MAX_FILE_BYTES, "recovery_corrupt")
            }
            return out.toByteArray()
        }
    }
    private fun seal(snapshot: Snapshot, key: SecretKey): ByteArray {
        val plain=SnapshotCodec.encode(snapshot)
        try {
            val cipher=Cipher.getInstance("AES/GCM/NoPadding")
            // Provider generates IV. AndroidKeyStore randomized-encryption requirements stay enabled.
            cipher.init(Cipher.ENCRYPT_MODE,key);requireRecovery(cipher.iv.size==12,"recovery_crypto_unavailable")
            cipher.updateAAD(aad);return magic+cipher.iv+cipher.doFinal(plain)
        } finally { plain.fill(0) }
    }
    fun read(): Snapshot {
        val blob=readFile()
        try {
            requireRecovery(blob.copyOfRange(0,8).contentEquals(magic),"recovery_corrupt")
            val cipher=Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE,key(),GCMParameterSpec(128,blob.copyOfRange(8,20)));cipher.updateAAD(aad)
            val plain=cipher.doFinal(blob,20,blob.size-20)
            try { return SnapshotCodec.decode(plain) } finally { plain.fill(0) }
        } catch (e: RecoveryFailure) {throw e}
        catch (_: Exception) {throw RecoveryFailure("recovery_corrupt")}
        finally {blob.fill(0)}
    }
    fun initialize() {
        val existing=keys.existing()
        if(Files.exists(state,NOFOLLOW_LINKS)) {
            requireRecovery(existing!=null,"recovery_key_unavailable");read();return
        }
        // Never turn a lost/corrupt state or lost key into an empty store. A failed initial
        // creation intentionally requires operator recovery instead of allowing a payment retry.
        requireRecovery(existing==null&&!Files.exists(temporary,NOFOLLOW_LINKS),"recovery_state_missing")
        val created=keys.create();write(Snapshot(0,emptyMap()),created)
    }
    fun write(snapshot: Snapshot, key: SecretKey = key()) {
        val encrypted=seal(snapshot,key)
        try {
            requireRecovery(!Files.isSymbolicLink(state)&&!Files.isSymbolicLink(temporary),"recovery_corrupt")
            if(Files.exists(temporary,NOFOLLOW_LINKS)) {regular(temporary);Files.delete(temporary)}
            FileChannel.open(temporary,CREATE_NEW,WRITE,NOFOLLOW_LINKS).use { channel ->
                val buffer=ByteBuffer.wrap(encrypted);while(buffer.hasRemaining())channel.write(buffer)
                channel.force(true)
            }
            fault("after_file_sync")
            // No non-atomic copy fallback. The same-directory move either succeeds or fails.
            Files.move(temporary,state,ATOMIC_MOVE,REPLACE_EXISTING)
            fault("after_rename")
            directorySync.sync(root)
            fault("after_directory_sync")
        } catch (e: RecoveryFailure) {throw e}
        catch (_: Exception) {throw RecoveryFailure("recovery_write_unknown")}
        finally {encrypted.fill(0)}
    }
    fun load(scope:String):String? {RecoveryProtocol.checkScope(scope);return read().values[scope]}
    fun compareAndSet(scope:String,expected:String?,value:String):Boolean {
        RecoveryProtocol.checkScope(scope);RecoveryProtocol.value(value)
        if(expected!=null)RecoveryProtocol.value(expected)
        val old=read();if(old.values[scope]!=expected)return false
        if(old.values[scope]==value)return true
        requireRecovery(old.revision<Long.MAX_VALUE,"recovery_capacity")
        requireRecovery(scope in old.values||old.values.size<RecoveryProtocol.MAX_SCOPES,"recovery_capacity")
        write(Snapshot(old.revision+1,old.values+Pair(scope,value)))
        requireRecovery(read().values[scope]==value,"recovery_write_unknown");return true
    }
}
