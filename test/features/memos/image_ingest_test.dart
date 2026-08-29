import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/image_ingest.dart';

void main() {
  group('fitLongEdge', () {
    test('긴 변이 상한 이하면 그대로', () {
      expect(fitLongEdge(1200, 800, 1600), (1200, 800));
      expect(fitLongEdge(1600, 1600, 1600), (1600, 1600));
    });

    test('가로가 긴 사진 → 가로 1600, 세로 비율 축소', () {
      expect(fitLongEdge(4000, 3000, 1600), (1600, 1200));
    });

    test('세로가 긴 사진 → 세로 1600', () {
      expect(fitLongEdge(3000, 4000, 1600), (1200, 1600));
    });

    test('극단 비율에서도 1 미만으로 떨어지지 않는다', () {
      expect(fitLongEdge(10000, 1, 1600), (1600, 1));
    });

    test('0·음수 입력은 상한 정사각으로 폴백 (크기 못 읽은 경우)', () {
      expect(fitLongEdge(0, 0, 1600), (1600, 1600));
      expect(fitLongEdge(-5, 100, 1600), (1600, 1600));
    });
  });
}
