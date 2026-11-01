import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../utils/app_palette.dart';
import 'attachment_thumbnail.dart';

/// 편집 화면 본문 아래 가로 스크롤 썸네일 줄. 사진 0장이면 호출부가 아예 넣지 않는다.
///
/// 편집 화면 토스 카드 맨 아래에 놓이며, 카드 아래 안쪽 여백([bottomPadding])까지 맡는다.
/// [onRemove] 가 있으면 사진마다 오른쪽 위에 빼기(−) 버튼을 붙인다 (T-261101-034 —
/// 길게 누르기만으로는 지우는 법을 알기 어렵다는 대종님 사용 소감). 길게 누르기는 그대로다.
class AttachmentStrip extends StatelessWidget {
  const AttachmentStrip({
    super.key,
    required this.fileNames,
    required this.onTap,
    required this.onLongPress,
    this.onRemove,
    this.horizontalPadding = 0,
  });

  static const double tileSize = 72;
  // 본문 마지막 줄 ~ 사진 윗변.
  static const double topPadding = 16;
  // 사진 아랫변 ~ 카드 아랫변. 편집 화면 카드 안쪽 여백(16)과 같은 값 (T-261101-034).
  static const double bottomPadding = 16;
  // 편집 화면이 뷰포트에서 이 스트립 몫으로 빼둬야 하는 총 높이 — 단일 출처.
  static const double totalHeight = topPadding + tileSize + bottomPadding;

  // 사진 사이 간격(옛 separator 값 그대로). 빼기 버튼 누르는 곳이 오른쪽으로 이만큼 나간다.
  static const double tileGap = 8;
  // 빼기 버튼 누르는 곳 — iOS 최소 터치 크기.
  static const double removeHitSize = 44;
  // 누르는 곳을 사진 위 바깥으로 이만큼 올려 둔다. 그래야 44pt 가 사진 가운데
  // (보기 탭·길게 누르기 자리)를 덮지 않는다: 사진 안으로는 위에서 44 − 12 = 32 까지만.
  // 이 몫은 [topPadding] 안에 겹치므로 본문 ~ 사진 간격과 줄 전체 높이는 그대로다.
  static const double removeOverhang = 12;
  static const double _badgeSize = 20;
  // 빼기 원은 사진 오른쪽 위 모서리 안쪽에 이만큼 떨어져 놓인다.
  static const double _badgeInset = 4;

  final List<String> fileNames;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onLongPress;
  final ValueChanged<int>? onRemove;

  // 첫 사진의 왼쪽 여백 — 호출부 본문 글자의 시작선과 맞춘다.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: topPadding - removeOverhang,
        bottom: bottomPadding,
      ),
      child: SizedBox(
        height: tileSize + removeOverhang,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          // 오른쪽 아래 사진 추가 FAB(작은 40pt + 여백 16) 밑으로 마지막 타일이
          // 숨지 않게 끝에 여백 — 스크롤하면 타일이 FAB 왼쪽으로 완전히 나온다.
          // 칸마다 오른쪽에 간격이 붙어 있어 그만큼 덜 둔다(사진 끝 위치는 같다).
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: 56 - tileGap,
          ),
          itemCount: fileNames.length,
          // 칸 = 사진 + 오른쪽 간격. 빼기 버튼 누르는 곳은 칸 오른쪽 위 44pt 다.
          itemBuilder: (context, index) => SizedBox(
            key: ValueKey(fileNames[index]),
            width: tileSize + tileGap,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: tileSize,
                  height: tileSize,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(index),
                    onLongPress: () => onLongPress(index),
                    child: AttachmentThumbnail(
                      fileName: fileNames[index],
                      size: tileSize,
                      radius: 10,
                    ),
                  ),
                ),
                if (onRemove != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _RemoveButton(onPressed: () => onRemove!(index)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 썸네일 오른쪽 위 빼기(−) 버튼. 누르는 곳은 44pt, 보이는 원은 20pt.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // 라이트·다크 모두 카드 바탕과 반대 밝기의 원에 카드 색 테두리를 두른다.
    // 원은 카드 위에서 보이고, 테두리는 밝은 사진·어두운 사진 위에서 원을 가른다.
    return Semantics(
      container: true,
      button: true,
      label: AppStrings.of(context).deletePhotoConfirmTitle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: AttachmentStrip.removeHitSize,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              // 누르는 곳은 사진보다 위로 removeOverhang, 오른쪽으로 tileGap 나가 있다.
              padding: const EdgeInsets.only(
                top:
                    AttachmentStrip.removeOverhang +
                    AttachmentStrip._badgeInset,
                right: AttachmentStrip.tileGap + AttachmentStrip._badgeInset,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.textPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.surface, width: 2),
                ),
                child: SizedBox.square(
                  dimension: AttachmentStrip._badgeSize,
                  child: Icon(Icons.remove, size: 14, color: palette.surface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
