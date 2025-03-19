import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: CustomScrollView(slivers: [CEAppBar(title: "Home")]));
  }
}
