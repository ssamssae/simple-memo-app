import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/checklist_text.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_embedding_engine.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/search_service.dart';

void main() {
  const open = ChecklistText.unchecked;
  const done = ChecklistText.checked;

  ChecklistSelectionEdit toggle(
    String text, {
    int base = 0,
    int extent = 0,
    bool valid = true,
  }) {
    return ChecklistText.togglePrefixes(
      text: text,
      base: base,
      extent: extent,
      selectionValid: valid,
    );
  }

  group('표기 넣기·빼기', () {
    test('커서가 있는 줄 앞에 ☐ 를 넣고 커서는 그 글자 뒤에 둔다', () {
      final edit = toggle('milk\neggs', base: 2, extent: 2);

      expect(edit.text, '${open}milk\neggs');
      expect(edit.base, 2 + open.length);
      expect(edit.extent, edit.base);
    });

    test('이미 표기가 있으면 그 줄에서만 뺀다', () {
      final edit = toggle('${open}milk\n${done}eggs', base: 2, extent: 2);

      expect(edit.text, 'milk\n${done}eggs');
      expect(edit.text.contains(open), isFalse);
    });

    test('여러 줄을 고르면 그 줄들을 함께 넣거나 뺀다', () {
      final added = toggle('milk\neggs', base: 0, extent: 'milk\neggs'.length);
      expect(added.text, '${open}milk\n${open}eggs');

      final removed = toggle(added.text, base: 0, extent: added.text.length);
      expect(removed.text, 'milk\neggs');
    });

    test('선택이 없으면 첫 줄만 바꾼다', () {
      final edit = toggle('milk\neggs', valid: false);

      expect(edit.text, '${open}milk\neggs');
    });
  });

  group('줄바꿈', () {
    ChecklistNewlineEdit? enter(String text, int cursor) {
      final next = '${text.substring(0, cursor)}\n${text.substring(cursor)}';
      return ChecklistText.adjustNewline(
        oldText: text,
        oldCursor: cursor,
        oldCollapsed: true,
        newText: next,
      );
    }

    test('체크 줄에서 줄바꿈하면 다음 줄이 ☐ 로 시작한다', () {
      final text = '${open}milk';
      final edit = enter(text, text.length);

      expect(edit, isNotNull);
      expect(edit!.text, '${open}milk\n$open');
      expect(edit.cursor, edit.text.length);
    });

    test('줄 중간에서 끊어도 다음 줄만 ☐ 로 시작한다', () {
      final text = '${open}buy milk';
      final cursor = '${open}buy'.length;
      final edit = enter(text, cursor);

      expect(edit!.text, '${open}buy\n$open milk');
      expect(edit.cursor, '${open}buy\n$open'.length);
    });

    test('체크된 줄의 다음 줄은 아직 안 한 ☐ 다', () {
      final text = '${done}milk';
      final edit = enter(text, text.length);

      expect(edit!.text, '${done}milk\n$open');
    });

    test('내용 없는 ☐ 줄에서 줄바꿈하면 표기를 지우고 리스트를 끝낸다', () {
      final text = '${open}milk\n$open';
      final edit = enter(text, text.length);

      expect(edit!.text, '${open}milk\n');
      expect(edit.cursor, edit.text.length);
    });

    test('메모 전체가 빈 체크 줄이면 표기만 사라진다', () {
      final edit = enter(open, open.length);

      expect(edit!.text, isEmpty);
      expect(edit.cursor, 0);
    });

    test('빈 ☑ 줄도 표기를 지운다', () {
      final edit = enter('${open}milk\n$done', '${open}milk\n$done'.length);

      expect(edit!.text, '${open}milk\n');
    });

    test('일반 줄의 줄바꿈은 그대로 둔다', () {
      expect(enter('milk', 4), isNull);
    });

    test('한 글자 줄바꿈이 아니면 본문을 바꾸지 않는다', () {
      expect(
        ChecklistText.adjustNewline(
          oldText: '${open}milk',
          oldCursor: open.length,
          oldCollapsed: true,
          newText: '${open}milk\n\nbread',
        ),
        isNull,
      );
    });
  });

  group('☐ ↔ ☑', () {
    test('칸 위치의 글자만 바뀌고 길이와 나머지 글자는 그대로다', () {
      final text = '${open}milk\n$open eggs';
      final next = ChecklistText.toggleCheckedAt(text, 0);

      expect(next, '${done}milk\n$open eggs');
      expect(next!.length, text.length);
      expect(next.substring(1), text.substring(1));
    });

    test('한 번 더 누르면 원래 칸으로 돌아온다', () {
      final text = '${done}milk';
      expect(ChecklistText.toggleCheckedAt(text, 0), '${open}milk');
    });

    test('칸이 아닌 글자 위치는 바꾸지 않는다', () {
      final text = '${open}milk';
      expect(ChecklistText.toggleCheckedAt(text, 2), isNull);
    });
  });

  group('목록 진행', () {
    test('완료 수와 전체 수를 센다', () {
      final progress = ChecklistText.progressOf(
        '$open a\n$done b\nplain\n$done c\n$open d\n$open',
      );

      expect(progress, isNotNull);
      expect(progress!.done, 2);
      expect(progress.total, 5);
    });

    test('체크 줄이 없으면 진행을 만들지 않는다', () {
      expect(ChecklistText.progressOf('plain\nsee ☐ later'), isNull);
      expect(ChecklistText.progressOf(''), isNull);
    });
  });

  group('저장 글 형식', () {
    test('빈 체크 줄의 접두 공백은 저장 정규화 뒤에도 남는다', () {
      expect(
        ChecklistText.normalizeStoredContent('$open milk  \n$open   \n'),
        '$open milk\n$open',
      );
      expect(ChecklistText.normalizeStoredContent(open), open);
    });

    test('체크 줄이 아닌 줄 끝 공백 정리는 이전과 같다', () {
      expect(
        ChecklistText.normalizeStoredContent(
          '1233 24 8\n\n7 2 37          \n\n부산 0949 서울 1233\t',
        ),
        '1233 24 8\n\n7 2 37\n\n부산 0949 서울 1233',
      );
      expect(
        ChecklistText.normalizeStoredContent('동대구 1043   서울 1233 \n행낭'),
        '동대구 1043   서울 1233\n행낭',
      );
    });

    test('JSON 키는 늘지 않고 content 문자열만 왕복한다', () {
      final t = DateTime.utc(2026, 11, 10, 1);
      final plain = Memo(
        id: 'plain',
        content: 'hello',
        createdAt: t,
        updatedAt: t,
      );
      final checklist = Memo(
        id: 'check',
        content: '$open milk\n$done eggs',
        createdAt: t,
        updatedAt: t,
      );

      expect(checklist.toJson().keys, plain.toJson().keys);
      expect(checklist.toJson().containsKey('checklist'), isFalse);

      final encoded = Memo.encodeList([checklist]);
      final decoded = Memo.decodeList(encoded).single;
      expect(decoded.content, '$open milk\n$done eggs');

      final imported = ExportImportService.parseImport(encoded);
      expect(imported!.single.content, checklist.content);
    });
  });

  group('검색은 글 그대로', () {
    final t = DateTime.utc(2026, 11, 10, 1);
    final memo = Memo(
      id: 'm',
      content: '$open milk\n$done 우유',
      createdAt: t,
      updatedAt: t,
    );

    test('낱말·초성 검색이 표기 글자 때문에 깨지지 않는다', () {
      expect(SearchService.search([memo], 'milk'), [memo]);
      expect(SearchService.search([memo], 'ㅇㅇ'), [memo]);
      expect(SearchService.search([memo], 'bread'), isEmpty);
      expect(
        () => SearchService.excerpt(memo.content, 'milk'),
        returnsNormally,
      );
    });

    test('뜻 검색에 넘기는 글도 표기를 포함한 원문이다', () {
      expect(
        MiniLmEmbeddingEngine.prepareText(memo.content, EmbeddingPurpose.query),
        memo.content,
      );
    });
  });
}
