import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets/logo.dart';

/// Khóa app bằng mã PIN / vân tay / khuôn mặt. Tự khóa lại khi rời app quá 30 giây.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _leftAt ??= DateTime.now();
      final st = StoreScope.read(context);
      if (st.revealHidden) st.setRevealHidden(false);
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null && DateTime.now().difference(left).inSeconds > 30 && mounted) {
        setState(() => _unlocked = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.locked || _unlocked) return widget.child;
    return LockScreen(onUnlock: () => setState(() => _unlocked = true));
  }
}

class Biometric {
  static final _auth = LocalAuthentication();

  static bool get platformOk => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isWindows);

  static Future<bool> available() async {
    if (!platformOk) return false;
    try {
      return await _auth.isDeviceSupported() && (await _auth.canCheckBiometrics || Platform.isWindows);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Mở khóa VieTing',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.onUnlock});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  Future<void> _bio() async {
    final store = StoreScope.read(context);
    if (!store.bioLock || !await Biometric.available()) return;
    if (await Biometric.authenticate()) widget.onUnlock();
  }

  void _press(String d) {
    final store = StoreScope.read(context);
    setState(() {
      _wrong = false;
      if (d == '<') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        return;
      }
      if (_pin.length >= 6) return;
      _pin += d;
    });
    if (_pin.length >= 4 && store.checkPin(_pin)) {
      widget.onUnlock();
    } else if (_pin.length == 6) {
      setState(() {
        _wrong = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    Widget key(String label, {IconData? icon}) => SizedBox(
          width: 76,
          height: 76,
          child: TextButton(
            style: TextButton.styleFrom(shape: const CircleBorder(), backgroundColor: cs.surfaceContainerHighest),
            onPressed: () => label == 'bio' ? _bio() : _press(label),
            child: icon != null ? Icon(icon, size: 28) : Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CoinLogo(size: 64),
            const SizedBox(height: 14),
            const Text('Nhập mã PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 6; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? Brand.red : Colors.transparent,
                    border: Border.all(color: _wrong ? Brand.red : cs.outline, width: 2),
                  ),
                ),
            ]),
            SizedBox(
              height: 28,
              child: _wrong ? const Center(child: Text('Sai mã PIN', style: TextStyle(color: Brand.red))) : null,
            ),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final d in row) Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: key(d)),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: store.bioLock ? key('bio', icon: Icons.fingerprint) : const SizedBox(width: 76),
                ),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: key('0')),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: key('<', icon: Icons.backspace_outlined)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Hộp thoại đặt mã PIN (nhập 2 lần). Trả về mã PIN hoặc null nếu hủy.
Future<String?> askNewPin(BuildContext context) async {
  final a = TextEditingController();
  final b = TextEditingController();
  String? err;
  return showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: const Text('Đặt mã PIN (4–6 số)'),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: a, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Mã PIN')),
            TextField(controller: b, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Nhập lại mã PIN')),
            if (err != null) Text(err!, style: const TextStyle(color: Brand.red)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final p = a.text.trim();
              if (!RegExp(r'^\d{4,6}$').hasMatch(p)) {
                setS(() => err = 'Mã PIN gồm 4–6 chữ số');
              } else if (p != b.text.trim()) {
                setS(() => err = 'Hai lần nhập không khớp');
              } else {
                Navigator.pop(c, p);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
}


/// Mở khóa xem khoản riêng tư: vân tay / khuôn mặt nếu bật, không thì nhập mã PIN.
Future<bool> unlockHidden(BuildContext context) async {
  final store = StoreScope.read(context);
  if (store.bioLock && await Biometric.available()) {
    if (await Biometric.authenticate()) return true;
  }
  if (!store.locked) return true;
  if (!context.mounted) return false;
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nhập mã PIN để xem'),
      content: SizedBox(
        width: 300,
        child: TextField(controller: c, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 6),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(ctx, store.checkPin(c.text.trim())), child: const Text('Mở')),
      ],
    ),
  );
  return ok == true;
}
