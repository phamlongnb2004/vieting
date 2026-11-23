package vn.thlong.vieting

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

/** Widget "Lịch VieTing": âm dương lịch, ngày lễ, chi tiêu hôm nay, thời tiết. Tự đổi ngày lúc nửa đêm. */
class CalendarWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) mgr.updateAppWidget(id, views(ctx, mgr, id))
        scheduleMidnight(ctx)
    }

    override fun onAppWidgetOptionsChanged(ctx: Context, mgr: AppWidgetManager, id: Int, o: Bundle) {
        mgr.updateAppWidget(id, views(ctx, mgr, id))
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        super.onReceive(ctx, intent)
        if (intent.action == ACTION_TICK || intent.action == Intent.ACTION_DATE_CHANGED || intent.action == Intent.ACTION_TIME_CHANGED) {
            refreshAll(ctx)
            scheduleMidnight(ctx)
        }
    }

    companion object {
        const val ACTION_TICK = "vn.thlong.vieting.CAL_TICK"

        fun refreshAll(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            for (id in mgr.getAppWidgetIds(ComponentName(ctx, CalendarWidget::class.java))) mgr.updateAppWidget(id, views(ctx, mgr, id))
        }

        private fun scheduleMidnight(ctx: Context) {
            val c = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 30)
            }
            val pi = PendingIntent.getBroadcast(
                ctx, 811, Intent(ctx, CalendarWidget::class.java).setAction(ACTION_TICK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            (ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager).set(AlarmManager.RTC, c.timeInMillis, pi)
        }

        private fun views(ctx: Context, mgr: AppWidgetManager, id: Int): RemoteViews {
            val p = ctx.getSharedPreferences(WidgetArt.PREFS, Context.MODE_PRIVATE)
            val en = p.getString("lang", "vi") == "en"
            val v = RemoteViews(ctx.packageName, R.layout.calendar_widget)
            val (w, h) = WidgetArt.size(ctx, mgr, id, 180, 110)
            val look = WidgetArt.look(ctx, w, h)
            v.setInt(R.id.c_root, "setBackgroundResource", 0)
            v.setImageViewBitmap(R.id.c_bg, look.bg)
            v.setTextViewText(R.id.c_brand, VietingWidget.brand(look.text, look.accent))

            val c = Calendar.getInstance()
            val d = c.get(Calendar.DAY_OF_MONTH)
            val m = c.get(Calendar.MONTH) + 1
            val y = c.get(Calendar.YEAR)
            val l = Lunar.of(d, m, y)
            v.setTextViewText(R.id.c_month, if (en) "${arrayOf("JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC")[m - 1]} $y" else "THÁNG $m · $y")
            v.setTextColor(R.id.c_month, look.accent)
            v.setTextViewText(R.id.c_day, "$d")
            v.setTextColor(R.id.c_day, look.text)
            val wd = c.get(Calendar.DAY_OF_WEEK) - 1
            v.setTextViewText(R.id.c_wday, if (en) arrayOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")[wd]
            else arrayOf("Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy")[wd])
            v.setTextColor(R.id.c_wday, look.text)
            val leap = if (l.leap) (if (en) " (leap)" else " nhuận") else ""
            v.setTextViewText(R.id.c_lunar, if (en) "Lunar ${l.day}/${l.month}$leap" else "Âm: ${Lunar.dayLabel(l)} tháng ${l.month}$leap")
            v.setTextColor(R.id.c_lunar, look.text)
            v.setTextViewText(R.id.c_can, if (en) "${Lunar.dayName(l)} day · ${Lunar.yearName(l)} year" else "Ngày ${Lunar.dayName(l)} · Năm ${Lunar.yearName(l)}")
            v.setTextColor(R.id.c_can, look.sub)
            val hol = Lunar.holiday(d, m, l, en)
            if (hol != null) {
                v.setViewVisibility(R.id.c_holiday, View.VISIBLE)
                v.setTextViewText(R.id.c_holiday, "★ $hol")
            } else v.setViewVisibility(R.id.c_holiday, View.GONE)
            v.setTextViewText(R.id.c_spent, p.getString("spent", "") ?: "")
            v.setTextColor(R.id.c_spent, look.sub)
            v.setTextViewText(R.id.c_weather, p.getString("weather", "") ?: "")
            v.setTextColor(R.id.c_weather, look.text)
            VietingWidget.openApp(ctx, v, R.id.c_root, "vieting://calendar", 812)
            return v
        }
    }
}
