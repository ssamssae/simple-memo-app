// Capture the current application on an isolated simulator/emulator.
// Demo notes and the existing ad-free state are local fixtures. No purchase,
// account login, backup upload, or production app implementation is changed.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simple_memo_app/l10n/app_strings.dart';
import 'package:simple_memo_app/main.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/ads_service.dart';
import 'package:simple_memo_app/services/memo_storage.dart';
import 'package:simple_memo_app/services/settings_service.dart';

const expectedVersion = String.fromEnvironment('STORE_CAPTURE_VERSION');
const expectedBuild = String.fromEnvironment('STORE_CAPTURE_BUILD');
const selectedLocales = String.fromEnvironment(
  'STORE_CAPTURE_LOCALES',
  defaultValue: 'ko,en-US,ja',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('current released store screens', (tester) async {
    expect(expectedVersion, isNotEmpty);
    expect(expectedBuild, isNotEmpty);
    final package = await PackageInfo.fromPlatform();
    expect(package.version, expectedVersion);
    expect(package.buildNumber, expectedBuild);
    var converted = false;

    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String locale, String scene) async {
      await settle();
      if (Platform.isAndroid && !converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
        await tester.pump();
      }
      await binding.takeScreenshot('${locale}__$scene');
    }

    for (final locale in selectedLocales.split(',')) {
      expect(['ko', 'en-US', 'ja'], contains(locale));
      final language = locale == 'ko' ? 'ko' : 'en';
      final strings = AppStrings.fromCode(language);
      final contents = switch (locale) {
        'ko' => [
          '장보기\n· 우유\n· 계란 한 판\n· 사과\n· 커피 원두',
          '오늘 회의 정리\n다음 분기 목표 3가지 정하기\n금요일까지 기획안 정리',
          '책에서 본 문장\n작게 시작해서 매일 한 줄씩.',
          '주말 할 일\n자전거 점검\n도서관 책 반납',
          '아이디어\n좋아하는 산책 코스 모아보기',
        ],
        'ja' => [
          '買い物リスト\n・牛乳\n・卵\n・りんご\n・コーヒー豆',
          '今日のミーティング\n来月の目標を3つに絞る\n金曜日までに企画書をまとめる',
          '本で見つけた言葉\n小さく始めて、毎日少しずつ。',
          '週末にやりたいこと\n自転車の点検\n図書館に本を返す',
          'アイデア\nお気に入りの散歩コースを記録する',
        ],
        _ => [
          'Shopping list\n• Milk\n• Eggs\n• Apples\n• Coffee beans',
          'Meeting notes\nChoose three goals for next month\nFinish the proposal by Friday',
          'A line worth keeping\nStart small. Write a little every day.',
          'Weekend plans\nCheck the bike\nReturn library books',
          'An idea\nKeep a list of favorite walking routes',
        ],
      };
      final base = DateTime(2026, 11, 7, 9, 30);
      await MemoStorage.saveMemos([
        for (var index = 0; index < contents.length; index++)
          Memo(
            id: 'store-$index',
            content: contents[index],
            isFavorite: index == 0,
            createdAt: base.subtract(Duration(hours: index * 4)),
            updatedAt: base.subtract(Duration(hours: index * 4)),
          ),
      ]);
      await SettingsService.instance.setLanguageCode(language);
      await SettingsService.instance.setThemeMode(ThemeMode.system);
      await SettingsService.instance.setOnboardingCompleted(true);
      AdsService.instance.removeAds.value = true;
      await tester.pumpWidget(const MemoApp());
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 500));
      await settle();
      await tester.tap(find.text(strings.memoTab).last);
      await settle();
      expect(
        find.textContaining(contents.first.split('\n').first),
        findsWidgets,
      );
      await capture(locale, '01-main');

      await tester.tap(find.text(strings.settings).last);
      await settle();
      expect(find.text('뜻 검색'), findsNothing);
      expect(find.text('뜻으로 찾기'), findsNothing);
      expect(find.text('Semantic search'), findsNothing);
      await capture(locale, '04-settings');

      final backup = find.text(strings.backupRestore);
      await tester.ensureVisible(backup);
      await tester.tap(backup);
      await settle();
      expect(find.textContaining('v$expectedVersion'), findsOneWidget);
      await capture(locale, '03-backup');
      await tester.tap(find.byType(BackButton));
      await settle();
      await tester.tap(find.text(strings.memoTab).last);
      await settle();
      await tester.tap(find.text(strings.newMemoTab));
      await settle();
      await tester.enterText(find.byType(TextField).first, switch (locale) {
        'ko' => '오후 3시 약속\n카페에서 기획안 리뷰\n\n생각난 순간, 잊기 전에 기록하기.',
        'ja' => '午後3時に待ち合わせ\nカフェで新しい企画を相談する\n\n忘れないうちに、ここにメモ。',
        _ => 'Meet at 3 PM\nReview the new idea at the cafe\n\nWrite it down while it is fresh.',
      });
      await capture(locale, '02-quick-write');
      await tester.pumpWidget(const SizedBox.shrink());
      await settle();
    }
    AdsService.instance.removeAds.value = false;
  });
}
