import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
  String tag; // thẻ cảm xúc: can_thiet | xa_stress | dau_tu | boc_dong | ''
  bool hidden; // khoản riêng tư: ẩn chi tiết, mở bằng vân tay / PIN
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
    this.tag = '',
    this.hidden = false,
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
        if (tag.isNotEmpty) 'tag': tag,
        if (hidden) 'hid': true,
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
        tag: (j['tag'] ?? '') as String,
        hidden: j['hid'] == true,
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
        'bank' => PhosphorIconsRegular.bank,
        'ewallet' => PhosphorIconsFill.wallet,
        _ => PhosphorIconsRegular.money,
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
  final String image; // đường dẫn ảnh người dùng gửi (lưu trên máy)

  ChatMsg({
    required this.role,
    required this.text,
    List<Map<String, dynamic>>? actions,
    List<String>? status,
    DateTime? time,
    this.error = false,
    this.image = '',
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
        if (image.isNotEmpty) 'img': image,
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
      image: (j['img'] ?? '') as String,
    );
  }
}


/// Thẻ cảm xúc / giá trị cho khoản chi: tiền đi đâu vì lý do gì.
class TagInfo {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  const TagInfo(this.id, this.name, this.icon, this.color);
}

const List<TagInfo> kTags = [
  TagInfo('can_thiet', 'Cần thiết', PhosphorIconsRegular.checkCircle, Color(0xFF3E8E41)),
  TagInfo('xa_stress', 'Xả stress', PhosphorIconsRegular.flowerLotus, Color(0xFF8E24AA)),
  TagInfo('dau_tu', 'Đầu tư bản thân', PhosphorIconsRegular.chartLineUp, Color(0xFF1E88E5)),
  TagInfo('boc_dong', 'Bốc đồng', PhosphorIconsFill.lightning, Color(0xFFE8710A)),
];

TagInfo? tagById(String id) {
  for (final t in kTags) {
    if (t.id == id) return t;
  }
  return null;
}

/// Hũ mục tiêu tiết kiệm (du lịch, laptop, quỹ dự phòng...).
/// Một lần bỏ tiền vào / rút ra khỏi mục tiêu.
class GoalMove {
  String id;
  int amount; // dương: bỏ vào · âm: rút ra
  int at;
  String status; // ok | pending (đã tạo mã QR, chờ thấy tiền đi thật)
  String reason; // lý do rút / ghi chú
  String txnId; // giao dịch "chuyển sang hũ" trong sổ (nếu có)
  GoalMove({required this.id, required this.amount, required this.at, this.status = 'ok', this.reason = '', this.txnId = ''});

  Map<String, dynamic> toJson() => {
        'id': id,
        'a': amount,
        'at': at,
        if (status != 'ok') 's': status,
        if (reason.isNotEmpty) 'r': reason,
        if (txnId.isNotEmpty) 't': txnId,
      };
  factory GoalMove.fromJson(Map<String, dynamic> j) => GoalMove(
        id: '${j['id'] ?? ''}',
        amount: (j['a'] as num?)?.toInt() ?? 0,
        at: (j['at'] as num?)?.toInt() ?? 0,
        status: '${j['s'] ?? 'ok'}',
        reason: '${j['r'] ?? ''}',
        txnId: '${j['t'] ?? ''}',
      );
}

