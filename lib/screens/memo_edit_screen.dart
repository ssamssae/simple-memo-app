import 'package:flutter/material.dart';
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
        appBar: AppBar(
          title: Text(_isEditing ? '메모 수정' : '새 메모'),
          actions: [
            TextButton(
              onPressed: _saveMemo,
              child: const Text('저장', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              hintText: '내용을 입력하세요...',
              border: InputBorder.none,
            ),
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              letterSpacing: 0.2,
            ),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            autofocus: true,
          ),
        ),
      ),
    );
  }
}
