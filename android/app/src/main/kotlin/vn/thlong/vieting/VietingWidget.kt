package vn.thlong.vieting

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/** Widget màn hình chính. App gửi dữ liệu mới mỗi khi số liệu đổi (MethodChannel "updateWidget"). */
class VietingWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) mgr.updateAppWidget(id, views(ctx))
    }

    companion object {
        private const val PREFS = "vieting_widget"

        fun save(ctx: Context, label: String, amount: String, line: String, over: Boolean) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("label", label).putString("amount", amount).putString("line", line).putBoolean("over", over)
                .apply()
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, VietingWidget::class.java))
            for (id in ids) mgr.updateAppWidget(id, views(ctx))
        }

        private fun views(ctx: Context): RemoteViews {
            val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val v = RemoteViews(ctx.packageName, R.layout.vieting_widget)
            v.setTextViewText(R.id.w_label, p.getString("label", "Hôm nay còn được tiêu"))
            v.setTextViewText(R.id.w_amount, p.getString("amount", "—"))
            v.setTextColor(R.id.w_amount, if (p.getBoolean("over", false)) 0xFFC1272C.toInt() else 0xFF3E8E41.toInt())
            v.setTextViewText(R.id.w_line, p.getString("line", "Mở VieTing để bắt đầu"))
            val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            if (open != null) {
                v.setOnClickPendingIntent(
                    R.id.w_root,
                    PendingIntent.getActivity(ctx, 801, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                )
            }
            val add = Intent(Intent.ACTION_VIEW, Uri.parse("vieting://add")).setPackage(ctx.packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            v.setOnClickPendingIntent(
                R.id.w_add,
                PendingIntent.getActivity(ctx, 802, add, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            )
            return v
        }
    }
}
