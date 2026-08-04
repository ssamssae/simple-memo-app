import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/l10n/app_strings.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';
import 'package:simple_memo_app/screens/trash_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';

/// T-260719-019 영어 로케일 스모크: 아니키 실기 제보(08:05~08:06) 잔존 지점을
/// 커버하는 주요 화면에서 (a) 한글 텍스트가 렌더되지 않고 (b) 대표 영문 문구가
/// 노출되는지 고정한다.
void main() {
  final han = RegExp(r'[가-힣]');

  Finder koreanText() => find.byWidgetPredicate(
        (w) => w is Text && han.hasMatch(w.data ?? ''),
        description: 'Text containing Korean',
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.languageCode.value = 'en';
  });

  tearDown(() {
    SettingsService.instance.languageCode.value = 'ko';
  });

  testWidgets('영어 로케일 빈 메모 목록 — 한글 0 + 빈 목록 안내 영문', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    expect(koreanText(), findsNothing);
    expect(find.textContaining('No memos yet.'), findsOneWidget);
  });

  testWidgets('영어 로케일 메모 목록(1건) — 한글 0 + Edit 영문', (tester) async {
    final now = DateTime(2026, 7, 19, 8, 0);
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        Memo(id: 'm1', content: 'hello memo', createdAt: now, updatedAt: now),
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    expect(koreanText(), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('영어 로케일 새메모 화면 — 한글 0 + Save/hint 영문', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoEditScreen()));
    await tester.pumpAndSettle();

    expect(koreanText(), findsNothing);
    expect(find.text('New memo'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Type your memo...'), findsOneWidget);
  });

  testWidgets('영어 로케일 휴지통 — 한글 0 + 빈 휴지통 안내 영문', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrashScreen()));
    await tester.pumpAndSettle();

    expect(koreanText(), findsNothing);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.textContaining('Trash is empty.'), findsOneWidget);
  });

  test('영어 AppStrings 대표 키 — 스샷 잔존 지점 문구 확인', () {
    final en = AppStrings.fromCode('en');
    expect(en.miniLmTitle, 'On-device semantic search model');
    expect(en.theme, 'Theme');
    expect(en.themeSystem, 'System');
    expect(en.themeLight, 'Light');
    expect(en.themeDark, 'Dark');
    expect(en.cancel, 'Cancel');
    expect(en.selectAll, 'Select all');
    // en.aiSummary 단언은 T-260804-078 에서 뺐다 — 문구가 가리키던 기능이
    // T-260804-062 로 제거돼 getter 자체가 사라졌다.
    expect(han.hasMatch(en.miniLmInstallBody), isFalse);
    expect(han.hasMatch(en.emptyTrashConfirm(3)), isFalse);
  });
}
