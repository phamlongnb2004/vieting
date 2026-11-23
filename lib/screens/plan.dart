import 'package:flutter/material.dart' hide Text, InputDecoration;
import 'package:vieting/i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'bills.dart';
import 'budgets.dart';
import 'gifts.dart';
import 'goals.dart';
import 'groups.dart';
import 'habits.dart';
import 'spaces.dart';
import 'wishlist.dart';

/// Tab "Kế hoạch": ngân sách, hũ mục tiêu, thói quen & thử thách, sổ chung.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kế hoạch', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(PhosphorIconsRegular.piggyBank), child: Text('Ngân sách')),
              Tab(icon: Icon(PhosphorIconsRegular.tree), child: Text('Mục tiêu')),
              Tab(icon: Icon(PhosphorIconsRegular.fire), child: Text('Thói quen')),
              Tab(icon: Icon(PhosphorIconsRegular.arrowsClockwise), child: Text('Định kỳ')),
              Tab(icon: Icon(PhosphorIconsRegular.snowflake), child: Text('Chờ mua')),
              Tab(icon: Icon(PhosphorIconsRegular.handshake), child: Text('Quỹ chung')),
              Tab(icon: Icon(PhosphorIconsRegular.usersThree), child: Text('Chia tiền')),
              Tab(icon: Icon(PhosphorIconsRegular.gift), child: Text('Hiếu hỉ')),
            ],
          ),
        ),
        body: const TabBarView(children: [
          BudgetsScreen(embedded: true),
          GoalsScreen(embedded: true),
          HabitsScreen(embedded: true),
          BillsScreen(embedded: true),
          WishlistScreen(embedded: true),
          SpacesScreen(embedded: true),
          GroupsScreen(embedded: true),
          GiftsScreen(embedded: true),
        ]),
      ),
    );
  }
}
