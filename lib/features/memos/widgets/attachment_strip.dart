import 'package:flutter/material.dart';

import 'attachment_thumbnail.dart';

/// 편집 화면 본문 아래 가로 스크롤 썸네일 줄. 사진 0장이면 호출부가 아예 넣지 않는다.
///
/// 편집 화면 토스 카드 맨 아래에 놓이며, 카드 아래 안쪽 여백([bottomPadding])까지 맡는다.
class AttachmentStrip extends StatelessWidget {
  const AttachmentStrip({
    super.key,
    required this.fileNames,
    required this.onTap,
    required this.onLongPress,
    this.horizontalPadding = 0,
  });

  static const double tileSize = 72;
  // 본문 마지막 줄 ~ 사진 윗변.
  static const double topPadding = 16;
  // 사진 아랫변 ~ 카드 아랫변. 편집 화면 카드 안쪽 여백(16)과 같은 값 (T-261101-034).
  static const double bottomPadding = 16;
  // 편집 화면이 뷰포트에서 이 스트립 몫으로 빼둬야 하는 총 높이 — 단일 출처.
  static const double totalHeight = topPadding + tileSize + bottomPadding;

  final List<String> fileNames;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onLongPress;

  // 첫 사진의 왼쪽 여백 — 호출부 본문 글자의 시작선과 맞춘다.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: SizedBox(
        height: tileSize,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          // 오른쪽 아래 사진 추가 FAB(작은 40pt + 여백 16) 밑으로 마지막 타일이
          // 숨지 않게 끝에 여백 — 스크롤하면 타일이 FAB 왼쪽으로 완전히 나온다.
          padding: EdgeInsets.only(left: horizontalPadding, right: 56),
          itemCount: fileNames.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => GestureDetector(
            key: ValueKey(fileNames[index]),
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
      ),
    );
  }
}
