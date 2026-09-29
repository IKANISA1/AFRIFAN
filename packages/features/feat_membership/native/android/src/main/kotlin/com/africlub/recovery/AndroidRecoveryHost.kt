package com.africlub.recovery

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.UserManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.system.Os
import android.system.OsConstants
import java.io.File
import java.nio.file.Files
import java.nio.file.LinkOption.NOFOLLOW_LINKS
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/** Android API 26+ host adapter. NOT included in the portable JVM test compilation.
 * Only an application-owned no-backup path is used; no path/key comes from Dart. */
internal class AndroidRecoveryHost(private val context: Context) {
    private val alias="africlub.checkout.recovery.aes.v1"
    fun requireUnlocked() {
        requireRecovery(Build.VERSION.SDK_INT>=26,"recovery_platform_unsupported")
        val users=context.getSystemService(UserManager::class.java)
        val guard=context.getSystemService(KeyguardManager::class.java)
        requireRecovery(users?.isUserUnlocked==true&&guard?.isDeviceLocked==false,"recovery_device_locked")
    }
    fun createStore():RecoveryStore {
        requireUnlocked()
        val directory=File(context.noBackupFilesDir,"africlub_checkout_recovery_v1")
        if(!directory.exists())requireRecovery(directory.mkdir(),"recovery_directory_unavailable")
        requireRecovery(!Files.isSymbolicLink(directory.toPath()),"recovery_directory_unavailable")
        Os.chmod(directory.absolutePath,448) // 0700, app-private; no added manifest permissions.
        val root=directory.canonicalFile.toPath()
        requireRecovery(Files.isDirectory(root,NOFOLLOW_LINKS),"recovery_directory_unavailable")
        val keySource=object:RecoveryKeySource {
            override fun existing():SecretKey? {
                requireUnlocked()
                val store=KeyStore.getInstance("AndroidKeyStore").apply{load(null)}
                if(!store.containsAlias(alias))return null
                return (store.getKey(alias,null) as? SecretKey) ?: throw RecoveryFailure("recovery_key_unavailable")
            }
            override fun create():SecretKey {
                requireUnlocked();requireRecovery(existing()==null,"recovery_key_conflict")
                val builder=KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(true)
                // Android documents key-deletion/unlock bugs on API 31-34. Do not opt
                // into that destructive behavior. Earlier versions have app-level locked
                // device checks, not a claimed hardware-enforced unlock constraint.
                if(Build.VERSION.SDK_INT>=35)builder.setUnlockedDeviceRequired(true)
                return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").run {
                    init(builder.build());generateKey()
                }
            }
        }
        return RecoveryStore(root,context.packageName,keySource,DirectorySync { path ->
            val fd=Os.open(path.toString(),OsConstants.O_RDONLY or OsConstants.O_NOFOLLOW,0)
            try{
                requireRecovery(OsConstants.S_ISDIR(Os.fstat(fd).st_mode),"recovery_directory_unavailable")
                Os.fsync(fd)
            }finally{Os.close(fd)}
        })
    }
}
