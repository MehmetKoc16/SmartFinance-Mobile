package com.walletmark.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (biyometrik giris) FragmentActivity gerektirir.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Sunucu bildirimleri bu kanalla gonderiyor (FcmPushSender.AndroidChannelId).
        // Kanal yoksa Android bildirimi "Diger" adli genel bir kanala dusurur ve
        // kullanici ayarlarda ne oldugunu anlayamaz.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val kanal = NotificationChannel("genel", "Bildirimler", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Bütçe uyarıları ve hesap bildirimleri"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(kanal)
        }
    }
}
