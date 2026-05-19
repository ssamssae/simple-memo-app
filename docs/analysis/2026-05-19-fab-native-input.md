# 메모요 FAB native input 거부 root cause 분석

- 날짜: 2026-05-20 KST (파일명은 본진 directive 의 2026-05-19 슬러그 유지)
- 작업자: 💻 노트북3060
- 트리거: 본진 directive — FAB 가 가끔 tap 안 받는 케이스 root cause trace
- 스코프: **분석/메모만**. 코드 수정 X.

## TL;DR

`lib/screens/memo_list_screen.dart:648-660` 의 FAB 가 다음 3 요소 결합으로 Android gesture nav 와 hit-test 경합이 생길 가능성 높음:

1. `FloatingActionButtonLocation.centerFloat` (bottom center)
2. `extendBody: true` (body 가 FAB 영역까지 확장)
3. `floatingActionButton: Padding(EdgeInsets.only(bottom: MediaQuery.viewPadding.bottom), child: FAB)`

→ FAB 가 Android 12+ edge-to-edge gesture 영역 (~16-24dp) 안 또는 인접 경계에 위치. 빠른 tap 이거나 살짝 edge 쪽 tap 이면 native Android 가 back gesture 로 분류해서 Flutter 까지 event 전달이 안 됨. iOS 에서는 같은 증상 거의 없음 (iOS home indicator 영역은 시스템 reserve 가 더 좁고 명시적).

## 코드 (현행)

```dart
// memo_list_screen.dart:648
floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
floatingActionButton: Padding(
  padding: EdgeInsets.only(
    bottom: MediaQuery.of(context).viewPadding.bottom,
  ),
  child: FloatingActionButton(
    onPressed: _addMemo,
    tooltip: '새 메모',
    backgroundColor: Colors.amber,
    foregroundColor: const Color(0xFF1C1C1E),
    child: const Icon(Icons.add),
  ),
),
```

상위 Scaffold (line 428) 는 `extendBody: true, resizeToAvoidBottomInset: false`. 그 위 Listener (line 411) 가 onPointerDown/Up 추적.

## 가설 ranking

### H1 — Android edge gesture 경합 (HIGH 확률)

근거:
- `FloatingActionButtonLocation.centerFloat` 는 기본적으로 bottom 16dp 마진. `Padding(bottom: viewPadding.bottom)` 추가하면 FAB 가 사실상 viewPadding 만큼 더 위로 올라가지만, gesture nav 모드의 `viewPadding.bottom` 자체가 0 이거나 매우 작을 수 있어 (3-button nav 와 다르게 gesture nav 는 viewPadding 이 0 인 케이스 있음) FAB 가 화면 최하단 inset 영역에 위치.
- Android 12+ gesture nav: 화면 하단 edge 에서 위로 swipe = home, 좌/우 edge 에서 안쪽 = back. 하단 ~24dp 의 tap 이 짧은 swipe 로 오인되면 system 이 먼저 consume.
- "가끔 tap 안 받는" 증상은 native consume 의 전형 — 100% 가 아니라 ~5-20% 의 tap 만 system 이 잡음. 손가락 위치/속도/edge 거리에 따라 확률 변동.

검증법 (코드 수정 0):
- 디버그 빌드를 실기기에 띄우고 ADB 로 입력 이벤트 dump: `adb shell getevent -lt`
- FAB 영역 tap 시 Flutter PointerEvent 가 도착하는지, 또는 EventHub 단계에서 system 이 가로채는지 확인

### H2 — Padding wrapper hit-region 분리 (MED 확률)

근거:
- `Scaffold(floatingActionButton: Padding(child: FAB))` 구조에서 Padding 의 bounding box 가 FAB visual 영역보다 큼. Padding 자체는 `HitTestBehavior.deferToChild` 라 visible FAB 영역 외 (= padding 만큼의 공간) 에서는 hit miss 가 정상. 단 `centerFloat` 위치 계산은 Padding 의 bounding box 기준이라 FAB 가 의도보다 더 아래로 살짝 밀려서 H1 의 edge 영역 침범을 악화.
- 즉 H2 자체가 단독 원인은 아니고 H1 의 amplifier.

### H3 — Listener / GestureDetector 외부 wrapper interference (LOW 확률)

근거:
- `Listener` (line 411) 는 onPointerDown 에서 `_buttonTapped = false`, onPointerUp 에서 swipe-close 트리거. FAB onPressed 가 호출되어 navigation push 가 일어나면 pointerUp event 가 취소될 수 있는데, 그래도 onPressed 자체는 이미 발화한 후라 FAB tap 자체에는 영향 X.
- 외부 GestureDetector 는 `behavior: HitTestBehavior.translucent` — pass-through 라서 FAB 까지 도달.
- 즉 H3 는 swipe-close 동작에 영향은 있어도 FAB tap rejection 의 직접 원인은 아님.

### H4 — onButtonTapped flag 미설정 (정보, root cause X)

- 다른 swipe 아이템 (line 598, 633) 은 `onButtonTapped: _onButtonTapped` 콜백을 받아 `_buttonTapped = true` 마킹. FAB 는 `onPressed: _addMemo` 만 등록, `_buttonTapped` flag 마킹 안 함.
- 결과: FAB tap → Listener.onPointerUp 이 `_buttonTapped == false` 라 swipe close 를 추가 트리거. 그러나 `_addMemo` 가 이미 `_closeAllSwipes()` 를 호출하므로 (line 212) 중복 호출은 무해.
- root cause 는 아니지만 향후 swipe 동작 변경 시 leak 가능 → 메모.

## 권장 수정 (구현 X, 후속 별 사이클)

옵션 a — **Custom FloatingActionButtonLocation** (가장 안전):
```dart
floatingActionButtonLocation: CustomFabLocation(extraOffset: 24),
floatingActionButton: FloatingActionButton(...),  // Padding 제거
```
FAB 를 시스템 gesture 영역 바깥으로 명시적으로 올림.

옵션 b — **SafeArea 위 래핑**:
```dart
floatingActionButton: SafeArea(
  child: FloatingActionButton(...),
),
```
viewPadding 처리를 Flutter 표준에 위임.

옵션 c — **`extendBody: false`** 로 전환 + FAB Padding 제거. 단 UI 디자인 영향 있음.

a) 가 디자인 변경 최소 + 효과 가장 확실. 그러나 위 어느 옵션도 본 사이클 scope 밖 (분석/메모만 directive).

## 다음 액션 (본진 결정 사항)

- 본 분석을 PR `notebook/fab-native-input-analysis-2026-05-19` 로 올림. 본진(🍎) 가 검토 후 옵션 (a/b/c) 픽 + 별 사이클 구현 위임.
- 실기기 ADB getevent dump 는 맥미니(🏭) USB 연결 환경에서 가능 (Galaxy S24). 노트북 자체로는 실기기 검증 불가.

## 근거

- 코드 위치: `lib/screens/memo_list_screen.dart:411-428, 648-660`
- 콜백 추적: `_buttonTapped` (21, 206, 413, 420), `_addMemo` (211-) — root cause 와 무관
- 외부 참고: 본 분석 작성 시점에 Flutter 공식 이슈 트래커 직접 verify 안 함. "Android gesture nav 와 FAB hit-test 경합" 키워드로 본진(🍎) 또는 데스크탑(🖥) 이 cross-check 후보.
