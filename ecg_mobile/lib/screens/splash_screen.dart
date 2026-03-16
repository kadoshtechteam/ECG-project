import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  final List<String> _startupStages = const [
    'Preparing secure local storage',
    'Loading ECG analysis tools',
    'Checking your saved session',
  ];

  int _currentStage = 0;
  double _progress = 0.12;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initializeApp();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _advanceStage(0, 0.28);
    await Future.delayed(const Duration(milliseconds: 450));

    _advanceStage(1, 0.58);
    await Future.delayed(const Duration(milliseconds: 450));

    _advanceStage(2, 0.82);
    await authProvider.initialize();

    _advanceStage(2, 1.0);
    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      authProvider.isLoggedIn ? '/dashboard' : '/login',
    );
  }

  void _advanceStage(int stage, double progress) {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentStage = stage;
      _progress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7B1E3A),
              Color(0xFFD6286C),
              Color(0xFFFF8FAF),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -30,
              child: _GlowOrb(
                size: 220,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -10,
              child: _GlowOrb(
                size: 180,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MLHADP',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: onPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Heart monitoring, signal capture, and prediction setup in one flow.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: onPrimary.withValues(alpha: 0.82),
                        height: 1.45,
                      ),
                    ),
                    const Spacer(),
                    Center(
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 26,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.monitor_heart_rounded,
                                size: 62,
                                color: onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: 300,
                            height: 80,
                            child: CustomPaint(
                              painter: _HeartbeatPainter(
                                progress: _pulseController.value,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Version 1.1',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${(_progress * 100).round()}%',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 8,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.18),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _startupStages[_currentStage],
                              key: ValueKey<int>(_currentStage),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_startupStages.length, (index) {
                            final isActive = index == _currentStage;
                            final isDone =
                                index < _currentStage || _progress >= 1;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    isDone
                                        ? Icons.check_circle
                                        : isActive
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: isDone || isActive
                                        ? onPrimary
                                        : onPrimary.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _startupStages[index],
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: onPrimary.withValues(
                                          alpha:
                                              isDone || isActive ? 0.92 : 0.58,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
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
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  const _HeartbeatPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final baseline = size.height * 0.56;
    final pulseCenter = size.width * (0.12 + (progress * 0.76));

    path.moveTo(0, baseline);

    for (double x = 0; x <= size.width; x += 4) {
      double y = baseline;
      final distance = (x - pulseCenter).abs();

      if (distance < 46) {
        final intensity = 1 - (distance / 46);
        y -= math.sin(intensity * math.pi * 2.2) * 18 * intensity;
        if (distance < 12) {
          y -= 22 * intensity;
        }
      }

      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartbeatPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
