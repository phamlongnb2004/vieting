import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';

/// Màu thương hiệu VieTing: đỏ cờ, vàng sao, xanh tre, xanh than.
class Brand {
  static const red = Color(0xFFC1272C);
  static const redDeep = Color(0xFF8E1519);
  static const yellow = Color(0xFFFFCD00);
  static const bamboo = Color(0xFF3E8E41);
  static const bambooLight = Color(0xFF8BC34A);
  static const navy = Color(0xFF152758);
  static const cream = Color(0xFFFFF8EC);
  static const income = Color(0xFF2E7D32);
  static const expense = Color(0xFFC1272C);
  static const ink = Color(0xFF1C1B19);

  /// Nền chính của app (sáng / tối)
  static const paper = Color(0xFFF7F3EC);
  static const night = Color(0xFF12110F);

  static const heroGradient = LinearGradient(
    colors: [Color(0xFFD4343A), Brand.red, Color(0xFF7C1216)],
    stops: [0, .45, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> softShadow(Brightness b) => b == Brightness.light
      ? const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 6))]
      : const [];
}

const kFont = 'BeVietnamPro';

ThemeData buildTheme(Brightness b) {
  final light = b == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.red,
    brightness: b,
    primary: light ? Brand.red : const Color(0xFFFF8A80),
    onPrimary: Colors.white,
    secondary: Brand.bamboo,
    tertiary: Brand.yellow,
    surface: light ? Colors.white : const Color(0xFF1D1B18),
    surfaceContainerHighest: light ? const Color(0xFFF0EAE0) : const Color(0xFF2A2723),
    outlineVariant: light ? const Color(0xFFE9E1D4) : const Color(0xFF3A362F),
  );
  final bg = light ? Brand.paper : Brand.night;
  final card = light ? Colors.white : const Color(0xFF1D1B18);
  final base = ThemeData(useMaterial3: true, brightness: b, fontFamily: kFont);
  final text = base.textTheme.apply(
    fontFamily: kFont,
    bodyColor: light ? Brand.ink : const Color(0xFFF1ECE4),
    displayColor: light ? Brand.ink : const Color(0xFFF1ECE4),
  );
  final r16 = BorderRadius.circular(16);

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.3),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.35),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: kFont,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -.4,
        color: light ? Brand.ink : Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: light ? const Color(0xFFEFE8DC) : const Color(0xFF2E2A25)),
      ),
      color: card,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: r16),
      iconColor: light ? Brand.navy : const Color(0xFFDCD5CA),
      titleTextStyle: TextStyle(fontFamily: kFont, fontSize: 15, fontWeight: FontWeight.w600, color: light ? Brand.ink : Colors.white),
      subtitleTextStyle: TextStyle(fontFamily: kFont, fontSize: 13, color: light ? const Color(0xFF6E6A63) : const Color(0xFFA9A398)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : const Color(0xFF24211D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: r16, borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: r16, borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: r16, borderSide: BorderSide(color: scheme.primary, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: r16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: r16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Brand.red,
      foregroundColor: Colors.white,
      elevation: 3,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      extendedTextStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w800),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: card,
      selectedColor: Brand.red.withAlpha(light ? 28 : 60),
      labelStyle: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, color: light ? Brand.ink : Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: light ? Colors.white : const Color(0xFF1A1815),
      surfaceTintColor: Colors.transparent,
      indicatorColor: Brand.red.withAlpha(light ? 26 : 70),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: kFont,
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? Brand.red : (light ? const Color(0xFF7A756D) : const Color(0xFFA9A398)),
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? Brand.red : (light ? const Color(0xFF7A756D) : const Color(0xFFA9A398)),
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: light ? Colors.white : const Color(0xFF1A1815),
      indicatorColor: Brand.red.withAlpha(light ? 26 : 70),
      selectedIconTheme: const IconThemeData(color: Brand.red),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Brand.red,
      unselectedLabelColor: light ? const Color(0xFF7A756D) : const Color(0xFFA9A398),
      indicatorColor: Brand.red,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w800, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: TextStyle(fontFamily: kFont, fontSize: 19, fontWeight: FontWeight.w800, color: light ? Brand.ink : Colors.white),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.navy,
      contentTextStyle: const TextStyle(fontFamily: kFont, color: Colors.white, fontWeight: FontWeight.w500),
      actionTextColor: Brand.yellow,
      closeIconColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: r16),
      insetPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Brand.bamboo : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Brand.bamboo : null),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: Brand.red, linearTrackColor: scheme.surfaceContainerHighest),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: Brand.red.withAlpha(light ? 26 : 70),
        selectedForegroundColor: Brand.red,
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: r16),
      textStyle: TextStyle(fontFamily: kFont, color: light ? Brand.ink : Colors.white),
    ),
    expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
    splashFactory: InkRipple.splashFactory,
  );
}
