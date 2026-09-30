package com.africlub.identity

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.UserManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.system.Os
import android.system.OsConstants
import java.io.File
import java.nio.file.Files
import java.nio.file.LinkOption.NOFOLLOW_LINKS
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

/** Android API 26+ host adapter. Not executed by portable JVM tests.
 * Only an application-owned no-backup path is used; no path/key comes from Dart. */
internal class AndroidCredentialHost(private val context: Context) {
    private val alias="africlub.identity.credentials.aes.v1"
    fun requireUnlocked() {
        requireCredential(Build.VERSION.SDK_INT>=26,"credential_platform_unsupported")
        val users=context.getSystemService(UserManager::class.java)
        val guard=context.getSystemService(KeyguardManager::class.java)
        requireCredential(users?.isUserUnlocked==true&&guard?.isDeviceLocked==false&&guard.isDeviceSecure,"credential_device_locked")
    }
    fun createStore():CredentialStore {
        requireUnlocked()
        val directory=File(context.noBackupFilesDir,"africlub_identity_credentials_v1")
        if(!directory.exists())requireCredential(directory.mkdir(),"credential_directory_unavailable")
        requireCredential(!Files.isSymbolicLink(directory.toPath()),"credential_directory_unavailable")
        val attributes=Os.lstat(directory.absolutePath)
        requireCredential(OsConstants.S_ISDIR(attributes.st_mode)&&attributes.st_uid==android.os.Process.myUid(),"credential_directory_unavailable")
        Os.chmod(directory.absolutePath,448) // 0700, app-private; no added manifest permissions.
        val root=directory.canonicalFile.toPath()
        requireCredential(Files.isDirectory(root,NOFOLLOW_LINKS),"credential_directory_unavailable")
        val keySource=object:CredentialKeySource {
            override fun existing():SecretKey? {
                requireUnlocked()
                val store=KeyStore.getInstance("AndroidKeyStore").apply{load(null)}
                if(!store.containsAlias(alias))return null
                val key = (store.getKey(alias,null) as? SecretKey) ?: throw CredentialFailure("credential_key_unavailable")
                val info = SecretKeyFactory.getInstance("AES", "AndroidKeyStore").getKeySpec(key, KeyInfo::class.java) as KeyInfo
                requireCredential(key.algorithm == "AES" && key.encoded == null && info.keystoreAlias == alias &&
                    info.keySize == 256 && info.origin == KeyProperties.ORIGIN_GENERATED &&
                    info.purposes == (KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT) &&
                    info.blockModes.toSet() == setOf(KeyProperties.BLOCK_MODE_GCM) &&
                    info.encryptionPaddings.toSet() == setOf(KeyProperties.ENCRYPTION_PADDING_NONE) &&
                    !info.isUserAuthenticationRequired && info.keyValidityStart == null &&
                    info.keyValidityForOriginationEnd == null && info.keyValidityForConsumptionEnd == null,
                    "credential_key_conflict")
                return key
            }
            override fun create():SecretKey {
                requireUnlocked();requireCredential(existing()==null,"credential_key_conflict")
                val builder=KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(true)
                // Android documents key-deletion/unlock bugs on API 31-34. Do not opt
                // into that destructive behavior. Earlier versions have app-level locked
                // device checks, not a claimed hardware-enforced unlock constraint.
                if(Build.VERSION.SDK_INT>=35)builder.setUnlockedDeviceRequired(true)
                return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").run {
                    init(builder.build());generateKey().also { requireCredential(existing() != null, "credential_key_conflict") }
                }
            }
        }
        return CredentialStore(root,context.packageName,keySource,DirectorySync { path ->
            val fd=Os.open(path.toString(),OsConstants.O_RDONLY or OsConstants.O_NOFOLLOW,0)
            try{
                requireCredential(OsConstants.S_ISDIR(Os.fstat(fd).st_mode),"credential_directory_unavailable")
                Os.fsync(fd)
            }finally{Os.close(fd)}
        })
    }
}
