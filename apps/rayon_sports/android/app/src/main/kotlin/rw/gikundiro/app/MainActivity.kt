package rw.gikundiro.app

import android.app.Activity
import android.content.Intent
import com.google.android.gms.pay.Pay
import com.google.android.gms.pay.PayApiAvailabilityStatus
import com.google.android.gms.pay.PayClient
import com.africlub.recovery.NativeCheckoutRecoveryPlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val googleWalletChannel = "africlub/google_wallet"
    private val savePassRequestCode = 7301
    private lateinit var walletClient: PayClient
    private var pendingSaveResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!flutterEngine.plugins.has(NativeCheckoutRecoveryPlugin::class.java)) {
            flutterEngine.plugins.add(NativeCheckoutRecoveryPlugin(enabled = true))
        }
        walletClient = Pay.getClient(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            googleWalletChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    walletClient
                        .getPayApiAvailabilityStatus(
                            PayClient.RequestType.SAVE_PASSES_JWT,
                        )
                        .addOnSuccessListener { status ->
                            result.success(status == PayApiAvailabilityStatus.AVAILABLE)
                        }
                        .addOnFailureListener {
                            result.success(false)
                        }
                }
                "savePassJwt" -> {
                    val jwt = call.argument<String>("jwt")?.trim()
                    if (jwt.isNullOrEmpty() || jwt.length > 16 * 1024) {
                        result.error("invalid_request", "A valid Wallet pass is required.", null)
                    } else if (pendingSaveResult != null) {
                        result.error("in_progress", "A Wallet save is already in progress.", null)
                    } else {
                        pendingSaveResult = result
                        try {
                            walletClient.savePassesJwt(jwt, this, savePassRequestCode)
                        } catch (_: RuntimeException) {
                            pendingSaveResult = null
                            result.error("unavailable", "Google Wallet is unavailable.", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Android SDK; required by the Google Wallet PayClient callback API.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != savePassRequestCode) return
        val callback = pendingSaveResult ?: return
        pendingSaveResult = null
        when (resultCode) {
            Activity.RESULT_OK -> callback.success(true)
            Activity.RESULT_CANCELED -> callback.error(
                "cancelled",
                "Google Wallet save was cancelled.",
                null,
            )
            PayClient.SavePassesResult.API_UNAVAILABLE -> callback.error(
                "unavailable",
                "Google Wallet is unavailable.",
                null,
            )
            PayClient.SavePassesResult.INTERNAL_ERROR -> callback.error(
                "internal_error",
                "Google Wallet could not complete the save.",
                null,
            )
            PayClient.SavePassesResult.SAVE_ERROR -> callback.error(
                "save_error",
                "Google Wallet rejected the pass.",
                null,
            )
            else -> callback.error(
                "unknown_result",
                "Google Wallet returned an unexpected result.",
                null,
            )
        }
    }

    override fun onDestroy() {
        pendingSaveResult?.error(
            "cancelled",
            "Google Wallet save was interrupted.",
            null,
        )
        pendingSaveResult = null
        super.onDestroy()
    }
}
