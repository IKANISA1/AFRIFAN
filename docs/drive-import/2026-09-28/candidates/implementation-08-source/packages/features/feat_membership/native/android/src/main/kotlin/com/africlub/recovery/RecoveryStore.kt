package com.africlub.recovery

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
 * Use one class-loader and directory for all engines. Never delete or replace recovery.lock. */
class RecoveryStore(
    root:Path, applicationId:String, keys:RecoveryKeySource, directorySync:DirectorySync,
    fault:(String)->Unit = {}
) {
    private val root:Path
    private val file:EncryptedRecoveryFile
    private data class Lease(val owner:String,val scope:String,val request:String,val token:String,
                             val channel:FileChannel,val lock:FileLock)
    companion object {
        private val mutex=Any()
        private val leases=mutableMapOf<String,Lease>()
    }
    init {
        val absolute=root.toAbsolutePath().normalize()
        requireRecovery(Files.isDirectory(absolute,NOFOLLOW_LINKS)&&!Files.isSymbolicLink(absolute),"recovery_directory_unavailable")
        // Reject alias paths so two engines cannot accidentally create independent locks.
        requireRecovery(absolute.toRealPath()==absolute,"recovery_directory_unavailable")
        this.root=absolute;file=EncryptedRecoveryFile(absolute,applicationId,keys,directorySync,fault)
    }
    fun tryAcquire(owner:String,scope:String,requestId:String):String? = synchronized(mutex) {
        RecoveryProtocol.checkId(owner);RecoveryProtocol.checkId(requestId);RecoveryProtocol.checkScope(scope)
        val path=root.toString();val held=leases[path]
        if(held!=null) {
            requireRecovery(held.lock.isValid,"recovery_lock_lost")
            return@synchronized if(held.owner==owner&&held.request==requestId&&held.scope==scope)held.token else null
        }
        requireRecovery(leases.size<16,"recovery_capacity")
        val lockPath=root.resolve("recovery.lock")
        requireRecovery(!Files.isSymbolicLink(lockPath),"recovery_directory_unavailable")
        val channel=FileChannel.open(lockPath,CREATE,WRITE,NOFOLLOW_LINKS)
        var lock:FileLock?=null
        try {
            lock=try{channel.tryLock()}catch(_:OverlappingFileLockException){null}
            if(lock==null) {channel.close();return@synchronized null}
            file.initialize()
            val lease=Lease(owner,scope,requestId,UUID.randomUUID().toString(),channel,lock)
            leases[path]=lease;lease.token
        } catch (e:Exception) {
            try{lock?.release()}finally{channel.close()}
            if(e is RecoveryFailure)throw e
            throw RecoveryFailure("recovery_unavailable")
        }
    }
    private fun held(owner:String,scope:String,token:String):Lease {
        RecoveryProtocol.checkId(owner);RecoveryProtocol.checkId(token);RecoveryProtocol.checkScope(scope)
        val h=leases[root.toString()]
        requireRecovery(h!=null&&h.owner==owner&&h.scope==scope&&h.token==token&&h.lock.isValid,"recovery_lock_required")
        return h!!
    }
    fun load(owner:String,scope:String,token:String):String? = synchronized(mutex) {
        held(owner,scope,token);file.load(scope)
    }
    fun compareAndSet(owner:String,scope:String,token:String,expected:String?,value:String):Boolean = synchronized(mutex) {
        held(owner,scope,token);file.compareAndSet(scope,expected,value)
    }
    fun release(owner:String,scope:String,requestId:String) = synchronized(mutex) {
        RecoveryProtocol.checkId(owner);RecoveryProtocol.checkId(requestId);RecoveryProtocol.checkScope(scope)
        val h=leases[root.toString()] ?: return@synchronized
        // Release is keyed by original acquisition, so a timed-out caller can clean up
        // a successful acquisition whose token response was lost. A later lease is safe.
        if(h.owner!=owner||h.scope!=scope||h.request!=requestId)return@synchronized
        try{h.lock.release()}finally{try{h.channel.close()}finally{leases.remove(root.toString())}}
    }
    fun closeOwner(owner:String) = synchronized(mutex) {
        RecoveryProtocol.checkId(owner)
        val h=leases[root.toString()] ?: return@synchronized
        if(h.owner==owner)release(owner,h.scope,h.request)
    }
}
