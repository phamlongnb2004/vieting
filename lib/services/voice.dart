import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Nhận giọng nói tiếng Việt (Android / iOS) để nhập nhanh "ăn phở 45k".
class Voice {
  static final SpeechToText _stt = SpeechToText();
  static bool _ready = false;

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<bool> init() async {
    if (!supported) return false;
    if (_ready) return true;
    try {
      _ready = await _stt.initialize();
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  static bool get listening => _stt.isListening;

  /// Bắt đầu nghe; [onText] nhận chữ tạm thời, [onDone] nhận câu cuối cùng.
  static Future<bool> listen({required void Function(String) onText, required void Function(String) onDone}) async {
    if (!await init()) return false;
    var locale = 'vi_VN';
    try {
      final locales = await _stt.locales();
      final vi = locales.where((l) => l.localeId.toLowerCase().startsWith('vi'));
      if (vi.isNotEmpty) locale = vi.first.localeId;
    } catch (_) {}
    await _stt.listen(
      localeId: locale,
      onResult: (r) {
        onText(r.recognizedWords);
        if (r.finalResult) onDone(r.recognizedWords);
      },
    );
    return true;
  }

  static Future<void> stop() async {
    if (_ready) await _stt.stop();
  }
}
