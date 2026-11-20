import 'package:flutter/material.dart';

import 'budgets.dart';
import 'goals.dart';
import 'groups.dart';
import 'habits.dart';

/// Tab "Kế hoạch": ngân sách, hũ mục tiêu, thói quen & thử thách, sổ chung.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kế hoạch', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.savings_outlined), text: 'Ngân sách'),
              Tab(icon: Icon(Icons.forest_outlined), text: 'Mục tiêu'),
              Tab(icon: Icon(Icons.local_fire_department_outlined), text: 'Thói quen'),
              Tab(icon: Icon(Icons.groups_2_outlined), text: 'Sổ chung'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          BudgetsScreen(embedded: true),
          GoalsScreen(embedded: true),
          HabitsScreen(embedded: true),
          GroupsScreen(embedded: true),
        ]),
      ),
    );
  }
}
