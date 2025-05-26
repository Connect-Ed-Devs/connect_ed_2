import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:connect_ed_2/frontend/setup/opacity_button.dart'; // Import OpacityTextButton
import 'package:connect_ed_2/requests/url_check.dart'; // Import checkLink
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect_ed_2/main.dart'; // For accessing the global 'prefs'
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _calendarLinkController;
  bool _isCalendarLinkEntered = false;

  @override
  void initState() {
    super.initState();
    _calendarLinkController = TextEditingController();
    _calendarLinkController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    setState(() {
      _isCalendarLinkEntered = _calendarLinkController.text.isNotEmpty;
    });
  }

  Future<void> _saveCalendarLink() async {
    final newLink = _calendarLinkController.text;
    // Button should be disabled if newLink is empty, but this is a safeguard.
    if (newLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calendar link cannot be empty.')));
      return;
    }

    // Show "Checking link..." dialog
    // Use a different context for the dialog to ensure it can be popped correctly.
    showDialog(
      context: context,
      barrierDismissible: false, // User cannot dismiss by tapping outside
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          alignment: Alignment.center,
          content: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Ensure the Row takes minimum horizontal space
              children: const [
                SizedBox(height: 24, width: 24, child: CircularProgressIndicator()),
                SizedBox(width: 20),
                Text("Checking link...", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );

    try {
      bool isValid = await checkLink(newLink);
      if (mounted) {
        // Check if the widget is still in the tree
        Navigator.of(context).pop(); // Dismiss the "Checking link..." dialog
      }

      if (isValid) {
        await prefs.setString('calendar_link', newLink);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Calendar link verified and saved successfully.')));
        }
        _calendarLinkController.clear(); // Clear field on success, which will also update button state
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid calendar link. Please check the URL and try again.')));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Ensure dialog is dismissed on error too
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: ${e.toString()}')));
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
      }
    }
  }

  @override
  void dispose() {
    _calendarLinkController.removeListener(_updateButtonState);
    _calendarLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          CEAppBar(title: 'Settings', showBackButton: true, onBackPressed: () => Navigator.of(context).pop()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calendar Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                  Text(
                    'Update the iCalendar (iCal) link used for fetching your schedule and assessments.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _calendarLinkController,
                          decoration: const InputDecoration(
                            labelText: 'Calendar Link (iCal URL)',
                            hintText: 'https://example.com/path/to/calendar.ics',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.url,
                          minLines: 1,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8), // Spacing between text field and button
                      OpacityTextButton(
                        text: "Save",
                        onPressed: _isCalendarLinkEntered ? _saveCalendarLink : () {}, // Pass null when disabled
                        color: _isCalendarLinkEntered ? Theme.of(context).colorScheme.primary : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ],
                  ),
                  const SizedBox(height: 64), // Increased spacing before next section
                  // Feedback and Bug Reports Section
                  Text('Feedback and Bugs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(
                    'Help us improve Connect-Ed by sharing your thoughts or reporting any issues you encounter.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OpacityTextButton(
                        text: "Feedback Form",
                        onPressed: () {
                          // Replace with your actual feedback form URL
                          _launchURL('https://forms.office.com/r/0BqkWRaEL3');
                        },
                        color: Theme.of(context).colorScheme.primary, // Style as a link
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      Spacer(), // Spacing between buttons
                      OpacityTextButton(
                        text: "Bug Report",
                        onPressed: () {
                          // Replace with your actual bug report form URL
                          _launchURL('https://forms.office.com/r/cn2xNd2M2V');
                        },
                        color: Theme.of(context).colorScheme.primary, // Style as a link
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  const SizedBox(height: 24), // Spacing at the end
                  // Text('Other settings content will go here.', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 64)), // Add some space before the footer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Made by Abdur-Rahman Rana '25\n and Demilade Olawumni '25",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
