import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/widgets/version_footer.dart';

void main() {
  testWidgets('VersionFooter renders "v<APP_VERSION> · 강대종"', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VersionFooter())),
    );

    const expectedVersion =
        String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
    expect(find.text('v$expectedVersion · 강대종'), findsOneWidget);
  });

  testWidgets('VersionFooter uses Theme.hintColor (cluster D fallback)',
      (tester) async {
    final theme = ThemeData(hintColor: const Color(0xFF8B95A1));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: VersionFooter()),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style?.color, theme.hintColor);
  });
}
