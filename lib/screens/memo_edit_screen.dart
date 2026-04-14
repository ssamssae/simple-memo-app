import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/memo.dart';

class MemoEditScreen extends StatefulWidget {
  final Memo? memo;

  const MemoEditScreen({super.key, this.memo});

  @override
  State<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  late final TextEditingController _contentController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.memo != null;
    _contentController = TextEditingController(
      text: widget.memo?.content ?? '',
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Memo? _buildMemo() {
    final content = _contentController.text.trim();
    if (content.isEmpty) return null;

    if (_isEditing && widget.memo != null) {
      return widget.memo!.copyWith(
        content: content,
        updatedAt: DateTime.now(),
      );
    } else {
      return Memo.create(content: content);
    }
  }

  void _saveMemo() {
    final memo = _buildMemo();
    if (memo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내용을 입력해주세요.')));
      return;
    }
    Navigator.pop(context, memo);
  }

  Future<void> _confirmDeleteEmpty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('빈 메모'),
        content: const Text('내용이 비어 있습니다. 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, 'delete:${widget.memo!.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final memo = _buildMemo();
        if (memo == null && _isEditing) {
          _confirmDeleteEmpty();
          return;
        }
        Navigator.pop(context, memo);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        appBar: AppBar(
          centerTitle: true,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leadingWidth: 90,
          leading: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 12, color: Colors.amber.shade300),
                      const SizedBox(width: 4),
                      Text(
                        '뒤로',
                        style: TextStyle(color: Colors.amber.shade300, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          title: Text(_isEditing ? '메모수정' : '새메모'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: _saveMemo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 12, color: Colors.amber.shade300),
                      const SizedBox(width: 4),
                      Text(
                        '저장',
                        style: TextStyle(color: Colors.amber.shade300, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: TextField(
            controller: _contentController,
            cursorColor: Colors.amber,
            decoration: InputDecoration(
              hintText: '내용을 입력하세요...',
              hintStyle: TextStyle(color: Colors.amber.withValues(alpha: 0.4)),
              border: InputBorder.none,
              isCollapsed: true,
            ),
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 18,
              height: 1.5,
              leadingDistribution: TextLeadingDistribution.even,
              letterSpacing: 0.2,
            ),
            maxLines: null,
            autofocus: !_isEditing,
            contextMenuBuilder: (context, editableTextState) {
              final items = List<ContextMenuButtonItem>.from(
                editableTextState.contextMenuButtonItems,
              );
              for (var i = 0; i < items.length; i++) {
                if (items[i].type == ContextMenuButtonType.copy) {
                  items[i] = ContextMenuButtonItem(
                    type: ContextMenuButtonType.copy,
                    onPressed: () {
                      final value = editableTextState.textEditingValue;
                      final selection = value.selection;
                      if (selection.isValid && !selection.isCollapsed) {
                        var selected = selection.textInside(value.text);
                        // 세 번 탭 등으로 줄 끝 개행까지 선택된 경우 제거
                        if (selected.endsWith('\n')) {
                          selected = selected.substring(
                            0,
                            selected.length - 1,
                          );
                        }
                        Clipboard.setData(
                          ClipboardData(text: selected),
                        );
                      }
                      editableTextState.hideToolbar();
                    },
                  );
                }
              }
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: items,
              );
            },
          ),
            ),
          ),
          ),
          ),
        ),
      ),
    );
  }
}
