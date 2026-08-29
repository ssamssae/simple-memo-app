import 'package:flutter/material.dart';

import 'attachment_thumbnail.dart';

/// 편집 화면 본문 아래 가로 스크롤 썸네일 줄. 사진 0장이면 호출부가 아예 넣지 않는다.
class AttachmentStrip extends StatelessWidget {
  const AttachmentStrip({
    super.key,
    required this.fileNames,
    required this.onTap,
    required this.onLongPress,
  });

  static const double tileSize = 72;
  static const double topPadding = 16;
  // 편집 화면이 뷰포트에서 이 스트립 몫으로 빼둬야 하는 총 높이 — 단일 출처.
  static const double totalHeight = tileSize + topPadding;

  final List<String> fileNames;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: topPadding),
      child: SizedBox(
        height: tileSize,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
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
