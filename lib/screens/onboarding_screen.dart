import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/settings_service.dart';
import '../utils/app_palette.dart';
import '../widgets/toss_surface_card.dart';
import 'home_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await SettingsService.instance.setOnboardingCompleted(true);
    if (!mounted) return;
    final callback = widget.onFinished;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  void _next() {
    final last = _page == 2;
    if (last) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsService.instance.languageCode,
      builder: (context, languageCode, _) {
        final strings = AppStrings.fromCode(languageCode);
        final pages = [
          _OnboardingPage(
            icon: Icons.edit_note,
            title: strings.onboardingQuickTitle,
            body: strings.onboardingQuickBody,
          ),
          _OnboardingPage(
            icon: Icons.search,
            title: strings.onboardingFindTitle,
            body: strings.onboardingFindBody,
          ),
          _OnboardingPage(
            icon: Icons.settings_outlined,
            title: strings.onboardingBackupTitle,
            body: strings.onboardingBackupBody,
          ),
        ];
        final palette = AppPalette.of(context);
        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: palette.background,
            foregroundColor: palette.textPrimary,
            automaticallyImplyLeading: false,
            centerTitle: true,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              strings.onboardingStartTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: _finish,
                style: TextButton.styleFrom(
                  foregroundColor: palette.textSecondary,
                ),
                child: Text(strings.skip),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SegmentedButton<String>(
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return palette.onAccent;
                        }
                        return palette.textPrimary;
                      }),
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return palette.accent;
                        }
                        return palette.surface;
                      }),
                    ),
                    segments: [
                      ButtonSegment(value: 'ko', label: Text(strings.korean)),
                      ButtonSegment(value: 'en', label: Text(strings.english)),
                    ],
                    selected: {SettingsService.instance.languageCode.value},
                    onSelectionChanged: (selection) {
                      SettingsService.instance.setLanguageCode(selection.first);
                    },
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (value) => setState(() => _page = value),
                    children: pages,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Row(
                        children: List.generate(
                          pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: index == _page ? 18 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? palette.accent
                                  : palette.textSecondary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: palette.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              TossSurfaceCard.radius,
                            ),
                          ),
                        ),
                        child: Text(
                          _page == pages.length - 1
                              ? strings.getStarted
                              : strings.next,
                        ),
                      ),
                    ],
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: TossSurfaceCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: palette.accent),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: palette.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
