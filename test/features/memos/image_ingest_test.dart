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

    test('상한 바로 위 반올림', () {
      expect(fitLongEdge(1601, 1600, 1600), (1600, 1599));
    });

    test('정사각(동률)은 양쪽 다 상한', () {
      expect(fitLongEdge(3000, 3000, 1600), (1600, 1600));
    });

    test('아주 작은 상한도 1 미만으로 안 떨어진다', () {
      expect(fitLongEdge(3, 2, 1), (1, 1));
    });

    test('상한 초과 입력은 긴 변이 항상 정확히 상한', () {
      for (final (w, h) in [(4032, 3024), (3024, 4032), (5000, 2000), (1700, 1699), (9999, 9998)]) {
        final (fw, fh) = fitLongEdge(w, h, 1600);
        expect(fw > fh ? fw : fh, 1600, reason: '($w,$h)');
      }
    });
  });
}
