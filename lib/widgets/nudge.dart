import 'package:flutter/material.dart';

import '../insights.dart';
import '../ui_keys.dart';

/// Hiện cảnh báo cố vấn (sắp vượt ngân sách, chi bất thường...) ngay sau khi ghi giao dịch.
void showNudges(List<Nudge> nudges) {
  if (nudges.isEmpty) return;
  final m = messengerKey.currentState;
  if (m == null) return;
  final serious = nudges.any((n) => n.serious);
  m.showSnackBar(SnackBar(
    duration: const Duration(seconds: 7),
    backgroundColor: serious ? const Color(0xFF8E1B1F) : const Color(0xFF152758),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final n in nudges)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(n.serious ? Icons.warning_amber_rounded : Icons.lightbulb_outline, color: const Color(0xFFFFCD00), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(n.text, style: const TextStyle(color: Colors.white))),
            ]),
          ),
      ],
    ),
  ));
}
