package cd.ikanisa.as_vita

import com.africlub.recovery.NativeCheckoutRecoveryPlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!flutterEngine.plugins.has(NativeCheckoutRecoveryPlugin::class.java)) {
            flutterEngine.plugins.add(NativeCheckoutRecoveryPlugin(enabled = true))
        }
    }
}
