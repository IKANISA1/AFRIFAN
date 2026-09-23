package rw.gikundiro.app

import android.app.Application
import android.util.Log

class RayonSportsApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            val messagingClass = Class.forName("com.google.firebase.messaging.FirebaseMessaging")
            val messaging = messagingClass.getMethod("getInstance").invoke(null)
            messagingClass
                .getMethod("setAutoInitEnabled", java.lang.Boolean.TYPE)
                .invoke(messaging, false)
        } catch (error: ReflectiveOperationException) {
            Log.w("RayonSportsApplication", "FCM auto-init disable skipped.", error)
        } catch (error: RuntimeException) {
            Log.w("RayonSportsApplication", "FCM auto-init disable skipped.", error)
        }
    }
}
