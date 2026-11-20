import 'package:flutter/material.dart';

import '../insights.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import 'simulate.dart';

/// Thói quen: chuỗi ngày giữ ngân sách, thử thách 7 ngày, tiền đi đâu vì lý do gì.
class HabitsScreen extends StatelessWidget {
  final bool embedded;
  const HabitsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final allowance = store.dailyAllowance;
    final streak = store.streak;
    final ch = store.activeChallenge;
    final per = store.currentPeriod;
    final tags = store.expenseByTag(per.year, per.month);
    final tagTotal = tags.values.fold<int>(0, (s, v) => s + v);

    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Thói quen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Text('💛', style: TextStyle(fontSize: 22)),
              title: const Text('Hôm nay là ngày ngoại lệ'),
              subtitle: const Text('Sinh nhật, đám cưới, đi chơi… tiêu nhiều cũng không mất chuỗi'),
              value: store.isSkipDay(DateTime.now()),
              onChanged: (_) => store.toggleSkipDay(DateTime.now()),
            ),
          ),
          const SizedBox(height: 8),
          // ---- Chuỗi ngày ----
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFFE8710A), Brand.red]),
            ),
            child: Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: allowance == null
                    ? const Text('Đặt ngân sách tổng tháng để bắt đầu chuỗi ngày giữ ngân sách.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$streak ngày liên tiếp',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        Text('chi không quá ${compactMoney(allowance)}/ngày và không bốc đồng',
                            style: const TextStyle(color: Colors.white)),
                      ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          // ---- Thử thách ----
          const Text('Thử thách 7 ngày', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ch == null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('7 ngày không mua sắm bốc đồng', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Mỗi khoản chi gắn thẻ "Bốc đồng" sẽ làm đứt thử thách. Giữ đủ 7 ngày để nhận huy hiệu 🎋.',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => store.startChallenge('no_impulse_7'),
                        icon: const Icon(Icons.flag),
                        label: const Text('Bắt đầu thử thách'),
                      ),
                    ])
                  : _ChallengeView(c: ch),
            ),
          ),
          const SizedBox(height: 18),
          // ---- Thẻ cảm xúc ----
          Text('Tiền đi đâu vì lý do gì (${store.periodLabel(per.year, per.month)})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: tagTotal == 0
                  ? Text('Khi ghi khoản chi, chọn "Cần thiết", "Xả stress", "Đầu tư bản thân" hoặc "Bốc đồng" để xem ở đây.',
                      style: TextStyle(color: cs.onSurfaceVariant))
                  : Column(children: [
                      for (final t in kTags)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(children: [
                            Row(children: [
                              Icon(t.icon, color: t.color, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              Text(compactMoney(tags[t.id] ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (tags[t.id] ?? 0) / tagTotal,
                                minHeight: 7,
                                color: t.color,
                                backgroundColor: t.color.withAlpha(30),
                              ),
                            ),
                          ]),
                        ),
                    ]),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_graph, color: Brand.bamboo),
              title: const Text('Mô phỏng: nếu bớt một thói quen thì sao?', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('VD bớt 2 ly trà sữa/tuần, sau 1 năm có thêm bao nhiêu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimulateScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeView extends StatelessWidget {
  final Challenge c;
  const _ChallengeView({required this.c});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final status = store.challengeStatus(c);
    final day = store.challengeDay(c);
    final title = switch (status) {
      'failed' => 'Thử thách đã đứt 😅',
      'done' => 'Hoàn thành! 🎋 Bạn giữ được 7 ngày',
      _ => 'Ngày $day/7 · không mua sắm bốc đồng',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Row(children: [
        for (var i = 1; i <= 7; i++)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: status == 'failed'
                    ? (i <= day ? Brand.red.withAlpha(60) : cs.surfaceContainerHighest)
                    : (i < day || status == 'done'
                        ? Brand.bamboo
                        : i == day
                            ? Brand.yellow
                            : cs.surfaceContainerHighest),
              ),
              child: Text('$i',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: (i < day || status == 'done') && status != 'failed' ? Colors.white : cs.onSurface)),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        if (status != 'running')
          FilledButton(onPressed: () => store.startChallenge('no_impulse_7'), child: const Text('Thử lại 7 ngày mới')),
        const Spacer(),
        TextButton(onPressed: () => store.stopChallenge(c.id), child: const Text('Dừng')),
      ]),
    ]);
  }
}
