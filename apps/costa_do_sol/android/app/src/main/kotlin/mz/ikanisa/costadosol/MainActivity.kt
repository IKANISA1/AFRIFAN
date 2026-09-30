package mz.ikanisa.costadosol

import com.africlub.recovery.NativeCheckoutRecoveryPlugin
import com.africlub.identity.NativeIdentityCredentialPlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Dedicated credentials remain disabled until this host has approved scopes.
        if (!flutterEngine.plugins.has(NativeIdentityCredentialPlugin::class.java)) {
            flutterEngine.plugins.add(NativeIdentityCredentialPlugin(enabled = false, approvedScopes = emptySet()))
        }
        if (!flutterEngine.plugins.has(NativeCheckoutRecoveryPlugin::class.java)) {
            flutterEngine.plugins.add(NativeCheckoutRecoveryPlugin(enabled = true))
        }
    }
}
