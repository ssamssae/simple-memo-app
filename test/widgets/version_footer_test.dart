import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simple_memo_app/widgets/version_footer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'simple_memo_app',
      packageName: 'com.daejongkang.simple_memo_app',
      version: '9.9.9',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets(
      'VersionFooter renders "v<version> · 마이너스베타스튜디오" from PackageInfo',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VersionFooter())),
    );
    await tester.pumpAndSettle();

    expect(find.text('v9.9.9 · 마이너스베타스튜디오'), findsOneWidget);
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
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style?.color, theme.hintColor);
  });
}
