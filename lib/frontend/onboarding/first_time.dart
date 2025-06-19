import 'dart:math' as math;
import 'dart:math';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

// Add this import - adjust path as needed for your project structure
import 'package:connect_ed_2/frontend/onboarding/setup_link.dart';

class FirstTimePage extends StatefulWidget {
  const FirstTimePage({super.key});

  @override
  State<FirstTimePage> createState() => _FirstTimePageState();
}

class _FirstTimePageState extends State<FirstTimePage>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _pulseController;
  late AnimationController _explosionController;
  final List<Particle> _particles = [];
  final Random _random = Random();
  late Size _screenSize;
  bool _isExploding = false;
  final GlobalKey _typewriterKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Main particle animation controller
    _particleController = AnimationController(
      duration: const Duration(seconds: 45),
      vsync: this,
    );

    // Pulse animation for breathing effect
    _pulseController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );

    // Explosion animation controller
    _explosionController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Start animations
    _particleController.repeat();
    _pulseController.repeat();

    // Initialize particles after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeParticles();
    });

    // Listen for explosion completion
    _explosionController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // Add a small delay to ensure all animations complete
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            // Navigate to LinkPage after explosion
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        const LinkPage(),
                transitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // Stop repeating animations before disposal
    if (_particleController.isAnimating) {
      _particleController.stop();
    }
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }

    _particleController.dispose();
    _pulseController.dispose();
    _explosionController.dispose();
    super.dispose();
  }

  void _onTapScreen() {
    if (!_isExploding && mounted) {
      // Immediately hide TypewriterText to prevent async issues
      setState(() {
        _isExploding = true;
      });

      // Start explosion animation after state update
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _explosionController.isCompleted == false) {
          _explosionController.forward();
        }
      });
    }
  }

  void _initializeParticles() {
    _particles.clear();
    const int particleCount = 20000; // Many more particles for dense cloud

    for (int i = 0; i < particleCount; i++) {
      // Generate particles with bias toward sphere surface
      final double phi = _random.nextDouble() * 2 * math.pi; // Azimuthal angle
      final double cosTheta =
          (_random.nextDouble() * 2) - 1; // Polar angle cosine

      // Bias radius toward surface (higher concentration near r=1)
      double r;
      if (_random.nextDouble() < 0.7) {
        // 70% of particles near surface
        r = 0.7 + (_random.nextDouble() * 0.3); // 0.7 to 1.0
      } else {
        // 30% scattered throughout
        r = _random.nextDouble(); // 0.0 to 1.0
      }

      final double theta = math.acos(cosTheta);
      final double x = r * math.sin(theta) * math.cos(phi);
      final double y = r * math.sin(theta) * math.sin(phi);
      final double z = r * cosTheta;

      _particles.add(
        Particle(
          x: x,
          y: y,
          z: z,
          radius: _random.nextDouble() * 1.5 + 0.3,
          baseOpacity: _random.nextDouble() * 0.5 + 0.3,

          // Independent movement parameters
          orbitSpeed: _random.nextDouble() * 0.4 + 0.1,
          orbitRadius: _random.nextDouble() * 0.2 + 0.05,
          driftSpeed: _random.nextDouble() * 0.3 + 0.1,
          phase: _random.nextDouble() * 2 * math.pi,
          pulseSpeed: _random.nextDouble() * 0.8 + 0.4,

          // Store original position for orbital motion
          centerX: x,
          centerY: y,
          centerZ: z,

          // Independent rotation axes
          rotAxisX: _random.nextDouble() * 2 - 1,
          rotAxisY: _random.nextDouble() * 2 - 1,
          rotAxisZ: _random.nextDouble() * 2 - 1,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: _onTapScreen,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _particleController,
                  _pulseController,
                  _explosionController,
                ]),
                builder: (context, child) {
                  return CustomPaint(
                    painter: ParticleCloudPainter(
                      particles: _particles,
                      animationValue: _particleController.value,
                      pulseValue: _pulseController.value,
                      explosionValue: _explosionController.value,
                      isExploding: _isExploding,
                      screenSize: _screenSize,
                    ),
                    size: Size(180, 180), // Slightly smaller for better focus
                  );
                },
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isExploding
                      ? const SizedBox.shrink() // Explicitly empty widget when exploding
                      : TypewriterText(
                        key: _typewriterKey,
                        texts: ['Hello', 'Tap to get started'],
                        textStyle: Theme.of(context).textTheme.bodyLarge,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Particle {
  double x;
  double y;
  double z;
  final double radius;
  final double baseOpacity;

  // Independent movement properties
  final double orbitSpeed;
  final double orbitRadius;
  final double driftSpeed;
  final double phase;
  final double pulseSpeed;

  // Original center position for orbital motion
  final double centerX;
  final double centerY;
  final double centerZ;

  // Independent rotation axis
  final double rotAxisX;
  final double rotAxisY;
  final double rotAxisZ;

  // Explosion properties
  late double explosionX;
  late double explosionY;
  late double explosionZ;
  late double explosionSpeed;
  late double explosionDelay;
  late double explosionScale;
  late Color explosionColor;

  double age = 0;

  Particle({
    required this.x,
    required this.y,
    required this.z,
    required this.radius,
    required this.baseOpacity,
    required this.orbitSpeed,
    required this.orbitRadius,
    required this.driftSpeed,
    required this.phase,
    required this.pulseSpeed,
    required this.centerX,
    required this.centerY,
    required this.centerZ,
    required this.rotAxisX,
    required this.rotAxisY,
    required this.rotAxisZ,
  }) {
    final random = Random();

    // Calculate explosion direction (outward from center)
    final distance = math.sqrt(x * x + y * y + z * z);
    if (distance > 0) {
      explosionX = x / distance;
      explosionY = y / distance;
      explosionZ = z / distance;
    } else {
      explosionX = 1;
      explosionY = 0;
      explosionZ = 0;
    }

    // Vary explosion properties for more dynamic effect
    explosionSpeed = 0.6 + (random.nextDouble() * 0.8); // 0.6 to 1.4
    explosionDelay = random.nextDouble() * 0.3; // Staggered explosion start
    explosionScale = 0.8 + (random.nextDouble() * 0.4); // Size variation

    // Assign explosion colors based on particle position/properties
    final colorVariant = random.nextDouble();
    if (colorVariant < 0.3) {
      explosionColor = const Color(0xFFFFD700); // Gold
    } else if (colorVariant < 0.6) {
      explosionColor = const Color(0xFFFF6B47); // Orange-red
    } else {
      explosionColor = const Color(0xFF87CEEB); // Light blue
    }
  }
}

class ParticleCloudPainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;
  final double pulseValue;
  final double explosionValue;
  final bool isExploding;
  final Size screenSize;

  ParticleCloudPainter({
    required this.particles,
    required this.animationValue,
    required this.pulseValue,
    required this.explosionValue,
    required this.isExploding,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double sphereRadius = 100; // Base radius of the sphere

    // Global breathing effect (disabled during explosion)
    final double globalBreath =
        isExploding
            ? 1.0
            : 1 + (math.sin(pulseValue * 2 * math.pi * 0.5) * 0.1);
    final double currentSphereRadius = sphereRadius * globalBreath;

    // Sort particles by z-depth for proper rendering
    particles.sort((a, b) => a.z.compareTo(b.z));

    // Update and draw each particle
    for (final particle in particles) {
      // Update particle position with independent movement
      _updateParticlePosition(particle);

      // Convert 3D position to 2D screen coordinates
      final double screenX = centerX + (particle.x * currentSphereRadius);
      final double screenY = centerY + (particle.y * currentSphereRadius);
      final double depth =
          (particle.z + 1.2) / 2.4; // Normalize z with some padding

      // Calculate particle size based on depth and distance from center
      final double distanceFromCenter = math.sqrt(
        particle.x * particle.x +
            particle.y * particle.y +
            particle.z * particle.z,
      );

      // Enhanced size calculation with explosion effects
      double sizeMultiplier = 0.4 + (depth * 0.6);
      if (isExploding) {
        sizeMultiplier *= _getExplosionSizeMultiplier(particle);
      }
      final double particleSize = particle.radius * sizeMultiplier;

      // Enhanced opacity calculation
      final double baseOpacityCalc = _calculateBaseOpacity(
        particle,
        depth,
        distanceFromCenter,
      );
      final double explosionOpacity = _getExplosionOpacity(particle);
      final double finalOpacity = baseOpacityCalc * explosionOpacity;

      // Skip drawing if opacity is too low
      if (finalOpacity < 0.01) continue;

      // Enhanced color calculation
      final Color color = _getEnhancedParticleColor(
        particle,
        depth,
        distanceFromCenter,
      );

      // Draw particle with enhanced effects
      _drawEnhancedParticle(
        canvas,
        paint,
        Offset(screenX, screenY),
        particleSize,
        color,
        finalOpacity,
        particle,
      );
    }
  }

  double _getExplosionSizeMultiplier(Particle particle) {
    final adjustedProgress = math.max(
      0.0,
      explosionValue - particle.explosionDelay,
    );
    final normalizedProgress = math.min(
      1.0,
      adjustedProgress / (1.0 - particle.explosionDelay),
    );

    if (normalizedProgress <= 0) return 1.0;

    // Three-phase size animation: rapid growth, sustain, rapid shrink
    if (normalizedProgress < 0.2) {
      // Rapid growth phase with elastic easing
      final phase = normalizedProgress / 0.2;
      final elasticGrow = _elasticOut(phase);
      return 1.0 + (elasticGrow * 2.5 * particle.explosionScale);
    } else if (normalizedProgress < 0.4) {
      // Sustain phase with slight breathing
      final sustainPhase = (normalizedProgress - 0.2) / 0.2;
      final breathe = 1.0 + (math.sin(sustainPhase * math.pi * 4) * 0.1);
      return (1.0 + 2.5 * particle.explosionScale) * breathe;
    } else {
      // Rapid shrink phase with exponential decay
      final shrinkPhase = (normalizedProgress - 0.4) / 0.6;
      final exponentialDecay = math.pow(1 - shrinkPhase, 3);
      return (1.0 + 2.5 * particle.explosionScale) * exponentialDecay;
    }
  }

  double _getExplosionOpacity(Particle particle) {
    if (!isExploding) return 1.0;

    final adjustedProgress = math.max(
      0.0,
      explosionValue - particle.explosionDelay,
    );
    final normalizedProgress = math.min(
      1.0,
      adjustedProgress / (1.0 - particle.explosionDelay),
    );

    if (normalizedProgress <= 0) return 1.0;

    // Four-phase opacity: flash, sustain, fade, disappear
    if (normalizedProgress < 0.1) {
      // Initial bright flash
      final flashPhase = normalizedProgress / 0.1;
      return 1.0 + (flashPhase * 1.5); // Up to 2.5x brightness
    } else if (normalizedProgress < 0.3) {
      // Sustain bright phase
      final sustainPhase = (normalizedProgress - 0.1) / 0.2;
      return 2.5 - (sustainPhase * 0.5); // Fade from 2.5x to 2.0x
    } else if (normalizedProgress < 0.7) {
      // Gradual fade
      final fadePhase = (normalizedProgress - 0.3) / 0.4;
      final smoothFade = 1.0 - _smoothStep(fadePhase);
      return 2.0 * smoothFade;
    } else {
      // Rapid disappear
      final disappearPhase = (normalizedProgress - 0.7) / 0.3;
      final rapidFade = math.pow(1 - disappearPhase, 2);
      return 2.0 * rapidFade;
    }
  }

  double _calculateBaseOpacity(
    Particle particle,
    double depth,
    double distanceFromCenter,
  ) {
    final double depthOpacity = math.max(
      0.2,
      math.min(1.0, 0.4 + (depth * 0.6)),
    );
    final double distanceOpacity = math.max(0.3, 1.2 - distanceFromCenter);
    final double pulseOpacity = _getOpacityMultiplier(particle);

    return particle.baseOpacity * depthOpacity * distanceOpacity * pulseOpacity;
  }

  Color _getEnhancedParticleColor(
    Particle particle,
    double depth,
    double distanceFromCenter,
  ) {
    final double colorMix = (depth + (1 - distanceFromCenter)) * 0.5;

    if (isExploding) {
      final adjustedProgress = math.max(
        0.0,
        explosionValue - particle.explosionDelay,
      );
      final normalizedProgress = math.min(
        1.0,
        adjustedProgress / (1.0 - particle.explosionDelay),
      );

      if (normalizedProgress <= 0) {
        // Pre-explosion: normal colors
        return _getNormalParticleColor(colorMix);
      } else if (normalizedProgress < 0.2) {
        // Flash phase: bright explosion colors
        final flashIntensity = normalizedProgress / 0.2;
        return Color.lerp(
              _getNormalParticleColor(colorMix),
              particle.explosionColor,
              flashIntensity,
            ) ??
            particle.explosionColor;
      } else if (normalizedProgress < 0.5) {
        // Peak explosion: full explosion color
        return particle.explosionColor;
      } else {
        // Fade phase: back to cooler colors
        final fadeIntensity = (normalizedProgress - 0.5) / 0.5;
        final coolColor =
            Color.lerp(
              const Color(0xFF2E5BBA),
              const Color(0xFF1A365D),
              fadeIntensity,
            ) ??
            const Color(0xFF2E5BBA);

        return Color.lerp(
              particle.explosionColor,
              coolColor,
              _smoothStep(fadeIntensity),
            ) ??
            coolColor;
      }
    }

    return _getNormalParticleColor(colorMix);
  }

  Color _getNormalParticleColor(double colorMix) {
    return Color.lerp(
          const Color(0xFF5BA3F5).withValues(alpha: 0.9),
          const Color(0xFF2E5BBA).withValues(alpha: 0.8),
          colorMix,
        ) ??
        const Color(0xFF4A90E2);
  }

  void _drawEnhancedParticle(
    Canvas canvas,
    Paint paint,
    Offset center,
    double size,
    Color color,
    double opacity,
    Particle particle,
  ) {
    // Clamp opacity to valid range
    final clampedOpacity = math.max(0.0, math.min(1.0, opacity));

    if (isExploding) {
      final adjustedProgress = math.max(
        0.0,
        explosionValue - particle.explosionDelay,
      );
      final normalizedProgress = math.min(
        1.0,
        adjustedProgress / (1.0 - particle.explosionDelay),
      );

      if (normalizedProgress > 0.1 && normalizedProgress < 0.8) {
        // Draw motion blur/streak effect during active explosion phase
        _drawParticleStreak(
          canvas,
          paint,
          center,
          size,
          color,
          clampedOpacity,
          particle,
          normalizedProgress,
        );
      }
    }

    // Draw main particle with enhanced gradient
    final gradient = RadialGradient(
      colors: [
        color.withValues(alpha: clampedOpacity),
        color.withValues(alpha: clampedOpacity * 0.6),
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final rect = Rect.fromCircle(center: center, radius: size);
    paint.shader = gradient.createShader(rect);
    canvas.drawCircle(center, size, paint);
  }

  void _drawParticleStreak(
    Canvas canvas,
    Paint paint,
    Offset center,
    double size,
    Color color,
    double opacity,
    Particle particle,
    double progress,
  ) {
    // Calculate previous position for streak effect
    final streakLength = size * 2 * progress;
    final streakDirection = Offset(-particle.explosionX, -particle.explosionY);
    final streakEnd = center + (streakDirection * streakLength);

    // Create streak gradient
    final streakGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: opacity * 0.4),
        color.withValues(alpha: opacity * 0.8),
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    // Draw streak as elongated oval
    final streakRect = Rect.fromPoints(streakEnd, center);
    paint.shader = streakGradient.createShader(streakRect);

    final path = Path();
    path.addOval(
      Rect.fromCenter(
        center: Offset.lerp(streakEnd, center, 0.5)!,
        width: streakLength,
        height: size * 0.3,
      ),
    );

    canvas.drawPath(path, paint);
  }

  // Easing functions for more professional animations
  double _elasticOut(double t) {
    const c4 = (2 * math.pi) / 3;
    return t == 0
        ? 0
        : t == 1
        ? 1
        : math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1;
  }

  double _smoothStep(double t) {
    return t * t * (3.0 - 2.0 * t);
  }

  void _updateParticlePosition(Particle particle) {
    particle.age += 0.016; // Assuming 60fps

    if (isExploding) {
      // Enhanced explosion dynamics with staggered timing
      final adjustedProgress = math.max(
        0.0,
        explosionValue - particle.explosionDelay,
      );
      final normalizedProgress = math.min(
        1.0,
        adjustedProgress / (1.0 - particle.explosionDelay),
      );

      if (normalizedProgress > 0) {
        // Multi-phase explosion movement with improved easing
        double easedProgress;
        if (normalizedProgress < 0.3) {
          // Acceleration phase
          easedProgress = _smoothStep(normalizedProgress / 0.3);
        } else if (normalizedProgress < 0.7) {
          // Constant velocity phase
          easedProgress = 1.0;
        } else {
          // Deceleration phase
          final decelerationPhase = (normalizedProgress - 0.7) / 0.3;
          easedProgress = 1.0 - (decelerationPhase * 0.3); // Slight slowdown
        }

        // Calculate explosion distance with enhanced dynamics
        final maxDistance =
            particle.explosionSpeed * 12; // Increased max distance
        final explosionDistance =
            easedProgress * maxDistance * normalizedProgress;

        // Add slight randomization for more natural movement
        final wobble =
            math.sin(normalizedProgress * math.pi * 6) *
            0.1 *
            normalizedProgress;

        // Update position with wobble effect
        particle.x =
            particle.centerX +
            (particle.explosionX * explosionDistance) +
            (wobble * particle.explosionY);
        particle.y =
            particle.centerY +
            (particle.explosionY * explosionDistance) +
            (wobble * particle.explosionX);
        particle.z =
            particle.centerZ +
            (particle.explosionZ * explosionDistance) +
            (wobble * 0.5);
      }
    } else {
      // Normal particle behavior (unchanged)
      final time = animationValue * 2 * math.pi;

      // Independent orbital motion around particle's center
      final double orbitTime = time * particle.orbitSpeed + particle.phase;
      final double driftTime =
          time * particle.driftSpeed + particle.phase * 0.7;

      // Create orbital motion in 3D space
      final double orbitX = math.cos(orbitTime) * particle.orbitRadius;
      final double orbitY = math.sin(orbitTime * 1.3) * particle.orbitRadius;
      final double orbitZ = math.sin(orbitTime * 0.8) * particle.orbitRadius;

      // Add gentle drift motion
      final double driftX = math.sin(driftTime * 0.6) * 0.1;
      final double driftY = math.cos(driftTime * 0.4) * 0.1;
      final double driftZ = math.sin(driftTime * 0.9) * 0.1;

      // Combine center position with orbital and drift motion
      particle.x = particle.centerX + orbitX + driftX;
      particle.y = particle.centerY + orbitY + driftY;
      particle.z = particle.centerZ + orbitZ + driftZ;

      // Apply gentle attraction back toward sphere
      final double distanceFromOrigin = math.sqrt(
        particle.x * particle.x +
            particle.y * particle.y +
            particle.z * particle.z,
      );

      if (distanceFromOrigin > 1.2) {
        final double pullStrength = 0.02;
        particle.x -= particle.x * pullStrength;
        particle.y -= particle.y * pullStrength;
        particle.z -= particle.z * pullStrength;
      }
    }
  }

  double _getOpacityMultiplier(Particle particle) {
    // Individual particle pulsing (disabled during explosion)
    if (isExploding) return 1.0;

    final pulseFactor = math.sin(
      pulseValue * 2 * math.pi * particle.pulseSpeed + particle.phase,
    );
    return 0.85 + (pulseFactor * 0.15);
  }

  @override
  bool shouldRepaint(ParticleCloudPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.explosionValue != explosionValue ||
        oldDelegate.isExploding != isExploding;
  }
}
