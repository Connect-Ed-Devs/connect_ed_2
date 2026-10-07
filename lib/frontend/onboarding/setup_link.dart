import 'package:carousel_slider/carousel_slider.dart';
import 'package:connect_ed_2/frontend/onboarding/finish_onboarding.dart';
import 'package:connect_ed_2/requests/url_check.dart';
import 'package:connect_ed_2/main.dart'; // Import for global prefs
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LinkPage extends StatefulWidget {
  const LinkPage({super.key});

  @override
  State<LinkPage> createState() => _LinkPageState();
}

class _LinkPageState extends State<LinkPage> with TickerProviderStateMixin {
  String link = '';
  final PageController _pageController = PageController();
  final TextEditingController _linkController = TextEditingController();
  final FocusNode _linkFocusNode = FocusNode();
  int _currentStep = 0;
  bool _isValidating = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _stepImages = [
    'assets/step1.png',
    'assets/step2.png',
    'assets/step3.png',
    'assets/step4.png',
  ];

  final List<String> _stepTitles = [
    'Access Your Portal',
    'Find Calendar',
    'Export Options',
    'Get Your Link',
  ];

  final List<String> _stepDescriptions = [
    'Log into your school portal account using your credentials',
    'Navigate to the calendar page using the main menu',
    'Look for calendar export or WebCal feed options in settings',
    'Click "My Calendars" and the link will be automatically processed',
  ];

