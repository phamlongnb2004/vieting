import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../categories.dart';
import '../models.dart';
import '../store.dart';

/// Khoản ghi nhanh từ Phím tắt iPhone (Siri, nút Tác vụ, chạm mặt sau) khi app chưa mở.
/// Phần Swift (tools/ios/QuickIntents.swift) xếp hàng vào UserDefaults, ở đây lấy ra và ghi vào sổ.
class QuickQueue {
  static bool get supported => !kIsWeb && Platform.isIOS;

  static Future<List<Txn>> drain(AppStore store) async {
    if (!supported) return const [];
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final raw = p.getString('vt_quick');
      if (raw == null || raw.isEmpty) return const [];
      await p.remove('vt_quick');
      final list = (jsonDecode(raw) as List).whereType<Map>().toList();
      final wallets = store.activeWallets;
      final out = <Txn>[];
      for (final e in list) {
        final amount = ((e['amount'] as num?) ?? 0).toInt();
        if (amount <= 0) continue;
        final income = e['income'] == true;
        final note = '${e['note'] ?? ''}'.trim();
        final t = Txn(
          id: newId(),
          amount: amount,
          income: income,
          categoryId: guessCategory(income, note, store.learnedRules),
          walletId: wallets.any((w) => w.id == 'cash') ? 'cash' : wallets.first.id,
          date: DateTime.fromMillisecondsSinceEpoch(((e['at'] as num?) ?? DateTime.now().millisecondsSinceEpoch).toInt()),
          note: note,
          source: 'shortcut',
        );
        store.saveTxn(t);
        out.add(t);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
