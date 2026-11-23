import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme.dart';

/// Biểu tượng riêng của VieTing (bộ Phosphor, nét đều) đặt trong ô bo tròn màu nhạt.
/// Dùng thay cho emoji của điện thoại để giao diện đồng bộ, không phụ thuộc hãng máy.
class VIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const VIcon(this.icon, {super.key, this.color = Brand.navy, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(size * 0.32)),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: size * 0.55),
      );
}

/// Biểu tượng cho hũ mục tiêu / sự kiện. Dữ liệu cũ lưu emoji nên vẫn đọc được: emoji -> icon.
const kGoalIcons = <String, IconData>{
  'target': PhosphorIconsRegular.target,
  'plane': PhosphorIconsRegular.airplaneTilt,
  'laptop': PhosphorIconsRegular.laptop,
  'moto': PhosphorIconsRegular.motorcycle,
  'home': PhosphorIconsRegular.house,
  'ring': PhosphorIconsRegular.diamond,
  'study': PhosphorIconsRegular.graduationCap,
  'safety': PhosphorIconsRegular.lifebuoy,
  'phone': PhosphorIconsRegular.deviceMobile,
  'gift': PhosphorIconsRegular.gift,
  'tea': PhosphorIconsRegular.coffee,
  'cart': PhosphorIconsRegular.shoppingCartSimple,
  'tet': PhosphorIconsRegular.envelopeSimple,
  'car': PhosphorIconsRegular.car,
  'heart': PhosphorIconsRegular.heart,
  'bamboo': PhosphorIconsRegular.plant,
};

const _emojiToKey = {
  '🎯': 'target', '✈️': 'plane', '💻': 'laptop', '🏍️': 'moto', '🏠': 'home', '💍': 'ring', '🎓': 'study',
  '🛟': 'safety', '📱': 'phone', '🎁': 'gift', '🧋': 'tea', '☕': 'tea', '🛒': 'cart', '🧧': 'tet', '🚗': 'car',
  '💛': 'heart', '🎋': 'bamboo',
};

IconData goalIcon(String key) => kGoalIcons[key] ?? kGoalIcons[_emojiToKey[key] ?? ''] ?? PhosphorIconsRegular.target;
