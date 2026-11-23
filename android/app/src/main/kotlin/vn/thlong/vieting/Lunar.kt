package vn.thlong.vieting

import kotlin.math.PI
import kotlin.math.floor
import kotlin.math.sin

/** Âm lịch Việt Nam (múi giờ +7), thuật toán Hồ Ngọc Đức. Tác giả: Phạm Thành Long (thlong) */
object Lunar {
    data class LDate(val day: Int, val month: Int, val year: Int, val leap: Boolean, val jd: Int)

    private val CAN = arrayOf("Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý")
    private val CHI = arrayOf("Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi")

    private fun i(d: Double) = floor(d).toInt()

    fun jdFromDate(dd: Int, mm: Int, yy: Int): Int {
        val a = i((14 - mm) / 12.0)
        val y = yy + 4800 - a
        val m = mm + 12 * a - 3
        var jd = dd + i((153 * m + 2) / 5.0) + 365 * y + i(y / 4.0) - i(y / 100.0) + i(y / 400.0) - 32045
        if (jd < 2299161) jd = dd + i((153 * m + 2) / 5.0) + 365 * y + i(y / 4.0) - 32083
        return jd
    }

    private fun newMoon(k: Int, tz: Double): Int {
        val t = k / 1236.85
        val t2 = t * t
        val t3 = t2 * t
        val dr = PI / 180
        var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3
        jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr)
        val m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3
        val mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3
        val f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3
        var c1 = (0.1734 - 0.000393 * t) * sin(m * dr) + 0.0021 * sin(2 * dr * m)
        c1 = c1 - 0.4068 * sin(mpr * dr) + 0.0161 * sin(dr * 2 * mpr)
        c1 -= 0.0004 * sin(dr * 3 * mpr)
        c1 = c1 + 0.0104 * sin(dr * 2 * f) - 0.0051 * sin(dr * (m + mpr))
        c1 = c1 - 0.0074 * sin(dr * (m - mpr)) + 0.0004 * sin(dr * (2 * f + m))
        c1 = c1 - 0.0004 * sin(dr * (2 * f - m)) - 0.0006 * sin(dr * (2 * f + mpr))
        c1 = c1 + 0.0010 * sin(dr * (2 * f - mpr)) + 0.0005 * sin(dr * (2 * mpr + m))
        val dt = if (t < -11) 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
        else -0.000278 + 0.000265 * t + 0.000262 * t2
        return i(jd1 + c1 - dt + 0.5 + tz / 24)
    }

    private fun sunLong(jdn: Int, tz: Double): Int {
        val t = (jdn - 2451545.5 - tz / 24) / 36525
        val t2 = t * t
        val dr = PI / 180
        val m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2
        val l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2
        var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(dr * m)
        dl = dl + (0.019993 - 0.000101 * t) * sin(dr * 2 * m) + 0.000290 * sin(dr * 3 * m)
        var l = (l0 + dl) * dr
        l -= PI * 2 * i(l / (PI * 2))
        return i(l / PI * 6)
    }

    private fun month11(yy: Int, tz: Double): Int {
        val off = jdFromDate(31, 12, yy) - 2415021
        val k = i(off / 29.530588853)
        var nm = newMoon(k, tz)
        if (sunLong(nm, tz) >= 9) nm = newMoon(k - 1, tz)
        return nm
    }

    private fun leapOffset(a11: Int, tz: Double): Int {
        val k = i((a11 - 2415021.076998695) / 29.530588853 + 0.5)
        var last: Int
        var n = 1
        var arc = sunLong(newMoon(k + n, tz), tz)
        do {
            last = arc
            n++
            arc = sunLong(newMoon(k + n, tz), tz)
        } while (arc != last && n < 14)
        return n - 1
    }

    fun of(dd: Int, mm: Int, yy: Int, tz: Double = 7.0): LDate {
        val dayNumber = jdFromDate(dd, mm, yy)
        val k = i((dayNumber - 2415021.076998695) / 29.530588853)
        var monthStart = newMoon(k + 1, tz)
        if (monthStart > dayNumber) monthStart = newMoon(k, tz)
        var a11 = month11(yy, tz)
        var b11 = a11
        var lunarYear: Int
        if (a11 >= monthStart) {
            lunarYear = yy
            a11 = month11(yy - 1, tz)
        } else {
            lunarYear = yy + 1
            b11 = month11(yy + 1, tz)
        }
        val lunarDay = dayNumber - monthStart + 1
        val diff = i((monthStart - a11) / 29.0)
        var leap = false
        var lunarMonth = diff + 11
        if (b11 - a11 > 365) {
            val ld = leapOffset(a11, tz)
            if (diff >= ld) {
                lunarMonth = diff + 10
                if (diff == ld) leap = true
            }
        }
        if (lunarMonth > 12) lunarMonth -= 12
        if (lunarMonth >= 11 && diff < 4) lunarYear -= 1
        return LDate(lunarDay, lunarMonth, lunarYear, leap, dayNumber)
    }

    fun yearName(l: LDate) = "${CAN[(l.year + 6) % 10]} ${CHI[(l.year + 8) % 12]}"
    fun dayName(l: LDate) = "${CAN[(l.jd + 9) % 10]} ${CHI[(l.jd + 1) % 12]}"
    fun dayLabel(l: LDate) = when {
        l.day == 15 -> "Rằm"
        l.day <= 10 -> "Mùng ${l.day}"
        else -> "${l.day}"
    }

    fun holiday(dd: Int, mm: Int, l: LDate, en: Boolean): String? {
        if (!l.leap) {
            val lunar = mapOf(
                "1/1" to ("Tết Nguyên Đán" to "Lunar New Year"), "2/1" to ("Mùng 2 Tết" to "Tet, day 2"),
                "3/1" to ("Mùng 3 Tết" to "Tet, day 3"), "15/1" to ("Rằm tháng Giêng" to "First full moon"),
                "10/3" to ("Giỗ Tổ Hùng Vương" to "Hung Kings' Day"), "15/4" to ("Lễ Phật Đản" to "Buddha's Birthday"),
                "5/5" to ("Tết Đoan Ngọ" to "Doan Ngo Festival"), "15/7" to ("Lễ Vu Lan" to "Vu Lan Festival"),
                "15/8" to ("Tết Trung Thu" to "Mid-Autumn Festival"), "23/12" to ("Ông Công Ông Táo" to "Kitchen Gods' Day")
            )[("${l.day}/${l.month}")]
            if (lunar != null) return if (en) lunar.second else lunar.first
        }
        val solar = mapOf(
            "1/1" to ("Tết Dương lịch" to "New Year's Day"), "14/2" to ("Lễ Tình nhân" to "Valentine's Day"),
            "8/3" to ("Quốc tế Phụ nữ" to "Women's Day"), "30/4" to ("Giải phóng miền Nam" to "Reunification Day"),
            "1/5" to ("Quốc tế Lao động" to "Labour Day"), "1/6" to ("Quốc tế Thiếu nhi" to "Children's Day"),
            "2/9" to ("Quốc khánh" to "National Day"), "20/10" to ("Phụ nữ Việt Nam" to "Vietnamese Women's Day"),
            "20/11" to ("Nhà giáo Việt Nam" to "Teachers' Day"), "24/12" to ("Đêm Giáng sinh" to "Christmas Eve"),
            "25/12" to ("Giáng sinh" to "Christmas")
        )["$dd/$mm"] ?: return null
        return if (en) solar.second else solar.first
    }
}
