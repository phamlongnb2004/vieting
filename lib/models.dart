import 'package:flutter/material.dart';

int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Giao dịch thu / chi.
class Txn {
  String id;
  int amount; // luôn dương
  bool income;
  String categoryId;
  String walletId;
  DateTime date;
  String note;
  String source; // manual | notify | paste | shortcut
  String raw; // nội dung thông báo gốc (nếu có)
  int? balanceAfter;
  int updatedAt;
  bool deleted;

  Txn({
    required this.id,
    required this.amount,
    required this.income,
    required this.categoryId,
    required this.walletId,
    required this.date,
    this.note = '',
    this.source = 'manual',
    this.raw = '',
    this.balanceAfter,
    int? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? nowMs();

  int get signed => income ? amount : -amount;
  bool get auto => source != 'manual';

  Txn copy() => Txn.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'income': income,
        'cat': categoryId,
        'wallet': walletId,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'source': source,
        'raw': raw,
        if (balanceAfter != null) 'bal': balanceAfter,
        'u': updatedAt,
        'del': deleted,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        amount: (j['amount'] as num).toInt(),
        income: j['income'] == true,
        categoryId: (j['cat'] ?? 'khac_chi') as String,
        walletId: (j['wallet'] ?? '') as String,
        date: DateTime.fromMillisecondsSinceEpoch((j['date'] as num).toInt()),
        note: (j['note'] ?? '') as String,
        source: (j['source'] ?? 'manual') as String,
        raw: (j['raw'] ?? '') as String,
        balanceAfter: (j['bal'] as num?)?.toInt(),
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['del'] == true,
      );
}

/// Ví / tài khoản: tiền mặt, ngân hàng, ví điện tử.
class Wallet {
  String id;
  String name;
  String kind; // cash | bank | ewallet
  int initial; // số dư ban đầu (số dư hiện tại = initial + tổng giao dịch)
  String bankId;
  int color;
  int updatedAt;
  bool deleted;

  Wallet({
    required this.id,
    required this.name,
    this.kind = 'cash',
    this.initial = 0,
    this.bankId = '',
    this.color = 0xFF3E8E41,
    int? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? nowMs();

  IconData get icon => switch (kind) {
        'bank' => Icons.account_balance,
        'ewallet' => Icons.account_balance_wallet,
        _ => Icons.payments_outlined,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'initial': initial,
        'bank': bankId,
        'color': color,
        'u': updatedAt,
        'del': deleted,
      };

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        id: j['id'] as String,
        name: (j['name'] ?? 'Ví') as String,
        kind: (j['kind'] ?? 'cash') as String,
        initial: (j['initial'] as num?)?.toInt() ?? 0,
        bankId: (j['bank'] ?? '') as String,
        color: (j['color'] as num?)?.toInt() ?? 0xFF3E8E41,
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['del'] == true,
      );
}

/// Ngân sách hàng tháng. id = mã danh mục, hoặc 'all' cho tổng chi.
class Budget {
  String id;
  int limit;
  int updatedAt;
  bool deleted;
  Budget({required this.id, required this.limit, int? updatedAt, this.deleted = false})
      : updatedAt = updatedAt ?? nowMs();

  Map<String, dynamic> toJson() => {'id': id, 'limit': limit, 'u': updatedAt, 'del': deleted};
  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        id: j['id'] as String,
        limit: (j['limit'] as num?)?.toInt() ?? 0,
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['del'] == true,
      );
}

/// Danh mục đã học từ lựa chọn của người dùng (khóa = 3 từ đầu của nội dung).
class CatRule {
  String id;
  String categoryId;
  int updatedAt;
  bool deleted;
  CatRule({required this.id, required this.categoryId, int? updatedAt, this.deleted = false})
      : updatedAt = updatedAt ?? nowMs();

  Map<String, dynamic> toJson() => {'id': id, 'cat': categoryId, 'u': updatedAt, 'del': deleted};
  factory CatRule.fromJson(Map<String, dynamic> j) => CatRule(
        id: j['id'] as String,
        categoryId: (j['cat'] ?? 'khac_chi') as String,
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['del'] == true,
      );
}

/// Thông báo thô nhận từ Android (hoặc Phím tắt iOS / dán tay).
class RawNotice {
  final String package;
  final String appName;
  final String title;
  final String text;
  final DateTime time;
  const RawNotice({required this.package, required this.appName, required this.title, required this.text, required this.time});

  String get full => title.isEmpty ? text : '$title\n$text';

  Map<String, dynamic> toJson() =>
      {'pkg': package, 'app': appName, 'title': title, 'text': text, 'time': time.millisecondsSinceEpoch};
  factory RawNotice.fromJson(Map<String, dynamic> j) => RawNotice(
        package: (j['pkg'] ?? '') as String,
        appName: (j['app'] ?? j['pkg'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        time: DateTime.fromMillisecondsSinceEpoch((j['time'] as num?)?.toInt() ?? nowMs()),
      );
}

/// Nhật ký xử lý thông báo (chỉ lưu trên máy).
class NoticeLog {
  final RawNotice notice;
  String status; // added | duplicate | skipped | unparsed
  String? txnId;
  NoticeLog(this.notice, this.status, [this.txnId]);

  Map<String, dynamic> toJson() => {'n': notice.toJson(), 's': status, if (txnId != null) 't': txnId};
  factory NoticeLog.fromJson(Map<String, dynamic> j) =>
      NoticeLog(RawNotice.fromJson(Map<String, dynamic>.from(j['n'] as Map)), (j['s'] ?? 'unparsed') as String, j['t'] as String?);
}

/// Một tin nhắn trong khung trò chuyện với trợ lý AI (chỉ lưu trên máy).
class ChatMsg {
  final String role; // user | model
  final String text;
  final List<Map<String, dynamic>> actions; // add_txn | set_budget
  final List<String> status; // '' | done | skip, theo từng hành động
  final DateTime time;
  final bool error;

  ChatMsg({
    required this.role,
    required this.text,
    List<Map<String, dynamic>>? actions,
    List<String>? status,
    DateTime? time,
    this.error = false,
  })  : actions = actions ?? [],
        status = status ?? List.filled((actions ?? []).length, '', growable: true),
        time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'r': role,
        't': text,
        if (actions.isNotEmpty) 'a': actions,
        if (actions.isNotEmpty) 's': status,
        'tm': time.millisecondsSinceEpoch,
        if (error) 'e': true,
      };

  factory ChatMsg.fromJson(Map<String, dynamic> j) {
    final acts = ((j['a'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final st = ((j['s'] as List?) ?? []).map((e) => e.toString()).toList();
    while (st.length < acts.length) {
      st.add('');
    }
    return ChatMsg(
      role: (j['r'] ?? 'user') as String,
      text: (j['t'] ?? '') as String,
      actions: acts,
      status: st,
      time: DateTime.fromMillisecondsSinceEpoch((j['tm'] as num?)?.toInt() ?? nowMs()),
      error: j['e'] == true,
    );
  }
}
