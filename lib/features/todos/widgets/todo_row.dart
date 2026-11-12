import 'package:flutter/material.dart';

import '../../../utils/app_palette.dart';
import '../models/todo.dart';

/// 할 일 한 줄: 둥근 네모 칸 · 제목 한 줄 · 메모 표시(T-261112-052).
/// [checked] 는 화면이 그리는 칸 상태(완료 구역으로 빠지기 전 1초 동안도 true).
class TodoRow extends StatelessWidget {
  const TodoRow({
    super.key,
    required this.todo,
    required this.checked,
    required this.onToggle,
    this.onTap,
    this.dimmed = false,
  });

  final Todo todo;
  final bool checked;
  final ValueChanged<Todo> onToggle;
  final VoidCallback? onTap;

  /// 완료 구역: 회색 + 취소선.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    const box = 22.0;
    final check = InkResponse(
      key: ValueKey('todo-check-${todo.id}'),
      onTap: () => onToggle(todo),
      radius: 22,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: box,
        height: box,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked ? palette.accent : null,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: checked ? palette.accent : palette.textSecondary,
            width: 1.6,
          ),
        ),
        child: checked
            ? Icon(Icons.check, size: 16, color: palette.onAccent)
            : null,
      ),
    );
    final titleStyle = TextStyle(
      fontSize: 16,
      color: dimmed ? palette.textSecondary : palette.textPrimary,
      decoration: dimmed ? TextDecoration.lineThrough : null,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Padding(padding: const EdgeInsets.all(4), child: check),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                todo.title.replaceAll(RegExp(r'\s*\n\s*'), ' '),
                key: ValueKey('todo-title-${todo.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            if (todo.hasNote) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.description_outlined,
                key: ValueKey('todo-note-${todo.id}'),
                size: 16,
                color: palette.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
