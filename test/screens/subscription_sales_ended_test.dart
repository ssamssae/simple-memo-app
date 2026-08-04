// T-260804-090 (parent T-260804-082 2페이즈) — 구독 판매가 되살아나거나,
// ★기존 구독자의 광고 제거가 무단 회수되면 빨개지는 회귀축.
//
// ■두 방향을 동시에 지킨다 — 한쪽만 지키면 반대쪽으로 사고가 난다
//   (1) 판매 종료  : 비구독자에게 구독을 파는 칸·문구·결제 진입이 보이면 안 된다.
//   (2) ★유예 보존 : 이미 결제한 사람은 여전히 광고가 안 떠야 한다.
//   (2)가 없으면 「구독 없앴으니 isPremium 도 죽은 코드」라며 ad_banner 의 `|| isPremium` 을
//   정리해 버리는 일이 실제로 일어난다. 그러면 ★돈은 냈는데 광고가 되살아난다.
//   환불(T-260804-082 4페이즈)은 아직 실인원 조회조차 안 된 상태다.
//
// ■mutation probe (계기가 살아있음의 증명)
//   (1) settings_screen 의 `if (!entitlement.active) return const SizedBox.shrink();` 를 지우면
//       → 비구독자에게 프리미엄 칸이 다시 떠서 이 파일이 빨개진다.
//   (2) ad_banner 의 `|| PremiumService.instance.isPremium` 을 지우면
//       → 구독자에게 광고가 살아나서 이 파일이 빨개진다.
//   착수 시 두 방향 모두 실측 RED 를 확인하고 출력을 보고에 첨부했다. 고치는 사람은 같은 절차를
//   다시 밟아라 — 안 밟으면 0회 도는 장식이 된다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';
import 'package:simple_memo_app/services/ads_service.dart';
import 'package:simple_memo_app/services/premium_entitlement_client.dart';
import 'package:simple_memo_app/services/premium_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const miniLmChannel = MethodChannel('memoyo/minilm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(miniLmChannel, (call) async {
      return switch (call.method) {
        'isSupported' => false,
        'close' => null,
        _ => null,
      };
    });
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(miniLmChannel, null);
    PremiumService.instance.entitlement.value =
        const PremiumEntitlement.inactive();
    AdsService.instance.removeAds.value = false;
  });

  PremiumEntitlement activeSubscription() => PremiumEntitlement(
    premium: true,
    productId: PremiumEntitlementClient.premiumProductId,
    expiresAt: DateTime(2999),
    source: PremiumEntitlementSource.subscription,
  );

  testWidgets('(1) 비구독자 설정 화면에 구독을 파는 칸이 없다', (tester) async {
    PremiumService.instance.entitlement.value =
        const PremiumEntitlement.inactive();

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    // ★대조군 먼저 — 설정 화면이 실제로 그려졌는지 증명한다. 화면이 안 떴으면 아래
    //   findsNothing 은 「없앴다」가 아니라 「아무것도 안 그려졌다」의 0건이고 눈먼 초록이다.
    //   광고제거 단품 칸은 이 티켓에서 무접촉이므로 살아 있어야 한다 = 좋은 대조군이다.
    expect(find.text('광고 제거'), findsOneWidget,
        reason: '설정 화면이 안 떴거나 광고제거 단품 칸까지 사라졌다 — 판정이 무의미해진다');

    expect(find.text('메모요 프리미엄'), findsNothing,
        reason: '비구독자에게 구독 칸이 되살아났다 (T-260804-090 으로 판매 종료)');
    // 파는 문구 자체가 렌더되지 않아야 한다. 문구만 바꾸고 칸을 남기면 죽은 버튼이 된다.
    expect(find.textContaining('뜻으로 찾기와 광고 제거'), findsNothing,
        reason: '구독 판매 문구(premiumSubtitle)가 화면에 되살아났다');
  });

  // ★관측점을 「광고 위젯의 높이」로 잡았다가 폐기했다 — 착수 시 실측에서 ★권한이 하나도 없는
  //   대조군에서도 높이가 0.0 이었다. 테스트 환경엔 실제 AdMob 이 없어 어차피 안 그린다.
  //   즉 높이는 유예를 재는 계기가 아니었다(계기 사망). 대조군이 그걸 잡아서 관측점을 바꿨다.
  //   지금은 유예를 이루는 ★두 조각을 각각 직접 잰다: ①권한 읽기가 살아 있나 ②그 권한을
  //   광고 위젯이 실제로 참조하나. 둘 중 하나만 끊겨도 구독자에게 광고가 되살아난다.

  test('(2a) ★유예 — 구독 권한을 읽는 경로가 살아 있다', () {
    PremiumService.instance.entitlement.value =
        const PremiumEntitlement.inactive();
    // 대조군 — 꺼진 상태에서 false 여야 아래 true 가 의미를 갖는다.
    expect(PremiumService.instance.isPremium, isFalse,
        reason: 'isPremium 이 항상 true 다 — 아래 단언이 무의미해진다');

    PremiumService.instance.entitlement.value = activeSubscription();
    expect(PremiumService.instance.isPremium, isTrue,
        reason: '구독 권한 읽기가 끊겼다 — 판매만 접어야 하는데 읽는 쪽까지 걷어냈다 '
            '(T-260804-082 4페이즈 환불 전까지 유예)');
  });

  test('(2b) ★유예 — 광고 위젯이 구독 권한을 여전히 참조한다', () {
    // 소스를 직접 읽는다. 실행 관측이 죽어 있으므로(위 주석) 계약을 글자로 지킨다.
    final source = File('lib/widgets/ad_banner.dart').readAsStringSync();

    // ★대조군 — 파일을 실제로 읽었는지 먼저 증명한다. 경로가 틀리면 아래 contains 는
    //   「지워졌다」가 아니라 「빈 문자열을 봤다」가 된다.
    expect(source, contains('_shouldHideAds'),
        reason: 'ad_banner.dart 를 못 읽었거나 구조가 바뀌었다 — 아래 판정이 무의미해진다');

    expect(source, contains('PremiumService.instance.isPremium'),
        reason: '광고 숨김 조건에서 구독 항이 사라졌다 — 돈 낸 사람에게 광고가 되살아난다. '
            '이 줄은 죽은 코드가 아니라 유예다 (T-260804-082 4페이즈 완주 후 제거)');
  });
}
