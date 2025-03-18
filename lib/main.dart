import 'package:connect_ed_2/frontend/articles/articles.dart';
import 'package:connect_ed_2/frontend/calendar/calendar.dart';
import 'package:connect_ed_2/frontend/events/events.dart';
import 'package:connect_ed_2/frontend/home/home.dart';
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

  prefs.setString(
    'calendar_link',
    'https://appleby.myschoolapp.com/podium/feed/iCal.aspx?z=rwbg9TXaxP2HmddvSTQ7hag8xBZbtW85mYDkAvSRgQWHFAQLrIAjDzM8j%2ffMmkZ75F1qvYGSl1lZiVeFaSZ4AA%3d%3d',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme:
            MediaQuery.of(context).platformBrightness == Brightness.dark
                ? darkScheme // Use dark scheme when system theme is dark
                : lightScheme, // Use light scheme when system theme is light
        fontFamily: 'Montserrat',
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  List<Widget> pages = [HomePage(), CalendarPage(), EventsPage(), SportsPage(), ArticlesPage()];

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
