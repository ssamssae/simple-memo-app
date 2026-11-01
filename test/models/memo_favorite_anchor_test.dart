// T-261101-034 ② — 즐겨찾기 자리 기록(favoriteAnchorId)의 저장 모양과 옛 데이터 호환.
//
// 메모 저장·백업 JSON 에 키 하나가 늘었다. 기록이 있을 때만 키를 쓰므로
// 일반 메모와 옛 즐겨찾기의 JSON 은 예전과 같다. 옛 앱은 모르는 키를 무시한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  final t = DateTime(2026, 11, 1, 9);

  Map<String, dynamic> legacyJson({bool favorite = true}) => {
    'id': 'old',
    'content': '옛 메모',
    'isFavorite': favorite,
    'createdAt': t.toIso8601String(),
    'updatedAt': t.toIso8601String(),
  };

  test('옛 JSON(키 없음)은 그대로 읽힌다 — 자리 기록은 null', () {
    final memo = Memo.fromJson(legacyJson());
    expect(memo.isFavorite, isTrue);
    expect(memo.favoriteAnchorId, isNull);
  });

  test('자리 기록이 없으면 키를 쓰지 않는다 — 옛 JSON 과 같은 모양', () {
    final json = Memo.fromJson(legacyJson()).toJson();
    expect(json.containsKey('favoriteAnchorId'), isFalse);
    expect(json, legacyJson());
  });

  test('자리 기록은 encodeList/decodeList 왕복에서 살아남는다 (저장·백업 같은 길)', () {
    final memo = Memo(
      id: 'f',
      content: '즐겨찾기',
      isFavorite: true,
      createdAt: t,
      updatedAt: t,
      favoriteAnchorId: 'below',
    );
    expect(memo.toJson()['favoriteAnchorId'], 'below');
    final back = Memo.decodeList(Memo.encodeList([memo])).single;
    expect(back.favoriteAnchorId, 'below');
    expect(back.isFavorite, isTrue);
  });

  test('문자열이 아닌 값은 버리고 나머지는 읽는다 — 저장 데이터를 통째로 잃지 않는다', () {
    // loadMemos 는 읽기 실패를 빈 목록으로 삼키고, 다음 저장이 그 빈 목록을 쓴다.
    // 이 키 하나 때문에 fromJson 이 던지면 메모 전체를 잃는다.
    final memo = Memo.fromJson(legacyJson()..['favoriteAnchorId'] = 42);
    expect(memo.favoriteAnchorId, isNull);
    expect(memo.content, '옛 메모');
    expect(memo.isFavorite, isTrue);
  });

  test('copyWith 는 생략하면 유지하고 null 을 주면 지운다', () {
    final memo = Memo(
      id: 'f',
      content: '본문',
      isFavorite: true,
      createdAt: t,
      updatedAt: t,
      favoriteAnchorId: 'below',
    );
    expect(memo.copyWith(content: '고침').favoriteAnchorId, 'below');
    expect(memo.copyWith(deletedAt: t).favoriteAnchorId, 'below');
    expect(memo.copyWith(favoriteAnchorId: null).favoriteAnchorId, isNull);
    expect(memo.copyWith(favoriteAnchorId: 'other').favoriteAnchorId, 'other');
  });
}
