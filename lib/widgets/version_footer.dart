import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

// 메모요 (simple_memo_app) 는 자체 AppColors 디자인 토큰이 없는 minimal
// Material 3 앱 (main.dart ColorScheme.fromSeed + amber accent inline, cluster D)
// 이라 spec v1.4 fallback 룰 `Theme.of(context).hintColor` 적용. 로또 친족.
// 버전은 package_info_plus 로 런타임에 실제 pubspec 버전을 읽는다 — dart-define
// (`--dart-define=APP_VERSION`) 의존이 사라져 빌드 플래그 누락 시 'vdev' 로 박히던
// footgun 제거. 로드 전엔 버전 없이 '마이너스베타스튜디오' 만 렌더.
class VersionFooter extends StatelessWidget {
  const VersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '';
        final label = version.isEmpty
            ? '마이너스베타스튜디오'
            : 'v$version · 마이너스베타스튜디오';
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).hintColor,
              letterSpacing: -0.1,
            ),
          ),
        );
      },
    );
  }
}
