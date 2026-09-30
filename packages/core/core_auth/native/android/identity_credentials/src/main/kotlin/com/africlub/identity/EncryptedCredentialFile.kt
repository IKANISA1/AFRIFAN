package com.africlub.identity

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
interface CredentialKeySource {
    fun existing(): SecretKey?
    /** Called only for first initialization while the global process/file lock is held. */
    fun create(): SecretKey
}
/** Directory durability is platform-specific. A failure must propagate as an UNKNOWN write. */
fun interface DirectorySync { fun sync(directory: Path) }
internal class EncryptedCredentialFile(
    val root: Path,
    private val applicationId: String,
    private val keys: CredentialKeySource,
    private val directorySync: DirectorySync,
    private val fault: (String) -> Unit = {}
) {
    private val state=root.resolve("credentials.v1")
    private val temporary=root.resolve("credentials.pending")
    private val magic=byteArrayOf(65,70,82,73,68,78,48,49) // AFRIDN01
    private val aad=("africlub-identity-credentials-file-v1:"+applicationId).toByteArray(UTF_8)
    init { CredentialProtocol.checkApplication(applicationId) }
    private fun key(): SecretKey = keys.existing() ?: throw CredentialFailure("credential_key_unavailable")
    private fun regular(path: Path) {
        requireCredential(!Files.isSymbolicLink(path) && Files.isRegularFile(path, NOFOLLOW_LINKS), "credential_corrupt")
        requireCredential((Files.getAttribute(path,"unix:nlink",NOFOLLOW_LINKS) as Number).toLong()==1L &&
            Files.getOwner(path,NOFOLLOW_LINKS)==Files.getOwner(root,NOFOLLOW_LINKS) &&
            Files.getPosixFilePermissions(path,NOFOLLOW_LINKS)==java.nio.file.attribute.PosixFilePermissions.fromString("rw-------"),
            "credential_corrupt")
    }
    private fun readFile(): ByteArray {
        regular(state)
        FileChannel.open(state, READ, NOFOLLOW_LINKS).use { c ->
            requireCredential(c.size() in 37L..CredentialProtocol.MAX_FILE_BYTES.toLong(), "credential_corrupt")
            val out=ByteArrayOutputStream();val block=ByteBuffer.allocate(4096)
            while(c.read(block)!=-1) {
                block.flip(); val b=ByteArray(block.remaining());block.get(b);out.write(b);block.clear()
                requireCredential(out.size()<=CredentialProtocol.MAX_FILE_BYTES, "credential_corrupt")
            }
            return out.toByteArray()
        }
    }
    private fun seal(snapshot: Snapshot, key: SecretKey): ByteArray {
        val plain=SnapshotCodec.encode(snapshot)
        try {
            val cipher=Cipher.getInstance("AES/GCM/NoPadding")
            // Provider generates IV. AndroidKeyStore randomized-encryption requirements stay enabled.
            cipher.init(Cipher.ENCRYPT_MODE,key);requireCredential(cipher.iv.size==12,"credential_crypto_unavailable")
            cipher.updateAAD(aad);return magic+cipher.iv+cipher.doFinal(plain)
        } finally { plain.fill(0) }
    }
    fun read(): Snapshot {
        val blob=readFile()
        try {
            requireCredential(blob.copyOfRange(0,8).contentEquals(magic),"credential_corrupt")
            val cipher=Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE,key(),GCMParameterSpec(128,blob.copyOfRange(8,20)));cipher.updateAAD(aad)
            val plain=cipher.doFinal(blob,20,blob.size-20)
            try { return SnapshotCodec.decode(plain).also { snapshot -> snapshot.values.keys.forEach { CredentialProtocol.bind(it, applicationId) } } } finally { plain.fill(0) }
        } catch (e: CredentialFailure) {throw e}
        catch (_: Exception) {throw CredentialFailure("credential_corrupt")}
        finally {blob.fill(0)}
    }
    fun initialize() {
        val existing=keys.existing()
        if(Files.exists(state,NOFOLLOW_LINKS)) {
            requireCredential(existing!=null,"credential_key_unavailable");read();return
        }
        // Never turn a lost/corrupt state or lost key into an empty store. A failed initial
        // creation remains unavailable; it cannot erase a reserved identity command.
        requireCredential(existing==null&&!Files.exists(temporary,NOFOLLOW_LINKS),"credential_state_missing")
        val created=keys.create();write(Snapshot(0,emptyMap()),created)
    }
    fun write(snapshot: Snapshot, key: SecretKey = key()) {
        val encrypted=seal(snapshot,key)
        try {
            requireCredential(!Files.isSymbolicLink(state)&&!Files.isSymbolicLink(temporary),"credential_corrupt")
            if(Files.exists(temporary,NOFOLLOW_LINKS)) {regular(temporary);Files.delete(temporary)}
            FileChannel.open(temporary,setOf(CREATE_NEW,WRITE,NOFOLLOW_LINKS),java.nio.file.attribute.PosixFilePermissions.asFileAttribute(java.nio.file.attribute.PosixFilePermissions.fromString("rw-------"))).use { channel ->
                val buffer=ByteBuffer.wrap(encrypted);while(buffer.hasRemaining())channel.write(buffer)
                channel.force(true)
            }
            fault("after_file_sync")
            // No non-atomic copy fallback. The same-directory move either succeeds or fails.
            Files.move(temporary,state,ATOMIC_MOVE,REPLACE_EXISTING)
            fault("after_rename")
            directorySync.sync(root)
            fault("after_directory_sync")
        } catch (e: CredentialFailure) {throw e}
        catch (_: Exception) {throw CredentialFailure("credential_write_unknown")}
        finally {encrypted.fill(0)}
    }
    fun load(scope:String):String? {CredentialProtocol.checkScope(scope);return read().values[scope]}
    fun compareAndSet(scope:String,expected:String?,value:String):Boolean {
        CredentialProtocol.checkScope(scope);CredentialProtocol.value(value)
        if(expected!=null)CredentialProtocol.value(expected)
        val old=read();if(old.values[scope]!=expected)return false
        if(old.values[scope]==value)return true
        requireCredential(old.revision<Long.MAX_VALUE,"credential_capacity")
        requireCredential(scope in old.values||old.values.size<CredentialProtocol.MAX_SCOPES,"credential_capacity")
        write(Snapshot(old.revision+1,old.values+Pair(scope,value)))
        requireCredential(read().values[scope]==value,"credential_write_unknown");return true
    }
}
