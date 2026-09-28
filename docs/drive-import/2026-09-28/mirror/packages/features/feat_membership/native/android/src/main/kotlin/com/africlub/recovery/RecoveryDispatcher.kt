package com.africlub.recovery

import java.util.UUID

/** Exact platform-channel contract. Platform integration supplies a fixed private
 * directory/key source; request payloads cannot select paths, owners or key aliases. */
class RecoveryDispatcher(
    private val enabled:Boolean=false,
    private val storeProvider:()->RecoveryStore,
    private val beforeAccess:()->Unit={}
) {
    private val owner=UUID.randomUUID().toString()
    private var store:RecoveryStore?=null
    private var closed=false
    private fun string(a:Map<*,*>,key:String):String=a[key] as? String ?: throw RecoveryFailure("recovery_invalid_request")
    @Synchronized fun invoke(method:String,arguments:Any?):Map<String,Any?> {
        requireRecovery(enabled&&!closed,"recovery_disabled")
        val keys=when(method) {
            "tryAcquire","release"->setOf("scope","acquisitionId")
            "load"->setOf("scope","lease")
            "compareAndSet"->setOf("scope","lease","expected","value")
            else->throw RecoveryFailure("recovery_invalid_request")
        }
        val a=arguments as? Map<*,*> ?: throw RecoveryFailure("recovery_invalid_request")
        requireRecovery(a.keys.toSet()==keys)
        val scope=string(a,"scope");RecoveryProtocol.checkScope(scope)
        if(method=="release") {
            val acquisition=string(a,"acquisitionId");RecoveryProtocol.checkId(acquisition)
            store?.release(owner,scope,acquisition)
            return mapOf("version" to 1,"released" to true)
        }
        if(method=="tryAcquire")RecoveryProtocol.checkId(string(a,"acquisitionId"))
        else RecoveryProtocol.checkId(string(a,"lease"))
        if(method=="compareAndSet") {
            requireRecovery(a["expected"]==null||a["expected"] is String)
            (a["expected"] as String?)?.let{RecoveryProtocol.value(it)}
            RecoveryProtocol.value(string(a,"value"))
        }
        beforeAccess()
        val s=store?:storeProvider().also{store=it}
        return when(method) {
            "tryAcquire"->{val token=s.tryAcquire(owner,scope,string(a,"acquisitionId"));mapOf("version" to 1,"busy" to (token==null),"lease" to token)}
            "load"->mapOf("version" to 1,"value" to s.load(owner,scope,string(a,"lease")))
            else->mapOf("version" to 1,"updated" to s.compareAndSet(owner,scope,string(a,"lease"),a["expected"] as String?,string(a,"value")))
        }
    }
    @Synchronized fun close(){closed=true;store?.closeOwner(owner);store=null}
}
