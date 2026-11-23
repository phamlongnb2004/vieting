import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../store.dart';
import '../ui_keys.dart';
import '../widgets/logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _register = false;
  bool _busy = false;
  bool _hide = true;
  bool _advanced = false;
  String? _error;
  late final TextEditingController _server;
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _name = TextEditingController();
  final _birth = TextEditingController();
  bool _gCancel = false;

  @override
  void initState() {
    super.initState();
    final saved = StoreScope.read(context).serverUrl;
    _server = TextEditingController(text: kServerUrl.isNotEmpty ? kServerUrl : saved);
  }

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    _name.dispose();
    _birth.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final server = kServerUrl.isNotEmpty ? kServerUrl : _server.text.trim();
    final email = _email.text.trim();
    String? err;
    if (server.isEmpty || !server.startsWith('http')) {
      err = 'Server đồng bộ chưa được cài đặt';
    } else if (!email.contains('@')) {
      err = 'Email chưa đúng';
    } else if (_pass.text.length < 6) {
      err = 'Mật khẩu tối thiểu 6 ký tự';
    } else if (_register && _pass.text != _pass2.text) {
      err = 'Hai mật khẩu không khớp';
    } else if (_register && _name.text.trim().length < 2) {
      err = 'Nhập họ và tên';
    } else if (_register && _birthErr() != null) {
      err = _birthErr();
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await StoreScope.read(context).login(server, email, _pass.text,
          register: _register, name: _name.text, birth: int.tryParse(_birth.text.trim()) ?? 0);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().contains('SocketException') || e.toString().contains('Timeout')
          ? 'Không kết nối được server'
          : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _serverUrl => kServerUrl.isNotEmpty ? kServerUrl : _server.text.trim();

  /// null = hợp lệ (để trống cũng được)
  String? _birthErr() {
    final y = int.tryParse(_birth.text.trim());
    if (y == null || y < 1900 || y > DateTime.now().year) return 'Nhập năm sinh (VD: 2000)';
    if (y > DateTime.now().year - 18) return 'VieTing chỉ dành cho người từ 18 tuổi trở lên';
    return null;
  }

  Future<void> _google() async {
    final server = _serverUrl;
    if (!server.startsWith('http')) {
      setState(() => _error = 'Server đồng bộ chưa được cài đặt');
      return;
    }
    final store = StoreScope.read(context);
    final (link, state) = store.googleStart(server);
    setState(() {
      _error = null;
      _gCancel = false;
    });
    final opened = await launchUrl(link, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened) {
      if (mounted) setState(() => _error = 'Không mở được trình duyệt');
      return;
    }
    if (!mounted) return;
    // hộp chờ: app hỏi server mỗi 2 giây, tối đa 10 phút
    final nav = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        content: const Row(children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 16),
          Expanded(child: Text('Đang chờ bạn đăng nhập Google trong trình duyệt…')),
        ]),
        actions: [
          TextButton(onPressed: () => launchUrl(link, mode: LaunchMode.externalApplication), child: const Text('Mở lại trình duyệt')),
          TextButton(
            onPressed: () {
              _gCancel = true;
              Navigator.pop(c);
            },
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
    String? res;
    final until = DateTime.now().add(const Duration(minutes: 10));
    while (!_gCancel && mounted && DateTime.now().isBefore(until)) {
      await Future.delayed(const Duration(seconds: 2));
      if (_gCancel || !mounted) break;
      res = await store.googlePoll(state);
      if (res != null) break;
    }
    if (_gCancel || !mounted) return;
    nav.pop(); // đóng hộp chờ
    if (res == '') {
      nav.pop(); // đăng nhập xong: rời màn hình đăng nhập
    } else {
      setState(() => _error = res ?? 'Hết thời gian đăng nhập, thử lại nhé');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideServer = kServerUrl != '' || !_advanced;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: Wordmark(fontSize: 34)),
              const SizedBox(height: 8),
              Center(child: Text(_register ? 'Tạo tài khoản đồng bộ' : 'Đăng nhập để đồng bộ giữa các máy')),
              const SizedBox(height: 24),
              if (!hideServer) ...[
                TextField(
                  controller: _server,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Địa chỉ server', hintText: 'https://vieting.xxx.workers.dev'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _busy ? null : _google,
                icon: const Icon(PhosphorIconsBold.googleLogo, size: 20),
                label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Tiếp tục với Google')),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('hoặc dùng email', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),
              if (_register) ...[
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(PhosphorIconsRegular.identificationCard)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _birth,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                      labelText: 'Năm sinh', hintText: 'VD: 2000', helperText: 'VieTing dành cho người từ 18 tuổi', counterText: '', prefixIcon: Icon(PhosphorIconsRegular.cake)),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(PhosphorIconsRegular.envelopeSimple)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(PhosphorIconsRegular.lockSimple),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
              if (!_register)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ForgotPasswordScreen(server: _serverUrl, email: _email.text.trim(), onGoogle: _google))),
                    child: const Text('Quên mật khẩu?'),
                  ),
                ),
              if (_register) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _pass2,
                  obscureText: _hide,
                  decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(PhosphorIconsRegular.lockKeyOpen)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (kServerUrl.isEmpty && !_advanced) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _advanced = true),
                    child: const Text('Nâng cao', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_register ? 'Đăng ký' : 'Đăng nhập'),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _register = !_register;
                  _error = null;
                }),
                child: Text(_register ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quên mật khẩu: nhận mã 6 số qua email rồi đặt mật khẩu mới. Email Google thì có thể vào lại bằng Google luôn.
class ForgotPasswordScreen extends StatefulWidget {
  final String server;
  final String email;
  final Future<void> Function() onGoogle;
  const ForgotPasswordScreen({super.key, required this.server, required this.email, required this.onGoogle});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _pass = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  bool _noMail = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Email chưa đúng');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await StoreScope.read(context).forgotPassword(widget.server, _email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _noMail = err != null && err.contains('Google');
      if (err == null) _sent = true;
    });
  }

  Future<void> _reset() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Nhập đủ mã 6 số trong email');
      return;
    }
    if (_pass.text.length < 6) {
      setState(() => _error = 'Mật khẩu tối thiểu 6 ký tự');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await StoreScope.read(context).resetPassword(widget.server, _email.text, _code.text, _pass.text);
    if (!mounted) return;
    if (err == null) {
      showToast(context, 'Đã đặt mật khẩu mới và đăng nhập');
      Navigator.of(context)
        ..pop()
        ..pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                _sent
                    ? 'Nếu email này có tài khoản, mã 6 số đã được gửi tới hộp thư (xem cả mục Spam / Quảng cáo). Mã có hiệu lực 15 phút.'
                    : 'Nhập email đã đăng ký, VieTing gửi mã 6 số để bạn đặt mật khẩu mới.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _email,
                enabled: !_sent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(PhosphorIconsRegular.envelopeSimple)),
              ),
              if (_sent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Mã 6 số', counterText: '', prefixIcon: Icon(PhosphorIconsRegular.hash)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu mới', prefixIcon: Icon(PhosphorIconsRegular.lockSimple)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : (_sent ? _reset : _send),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_sent ? 'Đặt mật khẩu mới' : 'Gửi mã'),
                ),
              ),
              if (_sent)
                TextButton(onPressed: _busy ? null : _send, child: const Text('Gửi lại mã')),
              const SizedBox(height: 8),
              Text(
                'Tài khoản dùng email Google (Gmail)? Bấm bên dưới để vào lại ngay, rồi đặt mật khẩu mới trong Cài đặt.',
                style: TextStyle(color: _noMail ? cs.primary : cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onGoogle();
                      },
                icon: const Icon(PhosphorIconsBold.googleLogo, size: 20),
                label: const Text('Tiếp tục với Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
