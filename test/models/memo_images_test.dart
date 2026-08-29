import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  final t = DateTime(2026, 8, 29, 12);

  Map<String, dynamic> baseJson() => {
        'id': 'a',
        'content': '본문',
        'isFavorite': false,
        'createdAt': '2026-08-29T12:00:00.000',
        'updatedAt': '2026-08-29T12:00:00.000',
      };

  group('Memo.imageFiles — JSON 호환', () {
    test('images 키 없는 1.0.18 이하 JSON → 빈 목록 (손실 0)', () {
      final memo = Memo.fromJson(baseJson());
      expect(memo.imageFiles, isEmpty);
      expect(memo.hasImages, isFalse);
    });

    test('images 있는 JSON → 순서 보존 파싱', () {
      final memo = Memo.fromJson({...baseJson(), 'images': ['b.jpg', 'a.jpg']});
      expect(memo.imageFiles, ['b.jpg', 'a.jpg']);
      expect(memo.hasImages, isTrue);
    });

    test('images 가 List 가 아니거나 원소가 문자열이 아니면 관대하게 걸러낸다', () {
      expect(Memo.fromJson({...baseJson(), 'images': 'x.jpg'}).imageFiles, isEmpty);
      expect(Memo.fromJson({...baseJson(), 'images': null}).imageFiles, isEmpty);
      expect(
        Memo.fromJson({...baseJson(), 'images': ['ok.jpg', 3, null, true]}).imageFiles,
        ['ok.jpg'],
      );
    });

    test('경로 조작 가능한 파일명은 파싱 단계에서 버린다', () {
      final memo = Memo.fromJson({
        ...baseJson(),
        'images': ['../etc.jpg', 'a/b.jpg', 'c\\d.jpg', '', 'fine-1.jpg'],
      });
      expect(memo.imageFiles, ['fine-1.jpg']);
    });

    test('toJson: 비어 있으면 images 키 생략, 있으면 그대로', () {
      final none = Memo(id: 'a', content: 'x', createdAt: t, updatedAt: t);
      expect(none.toJson().containsKey('images'), isFalse);

      final some = Memo(id: 'a', content: 'x', createdAt: t, updatedAt: t, imageFiles: ['p.jpg']);
      expect(some.toJson()['images'], ['p.jpg']);
    });

    test('encodeList/decodeList 라운드트립', () {
      final memo = Memo(id: 'a', content: 'x', createdAt: t, updatedAt: t, imageFiles: ['p.jpg', 'q.jpg']);
      final back = Memo.decodeList(Memo.encodeList([memo])).single;
      expect(back.imageFiles, ['p.jpg', 'q.jpg']);
    });
  });

  group('Memo.imageFiles — copyWith / create / 불변', () {
    test('copyWith(imageFiles: null) 은 기존 유지, 값 주면 교체', () {
      final memo = Memo(id: 'a', content: 'x', createdAt: t, updatedAt: t, imageFiles: ['p.jpg']);
      expect(memo.copyWith(content: 'y').imageFiles, ['p.jpg']);
      expect(memo.copyWith(imageFiles: const []).imageFiles, isEmpty);
      expect(memo.copyWith(imageFiles: ['z.jpg']).imageFiles, ['z.jpg']);
    });

    test('Memo.create 기본 빈 목록, 인자로 넣으면 실림', () {
      expect(Memo.create(content: 'x').imageFiles, isEmpty);
      expect(Memo.create(content: 'x', imageFiles: ['p.jpg']).imageFiles, ['p.jpg']);
    });

    test('imageFiles 는 수정 불가 목록', () {
      final memo = Memo(id: 'a', content: 'x', createdAt: t, updatedAt: t, imageFiles: ['p.jpg']);
      expect(() => memo.imageFiles.add('q.jpg'), throwsUnsupportedError);
    });

    test('isValidImageFileName', () {
      expect(Memo.isValidImageFileName('3f2a-1.jpg'), isTrue);
      expect(Memo.isValidImageFileName('.hidden'), isFalse);
      expect(Memo.isValidImageFileName('a..b.jpg'), isFalse);
      expect(Memo.isValidImageFileName('a/b.jpg'), isFalse);
      expect(Memo.isValidImageFileName(''), isFalse);
      expect(Memo.isValidImageFileName('a.jpg\n'), isFalse); // Dart $ 는 엄격 — 줄끝 우회 없음을 고정
      expect(Memo.isValidImageFileName('a .jpg'), isFalse);
      expect(Memo.isValidImageFileName('A' * 128), isTrue); // 상한 = 1 + 127
      expect(Memo.isValidImageFileName('A' * 129), isFalse);
    });
  });
}
