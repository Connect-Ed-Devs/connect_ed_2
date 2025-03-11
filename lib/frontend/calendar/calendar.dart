import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:flutter/material.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CEAppBar(title: "Calendar", showBackButton: false),
          SliverToBoxAdapter(child: Container(height: 700, color: Colors.grey)),
        ],
      ),
    );
  }
}
