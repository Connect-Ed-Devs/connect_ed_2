import 'package:flutter/material.dart';
import 'package:connect_ed_2/main.dart';
import 'package:core_ui/core_ui.dart';

class FinishPage extends StatelessWidget {
  const FinishPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 48),
              Text(
                "You're All Set!",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Montserrat',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                alignment: Alignment.center,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.90,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TypewriterText(
                    texts: [
                      'Your calendar has been successfully connected',
                      'You can now access your schedule, assignments, and other school info',
                      'Press the button below to continue',
                    ],
                    textStyle: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withAlpha(127),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 64),
              OpacityBlockButton(
                text: "Let's Go",
                onPressed: () {
                  prefs.setString('setup', 'complete');
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const MyHomePage()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
