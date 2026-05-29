import 'package:flutter/material.dart';

// 메모요 (simple_memo_app) 는 자체 AppColors 디자인 토큰이 없는 minimal
// Material 3 앱 (main.dart ColorScheme.fromSeed + amber accent inline, cluster D)
// 이라 spec v1.4 fallback 룰 `Theme.of(context).hintColor` 적용. 로또 친족.
// 버전은 spec v1 dart-define 안 — 빌드 시 `--dart-define=APP_VERSION=X.Y.Z`
// 주입, 미주입 빌드는 `vdev · 강대종` 으로 렌더 (dev 시그널). const widget 안 됨.
class VersionFooter extends StatelessWidget {
  const VersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    const version = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        'v$version · 강대종',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).hintColor,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}
