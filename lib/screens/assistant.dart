import 'package:flutter/material.dart';

import '../config.dart';
import '../insights.dart';
import '../models.dart';
import '../widgets/nudge.dart';
import '../services/assistant.dart';
import '../services/voice.dart';
import '../store.dart';
import '../ui_keys.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/logo.dart';
import 'edit_txn.dart';

const _suggestions = [
  'Tháng này mình chi bao nhiêu rồi?',
  'Mình tiêu nhiều nhất vào đâu?',
  'Ăn phở 45k',
  'Đặt ngân sách ăn uống 3 triệu',
  'So với tháng trước thế nào?',
  'Gợi ý cách tiết kiệm cho mình',
];

/// Trò chuyện với trợ lý AI: hỏi về chi tiêu, ghi giao dịch bằng lời, đặt ngân sách.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  bool _listening = false;

  Future<void> _mic() async {
    if (_listening) {
      await Voice.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    final ok = await Voice.listen(
      onText: (t) {
        if (mounted) setState(() => _input.text = t);
      },
      onDone: (t) {
        if (!mounted) return;
        setState(() => _listening = false);
        if (t.trim().isNotEmpty) _send(t);
      },
    );
    if (!ok && mounted) {
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa dùng được micro trên máy này')));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    final store = StoreScope.read(context);
    _input.clear();
    store.addChat(ChatMsg(role: 'user', text: text));
    setState(() => _busy = true);
    _toBottom();
    final r = await Assistant.ask(store, text);
    if (!mounted) return;
    store.addChat(Assistant.toMsg(r));
    setState(() => _busy = false);
    _toBottom();
  }

  Future<void> _serverDialog() async {
    final store = StoreScope.read(context);
    final c = TextEditingController(text: store.serverUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Địa chỉ server trợ lý'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: c,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: 'https://vieting.xxx.workers.dev'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok == true) store.setServerUrl(c.text);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final msgs = store.chat;

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          CoinLogo(size: 30),
          SizedBox(width: 10),
          Text('Trợ lý VieTing', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'server') _serverDialog();
              // (chỉ hiện khi app chưa gắn sẵn server)
              if (v == 'clear') store.clearChat();
            },
            itemBuilder: (_) => [
              if (kServerUrl.isEmpty) const PopupMenuItem(value: 'server', child: Text('Địa chỉ server')),
              const PopupMenuItem(value: 'clear', child: Text('Xóa cuộc trò chuyện')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        if (store.serverUrl.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              color: Brand.yellow.withAlpha(55),
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Chưa nối server AI', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Vẫn ghi nhanh được câu kiểu "phở 45k". Nhập địa chỉ server để hỏi đáp.'),
                trailing: kServerUrl.isEmpty ? TextButton(onPressed: _serverDialog, child: const Text('Nhập')) : null,
              ),
            ),
          ),
        Expanded(
          child: msgs.isEmpty
              ? _Empty(onPick: _send)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                  itemCount: msgs.length + (_busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == msgs.length) return const _Typing();
                    return _Bubble(msg: msgs[i]);
                  },
                ),
        ),
        if (msgs.isNotEmpty && !_busy)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(label: Text(s), onPressed: () => _send(s)),
                  ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Hỏi hoặc ghi: "cafe 35k", "tháng này chi bao nhiêu?"',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              if (Voice.supported) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _busy ? null : _mic,
                  icon: Icon(_listening ? Icons.stop_circle : Icons.mic, color: Brand.red),
                ),
              ],
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: _busy ? null : () => _send(),
                icon: const Icon(Icons.arrow_upward),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Câu hỏi và tóm tắt chi tiêu được gửi tới AI để trả lời. AI có thể nhầm, hãy kiểm tra trước khi ghi.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final void Function(String) onPick;
  const _Empty({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        const Center(child: CoinLogo(size: 72)),
        const SizedBox(height: 14),
        const Center(
          child: Text('Chào bạn, mình là trợ lý VieTing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Text(
          'Hỏi mình về chi tiêu, nhờ ghi giao dịch bằng một câu ("ăn phở 45k") hoặc đặt ngân sách. '
          'Mình luôn hỏi lại trước khi ghi.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in _suggestions) ActionChip(label: Text(s), onPressed: () => onPick(s))],
        ),
      ],
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const SizedBox(width: 22, height: 14, child: LinearProgressIndicator(minHeight: 3)),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final ChatMsg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final mine = msg.role == 'user';
    final maxW = MediaQuery.sizeOf(context).width * 0.8;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW > 560 ? 560 : maxW),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? Brand.red : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
              ),
              child: SelectableText(msg.text,
                  style: TextStyle(color: mine ? Colors.white : cs.onSurface, fontSize: 15, height: 1.35)),
            ),
            for (var i = 0; i < msg.actions.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Brand.bamboo.withAlpha(120)),
                  borderRadius: BorderRadius.circular(14),
                  color: Brand.bamboo.withAlpha(18),
                ),
                child: Row(children: [
                  Icon(msg.actions[i]['type'] == 'add_txn' ? Icons.edit_note : Icons.savings_outlined,
                      color: Brand.bamboo, size: 20),
                  const SizedBox(width: 8),
                  Flexible(child: Text(Assistant.describe(msg.actions[i]), style: const TextStyle(fontWeight: FontWeight.w600))),
                  const SizedBox(width: 6),
                  if (msg.status[i] == 'done')
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, color: Brand.bamboo, size: 18),
                        SizedBox(width: 4),
                        Text('Đã xong', style: TextStyle(color: Brand.bamboo, fontWeight: FontWeight.w700)),
                      ]),
                    )
                  else if (msg.status[i] == 'skip')
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text('Đã bỏ qua', style: TextStyle(color: cs.onSurfaceVariant)),
                    )
                  else ...[
                    TextButton(onPressed: () => store.skipAction(msg, i), child: const Text('Bỏ')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Brand.bamboo, visualDensity: VisualDensity.compact),
                      onPressed: () {
                        final r = store.applyAction(msg, i);
                        final isTxn = r.startsWith('txn:');
                        if (isTxn) {
                          final t = store.txns[r.substring(4)];
                          final n = t == null ? const <Nudge>[] : store.nudgesFor(t);
                          if (n.isNotEmpty) {
                            showNudges(n);
                            return;
                          }
                        }
                        showToast(context, isTxn ? 'Đã ghi giao dịch' : 'Đã đặt ngân sách',
                            actionLabel: isTxn ? 'Sửa' : null,
                            onAction: isTxn
                                ? () {
                                    final t = store.txns[r.substring(4)];
                                    if (t != null) openEditTxn(context, t);
                                  }
                                : null);
                      },
                      child: Text(msg.actions[i]['type'] == 'add_txn' ? 'Ghi' : 'Đặt'),
                    ),
                  ],
                ]),
              ),
            if (!mine && msg.actions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(hm(msg.time), style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }
}