class Goal {
  String id;
  String name;
  String emoji;
  int target;
  int saved;
  DateTime? deadline;
  int updatedAt;
  bool deleted;
  // Tiền của mục tiêu nằm ở đâu: app (chỉ giữ chỗ trong ví) · bank (tài khoản tiết kiệm / hũ riêng) · cash (tiền mặt để riêng)
  String hold;
  String holdName; // VD "Hũ Techcombank", "Phong bì tủ quần áo"
  String bin; // ngân hàng của tài khoản tiết kiệm (mã NAPAS) để tạo mã VietQR
  String acct;
  String owner;
  String code; // 4 ký tự trong nội dung chuyển khoản "VTG <code>"
  int reconAt; // lần đối chiếu số dư gần nhất
  List<GoalMove> moves;
  Goal({
    required this.id,
    required this.name,
    this.emoji = 'target',
    required this.target,
    this.saved = 0,
    this.deadline,
    int? updatedAt,
    this.deleted = false,
    this.hold = 'app',
    this.holdName = '',
    this.bin = '',
    this.acct = '',
    this.owner = '',
    this.code = '',
    this.reconAt = 0,
    List<GoalMove>? moves,
  })  : updatedAt = updatedAt ?? nowMs(),
        moves = moves ?? [];

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  bool get separate => hold == 'bank' || hold == 'cash';
  bool get hasQr => hold == 'bank' && bin.isNotEmpty && acct.isNotEmpty;
  List<GoalMove> get pending => moves.where((m) => m.status == 'pending').toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'target': target,
        'saved': saved,
        if (deadline != null) 'deadline': deadline!.millisecondsSinceEpoch,
        'u': updatedAt,
        'del': deleted,
        if (hold != 'app') 'hold': hold,
        if (holdName.isNotEmpty) 'holdName': holdName,
        if (bin.isNotEmpty) 'bin': bin,
        if (acct.isNotEmpty) 'acct': acct,
        if (owner.isNotEmpty) 'owner': owner,
        if (code.isNotEmpty) 'code': code,
        if (reconAt > 0) 'recon': reconAt,
        if (moves.isNotEmpty) 'moves': [for (final m in moves.length > 120 ? moves.sublist(moves.length - 120) : moves) m.toJson()],
      };
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        name: (j['name'] ?? 'Mục tiêu') as String,
        emoji: (j['emoji'] ?? 'target') as String,
        target: (j['target'] as num?)?.toInt() ?? 0,
        saved: (j['saved'] as num?)?.toInt() ?? 0,
        deadline: j['deadline'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j['deadline'] as num).toInt()),
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['del'] == true,
        hold: '${j['hold'] ?? 'app'}',
        holdName: '${j['holdName'] ?? ''}',
        bin: '${j['bin'] ?? ''}',
        acct: '${j['acct'] ?? ''}',
        owner: '${j['owner'] ?? ''}',
        code: '${j['code'] ?? ''}',
        reconAt: (j['recon'] as num?)?.toInt() ?? 0,
        moves: [
          for (final m in (j['moves'] as List? ?? const []))
            if (m is Map) GoalMove.fromJson(Map<String, dynamic>.from(m))
        ],
      );
}

/// Thử thách ngắn, VD 7 ngày không mua sắm bốc đồng.
class Challenge {
  String id;
  String type; // no_impulse_7 | campaign
  DateTime start;
  // thử thách theo mùa do admin tạo (lưu kèm để chạy cả khi sự kiện đã kết thúc)
  String title;
  String emoji;
  List<String> keywords;
  String category;
  int? dayCount;
  int updatedAt;
  bool deleted;
  Challenge({
    required this.id,
    required this.type,
    required this.start,
    this.title = '',
    this.emoji = '',
    this.keywords = const [],
    this.category = '',
    this.dayCount,
    int? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? nowMs();

  int get days => dayCount ?? 7;
  DateTime get end => DateTime(start.year, start.month, start.day).add(Duration(days: days));

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'start': start.millisecondsSinceEpoch,
        if (title.isNotEmpty) 'title': title,
        if (emoji.isNotEmpty) 'emoji': emoji,
        if (keywords.isNotEmpty) 'kw': keywords,
        if (category.isNotEmpty) 'cat': category,
        if (dayCount != null) 'days': dayCount,
        'u': updatedAt,
        'del': deleted,
      };
  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as String,
        type: (j['type'] ?? 'no_impulse_7') as String,
        start: DateTime.fromMillisecondsSinceEpoch((j['start'] as num).toInt()),
        title: (j['title'] ?? '') as String,
        emoji: (j['emoji'] ?? '') as String,
        keywords: ((j['kw'] as List?) ?? const []).map((e) => e.toString()).toList(),
        category: (j['cat'] ?? '') as String,
        dayCount: (j['days'] as num?)?.toInt(),
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['del'] == true,
      );
}

/// Một khoản chi trong sổ chung: ai trả, chia cho những ai.
class GroupExpense {
  String id;
  String desc;
  int amount;
  String payer;
  Map<String, int> shares; // người -> số tiền phải chịu (tổng = amount)
  DateTime date;
  GroupExpense({required this.id, required this.desc, required this.amount, required this.payer, required this.shares, required this.date});

