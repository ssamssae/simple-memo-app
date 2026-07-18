// T-260718-058 앱인토스 정식 래퍼 — 메모 편집 화면.
//
// 본편 memo_edit_screen 은 프리미엄 요약·shake·share 플러그인이 얽혀 웹 빌드에
// 못 올라온다. 미니앱판은 핵심 편집 UX 만 유지: 전체화면 입력, 뒤로가기 = 자동
// 저장(빈 새 메모는 폐기), 기존 메모 휴지통 이동. 저장은 호출측(리스트)이 아니라
// 이 화면이 AitMemoStore 로 직접 수행해 재진입/중단에도 유실이 없다.
import 'package:flutter/material.dart';

import '../../models/memo.dart';
import '../ait_memo_store.dart';

class AitMemoEditScreen extends StatefulWidget {
  const AitMemoEditScreen({super.key, this.memoId});

  /// null = 새 메모.
  final String? memoId;

  @override
  State<AitMemoEditScreen> createState() => _AitMemoEditScreenState();
}

class _AitMemoEditScreenState extends State<AitMemoEditScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  Memo? _memo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.memoId != null) {
      final memos = await AitMemoStore.loadMemos();
      final idx = memos.indexWhere((m) => m.id == widget.memoId);
      if (idx >= 0) {
        _memo = memos[idx];
        _controller.text = _memo!.content;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 변경분 저장. 새 메모 + 빈 내용 = 저장 없이 폐기.
  Future<void> _saveIfNeeded() async {
    if (_saving) return;
    final text = _controller.text.trim();
    final existing = _memo;
    if (existing == null && text.isEmpty) return;
    if (existing != null && existing.content == text) return;
    _saving = true;
    final memos = await AitMemoStore.loadMemos();
    final now = DateTime.now();
    if (existing == null) {
      memos.insert(0, Memo.create(content: text));
    } else {
      final idx = memos.indexWhere((m) => m.id == existing.id);
      if (idx >= 0) {
        memos[idx] = memos[idx].copyWith(content: text, updatedAt: now);
      } else {
        memos.insert(0, Memo.create(content: text));
      }
    }
    await AitMemoStore.saveMemos(memos);
    _saving = false;
  }

  Future<void> _moveToTrash() async {
    final existing = _memo;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('휴지통으로 이동할까요?'),
        content: const Text('휴지통에서 30일 안에 복구할 수 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('이동')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final memos = await AitMemoStore.loadMemos();
    final idx = memos.indexWhere((m) => m.id == existing.id);
    if (idx >= 0) {
      memos[idx] = memos[idx].copyWith(deletedAt: DateTime.now());
      await AitMemoStore.saveMemos(memos);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await _saveIfNeeded();
        if (mounted) navigator.pop(true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.memoId == null ? '새 메모' : '메모'),
          actions: [
            if (_memo != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '휴지통으로 이동',
                onPressed: _moveToTrash,
              ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _controller,
                    autofocus: widget.memoId == null,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '메모를 입력하세요',
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
