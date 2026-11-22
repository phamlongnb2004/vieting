package vn.thlong.vieting

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
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
                "schedule" -> {
                    Reminders.schedule(this, call.argument<String>("items") ?: "[]")
                    result.success(true)
                }
                "setServer" -> {
                    Reminders.setServer(this, call.argument<String>("url") ?: "", call.argument<String>("token") ?: "")
                    result.success(true)
                }
                "askNotifyPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7301)
                    }
                    result.success(true)
                }
                "updateWidget" -> {
                    VietingWidget.save(
                        this,
                        call.argument<String>("label") ?: "",
                        call.argument<String>("amount") ?: "",
                        call.argument<String>("line") ?: "",
                        call.argument<Boolean>("over") ?: false
                    )
                    result.success(true)
                }
                "testNotify" -> {
                    Reminders.show(this, 700001, call.argument<String>("title") ?: "VieTing", call.argument<String>("body") ?: "", Reminders.CH_REMIND)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        // Có thông báo mới khi app đang mở -> báo Dart lấy hàng đợi ngay
        NoticeQueue.onNew = { runOnUiThread { channel?.invokeMethod("onNotice", null) } }
        Reminders.ensureChannels(this)
        Reminders.startPolling(this)
    }

    override fun onDestroy() {
        NoticeQueue.onNew = null
        channel = null
        super.onDestroy()
    }
}
