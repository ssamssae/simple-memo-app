import 'package:flutter/material.dart';

import '../utils/app_palette.dart';

/// 분절 버튼의 한 칸.
class TossSegment<T> {
  const TossSegment(this.value, this.label);

  final T value;
  final String label;
}

/// 토스 분절 버튼 — 회색 트랙 위에 선택한 칸만 떠 있는 손잡이 (T-261103-005).
///
/// 머티리얼 SegmentedButton 의 테두리·칸 구분선·보라 채움 대신, 트랙은 화면 바탕색,
/// 손잡이는 한 단 뜬 면(라이트는 흰색 + 옅은 그림자)이다. 선택 글자만 굵고 진하다.
class TossSegmentedControl<T> extends StatelessWidget {
  const TossSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<TossSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final count = segments.length;
    final index = segments.indexWhere((s) => s.value == selected);
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          if (index >= 0)
            AnimatedAlign(
              alignment: Alignment(
                count == 1 ? 0 : -1 + 2 * index / (count - 1),
                0,
              ),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: Container(
                  key: const Key('toss-segmented-thumb'),
                  decoration: BoxDecoration(
                    color: palette.elevatedSurface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isLight
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final segment in segments)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: segment.value == selected,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (segment.value != selected) onChanged(segment.value);
                      },
                      child: Center(
                        child: Text(
                          segment.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: segment.value == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: segment.value == selected
                                ? palette.textPrimary
                                : palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
