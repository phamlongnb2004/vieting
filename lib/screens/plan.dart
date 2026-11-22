import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'bills.dart';
import 'budgets.dart';
import 'gifts.dart';
import 'goals.dart';
import 'groups.dart';
import 'habits.dart';
import 'wishlist.dart';

/// Tab "Kế hoạch": ngân sách, hũ mục tiêu, thói quen & thử thách, sổ chung.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kế hoạch', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(PhosphorIconsRegular.piggyBank), text: 'Ngân sách'),
              Tab(icon: Icon(PhosphorIconsRegular.tree), text: 'Mục tiêu'),
              Tab(icon: Icon(PhosphorIconsRegular.fire), text: 'Thói quen'),
              Tab(icon: Icon(PhosphorIconsRegular.arrowsClockwise), text: 'Định kỳ'),
              Tab(icon: Icon(PhosphorIconsRegular.snowflake), text: 'Chờ mua'),
              Tab(icon: Icon(PhosphorIconsRegular.usersThree), text: 'Sổ chung'),
              Tab(icon: Icon(PhosphorIconsRegular.gift), text: 'Hiếu hỉ'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          BudgetsScreen(embedded: true),
          GoalsScreen(embedded: true),
          HabitsScreen(embedded: true),
          BillsScreen(embedded: true),
          WishlistScreen(embedded: true),
          GroupsScreen(embedded: true),
          GiftsScreen(embedded: true),
        ]),
      ),
    );
  }
}
