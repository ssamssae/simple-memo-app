// T-260718-058 앱인토스 정식 래퍼 — 검색 화면.
//
// 본편 search_screen 은 시맨틱(MiniLM/Gemini)·프리미엄 경로가 얽혀 있어 미니앱판은
// 키워드 검색(SearchService — pure)만 쓴다. 랭킹·발췌 하이라이트 계약은 본편과 동일
// (1.0.8-search spec).
import 'package:flutter/material.dart';

import '../../models/memo.dart';
import '../../services/search_service.dart';
import '../ait_memo_store.dart';
import 'ait_memo_edit_screen.dart';

class AitSearchScreen extends StatefulWidget {
  const AitSearchScreen({super.key});

  @override
  State<AitSearchScreen> createState() => _AitSearchScreenState();
}

class _AitSearchScreenState extends State<AitSearchScreen> {
  final _controller = TextEditingController();
  List<Memo> _active = [];
  List<Memo> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(_runSearch);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final memos = await AitMemoStore.loadMemos();
    if (!mounted) return;
    setState(() {
      _active = memos.where((m) => !m.isInTrash).toList();
      _loading = false;
    });
    _runSearch();
  }

  void _runSearch() {
    final q = _controller.text;
    setState(() {
      _results = q.trim().isEmpty ? [] : SearchService.search(_active, q);
    });
  }

  Future<void> _open(Memo memo) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AitMemoEditScreen(memoId: memo.id)),
    );
    await _load();
  }

  /// 발췌 텍스트에서 매치 구간만 강조한 RichText 스팬 구성.
  Widget _excerptText(Memo memo, String query, ColorScheme scheme) {
    final ex = SearchService.excerpt(memo.content, query);
    if (ex.start < 0) {
      return Text(ex.text, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final before = ex.text.substring(0, ex.start);
    final match = ex.text.substring(ex.start, ex.start + ex.length);
    final after = ex.text.substring(ex.start + ex.length);
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '메모 검색',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: '지우기',
              onPressed: () => _controller.clear(),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : query.isEmpty
                ? const Center(child: Text('검색어를 입력하세요.'))
                : _results.isEmpty
                    ? const Center(child: Text('검색 결과가 없어요.'))
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final m = _results[i];
                          return ListTile(
                            leading: m.isFavorite
                                ? Icon(Icons.star, size: 18, color: scheme.primary)
                                : null,
                            title: Text(m.firstLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: _excerptText(m, query, scheme),
                            onTap: () => _open(m),
                          );
                        },
                      ),
      ),
    );
  }
}
