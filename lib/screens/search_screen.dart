import 'dart:async';

import 'package:flutter/material.dart';

import '../models/memo.dart';
import '../services/memo_storage.dart';
import '../services/search_service.dart';
import 'memo_edit_screen.dart';

/// 메모요 1.0.8 검색 화면 (T-260615-26, spec docs/specs/1.0.8-search.md §3).
///
/// AppBar morph 대신 별 화면 push — 뒤로가기 = 검색 이탈(§6.1 step 6). 활성 메모만 대상(§4.1 A).
/// 입력 디바운스 300ms(§2.4), 결과 카드 RichText amber 하이라이트(§3.3/§3.5), 빈 결과 empty state(§3.7).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _sub = Color(0xFF9A9AA2);
  static const _debounceMs = 300;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  List<Memo> _all = [];
  List<Memo> _results = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMemos();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadMemos() async {
    final memos = await MemoStorage.loadMemos(); // 활성 메모만
    if (!mounted) return;
    setState(() {
      _all = memos;
      _results = SearchService.search(_all, _query);
      _loading = false;
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _results = SearchService.search(_all, _query);
      });
    });
  }

  Future<void> _openMemo(Memo memo) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(
          memo: memo,
          // 편집 화면은 영속하지 않고 콜백에 위임(메모 리스트 화면과 동일 패턴).
          onSave: (updated) {
            final i = _all.indexWhere((m) => m.id == updated.id);
            if (i != -1) _all[i] = updated;
            MemoStorage.saveMemos(_all);
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _results = SearchService.search(_all, _query));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: '메모 검색',
            border: InputBorder.none,
            hintStyle: TextStyle(color: _sub),
          ),
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: _sub),
              tooltip: '지우기',
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_query.trim().isEmpty) {
      return const _CenterHint(
        icon: Icons.search,
        text: '메모 내용을 검색해 보세요.',
      );
    }
    if (_results.isEmpty) {
      return _CenterHint(
        icon: Icons.search_off,
        text: '"${_query.trim()}" 검색 결과가 없습니다.\n다른 검색어로 시도해 보세요.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '메모 결과 (${_results.length}건)',
            style: const TextStyle(color: _sub, fontSize: 13),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) => _SearchResultCard(
              memo: _results[i],
              query: _query,
              onTap: () => _openMemo(_results[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterHint extends StatelessWidget {
  const _CenterHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: const Color(0xFF9A9AA2)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF9A9AA2)),
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.memo,
    required this.query,
    required this.onTap,
  });

  final Memo memo;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 제목(첫 줄) 하이라이트 — 짧으므로 충분한 context 로 전체 노출.
    final titleExc =
        SearchService.excerpt(memo.firstLine, query, context: 1000);
    // 본문 발췌 하이라이트 (첫 매치 ±30자). 본문 미매치면 plain 미리보기.
    final bodyExc = SearchService.excerpt(memo.content, query);
    final bodyPreview = bodyExc.start >= 0
        ? bodyExc
        : SearchExcerpt(_plainPreview(memo.content), -1, 0);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (memo.isFavorite)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.star, size: 16, color: Color(0xFF7C5CFF)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _highlight(
                    titleExc,
                    const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222228),
                    ),
                  ),
                  if (bodyPreview.text.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    _highlight(
                      bodyPreview,
                      const TextStyle(fontSize: 13, color: Color(0xFF9A9AA2)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _plainPreview(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= 1) return '';
    final rest = lines.skip(1).join(' ').trim();
    return rest.length > 60 ? '${rest.substring(0, 60)}…' : rest;
  }

  Widget _highlight(SearchExcerpt exc, TextStyle base) {
    if (exc.start < 0) {
      return Text(exc.text,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    }
    final end = exc.start + exc.length;
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: exc.text.substring(0, exc.start)),
          TextSpan(
            text: exc.text.substring(exc.start, end),
            style: base.copyWith(
              backgroundColor: Colors.amber.shade300,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222228),
            ),
          ),
          TextSpan(text: exc.text.substring(end)),
        ],
      ),
    );
  }
}
