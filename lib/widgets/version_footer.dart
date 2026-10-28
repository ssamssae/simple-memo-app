import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/app_strings.dart';
import '../utils/app_palette.dart';

// 버전은 package_info_plus 로 런타임에 실제 pubspec 버전을 읽는다 — dart-define
// (`--dart-define=APP_VERSION`) 의존이 사라져 빌드 플래그 누락 시 'vdev' 로 박히던
// footgun 제거. 로드 전엔 버전 없이 '마이너스베타스튜디오' 만 렌더.
// 글자색은 토스 보조 회색(AppPalette.textSecondary).
class VersionFooter extends StatelessWidget {
  const VersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '';
        final label = version.isEmpty
            ? AppStrings.of(context).madeBy
            : AppStrings.of(context).versionLine(version);
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppPalette.of(context).textSecondary,
              letterSpacing: -0.1,
            ),
          ),
        );
      },
    );
  }
}
