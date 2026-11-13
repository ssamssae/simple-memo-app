// T-261113-024 — 메모 완료 표시(doneAt)의 저장 모양과 옛 데이터 호환.
//
// 메모 저장·백업 JSON 에 키 하나가 늘었다. 완료한 메모만 키를 쓰므로
// 안 한 메모의 JSON 은 예전과 같다. 옛 앱은 모르는 키를 무시한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  final t = DateTime(2026, 11, 13, 9);
  final done = DateTime(2026, 11, 13, 21, 30);

  Map<String, dynamic> legacyJson() => {
    'id': 'old',
    'content': '옛 메모',
    'isFavorite': false,
    'createdAt': t.toIso8601String(),
    'updatedAt': t.toIso8601String(),
  };

  test('옛 JSON(doneAt 키 없음) → 안 한 메모, 다시 쓰면 같은 모양', () {
    final memo = Memo.fromJson(legacyJson());
    expect(memo.doneAt, isNull);
    expect(memo.isDone, isFalse);
    expect(memo.toJson().containsKey('doneAt'), isFalse);
    expect(memo.toJson(), legacyJson());
  });

  test('doneAt 은 ISO-8601 로 쓰고 encodeList/decodeList 왕복에서 살아남는다', () {
    final memo = Memo(
      id: 'd',
      content: '끝낸 일',
      createdAt: t,
      updatedAt: t,
      doneAt: done,
    );
    expect(memo.toJson()['doneAt'], done.toIso8601String());
    final back = Memo.decodeList(Memo.encodeList([memo])).single;
    expect(back.doneAt, done);
    expect(back.isDone, isTrue);
    expect(back.updatedAt, t);
  });

  test('깨진 doneAt(문자열 아님·날짜 아님)은 null — 메모 읽기는 실패하지 않는다', () {
    expect(Memo.fromJson({...legacyJson(), 'doneAt': 'nope'}).doneAt, isNull);
    expect(Memo.fromJson({...legacyJson(), 'doneAt': 42}).doneAt, isNull);
  });

  test('copyWith: 안 넘기면 유지, 명시 null 이면 풀림, 값이면 바뀜', () {
    final memo = Memo(
      id: 'c',
      content: 'x',
      createdAt: t,
      updatedAt: t,
      doneAt: done,
    );
    expect(memo.copyWith(content: 'y').doneAt, done);
    expect(memo.copyWith(deletedAt: t).doneAt, done);
    expect(memo.copyWith(doneAt: null).doneAt, isNull);
    final later = done.add(const Duration(days: 1));
    expect(memo.copyWith(doneAt: later).doneAt, later);
  });

  test('완료와 휴지통은 따로 간다 — 지웠다 되살려도 완료 그대로', () {
    final memo = Memo(
      id: 'c',
      content: 'x',
      createdAt: t,
      updatedAt: t,
      doneAt: done,
    );
    final trashed = memo.copyWith(deletedAt: t);
    final json = trashed.toJson();
    expect(json['doneAt'], done.toIso8601String());
    expect(json['deletedAt'], t.toIso8601String());
    final restored = Memo.fromJson(json).copyWith(deletedAt: null);
    expect(restored.doneAt, done);
    expect(restored.isInTrash, isFalse);
  });
}
