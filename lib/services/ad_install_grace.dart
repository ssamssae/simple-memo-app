/// 설치 후 72시간 광고 유예 (T-261112-020).
///
/// 실제 광고 단위를 쓰기 직전에 [resolveFirstSeen] 으로 처음 본 시각을 고르고,
/// [inInstallGrace] 가 참이면 광고를 요청하지 않는다.
class AdInstallGrace {
  const AdInstallGrace._();

  /// 처음 본 시각. epoch 밀리초. 한 번 저장하면 덮어쓰지 않는다.
  static const String storageKey = 'ads_first_seen_ms';

  /// 이 시간보다 짧게 지났으면 유예다. 딱 72시간은 유예가 아니다.
  static const Duration length = Duration(hours: 72);

  /// `now` 에서 `firstSeen` 을 뺀 시간이 [length] 보다 짧으면 참이다.
  ///
  /// `now` 가 `firstSeen` 보다 과거여도 참이다. 시계를 뒤로 돌린 기기에는
  /// 광고를 내지 않는다.
  static bool inInstallGrace({
    required DateTime now,
    required DateTime firstSeen,
  }) {
    return now.difference(firstSeen) < length;
  }

  /// 처음 본 시각을 고른다.
  ///
  /// 저장값이 있으면 그 값이다. 없으면 [readInstallTime], 그것도 없거나
  /// 읽기에 실패하면 [now]. 고른 값은 저장값이 없을 때만 [saveMs] 로 저장한다.
  static Future<DateTime> resolveFirstSeen({
    required DateTime now,
    required int? storedMs,
    required Future<void> Function(int milliseconds) saveMs,
    required Future<DateTime?> Function() readInstallTime,
  }) async {
    if (storedMs != null) {
      return DateTime.fromMillisecondsSinceEpoch(storedMs);
    }

    DateTime chosen;
    try {
      chosen = await readInstallTime() ?? now;
    } catch (_) {
      chosen = now;
    }
    final millis = chosen.millisecondsSinceEpoch;
    await saveMs(millis);
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
