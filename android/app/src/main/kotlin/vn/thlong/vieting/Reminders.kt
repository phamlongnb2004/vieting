package vn.thlong.vieting

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Thông báo hiện trên máy kể cả khi không mở app (Android):
 *  - Nhắc nhở hẹn giờ (ghi chi tiêu, khoản định kỳ sắp trừ tiền, món chờ mua đủ 48h, quay lại sau vài ngày...):
 *    app tính lịch rồi giao cho AlarmManager. Danh sách lưu lại để đặt lại sau khi khởi động máy.
 *  - Tin admin gửi cho mọi người + phản hồi góp ý: cứ khoảng 30 phút máy hỏi server một lần.
 * Không cần Firebase.
 */
object Reminders {
    private const val PREFS = "vieting_reminders"
    const val CH_REMIND = "nhac_nho"
    const val CH_NEWS = "tin_tu_vieting"
    const val ACTION_SHOW = "vn.thlong.vieting.SHOW_REMINDER"
    const val ACTION_POLL = "vn.thlong.vieting.POLL"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(NotificationChannel(CH_REMIND, "Nhắc nhở chi tiêu", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Nhắc ghi chi tiêu, khoản định kỳ sắp trừ tiền, món chờ mua..."
        })
        nm.createNotificationChannel(NotificationChannel(CH_NEWS, "Tin từ VieTing", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Thông báo chung và phản hồi góp ý"
        })
    }

    fun show(ctx: Context, id: Int, title: String, body: String, channel: String) {
        ensureChannels(ctx)
        val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pi = open?.let {
            PendingIntent.getActivity(ctx, id, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, channel) else Notification.Builder(ctx)
        b.setSmallIcon(R.drawable.ic_stat_vieting)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setColor(0xFFC1272C.toInt())
        if (pi != null) b.setContentIntent(pi)
        try {
            ctx.getSystemService(NotificationManager::class.java)?.notify(id, b.build())
        } catch (_: SecurityException) {
            // chưa cho phép thông báo (Android 13+)
        }
    }

    private fun alarmIntent(ctx: Context, item: JSONObject): PendingIntent {
        val i = Intent(ctx, ReminderReceiver::class.java).apply {
            action = ACTION_SHOW
            putExtra("id", item.optInt("id"))
            putExtra("title", item.optString("title"))
            putExtra("body", item.optString("body"))
        }
        return PendingIntent.getBroadcast(ctx, item.optInt("id"), i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** Thay toàn bộ lịch nhắc bằng danh sách mới: [{id, title, body, at(ms)}]. */
    fun schedule(ctx: Context, json: String) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        // hủy lịch cũ
        val old = try { JSONArray(prefs(ctx).getString("items", "[]")) } catch (_: Exception) { JSONArray() }
        for (k in 0 until old.length()) {
            val o = old.optJSONObject(k) ?: continue
            am.cancel(alarmIntent(ctx, o))
        }
        val list = try { JSONArray(json) } catch (_: Exception) { JSONArray() }
        prefs(ctx).edit().putString("items", list.toString()).apply()
        arm(ctx, list)
    }

    private fun arm(ctx: Context, list: JSONArray) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        val now = System.currentTimeMillis()
        for (k in 0 until list.length()) {
            val o = list.optJSONObject(k) ?: continue
            val at = o.optLong("at")
            if (at <= now) continue
            // không cần quyền "báo thức chính xác": Android có thể lệch vài phút để tiết kiệm pin
            if (Build.VERSION.SDK_INT >= 23) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarmIntent(ctx, o))
            } else {
                am.set(AlarmManager.RTC_WAKEUP, at, alarmIntent(ctx, o))
            }
        }
    }

    fun rearm(ctx: Context) {
        val list = try { JSONArray(prefs(ctx).getString("items", "[]")) } catch (_: Exception) { JSONArray() }
        arm(ctx, list)
        startPolling(ctx)
    }

    fun setServer(ctx: Context, url: String, token: String) {
        prefs(ctx).edit().putString("server", url.trimEnd('/')).putString("token", token).apply()
        startPolling(ctx)
    }

    fun startPolling(ctx: Context) {
        if (prefs(ctx).getString("server", "").isNullOrEmpty()) return
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        val i = Intent(ctx, ReminderReceiver::class.java).apply { action = ACTION_POLL }
        val pi = PendingIntent.getBroadcast(ctx, 990001, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        am.setInexactRepeating(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + AlarmManager.INTERVAL_FIFTEEN_MINUTES,
            AlarmManager.INTERVAL_HALF_HOUR,
            pi
        )
    }

    /** Hỏi server có tin mới không (chạy trên luồng nền). */
    fun poll(ctx: Context) {
        val p = prefs(ctx)
        val server = p.getString("server", "") ?: ""
        if (server.isEmpty()) return
        val after = p.getLong("after", -1L)
        val ticketAt = p.getLong("ticketAt", 0L)
        var conn: HttpURLConnection? = null
        try {
            conn = (URL("$server/api/push?after=$after").openConnection() as HttpURLConnection).apply {
                connectTimeout = 10000
                readTimeout = 10000
                val t = p.getString("token", "") ?: ""
                if (t.isNotEmpty()) setRequestProperty("Authorization", "Bearer $t")
            }
            if (conn.responseCode != 200) return
            val j = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            val pushes = j.optJSONArray("pushes") ?: JSONArray()
            var last = after
            for (k in 0 until pushes.length()) {
                val o = pushes.optJSONObject(k) ?: continue
                val id = o.optLong("id")
                // lần đầu chỉ ghi nhớ mốc, không hiện tin cũ
                if (after >= 0) show(ctx, 500000 + (id % 100000).toInt(), o.optString("title"), o.optString("body"), CH_NEWS)
                if (id > last) last = id
            }
            if (after < 0 && last < 0) last = j.optLong("latest", 0L)
            val tAt = j.optLong("ticketAt", 0L)
            if (tAt > ticketAt && ticketAt > 0) {
                show(ctx, 600001, "VieTing đã trả lời góp ý của bạn", "Mở app → Cài đặt → Góp ý & báo lỗi để xem.", CH_NEWS)
            }
            p.edit().putLong("after", last).putLong("ticketAt", if (tAt > 0) tAt else maxOf(ticketAt, 1L)).apply()
        } catch (_: Exception) {
        } finally {
            conn?.disconnect()
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            Reminders.ACTION_SHOW -> Reminders.show(
                ctx,
                intent.getIntExtra("id", 1),
                intent.getStringExtra("title") ?: "VieTing",
                intent.getStringExtra("body") ?: "",
                Reminders.CH_REMIND
            )
            Reminders.ACTION_POLL -> {
                val pending = goAsync()
                Thread {
                    try { Reminders.poll(ctx.applicationContext) } finally { pending.finish() }
                }.start()
            }
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> Reminders.rearm(ctx)
        }
    }
}
