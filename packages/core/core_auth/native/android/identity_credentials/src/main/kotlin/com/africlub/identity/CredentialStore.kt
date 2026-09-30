package com.africlub.identity

import java.nio.channels.FileChannel
import java.nio.channels.FileLock
import java.nio.channels.OverlappingFileLockException
import java.nio.file.Files
import java.nio.file.LinkOption.NOFOLLOW_LINKS
import java.nio.file.Path
import java.nio.file.StandardOpenOption.*
import java.util.UUID

/** One global lock per installation, not only per account. No time-expiry releases a
 * live critical section. Process death releases the OS lock; persisted reservations survive.
 * Use one class-loader and directory for all engines. Never delete or replace credentials.lock. */
class CredentialStore(
    root:Path, private val applicationId:String, keys:CredentialKeySource, directorySync:DirectorySync,
    fault:(String)->Unit = {}
) {
    private val root:Path
    private val file:EncryptedCredentialFile
    private data class Lease(val owner:String,val scope:String,val request:String,val token:String,
                             val channel:FileChannel,val lock:FileLock,val fileKey:Any)
    companion object {
        private val mutex=Any()
        private val leases=mutableMapOf<String,Lease>()
    }
    init {
        val absolute=root.toAbsolutePath().normalize()
        requireCredential(Files.isDirectory(absolute,NOFOLLOW_LINKS)&&!Files.isSymbolicLink(absolute),"credential_directory_unavailable")
        // Reject alias paths so two engines cannot accidentally create independent locks.
        requireCredential(absolute.toRealPath()==absolute,"credential_directory_unavailable")
        this.root=absolute;file=EncryptedCredentialFile(absolute,applicationId,keys,directorySync,fault)
    }
    private fun lockIdentity():Any {
        val path=root.resolve("credentials.lock")
        requireCredential(!Files.isSymbolicLink(path)&&Files.isRegularFile(path,NOFOLLOW_LINKS),"credential_lock_lost")
        requireCredential((Files.getAttribute(path,"unix:nlink",NOFOLLOW_LINKS) as Number).toLong()==1L&&Files.getOwner(path,NOFOLLOW_LINKS)==Files.getOwner(root,NOFOLLOW_LINKS),"credential_lock_lost")
        val permissions=Files.getPosixFilePermissions(path,NOFOLLOW_LINKS)
        requireCredential(permissions==java.nio.file.attribute.PosixFilePermissions.fromString("rw-------"),"credential_lock_lost")
        return Files.readAttributes(path,java.nio.file.attribute.BasicFileAttributes::class.java,NOFOLLOW_LINKS).fileKey()?:throw CredentialFailure("credential_lock_lost")
    }
    fun tryAcquire(owner:String,scope:String,requestId:String):String? = synchronized(mutex) {
        CredentialProtocol.checkId(owner);CredentialProtocol.checkId(requestId);CredentialProtocol.bind(scope, applicationId)
        val path=root.toString();val held=leases[path]
        if(held!=null) {
            requireCredential(held.lock.isValid&&lockIdentity()==held.fileKey,"credential_lock_lost")
            return@synchronized if(held.owner==owner&&held.request==requestId&&held.scope==scope)held.token else null
        }
        requireCredential(leases.size<16,"credential_capacity")
        val lockPath=root.resolve("credentials.lock")
        requireCredential(!Files.isSymbolicLink(lockPath),"credential_directory_unavailable")
        val channel=FileChannel.open(lockPath,CREATE,WRITE,NOFOLLOW_LINKS)
        Files.setPosixFilePermissions(lockPath,java.nio.file.attribute.PosixFilePermissions.fromString("rw-------"))
        val identity=lockIdentity()
        var lock:FileLock?=null
        try {
            lock=try{channel.tryLock()}catch(_:OverlappingFileLockException){null}
            if(lock==null) {channel.close();return@synchronized null}
            requireCredential(lockIdentity()==identity,"credential_lock_lost")
            file.initialize()
            val lease=Lease(owner,scope,requestId,UUID.randomUUID().toString(),channel,lock,identity)
            leases[path]=lease;lease.token
        } catch (e:Exception) {
            try{lock?.release()}finally{channel.close()}
            if(e is CredentialFailure)throw e
            throw CredentialFailure("credential_unavailable")
        }
    }
    private fun held(owner:String,scope:String,token:String):Lease {
        CredentialProtocol.checkId(owner);CredentialProtocol.checkId(token);CredentialProtocol.bind(scope, applicationId)
        val h=leases[root.toString()]
        requireCredential(h!=null&&h.owner==owner&&h.scope==scope&&h.token==token&&h.lock.isValid,"credential_lock_required")
        requireCredential(lockIdentity()==h!!.fileKey,"credential_lock_lost")
        return h
    }
    fun load(owner:String,scope:String,token:String):String? = synchronized(mutex) {
        held(owner,scope,token);file.load(scope)
    }
    fun compareAndSet(owner:String,scope:String,token:String,expected:String?,value:String):Boolean = synchronized(mutex) {
        held(owner,scope,token);file.compareAndSet(scope,expected,value)
    }
    fun release(owner:String,scope:String,requestId:String) = synchronized(mutex) {
        CredentialProtocol.checkId(owner);CredentialProtocol.checkId(requestId);CredentialProtocol.bind(scope, applicationId)
        val h=leases[root.toString()] ?: return@synchronized
        // Release is keyed by original acquisition, so a timed-out caller can clean up
        // a successful acquisition whose token response was lost. A later lease is safe.
        if(h.owner!=owner||h.scope!=scope||h.request!=requestId)return@synchronized
        try{h.lock.release()}finally{try{h.channel.close()}finally{leases.remove(root.toString())}}
    }
    fun closeOwner(owner:String) = synchronized(mutex) {
        CredentialProtocol.checkId(owner)
        val h=leases[root.toString()] ?: return@synchronized
        if(h.owner==owner)release(owner,h.scope,h.request)
    }
}
