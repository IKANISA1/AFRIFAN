package rw.gikundiro.app

import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val nfcHceChannel = "africlub/BioPay_nfc_hce"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nfcHceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> {
                        result.success(isNfcHceSupported())
                    }
                    "isPaymentRequestActive" -> {
                        result.success(isPaymentRequestActive())
                    }
                    "getPaymentRequestUri" -> {
                        result.success(getPaymentRequestUri())
                    }
                    "startPaymentRequest" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.error("invalid_uri", "uri is required", null)
                        } else {
                            val prefs = getSharedPreferences(
                                BioPayNfcHostApduService.PREFS_NAME,
                                MODE_PRIVATE
                            )
                            prefs.edit()
                                .putString(BioPayNfcHostApduService.KEY_URI, uri)
                                .putBoolean(BioPayNfcHostApduService.KEY_ENABLED, true)
                                .apply()
                            result.success(null)
                        }
                    }
                    "stopPaymentRequest" -> {
                        val prefs = getSharedPreferences(
                            BioPayNfcHostApduService.PREFS_NAME,
                            MODE_PRIVATE
                        )
                        prefs.edit()
                            .putBoolean(BioPayNfcHostApduService.KEY_ENABLED, false)
                            .remove(BioPayNfcHostApduService.KEY_URI)
                            .apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isNfcHceSupported(): Boolean {
        return NfcAdapter.getDefaultAdapter(this) != null &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)
    }

    private fun isPaymentRequestActive(): Boolean {
        val prefs = getSharedPreferences(BioPayNfcHostApduService.PREFS_NAME, MODE_PRIVATE)
        return prefs.getBoolean(BioPayNfcHostApduService.KEY_ENABLED, false) &&
            !prefs.getString(BioPayNfcHostApduService.KEY_URI, null).isNullOrBlank()
    }

    private fun getPaymentRequestUri(): String? {
        if (!isPaymentRequestActive()) {
            return null
        }
        val prefs = getSharedPreferences(BioPayNfcHostApduService.PREFS_NAME, MODE_PRIVATE)
        return prefs.getString(BioPayNfcHostApduService.KEY_URI, null)
    }
}
