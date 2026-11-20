import 'package:flutter/material.dart';

import '../config.dart';
import '../store.dart';
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
      await StoreScope.read(context).login(server, email, _pass.text, register: _register);
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
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
              if (_register) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _pass2,
                  obscureText: _hide,
                  decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.lock_reset)),
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
