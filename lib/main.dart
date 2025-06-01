import 'package:connect_ed_2/frontend/articles/articles.dart';
import 'package:connect_ed_2/frontend/calendar/calendar.dart';
import 'package:connect_ed_2/frontend/events/events.dart';
import 'package:connect_ed_2/frontend/home/home.dart';
import 'package:connect_ed_2/frontend/onboarding/welcome.dart';
import 'package:connect_ed_2/frontend/setup/nav_bar.dart';
import 'package:connect_ed_2/frontend/setup/styles.dart';
import 'package:connect_ed_2/frontend/sports/sports.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase/firebase_options.dart';

// Global SharedPreferences instance
late SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize SharedPreferences before running app
  prefs = await SharedPreferences.getInstance();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Connect-Ed',
      theme: ThemeData(
        colorScheme:
            MediaQuery.of(context).platformBrightness == Brightness.dark
                ? darkScheme
                : lightScheme,
        fontFamily: 'Montserrat',
        useMaterial3: true,
      ),
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {
    // Check if user has completed setup
    final String? setup = prefs.getString('setup');
    final String? link = prefs.getString('link');

    // If no link is saved or setup is not complete, show welcome/setup flow
    if (setup != 'complete') {
      return const WelcomePage();
    }

    return const MyHomePage();
    // return const WelcomePage();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  List<Widget> pages = [HomePage(), CalendarPage(), SportsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content that extends full screen
          pages[_selectedIndex],

          // Navigation bar positioned at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CENavBar(
              selectedIndex: _selectedIndex,
              onIndexChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