  Map<String, dynamic> toJson() =>
      {'id': id, 'desc': desc, 'amount': amount, 'payer': payer, 'shares': shares, 'date': date.millisecondsSinceEpoch};
  factory GroupExpense.fromJson(Map<String, dynamic> j) => GroupExpense(
        id: j['id'] as String,
        desc: (j['desc'] ?? '') as String,
        amount: (j['amount'] as num).toInt(),
        payer: (j['payer'] ?? '') as String,
        shares: Map<String, dynamic>.from((j['shares'] as Map?) ?? {}).map((k, v) => MapEntry(k, (v as num).toInt())),
        date: DateTime.fromMillisecondsSinceEpoch((j['date'] as num?)?.toInt() ?? nowMs()),
      );
}

/// Sổ chung cho cặp đôi / gia đình / nhóm đi chơi.
class Group {
  String id;
  String name;
  List<String> members;
  List<GroupExpense> expenses;
  int updatedAt;
  bool deleted;
  Group({required this.id, required this.name, required this.members, List<GroupExpense>? expenses, int? updatedAt, this.deleted = false})
      : expenses = expenses ?? [],
        updatedAt = updatedAt ?? nowMs();

  int get total => expenses.fold(0, (s, e) => s + e.amount);

  /// Số dư mỗi người: dương = được nhận lại, âm = đang nợ.
  Map<String, int> balances() {
    final b = {for (final m in members) m: 0};
    for (final e in expenses) {
      b[e.payer] = (b[e.payer] ?? 0) + e.amount;
      e.shares.forEach((m, v) => b[m] = (b[m] ?? 0) - v);
    }
    return b;
  }

