package vn.thlong.vieting

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.*
import kotlin.math.max
import kotlin.math.min

/** Vẽ nền widget theo chủ đề người dùng chọn (màu thương hiệu, ảnh riêng...). Tác giả: Phạm Thành Long (thlong) */
object WidgetArt {
    const val PREFS = "vieting_widget"

    data class Style(val theme: String, val photo: String, val dim: Float)
    data class Look(val bg: Bitmap, val dark: Boolean, val accent: Int, val text: Int, val sub: Int)

    fun style(ctx: Context): Style {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return Style(p.getString("theme", "red") ?: "red", p.getString("photo", "") ?: "", p.getFloat("dim", 0.35f))
    }

    fun saveStyle(ctx: Context, theme: String, photo: String, dim: Float) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("theme", theme).putString("photo", photo).putFloat("dim", dim).apply()
    }

    /** Kích thước thật của widget (px), giới hạn để không vượt bộ nhớ của RemoteViews. */
    fun size(ctx: Context, mgr: AppWidgetManager, id: Int, defW: Int, defH: Int): Pair<Int, Int> {
        val o = mgr.getAppWidgetOptions(id)
        val d = ctx.resources.displayMetrics.density
        var w = (o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, defW).takeIf { it > 0 } ?: defW) * d
        var h = (o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, defH).takeIf { it > 0 } ?: defH) * d
        val s = min(1f, 720f / max(w, h))
        w *= s
        h *= s
        return Pair(max(120, w.toInt()), max(120, h.toInt()))
    }

    private fun grad(c: Canvas, w: Int, h: Int, colors: IntArray) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.shader = LinearGradient(0f, 0f, w.toFloat(), h.toFloat(), colors, null, Shader.TileMode.CLAMP)
        c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), p)
    }

    private fun bamboo(c: Canvas, w: Int, h: Int, color: Int) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        val gap = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = Color.argb(60, 0, 0, 0) }
        val stalkW = w * 0.045f
        val xs = floatArrayOf(w * 0.70f, w * 0.80f, w * 0.90f)
        for ((n, x) in xs.withIndex()) {
            val top = h * (0.05f + 0.12f * n)
            c.drawRoundRect(RectF(x, top, x + stalkW, h * 1.1f), stalkW / 2, stalkW / 2, p)
            var y = top + h * 0.18f
            while (y < h) {
                c.drawRect(x, y, x + stalkW, y + stalkW * 0.18f, gap)
                y += h * 0.2f
            }
        }
    }

    private fun star(c: Canvas, cx: Float, cy: Float, r: Float, color: Int) {
        val path = Path()
        for (k in 0 until 10) {
            val rr = if (k % 2 == 0) r else r * 0.42f
            val a = Math.toRadians((-90 + k * 36).toDouble())
            val x = cx + (rr * Math.cos(a)).toFloat()
            val y = cy + (rr * Math.sin(a)).toFloat()
            if (k == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
        c.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color })
    }

    private fun dots(c: Canvas, w: Int, h: Int) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        val rnd = java.util.Random(7)
        for (k in 0 until 40) {
            p.color = Color.argb(40 + rnd.nextInt(120), 255, 255, 255)
            c.drawCircle(rnd.nextFloat() * w, rnd.nextFloat() * h, 1f + rnd.nextFloat() * 2.2f, p)
        }
    }

    private fun photo(path: String, w: Int, h: Int): Bitmap? = try {
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, o)
        var sample = 1
        while (o.outWidth / (sample * 2) >= w && o.outHeight / (sample * 2) >= h) sample *= 2
        BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
    } catch (e: Throwable) {
        null
    }

    fun look(ctx: Context, w: Int, h: Int): Look {
        val st = style(ctx)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val radius = 26f * ctx.resources.displayMetrics.density * (w / max(w.toFloat(), 1f))
        val clip = Path().apply { addRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), radius, radius, Path.Direction.CW) }
        c.clipPath(clip)
        var dark = true
        var accent = 0xFFFFCD00.toInt()
        when (st.theme) {
            "navy" -> {
                grad(c, w, h, intArrayOf(0xFF2A4A9A.toInt(), 0xFF152758.toInt(), 0xFF0B1533.toInt()))
                dots(c, w, h)
                star(c, w * 0.9f, h * 0.2f, h * 0.08f, 0x55FFCD00)
            }
            "bamboo" -> {
                grad(c, w, h, intArrayOf(0xFF6FAE3B.toInt(), 0xFF3E8E41.toInt(), 0xFF1F5E22.toInt()))
                bamboo(c, w, h, Color.argb(45, 255, 255, 255))
            }
            "sunset" -> {
                grad(c, w, h, intArrayOf(0xFFFFB547.toInt(), 0xFFF26B3A.toInt(), 0xFFC1272C.toInt(), 0xFF5B1A4A.toInt()))
                c.drawCircle(w * 0.85f, h * 0.25f, h * 0.22f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x40FFF3C4 })
            }
            "paper" -> {
                grad(c, w, h, intArrayOf(0xFFFFFDF7.toInt(), 0xFFF7F3EC.toInt()))
                c.drawRect(0f, 0f, w * 0.018f, h.toFloat(), Paint().apply { color = 0xFFC1272C.toInt() })
                bamboo(c, w, h, Color.argb(22, 62, 142, 65))
                dark = false
                accent = 0xFFC1272C.toInt()
            }
            "glass" -> {
                c.drawColor(Color.argb(150, 18, 17, 15))
            }
            "photo" -> {
                val src = if (st.photo.isNotEmpty()) photo(st.photo, w, h) else null
                if (src != null) {
                    val s = max(w / src.width.toFloat(), h / src.height.toFloat())
                    val dw = src.width * s
                    val dh = src.height * s
                    c.drawBitmap(src, null, RectF((w - dw) / 2, (h - dh) / 2, (w + dw) / 2, (h + dh) / 2), Paint(Paint.FILTER_BITMAP_FLAG))
                    src.recycle()
                    c.drawColor(Color.argb((st.dim.coerceIn(0f, 0.85f) * 255).toInt(), 0, 0, 0))
                } else grad(c, w, h, intArrayOf(0xFFD4343A.toInt(), 0xFFC1272C.toInt(), 0xFF7C1216.toInt()))
            }
            else -> { // "red": đỏ cờ, sao vàng, tre
                grad(c, w, h, intArrayOf(0xFFD4343A.toInt(), 0xFFC1272C.toInt(), 0xFF7C1216.toInt()))
                bamboo(c, w, h, Color.argb(30, 255, 255, 255))
                star(c, w * 0.93f, h * 0.17f, h * 0.075f, 0xFFFFCD00.toInt())
            }
        }
        val text = if (dark) Color.WHITE else 0xFF1C1B19.toInt()
        val sub = if (dark) Color.argb(200, 255, 255, 255) else 0xFF6E6A63.toInt()
        return Look(bmp, dark, accent, text, sub)
    }

    /** Thanh tiến độ chi tiêu trong ngày (0..1+), vẽ thành ảnh vì RemoteViews không đổi màu ProgressBar được. */
    fun bar(pct: Float, dark: Boolean): Bitmap {
        val w = 600
        val h = 18
        val b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.color = if (dark) Color.argb(70, 255, 255, 255) else 0xFFEAE2D5.toInt()
        c.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), h / 2f, h / 2f, p)
        val f = pct.coerceIn(0f, 1f)
        if (f > 0f) {
            p.color = when {
                pct > 1f -> if (dark) 0xFFFFFFFF.toInt() else 0xFFC1272C.toInt()
                pct > 0.8f -> 0xFFFF9F1C.toInt()
                else -> if (dark) 0xFFFFCD00.toInt() else 0xFF3E8E41.toInt()
            }
            c.drawRoundRect(RectF(0f, 0f, max(h.toFloat(), w * f), h.toFloat()), h / 2f, h / 2f, p)
        }
        return b
    }
}
