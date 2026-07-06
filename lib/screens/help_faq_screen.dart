import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

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

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(strings.helpFaq, style: const TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.$1,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(item.$2),
              ),
            );
          },
          separatorBuilder: (_, _) => const Divider(height: 24, thickness: 0.5),
          itemCount: items.length,
        ),
      ),
    );
  }
}