  /// Ai trả ai bao nhiêu để chốt sổ, với số lần chuyển khoản ít nhất (tham lam).
  List<({String from, String to, int amount})> settle() {
    final b = balances();
    final cred = b.entries.where((e) => e.value > 0).map((e) => [e.key, e.value]).toList()
      ..sort((x, y) => (y[1] as int).compareTo(x[1] as int));
    final debt = b.entries.where((e) => e.value < 0).map((e) => [e.key, -e.value]).toList()
      ..sort((x, y) => (y[1] as int).compareTo(x[1] as int));
    final out = <({String from, String to, int amount})>[];
    var i = 0, j = 0;
    while (i < debt.length && j < cred.length) {
      final pay = (debt[i][1] as int) < (cred[j][1] as int) ? debt[i][1] as int : cred[j][1] as int;
      if (pay > 0) out.add((from: debt[i][0] as String, to: cred[j][0] as String, amount: pay));
      debt[i][1] = (debt[i][1] as int) - pay;
      cred[j][1] = (cred[j][1] as int) - pay;
      if (debt[i][1] == 0) i++;
      if (cred[j][1] == 0) j++;
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'u': updatedAt,
        'del': deleted,
      };
  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'] as String,
        name: (j['name'] ?? 'Sổ chung') as String,
        members: ((j['members'] as List?) ?? []).map((e) => e.toString()).toList(),
        expenses: ((j['expenses'] as List?) ?? []).map((e) => GroupExpense.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['del'] == true,
      );
}


/// Khoản định kỳ: gói đăng ký (Netflix, gym...) hoặc trả góp còn N kỳ.
class Bill {
  String id;
  String name;
  int amount;
  String cycle; // month | year | week
  DateTime next; // ngày đến hạn kế tiếp
  int? remaining; // trả góp: số kỳ còn lại; null = gói đăng ký không thời hạn
  String categoryId;
  int updatedAt;
  bool deleted;
  Bill({
    required this.id,
    required this.name,
    required this.amount,
    this.cycle = 'month',
    required this.next,
    this.remaining,
    this.categoryId = 'hoa_don',
    int? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? nowMs();

  bool get isInstallment => remaining != null;
  bool get finished => remaining != null && remaining! <= 0;

  DateTime after(DateTime d) => switch (cycle) {
        'year' => DateTime(d.year + 1, d.month, d.day),
        'week' => d.add(const Duration(days: 7)),
        _ => DateTime(d.year, d.month + 1, d.day),
      };

  /// Các ngày đến hạn trong [from, to).
  List<DateTime> dueBetween(DateTime from, DateTime to) {
    final out = <DateTime>[];
    var d = next;
    var left = remaining;
    var guard = 0;
    while (d.isBefore(to) && guard++ < 400) {
      if (left != null && left <= 0) break;
      if (!d.isBefore(from)) out.add(d);
      d = after(d);
      if (left != null) left--;
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'cycle': cycle,
        'next': next.millisecondsSinceEpoch,
        if (remaining != null) 'left': remaining,
        'cat': categoryId,
        'u': updatedAt,
        'del': deleted,
      };
  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        cycle: (j['cycle'] ?? 'month') as String,
        next: DateTime.fromMillisecondsSinceEpoch((j['next'] as num?)?.toInt() ?? nowMs()),
        remaining: (j['left'] as num?)?.toInt(),
        categoryId: (j['cat'] ?? 'hoa_don') as String,
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['del'] == true,
      );
}

/// Món muốn mua, chờ 48 giờ "làm nguội" trước khi quyết định. Sau khi mua thì theo dõi số lần dùng.
class Wish {
  String id;
  String name;
  int price;
  DateTime created;
  String status; // waiting | bought | skipped
  DateTime? decidedAt;
  int uses;
  int updatedAt;
  bool deleted;
  Wish({
    required this.id,
    required this.name,
    required this.price,
    DateTime? created,
    this.status = 'waiting',
    this.decidedAt,
    this.uses = 0,
    int? updatedAt,
    this.deleted = false,
  })  : created = created ?? DateTime.now(),
        updatedAt = updatedAt ?? nowMs();

  static const cooldown = Duration(hours: 48);
  DateTime get readyAt => created.add(cooldown);
  bool get ready => DateTime.now().isAfter(readyAt);
  int get costPerUse => uses <= 0 ? price : (price / uses).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'created': created.millisecondsSinceEpoch,
        'status': status,
        if (decidedAt != null) 'decided': decidedAt!.millisecondsSinceEpoch,
        'uses': uses,
        'u': updatedAt,
        'del': deleted,
      };
  factory Wish.fromJson(Map<String, dynamic> j) => Wish(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        price: (j['price'] as num?)?.toInt() ?? 0,
        created: DateTime.fromMillisecondsSinceEpoch((j['created'] as num?)?.toInt() ?? nowMs()),
        status: (j['status'] ?? 'waiting') as String,
        decidedAt: j['decided'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j['decided'] as num).toInt()),
        uses: (j['uses'] as num?)?.toInt() ?? 0,
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['del'] == true,
      );
}

/// Một lần mừng / được mừng trong sổ hiếu hỉ.
class GiftEntry {
  String id;
  String person;
  String event; // cuoi | day_thang | tan_gia | sinh_nhat | ma_chay | om_dau | khac
  bool given; // true: mình mừng họ; false: họ mừng mình
  int amount;
  DateTime date;
  String note;
  DateTime? remind; // ngày sắp tới của người đó (VD đám cưới họ) để nhắc
  int updatedAt;
  bool deleted;
  GiftEntry({
    required this.id,
    required this.person,
    this.event = 'cuoi',
    this.given = true,
    required this.amount,
    required this.date,
    this.note = '',
    this.remind,
    int? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? nowMs();

  Map<String, dynamic> toJson() => {
        'id': id,
        'person': person,
        'event': event,
        'given': given,
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        if (remind != null) 'remind': remind!.millisecondsSinceEpoch,
        'u': updatedAt,
        'del': deleted,
      };
  factory GiftEntry.fromJson(Map<String, dynamic> j) => GiftEntry(
        id: j['id'] as String,
        person: (j['person'] ?? '') as String,
        event: (j['event'] ?? 'khac') as String,
        given: j['given'] != false,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        date: DateTime.fromMillisecondsSinceEpoch((j['date'] as num?)?.toInt() ?? nowMs()),
        note: (j['note'] ?? '') as String,
        remind: j['remind'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j['remind'] as num).toInt()),
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['del'] == true,
      );
}

const Map<String, String> kGiftEvents = {
  'cuoi': 'Đám cưới',
  'day_thang': 'Đầy tháng / thôi nôi',
  'tan_gia': 'Tân gia',
  'sinh_nhat': 'Sinh nhật',
  'om_dau': 'Thăm ốm',
  'ma_chay': 'Đám hiếu',
  'khac': 'Dịp khác',
};
