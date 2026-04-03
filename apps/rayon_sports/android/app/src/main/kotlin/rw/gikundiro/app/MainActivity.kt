package rw.gikundiro.app

import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val nfcHceChannel = "africlub/biopay_nfc_hce"

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
                                BiopayNfcHostApduService.PREFS_NAME,
                                MODE_PRIVATE
                            )
                            prefs.edit()
                                .putString(BiopayNfcHostApduService.KEY_URI, uri)
                                .putBoolean(BiopayNfcHostApduService.KEY_ENABLED, true)
                                .apply()
                            result.success(null)
                        }
                    }
                    "stopPaymentRequest" -> {
                        val prefs = getSharedPreferences(
                            BiopayNfcHostApduService.PREFS_NAME,
                            MODE_PRIVATE
                        )
                        prefs.edit()
                            .putBoolean(BiopayNfcHostApduService.KEY_ENABLED, false)
                            .remove(BiopayNfcHostApduService.KEY_URI)
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
        val prefs = getSharedPreferences(BiopayNfcHostApduService.PREFS_NAME, MODE_PRIVATE)
        return prefs.getBoolean(BiopayNfcHostApduService.KEY_ENABLED, false) &&
            !prefs.getString(BiopayNfcHostApduService.KEY_URI, null).isNullOrBlank()
    }

    private fun getPaymentRequestUri(): String? {
        if (!isPaymentRequestActive()) {
            return null
        }
        val prefs = getSharedPreferences(BiopayNfcHostApduService.PREFS_NAME, MODE_PRIVATE)
        return prefs.getString(BiopayNfcHostApduService.KEY_URI, null)
    }
}
