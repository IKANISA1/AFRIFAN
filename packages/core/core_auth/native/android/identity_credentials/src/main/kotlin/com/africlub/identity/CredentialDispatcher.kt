package com.africlub.identity

import java.util.UUID

/** Exact platform-channel contract. Platform integration supplies a fixed private
 * directory/key source; request payloads cannot select paths, owners or key aliases. */
internal class CredentialDispatcher(
    private val enabled:Boolean=false,
    private val policy:CredentialPolicy,
    private val storeProvider:()->CredentialStore,
    private val beforeAccess:()->Unit={}
) {
    private val owner=UUID.randomUUID().toString()
    private var store:CredentialStore?=null
    private var closed=false
    private fun string(a:Map<*,*>,key:String):String=a[key] as? String ?: throw CredentialFailure("credential_invalid_request")
    @Synchronized fun invoke(method:String,arguments:Any?):Map<String,Any?> {
        requireCredential(enabled&&!closed,"credential_disabled")
        if (method == "describe") {
            val a = arguments as? Map<*,*> ?: throw CredentialFailure("credential_invalid_request")
            requireCredential(a.keys.toSet() == setOf("scope"))
            val scope = string(a,"scope"); policy.authorize(scope); beforeAccess()
            return mapOf("version" to 1,"scope" to scope,"applicationId" to policy.applicationId,"maxJournalBytes" to 8192,"policy" to "android_keystore_aead_foreground_v1")
        }
        val keys=when(method) {
            "tryAcquire","release","drain"->setOf("scope","acquisitionId")
            "read"->setOf("scope","lease")
            "compareAndSet"->setOf("scope","lease","expected","value")
            else->throw CredentialFailure("credential_invalid_request")
        }
        val a=arguments as? Map<*,*> ?: throw CredentialFailure("credential_invalid_request")
        requireCredential(a.keys.toSet()==keys)
        val scope=string(a,"scope");CredentialProtocol.checkScope(scope)
        if(method=="release" || method=="drain") {
            CredentialProtocol.bind(scope, policy.applicationId)
            val acquisition=string(a,"acquisitionId");CredentialProtocol.checkId(acquisition)
            if(method=="drain")return mapOf("version" to 1,"settled" to true)
            store?.release(owner,scope,acquisition)
            return mapOf("version" to 1,"released" to true)
        }
        if(method=="tryAcquire")CredentialProtocol.checkId(string(a,"acquisitionId"))
        else CredentialProtocol.checkId(string(a,"lease"))
        if(method=="compareAndSet") {
            requireCredential(a["expected"]==null||a["expected"] is String)
            (a["expected"] as String?)?.let{CredentialProtocol.value(it)}
            CredentialProtocol.value(string(a,"value"))
        }
        policy.authorize(scope)
        beforeAccess()
        val s=store?:storeProvider().also{store=it}
        return when(method) {
            "tryAcquire"->{val token=s.tryAcquire(owner,scope,string(a,"acquisitionId"));mapOf("version" to 1,"busy" to (token==null),"lease" to token)}
            "read"->mapOf("version" to 1,"value" to s.load(owner,scope,string(a,"lease")))
            else->mapOf("version" to 1,"updated" to s.compareAndSet(owner,scope,string(a,"lease"),a["expected"] as String?,string(a,"value")))
        }
    }
    @Synchronized fun close(){closed=true;store?.closeOwner(owner);store=null}
}
