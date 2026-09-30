package com.africlub.identity

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.RejectedExecutionException

/** Dedicated credential host. Disabled/empty policy creates no key or files.
 * Every engine has its own owner and FIFO. No network, prompts, logs or timers. */
class NativeIdentityCredentialPlugin(
    private val enabled:Boolean=false,
    private val approvedScopes:Set<String> = emptySet()
):FlutterPlugin,ActivityAware,Application.ActivityLifecycleCallbacks,MethodChannel.MethodCallHandler {
    private var channel:MethodChannel?=null
    private var executor:ThreadPoolExecutor?=null
    private var dispatcher:CredentialDispatcher?=null
    private var application:Application?=null
    @Volatile private var activity:Activity?=null
    @Volatile private var foreground=false
    @Volatile private var detached=true
    private val admission=CredentialQueueAdmission()
    private val main=Handler(Looper.getMainLooper())
    private var everAttached=false
    override fun onAttachedToEngine(binding:FlutterPlugin.FlutterPluginBinding) {
        check(!everAttached){"Create a fresh credential plugin per engine"};everAttached=true;detached=false
        val host=AndroidCredentialHost(binding.applicationContext)
        val policy=CredentialPolicy(binding.applicationContext.packageName,enabled,approvedScopes)
        dispatcher=CredentialDispatcher(enabled,policy,host::createStore){
            requireCredential(!detached&&foreground&&activity!=null,"credential_device_locked");host.requireUnlocked()
        }
        // User calls are bounded to32, plus two reserved FIFO cleanup slots.
        executor=ThreadPoolExecutor(1,1,0L,TimeUnit.MILLISECONDS,LinkedBlockingQueue())
        application=binding.applicationContext as? Application
        application?.registerActivityLifecycleCallbacks(this)
        channel=MethodChannel(binding.binaryMessenger,"africlub/native-identity-credentials/v1").also{it.setMethodCallHandler(this)}
    }
    private fun fail(result:MethodChannel.Result,code:String){main.post{if(!detached)result.error(code,null,null)}}
    override fun onMethodCall(call:MethodCall,result:MethodChannel.Result) {
        if(!enabled||detached){fail(result,"credential_disabled");return}
        try { CredentialProtocol.requestShape(call.method, call.arguments) }
        catch (_: CredentialFailure) { fail(result,"credential_invalid_request");return }
        if(!admission.enqueue(call.method)){fail(result,"credential_busy");return}
        try{
            val queue=executor?:throw RejectedExecutionException()
            queue.execute {
                try {
                    // Engine abort fences every operation that has not started.
                    if(!detached){
                        val response=dispatcher!!.invoke(call.method,call.arguments)
                        main.post{if(!detached)result.success(response)}
                    }
                }catch(e:Exception){fail(result,(e as? CredentialFailure)?.code?:"credential_unavailable")}
                finally{admission.finished(call.method)}
            }
        }catch(_:RejectedExecutionException){admission.finished(call.method);fail(result,"credential_busy")}
    }
    override fun onDetachedFromEngine(binding:FlutterPlugin.FlutterPluginBinding) {
        detached=true;foreground=false;activity=null;admission.stop()
        channel?.setMethodCallHandler(null);channel=null
        application?.unregisterActivityLifecycleCallbacks(this);application=null
        val queue=executor;executor=null;val closing=dispatcher
        // Existing work finishes/aborts in FIFO order before the owner is released.
        queue?.execute{try{closing?.close()}finally{dispatcher=null}}
        queue?.shutdown()
    }
    override fun onAttachedToActivity(binding:ActivityPluginBinding){activity=binding.activity;foreground=false}
    override fun onDetachedFromActivityForConfigChanges(){foreground=false;activity=null}
    override fun onReattachedToActivityForConfigChanges(binding:ActivityPluginBinding){onAttachedToActivity(binding)}
    override fun onDetachedFromActivity(){foreground=false;activity=null}
    override fun onActivityResumed(a:Activity){if(a===activity)foreground=true}
    override fun onActivityPaused(a:Activity){if(a===activity)foreground=false}
    override fun onActivityStopped(a:Activity){if(a===activity)foreground=false}
    override fun onActivityDestroyed(a:Activity){if(a===activity){foreground=false;activity=null}}
    override fun onActivityCreated(a:Activity,b:Bundle?){}
    override fun onActivityStarted(a:Activity){}
    override fun onActivitySaveInstanceState(a:Activity,b:Bundle){}
}
