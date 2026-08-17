import 'package:flutter/material.dart';
import '../workspace/reports_tab.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: ReportsTab(),
      ),
    );
  }
}
