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

    if (_isEditing) {
      final memo = widget.memo!;
      memo.content = content;
      memo.updatedAt = DateTime.now();
      return memo;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final memo = _buildMemo();
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
