package vn.thlong.vieting

import android.app.Notification
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Nhận mọi thông báo hiện trên máy, chỉ giữ những thông báo có dấu hiệu tiền (VND, đ, số dư...)
 * vào hàng đợi. App Flutter lấy hàng đợi ra để đọc số tiền và ghi giao dịch.
 * Hàng đợi lưu trong SharedPreferences nên app tắt vẫn không mất thông báo.
 */
class BankNotificationService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        try {
            val pkg = sbn.packageName ?: return
            if (pkg == packageName) return
            val n = sbn.notification ?: return
            if ((n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
            if ((n.flags and Notification.FLAG_ONGOING_EVENT) != 0) return
            val ex = n.extras ?: return

            val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val text = ex.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val big = ex.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
            val lines = ex.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.joinToString("\n") ?: ""
            val body = listOf(text, big, lines).maxByOrNull { it.length } ?: ""
            if (body.isBlank()) return
            if (!MONEY.containsMatchIn(("$title $body").lowercase())) return

            val appName = try {
                val pm = applicationContext.packageManager
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            } catch (e: Exception) {
                pkg
            }
            val time = if (sbn.postTime > 0) sbn.postTime else System.currentTimeMillis()
            NoticeQueue.push(applicationContext, pkg, appName, title, body, time)
        } catch (e: Exception) {
            // không để lỗi một thông báo làm dừng dịch vụ
        }
    }

    companion object {
        private val MONEY = Regex("""\d[\d.,]*\s*(vnd|vnđ|đ|₫)|số dư|so du|\bsd\b|biến động|bien dong|[+-]\s?\d{1,3}([.,]\d{3})+""")
    }
}

object NoticeQueue {
    private const val PREFS = "vieting_notice_queue"
    private const val KEY = "items"
    private const val KEY_RECENT = "recent"
    private val lock = Any()

    @Volatile
    var onNew: (() -> Unit)? = null

    fun isListenerEnabled(ctx: Context): Boolean {
        val flat = Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners") ?: return false
        return flat.split(":").any { it.startsWith(ctx.packageName + "/") || it == ctx.packageName }
    }

    fun push(ctx: Context, pkg: String, app: String, title: String, text: String, time: Long) {
        synchronized(lock) {
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            // app ngân hàng hay cập nhật lại cùng một thông báo -> bỏ bản lặp
            val sig = (pkg + "|" + title + "|" + text).hashCode().toString()
            val recent = JSONArray(prefs.getString(KEY_RECENT, "[]"))
            for (i in 0 until recent.length()) if (recent.optString(i) == sig) return
            recent.put(sig)
            while (recent.length() > 60) recent.remove(0)

            val arr = JSONArray(prefs.getString(KEY, "[]"))
            arr.put(JSONObject().apply {
                put("pkg", pkg)
                put("app", app)
                put("title", title)
                put("text", text)
                put("time", time)
            })
            while (arr.length() > 500) arr.remove(0)
            prefs.edit().putString(KEY, arr.toString()).putString(KEY_RECENT, recent.toString()).apply()
        }
        onNew?.invoke()
    }

    fun drain(ctx: Context): String {
        synchronized(lock) {
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val s = prefs.getString(KEY, "[]") ?: "[]"
            prefs.edit().putString(KEY, "[]").apply()
            return s
        }
    }
}
