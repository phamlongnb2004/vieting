import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../insights.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/bamboo.dart';
import '../widgets/vicon.dart';

/// Mô phỏng tác động tương lai: "Nếu bớt 2 ly trà sữa/tuần, sau 1 năm có thêm X".
class SimulateScreen extends StatefulWidget {
  final String? goalId;
  const SimulateScreen({super.key, this.goalId});

  @override
  State<SimulateScreen> createState() => _SimulateScreenState();
}

class _SimulateScreenState extends State<SimulateScreen> {
  final _habit = TextEditingController(text: tr('trà sữa'));
  final _price = TextEditingController(text: groupDigits(45000));
  double _perWeek = 2;
  String? _goal;

  static const _presets = [
    ('trà sữa', 45000),
    ('cà phê', 35000),
    ('ăn ngoài', 80000),
    ('Grab', 40000),
    ('mua sắm online', 200000),
  ];

  @override
  void initState() {
    super.initState();
    _goal = widget.goalId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _usePrice(_habit.text));
  }

  @override
  void dispose() {
    _habit.dispose();
    _price.dispose();
    super.dispose();
  }

  void _usePrice(String habit, [int? fallback]) {
    final avg = StoreScope.read(context).averagePriceFor(habit);
    final v = avg > 0 ? avg : fallback;
    if (v != null) setState(() => _price.text = groupDigits(v));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final price = parseMoneyInput(_price.text);
    final perMonth = (price * _perWeek * 52 / 12).round();
    final perYear = (price * _perWeek * 52).round();
    final goals = store.activeGoals;
    Goal? goal;
    for (final g in goals) {
      if (g.id == _goal) goal = g;
    }
    final int left = goal == null ? 0 : (goal.target - goal.saved < 0 ? 0 : goal.target - goal.saved);
    final monthsToGoal = goal == null || perMonth <= 0 ? null : (left / perMonth).ceil();

    return Scaffold(
      appBar: AppBar(title: const Text('Mô phỏng tiết kiệm')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Nếu mình bớt…', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final p in _presets)
              ActionChip(
                label: Text(p.$1),
                onPressed: () {
                  _habit.text = p.$1;
                  _usePrice(p.$1, p.$2);
                },
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _habit,
            decoration: const InputDecoration(labelText: 'Thói quen', prefixIcon: Icon(PhosphorIconsRegular.coffee)),
            onSubmitted: (v) => _usePrice(v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Mỗi lần khoảng', suffixText: '₫', helperText: 'Tự lấy theo giá trung bình bạn hay chi'),
          ),
          const SizedBox(height: 16),
          Text('Bớt ${_perWeek.round()} lần mỗi tuần', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: _perWeek,
            min: 1,
            max: 14,
            divisions: 13,
            label: tr('${_perWeek.round()} lần/tuần'),
            onChanged: (v) => setState(() => _perWeek = v),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Brand.bamboo, Color(0xFF2B6A2E)]),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sau 1 năm bạn có thêm', style: TextStyle(color: Colors.white70)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(money(perYear),
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 6),
                  Text('≈ ${money(perMonth)}/tháng · 3 năm: ${compactMoney(perYear * 3)}',
                      style: const TextStyle(color: Colors.white)),
                ]),
              ),
              const BambooTree(progress: 0.75, height: 90),
            ]),
          ),
          const SizedBox(height: 18),
          if (goals.isNotEmpty) ...[
            const Text('Dồn vào mục tiêu', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final g in goals)
                ChoiceChip(
                  avatar: Icon(goalIcon(g.emoji), size: 18),
                  label: Text(g.name),
                  selected: _goal == g.id,
                  onSelected: (v) => setState(() => _goal = v ? g.id : null),
                ),
            ]),
            if (goal != null && monthsToGoal != null) ...[
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: VIcon(goalIcon(goal.emoji), color: Brand.bamboo),
                  title: Text(left <= 0
                      ? 'Mục tiêu đã đạt rồi!'
                      : 'Chỉ nhờ bớt ${_habit.text}, bạn đạt "${goal.name}" sau khoảng $monthsToGoal tháng'),
                  subtitle: Text('Còn thiếu ${money(left)}'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
