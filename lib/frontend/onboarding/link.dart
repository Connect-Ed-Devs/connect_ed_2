// ignore_for_file: use_build_context_synchronously

import 'package:connect_ed_2/frontend/onboarding/finish.dart';
import 'package:connect_ed_2/requests/url_check.dart';
import 'package:connect_ed_2/main.dart'; // Import for global prefs
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LinkPage extends StatefulWidget {
  const LinkPage({super.key});

  @override
  State<LinkPage> createState() => _LinkPageState();
}

class _LinkPageState extends State<LinkPage> {
  String link = "";
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final List<String> _stepImages = ['assets/step1.png', 'assets/step2.png', 'assets/step3.png', 'assets/step4.png'];

  final List<String> _stepDescriptions = [
    "Log into your school portal account",
    "Navigate to the calendar page using the menu",
    "Look for calendar export or WebCal feed options",
    "Click My Calendars and the link will be processed",
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.surface;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                toolbarHeight: 120,
                backgroundColor: bgColor,
                floating: false,
                pinned: true,
                flexibleSpace: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Text(
                        "BBK Link",
                        softWrap: true,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 35,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Image Carousel Section
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      "Setup Guide",
                      style: TextStyle(
                        fontSize: 25,
                        fontFamily: "Montserrat",
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Image Carousel
                    Container(
                      height: 250,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentStep = index;
                          });
                        },
                        itemCount: _stepImages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                _stepImages[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: theme.colorScheme.surfaceVariant,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image_not_supported,
                                            size: 48,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Step ${index + 1}',
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Page Indicator Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _stepImages.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentStep == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color:
                                _currentStep == index
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.primary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Step Description
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${_currentStep + 1}. ${_stepDescriptions[_currentStep]}",
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: "Montserrat",
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SliverPadding(padding: EdgeInsets.all(20)),
              SliverToBoxAdapter(
                child: Center(
                  child: OutlinedButton(
                    onPressed: () async {
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(builder: (context) => WebViewPage()),
                      );
                      if (result != null) {
                        setState(() {
                          link = result;
                        });
                        await _validateAndSaveLink(context, result);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: BorderSide(width: 2, color: theme.colorScheme.primary),
                    ),
                    child: Text(
                      "Go to Portal",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(padding: EdgeInsets.all(30)),
              SliverToBoxAdapter(
                child: Container(
                  height: 120,
                  child: Column(
                    children: [
                      Text(
                        "If the link does not automatically process, paste it here:",
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: "Montserrat",
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        onChanged: (value) {
                          setState(() {
                            link = value;
                          });
                        },
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w400, fontSize: 15),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.only(bottom: 0, left: 10),
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: textColor), gapPadding: 1),
                          label: Text("Calendar Link", style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: OutlinedButton(
                    onPressed: () async {
                      if (link.isNotEmpty) {
                        await _validateAndSaveLink(context, link);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: BorderSide(width: 2, color: theme.colorScheme.primary),
                    ),
                    child: Text(
                      "Continue",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _validateAndSaveLink(BuildContext context, String url) async {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            "Validating link",
            style: TextStyle(fontFamily: "Montserrat", color: theme.colorScheme.onSurface),
          ),
          content: Text(
            "Checking link validity please wait...",
            style: TextStyle(fontFamily: "Montserrat", color: theme.colorScheme.onSurface),
          ),
        );
      },
    );

    try {
      bool isValid = await checkLink(url);
      Navigator.of(context).pop(); // Close loading dialog

      if (isValid) {
        // Save the link using global prefs with new key
        await prefs.setString('link', makeHTTPS(url));
        await prefs.setBool('setup_complete', true);

        // Navigate to main app
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => FinishPage()));
      } else {
        _showErrorDialog(context, "Invalid Link", "The link you entered is invalid. Please try again.");
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorDialog(context, "Error", "An error occurred while validating the link: ${e.toString()}");
    }
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(title, style: TextStyle(fontFamily: "Montserrat", color: theme.colorScheme.onSurface)),
          content: Text(message, style: TextStyle(fontFamily: "Montserrat", color: theme.colorScheme.onSurface)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK", style: TextStyle(fontFamily: "Montserrat", color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }
}

class WebViewPage extends StatefulWidget {
  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setUserAgent(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
          )
          ..addJavaScriptChannel('Print', onMessageReceived: (JavaScriptMessage message) {})
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (NavigationRequest request) {
                if (request.url.startsWith('webcal')) {
                  Navigator.pop(context, request.url);
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse('https://appleby.myschoolapp.com/app/'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Get Calendar URL'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w600,
          fontSize: 24,
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
