// Opt-in capture of production Flutter widgets. No simulator or live user data.
// STORE_CAPTURE_LOCALE selects listing/demo content; both listings use English UI.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/main.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/ads_service.dart';
import 'package:simple_memo_app/services/settings_service.dart';

const capture = bool.fromEnvironment('STORE_CAPTURE');
const locale = String.fromEnvironment(
  'STORE_CAPTURE_LOCALE',
  defaultValue: 'en-US',
);

void main() {
  testWidgets('capture localized store listing from production widgets', (
    tester,
  ) async {
    expect(['en-US', 'ja'], contains(locale));
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
    addTearDown(tester.view.reset);

    // macOS system fonts are loaded locally; no font files are redistributed.
    await tester.runAsync(() async {
      final latin = ByteData.sublistView(
        await File('/System/Library/Fonts/SFNS.ttf').readAsBytes(),
      );
      final japanese = ByteData.sublistView(
        await File('/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc').readAsBytes(),
      );
      for (final family in [
        'Roboto',
        'CupertinoSystemText',
        'CupertinoSystemDisplay',
        '.SF UI Text',
        '.SF UI Display',
        '.SF Pro Text',
        '.SF Pro Display',
        '.AppleSystemUIFont',
      ]) {
        final loader = FontLoader(family)
          ..addFont(Future.value(locale == 'ja' ? japanese : latin));
        await loader.load();
      }
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final font in manifest) {
        final loader = FontLoader(font['family'] as String);
        for (final asset in font['fonts'] as List) {
          loader.addFont(rootBundle.load(asset['asset'] as String));
        }
        await loader.load();
      }
    });

    final contents = locale == 'ja'
        ? [
            '買い物リスト\n・牛乳\n・卵\n・りんご\n・コーヒー豆',
            '今日のミーティング\n来月の目標を3つに絞る\n金曜日までに企画書をまとめる',
            '本で見つけた言葉\n小さく始めて、毎日少しずつ。',
            '週末にやりたいこと\n自転車の点検\n図書館に本を返す',
            'アイデア\nお気に入りの散歩コースを記録する',
          ]
        : [
            'Shopping list\n• Milk\n• Eggs\n• Apples\n• Coffee beans',
            'Meeting notes\nChoose three goals for next month\nFinish the proposal by Friday',
            'A line worth keeping\nStart small. Write a little every day.',
            'Weekend plans\nCheck the bike\nReturn library books',
            'An idea\nKeep a list of favorite walking routes',
          ];
    final base = DateTime(2026, 10, 11, 9, 30);
    final memos = List.generate(
      contents.length,
      (i) => Memo(
        id: 'store-$i',
        content: contents[i],
        isFavorite: i == 0,
        createdAt: base.subtract(Duration(hours: i * 4)),
        updatedAt: base.subtract(Duration(hours: i * 4)),
      ),
    );
    SharedPreferences.setMockInitialValues({'memos': Memo.encodeList(memos)});
    SettingsService.instance.resetForTesting();
    SettingsService.instance.languageCode.value = 'en';
    SettingsService.instance.themeMode.value = ThemeMode.dark;
    SettingsService.instance.onboardingCompleted.value = true;
    AdsService.instance.removeAds.value = true;
    PackageInfo.setMockInitialValues(
      appName: 'Memoyo',
      packageName: 'com.daejongkang.simpleMemoApp',
      version: '1.0.20',
      buildNumber: '46',
      buildSignature: '',
    );
    const channel = MethodChannel('memoyo/minilm');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      SettingsService.instance.resetForTesting();
      AdsService.instance.removeAds.value = false;
    });

    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: boundary, child: const MemoApp()),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    Future<void> save(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 3);
        expect(image.width, 1320);
        expect(image.height, 2868);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'fastlane/screenshots/$locale/iPhone 6.9 Display/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    expect(find.textContaining(contents.first.split('\n').first), findsWidgets);
    await save('01_dark_main');
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backup & restore'));
    await tester.pumpAndSettle();
    await save('06_drive_backup');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Memo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      locale == 'ja'
          ? '午後3時に待ち合わせ\nカフェで新しい企画を相談する\n\n忘れないうちに、ここにメモ。'
          : 'Meet at 3 PM\nReview the new idea at the cafe\n\nWrite it down while it is fresh.',
    );
    await save('02_quick_write');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  }, skip: !capture);
}
