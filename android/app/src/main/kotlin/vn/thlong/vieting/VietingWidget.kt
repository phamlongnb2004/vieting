package vn.thlong.vieting

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.widget.RemoteViews
import java.util.Calendar

/** Widget "Chi tiêu hôm nay". App gửi số liệu mới qua MethodChannel "updateWidget". Tác giả: Phạm Thành Long (thlong) */
class VietingWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) mgr.updateAppWidget(id, views(ctx, mgr, id))
    }

    override fun onAppWidgetOptionsChanged(ctx: Context, mgr: AppWidgetManager, id: Int, o: Bundle) {
        mgr.updateAppWidget(id, views(ctx, mgr, id))
    }

    companion object {
        fun save(ctx: Context, data: Map<String, Any?>) {
            val e = ctx.getSharedPreferences(WidgetArt.PREFS, Context.MODE_PRIVATE).edit()
            for ((k, v) in data) when (v) {
                is String -> e.putString(k, v)
                is Boolean -> e.putBoolean(k, v)
                is Number -> e.putFloat(k, v.toFloat())
            }
            e.apply()
            refreshAll(ctx)
        }

        fun refreshAll(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            for (id in mgr.getAppWidgetIds(ComponentName(ctx, VietingWidget::class.java))) mgr.updateAppWidget(id, views(ctx, mgr, id))
            CalendarWidget.refreshAll(ctx)
        }

        fun brand(text: Int, accent: Int): CharSequence {
            val s = SpannableString("VieTing")
            s.setSpan(ForegroundColorSpan(text), 0, 3, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            s.setSpan(ForegroundColorSpan(accent), 3, 7, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            return s
        }

        fun openApp(ctx: Context, v: RemoteViews, viewId: Int, link: String?, req: Int) {
            val intent = if (link != null) Intent(Intent.ACTION_VIEW, Uri.parse(link)).setPackage(ctx.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            else ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return
            v.setOnClickPendingIntent(viewId, PendingIntent.getActivity(ctx, req, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }

        private fun views(ctx: Context, mgr: AppWidgetManager, id: Int): RemoteViews {
            val p = ctx.getSharedPreferences(WidgetArt.PREFS, Context.MODE_PRIVATE)
            val en = p.getString("lang", "vi") == "en"
            val v = RemoteViews(ctx.packageName, R.layout.vieting_widget)
            val (w, h) = WidgetArt.size(ctx, mgr, id, 250, 110)
            val look = WidgetArt.look(ctx, w, h)
            v.setInt(R.id.w_root, "setBackgroundResource", 0)
            v.setImageViewBitmap(R.id.w_bg, look.bg)
            v.setTextViewText(R.id.w_brand, brand(look.text, look.accent))
            val c = Calendar.getInstance()
            val wd = if (en) arrayOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")[c.get(Calendar.DAY_OF_WEEK) - 1]
            else arrayOf("CN", "Th 2", "Th 3", "Th 4", "Th 5", "Th 6", "Th 7")[c.get(Calendar.DAY_OF_WEEK) - 1]
            v.setTextViewText(R.id.w_date, "· $wd ${c.get(Calendar.DAY_OF_MONTH)}/${c.get(Calendar.MONTH) + 1}")
            v.setTextColor(R.id.w_date, look.sub)
            v.setTextViewText(R.id.w_weather, p.getString("weather", "") ?: "")
            v.setTextColor(R.id.w_weather, look.text)
            v.setTextViewText(R.id.w_label, p.getString("label", if (en) "Left to spend today" else "Hôm nay còn được tiêu"))
            v.setTextColor(R.id.w_label, look.sub)
            val over = p.getBoolean("over", false)
            v.setTextViewText(R.id.w_amount, p.getString("amount", "—"))
            v.setTextColor(R.id.w_amount, if (over) (if (look.dark) 0xFFFFCD00.toInt() else 0xFFC1272C.toInt()) else (if (look.dark) look.text else 0xFF3E8E41.toInt()))
            v.setImageViewBitmap(R.id.w_bar, WidgetArt.bar(p.getFloat("pct", 0f), look.dark))
            v.setTextViewText(R.id.w_line, p.getString("line", if (en) "Open VieTing to get started" else "Mở VieTing để bắt đầu"))
            v.setTextColor(R.id.w_line, look.text)
            v.setTextColor(R.id.w_add, if (look.dark) 0xFFC1272C.toInt() else 0xFFFFFFFF.toInt())
            v.setInt(R.id.w_add, "setBackgroundResource", if (look.dark) R.drawable.widget_btn else R.drawable.widget_btn_red)
            openApp(ctx, v, R.id.w_root, null, 801)
            openApp(ctx, v, R.id.w_add, "vieting://add", 802)
            return v
        }
    }
}
