import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../utils/app_palette.dart';
import '../widgets/toss_surface_card.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final items = [
      (strings.helpStorageQuestion, strings.helpStorageAnswer),
      (strings.helpBackupQuestion, strings.helpBackupAnswer),
      (strings.helpDeleteQuestion, strings.helpDeleteAnswer),
      (strings.helpFeedbackQuestion, strings.helpFeedbackAnswer),
    ];

    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          strings.helpFaq,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemBuilder: (context, index) {
            final item = items[index];
            return TossSurfaceCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$1,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.$2,
                    style: TextStyle(
                      color: palette.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            );
          },
          itemCount: items.length,
        ),
      ),
    );
  }
}
