
// ===== VieTing: ghi nhanh không cần mở app (App Intents) =====
// Dùng được trong app Phím tắt, Siri, nút Tác vụ (Action Button) và "Chạm vào mặt sau" (Back Tap).
// Khoản ghi được xếp hàng trong UserDefaults ("flutter.vt_quick"); lần mở app tiếp theo VieTing tự ghi vào sổ.
// Tác giả: Phạm Thành Long (thlong)

enum VieTingQuickQueue {
  static let key = "flutter.vt_quick"

  static func push(amount: Int, note: String, income: Bool) {
    let d = UserDefaults.standard
    var arr: [[String: Any]] = []
    if let s = d.string(forKey: key), let data = s.data(using: .utf8),
       let a = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
      arr = a
    }
    arr.append([
      "amount": amount,
      "note": note,
      "income": income,
      "at": Int(Date().timeIntervalSince1970 * 1000),
    ])
    if let data = try? JSONSerialization.data(withJSONObject: arr), let s = String(data: data, encoding: .utf8) {
      d.set(s, forKey: key)
    }
  }

  static func money(_ v: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = "."
    return (f.string(from: NSNumber(value: v)) ?? "\(v)") + " ₫"
  }
}

@available(iOS 16.0, *)
struct VieTingGhiChiIntent: AppIntent {
  static var title: LocalizedStringResource = "Ghi khoản chi"
  static var description = IntentDescription("Ghi nhanh một khoản chi vào VieTing mà không cần mở app.")
  static var openAppWhenRun: Bool = false

  @Parameter(title: "Số tiền (đồng)")
  var amount: Int

  @Parameter(title: "Nội dung")
  var note: String?

  static var parameterSummary: some ParameterSummary {
    Summary("Ghi chi \(\.$amount) đồng") {
      \.$note
    }
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    VieTingQuickQueue.push(amount: amount, note: note ?? "", income: false)
    return .result(dialog: "Đã ghi chi \(VieTingQuickQueue.money(amount)) vào VieTing")
  }
}

@available(iOS 16.0, *)
struct VieTingGhiThuIntent: AppIntent {
  static var title: LocalizedStringResource = "Ghi khoản thu"
  static var description = IntentDescription("Ghi nhanh một khoản tiền vào VieTing mà không cần mở app.")
  static var openAppWhenRun: Bool = false

  @Parameter(title: "Số tiền (đồng)")
  var amount: Int

  @Parameter(title: "Nội dung")
  var note: String?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    VieTingQuickQueue.push(amount: amount, note: note ?? "", income: true)
    return .result(dialog: "Đã ghi thu \(VieTingQuickQueue.money(amount)) vào VieTing")
  }
}

@available(iOS 16.0, *)
struct VieTingShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: VieTingGhiChiIntent(),
      phrases: ["Ghi chi tiêu với \(.applicationName)", "\(.applicationName) ghi chi"]
    )
    AppShortcut(
      intent: VieTingGhiThuIntent(),
      phrases: ["Ghi khoản thu với \(.applicationName)", "\(.applicationName) ghi thu"]
    )
  }
}
