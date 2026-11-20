package vn.thlong.vieting

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity: cần cho mở khóa vân tay (local_auth)
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vieting/notify")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> result.success(NoticeQueue.isListenerEnabled(this))
                "drain" -> result.success(NoticeQueue.drain(this))
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                "openAppDetails" -> {
                    val i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        // Có thông báo mới khi app đang mở -> báo Dart lấy hàng đợi ngay
        NoticeQueue.onNew = { runOnUiThread { channel?.invokeMethod("onNotice", null) } }
    }

    override fun onDestroy() {
        NoticeQueue.onNew = null
        channel = null
        super.onDestroy()
    }
}