  final List<IconData> _stepIcons = [
    Icons.login_rounded,
    Icons.calendar_month_rounded,
    Icons.settings_rounded,
    Icons.link_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    _linkController.addListener(() {
      setState(() {
        link = _linkController.text;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _linkController.dispose();
    _linkFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.surface;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.link_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Calendar Setup',
              style: TextStyle(
                color: textColor,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      backgroundColor: bgColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  child: CECard(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.7,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.school_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Connect Your School Calendar',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontFamily: 'Montserrat',
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Follow the steps below to link your school calendar and stay up to date with all your events.',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Montserrat',
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Enhanced Step Guide
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Setup Guide',
                        style: TextStyle(
                          fontSize: 24,
                          fontFamily: 'Montserrat',
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Swipe through the steps or tap to navigate',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Montserrat',
                          color: textColor.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Enhanced Carousel with better design
                      CarouselSlider.builder(
                        itemCount: _stepImages.length,
                        itemBuilder: (context, index, realIndex) {
                          final isActive = index == _currentStep;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: EdgeInsets.symmetric(
                              horizontal: isActive ? 4 : 8,
                            ),
                            child: CECard(
                              elevation: isActive ? 8 : 4,
                              borderRadius: 20,
                              child: Column(
                                children: [
                                  // Image section
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                                        color:
                                            theme
                                                .colorScheme
                                                .surfaceContainerHighest,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                                        child: Image.asset(
                                          _stepImages[index],
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              color:
                                                  theme
                                                      .colorScheme
                                                      .surfaceContainer,
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              50,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        _stepIcons[index],
                                                        size: 32,
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .primary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      'Step ${index + 1}',
                                                      style: TextStyle(
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontFamily:
                                                            'Montserrat',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Content section
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${index + 1}',
                                                  style: TextStyle(
                                                    color:
                                                        theme
                                                            .colorScheme
                                                            .onPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    fontFamily: 'Montserrat',
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _stepTitles[index],
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontFamily: 'Montserrat',
                                                    color: textColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: Text(
                                              _stepDescriptions[index],
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontFamily: 'Montserrat',
                                                color: textColor.withValues(
                                                  alpha: 0.7,
                                                ),
                                                fontWeight: FontWeight.w500,
                                                height: 1.3,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        options: CarouselOptions(
                          height: 280,
                          viewportFraction: 0.85,
                          enlargeCenterPage: true,
                          enlargeFactor: 0.2,
                          onPageChanged: (index, reason) {
                            setState(() {
                              _currentStep = index;
                            });
                            HapticFeedback.lightImpact();
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Enhanced Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _stepImages.length,
                          (index) => GestureDetector(
                            onTap: () {
                              // Add carousel navigation on tap
                              setState(() {
                                _currentStep = index;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: _currentStep == index ? 32 : 8,
                              decoration: BoxDecoration(
                                color:
                                    _currentStep == index
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Action Buttons Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Portal Button with enhanced design
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OpacityBlockButton(
                          text: 'Open School Portal',
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final result = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WebViewPage(),
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                link = result;
                                _linkController.text = result;
                              });
                              await _validateAndSaveLink(context, result);
                            }
                          },
                          gradientColors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Divider with text
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Manual Link Input Section
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: CECard(
                          padding: const EdgeInsets.all(20),
                          color: theme.colorScheme.surfaceContainer.withValues(
                            alpha: 0.5,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Manual Link Entry',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Montserrat',
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Already have your calendar link? Paste it below:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Montserrat',
                                  color: textColor.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Enhanced TextField
                              TextField(
                                controller: _linkController,
                                focusNode: _linkFocusNode,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  labelText: 'Calendar Link (webcal://...)',
                                  labelStyle: TextStyle(
                                    color: textColor.withValues(alpha: 0.6),
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.link_rounded,
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  suffixIcon:
                                      link.isNotEmpty
                                          ? IconButton(
                                            icon: Icon(
                                              Icons.clear_rounded,
                                              color: theme.colorScheme.outline,
                                            ),
                                            onPressed: () {
                                              _linkController.clear();
                                              setState(() {
                                                link = '';
                                              });
                                            },
                                          )
                                          : null,
                                ),
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.done,
                                onSubmitted:
                                    link.isNotEmpty
                                        ? (value) =>
                                            _validateAndSaveLink(context, value)
                                        : null,
                              ),

                              if (link.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                // Continue Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _isValidating
                                            ? null
                                            : () async {
                                              HapticFeedback.lightImpact();
                                              await _validateAndSaveLink(
                                                context,
                                                link,
                                              );
                                            },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    icon:
                                        _isValidating
                                            ? SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(
                                                      theme
                                                          .colorScheme
                                                          .onPrimary,
                                                    ),
                                              ),
                                            )
                                            : Icon(Icons.arrow_forward_rounded),
                                    label: Text(
                                      _isValidating
                                          ? 'Validating...'
                                          : 'Continue Setup',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _validateAndSaveLink(BuildContext context, String url) async {
    final theme = Theme.of(context);

    setState(() {
      _isValidating = true;
    });

    // Show loading dialog with better design
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Validating Calendar Link',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we verify your calendar link...',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final result = await checkLinkDetailed(url.trim());

      setState(() {
        _isValidating = false;
      });

      Navigator.of(context).pop(); // Close loading dialog

      if (result.ok) {
        // Show animated success feedback
        HapticFeedback.heavyImpact();

        // Show success animation
        await _showSuccessAnimation(context);

        // Save the link using global prefs with new key
        await prefs.setString('link', makeHTTPS(url.trim()));
        await prefs.setBool('setup_complete', true);

        // Navigate to main app
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => FinishPage()),
        );
      } else {
        HapticFeedback.heavyImpact();
        _showErrorDialog(
          context,
          'Calendar Link Rejected',
          result.message,
        );
      }
    } catch (e) {
      setState(() {
        _isValidating = false;
      });

      Navigator.of(context).pop(); // Close loading dialog
      HapticFeedback.heavyImpact();
      _showErrorDialog(
        context,
        'Connection Error',
        'Unable to validate the calendar link. Please check your internet connection and try again.',
      );
    }
  }

  Future<void> _showSuccessAnimation(BuildContext context) async {
    final theme = Theme.of(context);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _AnimatedSuccessDialog(theme: theme);
      },
    );
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.onErrorContainer,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Try Again',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSuccessDialog extends StatefulWidget {
  final ThemeData theme;

  const _AnimatedSuccessDialog({required this.theme});

  @override
  State<_AnimatedSuccessDialog> createState() => _AnimatedSuccessDialogState();
}

class _AnimatedSuccessDialogState extends State<_AnimatedSuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _checkController;
  late AnimationController _splashController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _splashAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _splashController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeInOut),
    );

    _splashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _splashController, curve: Curves.easeOut),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    // Start scale animation
    _scaleController.forward();

    // Wait a bit then start check animation
    await Future.delayed(const Duration(milliseconds: 300));
    _checkController.forward();

    // Start splash animation
    await Future.delayed(const Duration(milliseconds: 200));
    _splashController.forward();

    // Auto close after animation completes
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _scaleAnimation,
            _checkAnimation,
            _splashAnimation,
          ]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Splash effect
                if (_splashAnimation.value > 0)
                  Transform.scale(
                    scale: _splashAnimation.value * 3,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.theme.colorScheme.primary.withValues(
                          alpha: (1 - _splashAnimation.value) * 0.3,
                        ),
                      ),
                    ),
                  ),

                // Main success container
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.theme.colorScheme.primary,
                            widget.theme.colorScheme.primary.withValues(
                              alpha: 0.8,
                            ),
                          ],
                        ),
                      ),
                      child: CustomPaint(
                        painter: CheckmarkPainter(
                          progress: _checkAnimation.value,
                          color: widget.theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),

                // Success text that appears after checkmark
                if (_checkAnimation.value > 0.7)
                  Positioned(
                    bottom: -60,
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _checkController,
                          curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
                        ),
                      ),
                      child: Text(
                        'Calendar Connected!',
                        style: TextStyle(
                          color: widget.theme.colorScheme.onSurface,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final checkmarkSize = size.width * 0.4;

    // Define checkmark path
    final path = Path();
    final startPoint = Offset(center.dx - checkmarkSize * 0.5, center.dy);
    final middlePoint = Offset(
      center.dx - checkmarkSize * 0.1,
      center.dy + checkmarkSize * 0.3,
    );
    final endPoint = Offset(
      center.dx + checkmarkSize * 0.5,
      center.dy - checkmarkSize * 0.3,
    );

    // First line (left part of checkmark)
    if (progress > 0) {
      final firstLineProgress = (progress * 2).clamp(0.0, 1.0);
      final firstLineEnd =
          Offset.lerp(startPoint, middlePoint, firstLineProgress)!;

      path.moveTo(startPoint.dx, startPoint.dy);
      path.lineTo(firstLineEnd.dx, firstLineEnd.dy);
    }

    // Second line (right part of checkmark)
    if (progress > 0.5) {
      final secondLineProgress = ((progress - 0.5) * 2).clamp(0.0, 1.0);
      final secondLineEnd =
          Offset.lerp(middlePoint, endPoint, secondLineProgress)!;

      path.moveTo(middlePoint.dx, middlePoint.dy);
      path.lineTo(secondLineEnd.dx, secondLineEnd.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

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
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
          )
          ..addJavaScriptChannel(
            'Print',
            onMessageReceived: (JavaScriptMessage message) {},
          )
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.web_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'School Portal',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
