import 'package:flutter/material.dart';

import '../services/memoyo_summary_client.dart';
import '../../../l10n/app_strings.dart';


class MemoSummarySheet extends StatelessWidget {
  const MemoSummarySheet({super.key, required this.result});

  final MemoyoSummaryResult result;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: Color(0xFF9E86FF)),
                SizedBox(width: 10),
                Text(
                  AppStrings.of(context).aiSummary,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SelectableText(
              result.summary,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.of(context).summaryUsage(result.usage.remaining, result.usage.limit),
              style: const TextStyle(color: Color(0xFF9A9AA2), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
