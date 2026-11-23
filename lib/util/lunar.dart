// Đổi ngày dương sang âm lịch Việt Nam (múi giờ +7), theo thuật toán của Hồ Ngọc Đức.
// Tác giả: Phạm Thành Long (thlong)
import 'dart:math' as m;

class LunarDate {
  final int day;
  final int month;
  final int year;
  final bool leap;
  final int jd;
  const LunarDate(this.day, this.month, this.year, this.leap, this.jd);

  static const can = ['Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý'];
  static const chi = ['Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ', 'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi'];

  String get yearName => '${can[(year + 6) % 10]} ${chi[(year + 8) % 12]}';
  String get monthName => '${can[(year * 12 + month + 3) % 10]} ${chi[(month + 1) % 12]}';
  String get dayName => '${can[(jd + 9) % 10]} ${chi[(jd + 1) % 12]}';

  /// "Mùng 4" / "Rằm" / "23"
  String get dayLabel => day == 15 ? 'Rằm' : (day <= 10 ? 'Mùng $day' : '$day');
  String get short => day == 1 ? '1/$month${leap ? 'N' : ''}' : '$day';
}

int _int(double d) => d.floor();

int jdFromDate(int dd, int mm, int yy) {
  final a = _int((14 - mm) / 12);
  final y = yy + 4800 - a;
  final mo = mm + 12 * a - 3;
  var jd = dd + _int((153 * mo + 2) / 5) + 365 * y + _int(y / 4) - _int(y / 100) + _int(y / 400) - 32045;
  if (jd < 2299161) jd = dd + _int((153 * mo + 2) / 5) + 365 * y + _int(y / 4) - 32083;
  return jd;
}

int _newMoonDay(int k, double tz) {
  final t = k / 1236.85;
  final t2 = t * t, t3 = t2 * t;
  const dr = m.pi / 180;
  var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
  jd1 += 0.00033 * m.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
  final mm = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
  final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
  final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
  var c1 = (0.1734 - 0.000393 * t) * m.sin(mm * dr) + 0.0021 * m.sin(2 * dr * mm);
  c1 = c1 - 0.4068 * m.sin(mpr * dr) + 0.0161 * m.sin(dr * 2 * mpr);
  c1 = c1 - 0.0004 * m.sin(dr * 3 * mpr);
  c1 = c1 + 0.0104 * m.sin(dr * 2 * f) - 0.0051 * m.sin(dr * (mm + mpr));
  c1 = c1 - 0.0074 * m.sin(dr * (mm - mpr)) + 0.0004 * m.sin(dr * (2 * f + mm));
  c1 = c1 - 0.0004 * m.sin(dr * (2 * f - mm)) - 0.0006 * m.sin(dr * (2 * f + mpr));
  c1 = c1 + 0.0010 * m.sin(dr * (2 * f - mpr)) + 0.0005 * m.sin(dr * (2 * mpr + mm));
  final deltat = t < -11 ? 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3 : -0.000278 + 0.000265 * t + 0.000262 * t2;
  final jdNew = jd1 + c1 - deltat;
  return _int(jdNew + 0.5 + tz / 24);
}

int _sunLongitude(int jdn, double tz) {
  final t = (jdn - 2451545.5 - tz / 24) / 36525;
  final t2 = t * t;
  const dr = m.pi / 180;
  final mm = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
  final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
  var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * m.sin(dr * mm);
  dl = dl + (0.019993 - 0.000101 * t) * m.sin(dr * 2 * mm) + 0.000290 * m.sin(dr * 3 * mm);
  var l = (l0 + dl) * dr;
  l = l - m.pi * 2 * _int(l / (m.pi * 2));
  return _int(l / m.pi * 6);
}

int _lunarMonth11(int yy, double tz) {
  final off = jdFromDate(31, 12, yy) - 2415021;
  final k = _int(off / 29.530588853);
  var nm = _newMoonDay(k, tz);
  if (_sunLongitude(nm, tz) >= 9) nm = _newMoonDay(k - 1, tz);
  return nm;
}

