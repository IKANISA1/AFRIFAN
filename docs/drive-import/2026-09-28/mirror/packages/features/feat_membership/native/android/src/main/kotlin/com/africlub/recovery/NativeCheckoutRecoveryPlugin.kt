package com.africlub.recovery

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.RejectedExecutionException

/** Optional host registration. A fresh instance is required per Flutter engine.
 * No key/file is created while disabled. No payment, dialer or credential API. */
class NativeCheckoutRecoveryPlugin(private val enabled:Boolean=false):FlutterPlugin,MethodChannel.MethodCallHandler {
    private var channel:MethodChannel?=null
    private var executor:ThreadPoolExecutor?=null
    private var dispatcher:RecoveryDispatcher?=null
    private val main=Handler(Looper.getMainLooper())
    private var everAttached=false
    @Volatile private var detached=true
    override fun onAttachedToEngine(binding:FlutterPlugin.FlutterPluginBinding) {
        check(!everAttached){"Create a fresh recovery plugin for each engine"};everAttached=true;detached=false
        val host=AndroidRecoveryHost(binding.applicationContext)
        dispatcher=RecoveryDispatcher(enabled,host::createStore,host::requireUnlocked)
        executor=ThreadPoolExecutor(1,1,0L,TimeUnit.MILLISECONDS,ArrayBlockingQueue(32))
        channel=MethodChannel(binding.binaryMessenger,"africlub/native-checkout-recovery/v1").also{it.setMethodCallHandler(this)}
    }
    private fun fail(result:MethodChannel.Result,code:String){main.post{if(!detached)result.error(code,code,null)}}
    override fun onMethodCall(call:MethodCall,result:MethodChannel.Result) {
        if(!enabled||detached){fail(result,"recovery_disabled");return}
        try{executor?.execute {
            if(detached)return@execute
            try {
                val response=dispatcher!!.invoke(call.method,call.arguments)
                main.post{if(!detached)result.success(response)}
            }catch(e:Exception){fail(result,(e as? RecoveryFailure)?.code?:"recovery_unavailable")}
        } ?: fail(result,"recovery_disabled")}catch(_:RejectedExecutionException){fail(result,"recovery_busy")}
    }
    override fun onDetachedFromEngine(binding:FlutterPlugin.FlutterPluginBinding) {
        detached=true;channel?.setMethodCallHandler(null);channel=null
        val queue=executor;executor=null;val closing=dispatcher
        if(queue!=null) {
            queue.queue.clear()
            queue.execute{try{closing?.close()}finally{dispatcher=null}}
            queue.shutdown()
        }
    }
}
