// Song ngữ Việt / Anh cho VieTing.
//
// Cách làm: các màn hình viết chữ tiếng Việt như bình thường. File này thay
// widget Text và InputDecoration của Flutter bằng bản tự dịch khi app đang ở
// tiếng Anh (import material.dart kèm `hide Text, InputDecoration`).
// Chuỗi có phần thay đổi (số tiền, tên…) được khớp theo mẫu {0} {1} trong
// i18n_en.dart; phần thay đổi cũng được dịch tiếp nếu có trong từ điển.
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';

import 'i18n_en.dart';

/// Ngôn ngữ đang hiển thị: 'vi' hoặc 'en'.
String appLang = 'vi';

/// Cài đặt người dùng chọn: 'auto' (theo máy), 'vi', 'en'.
String resolveLang(String pref) {
  if (pref == 'vi' || pref == 'en') return pref;
  final code = PlatformDispatcher.instance.locale.languageCode;
  return code == 'vi' ? 'vi' : 'en';
}

void setAppLang(String pref) {
  final l = resolveLang(pref);
  if (l != appLang) _cache.clear();
  appLang = l;
}

bool get isEn => appLang == 'en';

class _Pat {
  final RegExp re;
  final String out;
  final List<String> names;
  _Pat(this.re, this.out, this.names);
}

final Map<String, String> _cache = {};
List<_Pat>? _pats;
final _ph = RegExp(r'\{([A-Za-z0-9_]+)\}');
final _nonAscii = RegExp(r'[^\x00-\x7F]');

List<_Pat> _build() {
  final list = <_Pat>[];
  kEn.forEach((k, v) {
    if (!_ph.hasMatch(k)) return;
    final lit = k.replaceAll(_ph, '');
    if (!RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(lit)) return; // mẫu chỉ toàn {0}{1} thì bỏ, khớp bừa
    final names = <String>[];
    final b = StringBuffer('^');
    var last = 0;
    for (final mm in _ph.allMatches(k)) {
      b.write(RegExp.escape(k.substring(last, mm.start)));
      names.add(mm.group(1)!);
      b.write('(.+?)');
      last = mm.end;
    }
    b.write(RegExp.escape(k.substring(last)));
    b.write(r'$');
    list.add(_Pat(RegExp(b.toString(), dotAll: true), v, names));
  });
  // mẫu dài (nhiều chữ cố định) thử trước để khớp chính xác hơn
  list.sort((a, b) => b.re.pattern.length.compareTo(a.re.pattern.length));
  return list;
}

/// Dịch một chuỗi tiếng Việt sang ngôn ngữ đang chọn.
String tr(String s) => _tr(s, 0);

String _tr(String s, int depth) {
  if (appLang != 'en' || s.isEmpty) return s;
  final hit = _cache[s];
  if (hit != null) return hit;
  var r = kEn[s];
  if (r == null && depth < 3 && _nonAscii.hasMatch(s)) {
    // giữ khoảng trắng / xuống dòng ở hai đầu
    final t = s.trim();
    if (t != s && t.isNotEmpty) {
      final x = _tr(t, depth + 1);
      if (x != t) r = s.replaceFirst(t, x);
    }
    if (r == null) {
      for (final p in (_pats ??= _build())) {
        final mm = p.re.firstMatch(s);
        if (mm == null) continue;
        var out = p.out;
        for (var i = 0; i < p.names.length; i++) {
          out = out.replaceAll('{${p.names[i]}}', _tr(mm.group(i + 1) ?? '', depth + 1));
        }
        r = out;
        break;
      }
    }
  }
  r ??= s;
  if (_cache.length > 4000) _cache.clear();
  _cache[s] = r;
  return r;
}

String? trn(String? s) => s == null ? null : tr(s);

/// Báo cho cây widget biết ngôn ngữ đã đổi để mọi Text (kể cả const) vẽ lại.
class LangScope extends InheritedWidget {
  final String lang;
  const LangScope({super.key, required this.lang, required super.child});
  static void watch(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LangScope>();
  @override
  bool updateShouldNotify(LangScope old) => old.lang != lang;
}

InlineSpan _span(InlineSpan s) {
  if (s is! TextSpan) return s;
  return TextSpan(
    text: s.text == null ? null : tr(s.text!),
    children: s.children?.map(_span).toList(),
    style: s.style,
    recognizer: s.recognizer,
    mouseCursor: s.mouseCursor,
    onEnter: s.onEnter,
    onExit: s.onExit,
    semanticsLabel: s.semanticsLabel,
    locale: s.locale,
    spellOut: s.spellOut,
  );
}

/// Text tự dịch. Dùng y như Text của Flutter.
class Text extends StatelessWidget {
  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  @override
  Widget build(BuildContext context) {
    LangScope.watch(context);
    if (textSpan != null) {
      return m.Text.rich(
        appLang == 'en' ? _span(textSpan!) : textSpan!,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return m.Text(
      tr(data!),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

/// InputDecoration tự dịch nhãn, gợi ý, chữ phụ.
class InputDecoration extends m.InputDecoration {
  const InputDecoration({
    super.icon,
    super.label,
    super.labelText,
    super.labelStyle,
    super.helperText,
    super.helperStyle,
    super.hintText,
    super.hintStyle,
    super.hintMaxLines,
    super.errorText,
    super.errorStyle,
    super.isDense,
    super.contentPadding,
    super.prefixIcon,
    super.prefix,
    super.prefixText,
    super.prefixStyle,
    super.suffixIcon,
    super.suffix,
    super.suffixText,
    super.suffixStyle,
    super.counterText,
    super.filled,
    super.fillColor,
    super.border,
    super.enabledBorder,
    super.focusedBorder,
    super.enabled,
    super.alignLabelWithHint,
  });

  @override
  String? get labelText => trn(super.labelText);
  @override
  String? get helperText => trn(super.helperText);
  @override
  String? get hintText => trn(super.hintText);
  @override
  String? get prefixText => trn(super.prefixText);
  @override
  String? get suffixText => trn(super.suffixText);
  @override
  String? get errorText => trn(super.errorText);
}
