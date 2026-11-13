import 'package:flutter/material.dart';

import '../../../utils/app_palette.dart';

/// 메모 줄 왼쪽의 둥근 네모 체크 칸 (T-261113-024).
///
/// 옛 할 일 줄(T-261112-052)과 같은 그림: 22 칸, 모서리 6, 체크하면 보라로 채우고
/// 흰 체크가 튀어나온다. 누르는 범위는 44×44 라 빗맞아도 줄(편집 열기)이 눌리지 않는다.
class MemoDoneCheckbox extends StatelessWidget {
  const MemoDoneCheckbox({
    super.key,
    required this.checked,
    required this.onTap,
    required this.semanticLabel,
  });

  final bool checked;
  final VoidCallback onTap;

  /// 화면 읽기용 이름(메모 첫 줄).
  final String semanticLabel;

  static const double boxSize = 22;
  static const double tapSize = 44;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      container: true,
      button: true,
      checked: checked,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: tapSize,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: boxSize,
              height: boxSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? palette.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? palette.accent : palette.textSecondary,
                  width: 1.6,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: checked
                    ? Icon(
                        Icons.check,
                        key: const ValueKey('on'),
                        size: 16,
                        color: palette.onAccent,
                      )
                    : const SizedBox.shrink(key: ValueKey('off')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
