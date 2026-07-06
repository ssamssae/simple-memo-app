import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/settings_service.dart';
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
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              strings.onboardingStartTitle,
              style: const TextStyle(fontSize: 17),
            ),
            actions: [
              TextButton(onPressed: _finish, child: Text(strings.skip)),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SegmentedButton<String>(
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
                                  ? const Color(0xFF7C5CFF)
                                  : const Color(0xFF6E6E76),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: const Color(0xFF7C5CFF)),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFECECEC),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
