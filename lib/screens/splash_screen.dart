import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_strings.dart';
import '../services/settings_service.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _timer = Timer(const Duration(milliseconds: 750), () {
      _fadeController.forward().then((_) {
        if (mounted) {
          final showOnboarding =
              !SettingsService.instance.onboardingCompleted.value;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  showOnboarding ? const OnboardingScreen() : const HomeShell(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    const backgroundColor = Color(0xFFFFF8E7);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 120,
                  height: 120,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.appName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A3266),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