int _leapMonthOffset(int a11, double tz) {
  final k = _int((a11 - 2415021.076998695) / 29.530588853 + 0.5);
  var last = 0;
  var i = 1;
  var arc = _sunLongitude(_newMoonDay(k + i, tz), tz);
  do {
    last = arc;
    i++;
    arc = _sunLongitude(_newMoonDay(k + i, tz), tz);
  } while (arc != last && i < 14);
  return i - 1;
}

final Map<int, LunarDate> _cache = {};

LunarDate toLunar(DateTime d, {double tz = 7}) {
  final dayNumber = jdFromDate(d.day, d.month, d.year);
  final hit = _cache[dayNumber];
  if (hit != null) return hit;
  final k = _int((dayNumber - 2415021.076998695) / 29.530588853);
  var monthStart = _newMoonDay(k + 1, tz);
  if (monthStart > dayNumber) monthStart = _newMoonDay(k, tz);
  var a11 = _lunarMonth11(d.year, tz);
  var b11 = a11;
  int lunarYear;
  if (a11 >= monthStart) {
    lunarYear = d.year;
    a11 = _lunarMonth11(d.year - 1, tz);
  } else {
    lunarYear = d.year + 1;
    b11 = _lunarMonth11(d.year + 1, tz);
  }
  final lunarDay = dayNumber - monthStart + 1;
  final diff = _int((monthStart - a11) / 29);
  var leap = false;
  var lunarMonth = diff + 11;
  if (b11 - a11 > 365) {
    final leapDiff = _leapMonthOffset(a11, tz);
    if (diff >= leapDiff) {
      lunarMonth = diff + 10;
      if (diff == leapDiff) leap = true;
    }
  }
  if (lunarMonth > 12) lunarMonth -= 12;
  if (lunarMonth >= 11 && diff < 4) lunarYear -= 1;
  final r = LunarDate(lunarDay, lunarMonth, lunarYear, leap, dayNumber);
  if (_cache.length > 2000) _cache.clear();
  _cache[dayNumber] = r;
  return r;
}

/// Ngày lễ / dịp đáng nhớ (dương lịch và âm lịch). Trả về tên hoặc null.
String? holidayOf(DateTime d, [LunarDate? l]) {
  const solar = {
    '1/1': 'Tết Dương lịch',
    '14/2': 'Lễ Tình nhân',
    '8/3': 'Quốc tế Phụ nữ',
    '30/4': 'Ngày Giải phóng miền Nam',
    '1/5': 'Quốc tế Lao động',
    '1/6': 'Quốc tế Thiếu nhi',
    '2/9': 'Quốc khánh',
    '20/10': 'Phụ nữ Việt Nam',
    '20/11': 'Nhà giáo Việt Nam',
    '24/12': 'Đêm Giáng sinh',
    '25/12': 'Giáng sinh',
  };
  l ??= toLunar(d);
  if (!l.leap) {
    const lunar = {
      '1/1': 'Tết Nguyên Đán',
      '2/1': 'Mùng 2 Tết',
      '3/1': 'Mùng 3 Tết',
      '15/1': 'Rằm tháng Giêng',
      '10/3': 'Giỗ Tổ Hùng Vương',
      '15/4': 'Lễ Phật Đản',
      '5/5': 'Tết Đoan Ngọ',
      '15/7': 'Lễ Vu Lan',
      '15/8': 'Tết Trung Thu',
      '23/12': 'Ông Công Ông Táo',
    };
    final x = lunar['${l.day}/${l.month}'];
    if (x != null) return x;
    // đêm Giao thừa: ngày cuối cùng của tháng Chạp
    if (l.month == 12 && toLunar(d.add(const Duration(days: 1))).day == 1) return 'Giao thừa';
  }
  return solar['${d.day}/${d.month}'];
}
