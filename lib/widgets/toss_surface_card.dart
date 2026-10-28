import 'package:flutter/material.dart';

import '../utils/app_palette.dart';

/// 홈 목록과 같은 토스톤 면. 바탕은 팔레트 surface, 모서리는 16.
class TossSurfaceCard extends StatelessWidget {
  const TossSurfaceCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.padding,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? padding;

  /// 목록 행의 물결은 모서리 안으로 자른다.
  /// 편집 본문처럼 선택 핸들이 밖으로 나가야 하는 면은 false.
  final bool clip;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: AppPalette.of(context).surface,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}
