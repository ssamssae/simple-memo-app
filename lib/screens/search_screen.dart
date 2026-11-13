import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/memos/semantic_search_availability.dart';
import '../features/memos/services/embedding_engine.dart';
import '../features/memos/services/mini_lm_embedding_engine.dart';
import '../features/memos/services/mini_lm_model_installer.dart';
import '../features/memos/services/mini_lm_runtime.dart';
import '../features/memos/services/semantic_search_coordinator.dart';
import '../features/memos/widgets/attachment_thumbnail.dart';
import '../models/memo.dart';
import '../services/memo_storage.dart';
import '../services/search_service.dart';
import '../services/settings_service.dart';
import '../utils/app_palette.dart';
import '../widgets/toss_surface_card.dart';
import 'memo_edit_screen.dart';
import '../l10n/app_strings.dart';

/// 메모요 1.0.8 검색 화면 (T-260615-26, spec docs/specs/1.0.8-search.md §3).
///
/// AppBar morph 대신 별 화면 push — 뒤로가기 = 검색 이탈(§6.1 step 6). 활성 메모만 대상(§4.1 A).
/// 입력 디바운스 300ms(§2.4), 결과 카드는 보라 하이라이트(§3.3/§3.5), 빈 결과 empty state(§3.7).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.semanticCoordinator});

  final SemanticSearchCoordinator? semanticCoordinator;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _SearchMode { lexical, semantic }

class _SearchScreenState extends State<SearchScreen> {
  static const _debounceMs = 300;

  /// 보조 글자·아이콘 색. 테마를 따라가야 라이트 모드에서 안 묻힌다.
  Color get _sub => AppPalette.of(context).textSecondary;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  List<Memo> _all = [];
  List<Memo> _results = [];
  String _query = '';
  bool _loading = true;
  bool _semanticBusy = false;
  String? _semanticFallbackCode;
  _SearchMode _mode = _SearchMode.lexical;
  int _searchTicket = 0;

  late final SemanticSearchCoordinator _semanticCoordinator =
      widget.semanticCoordinator ?? _buildSemanticCoordinator();

  SemanticSearchCoordinator _buildSemanticCoordinator() {
    final policy = SemanticEnginePolicy.configured;
    MiniLmEmbeddingEngine? onDeviceEngine;
    if (policy == SemanticEnginePolicy.ondevicePreferred) {
      final runtime = MethodChannelMiniLmRuntime();
      final installer = MiniLmModelInstaller(
        freeSpaceProvider: runtime.availableBytes,
      );
      onDeviceEngine = MiniLmEmbeddingEngine(
        installer: installer,
        runtime: runtime,
      );
    }
    return SemanticSearchCoordinator(
      policy: policy,
      onDeviceEngine: onDeviceEngine,
    );
  }

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
    // T-261103-001: 들어오자마자 뒤로 가면 아이폰에서 키보드 내림이 올림과 엇갈려 묻히고
    // 메모 목록 위에 키보드가 남은 적이 있다. 화면이 완전히 사라진 지금 한 번 더 내린다.
    // 이 화면은 입력칸 없는 메모 목록으로만 돌아간다.
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
    super.dispose();
  }

  Future<void> _loadMemos() async {
    // 색인 저장 시 휴지통도 보존하도록 전체 목록을 유지한다.
    final memos = await MemoStorage.loadMemos();
    if (!mounted) return;
    setState(() {
      _all = memos;
      _results = SearchService.search(_all, _query);
      _loading = false;
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Invalidate the old result as soon as the input changes, before debounce.
    _searchTicket++;
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      if (!mounted) return;
      unawaited(_runSearch(value));
    });
  }

  Future<void> _selectMode(Set<_SearchMode> selection) async {
    final next = selection.first;
    if (next == _mode) return;
    // ★2차 방어 (T-260804-086) — 세그먼트를 안 그리므로 여기 semantic 이 들어올 길은 지금 없다.
    //   그래도 막아 둔다: 나중에 누가 다른 진입점(메뉴·단축키·딥링크)을 붙이면 UI 만 고치고
    //   이 함수는 안 볼 텐데, 그러면 잠금이 조용히 풀린다.
    if (!kSemanticSearchEnabled && next == _SearchMode.semantic) return;
    _debounce?.cancel();
    // ★구독 폐지 (T-260805-076) — 종전에는 여기서 비구독자를 PaywallScreen 으로 보냈다.
    //   구독 상품 자체가 없어졌으니 「돈 내면 열리는 문」이 아니라 그냥 잠긴 문이다.
    //   잠금은 위 kSemanticSearchEnabled 한 줄이 전담한다(판정 이중화 금지 — 그 파일 주석 참조).
    setState(() {
      _mode = next;
      _semanticFallbackCode = null;
    });
    await _runSearch(_controller.text);
  }

  Future<void> _runSearch(String value) async {
    final ticket = ++_searchTicket;
    final query = value;
    // ★3차 방어 (T-260804-086) — 이 조건이 유료 임베딩 호출의 마지막 관문이다.
    //   플래그가 꺼져 있으면 _mode 값이 무엇이든 lexical 경로로만 간다 = 임베딩 클라이언트에
    //   도달 불가. 회귀축 (b)가 스파이로 이걸 단언한다.
    if (!kSemanticSearchEnabled ||
        _mode == _SearchMode.lexical ||
        query.trim().isEmpty) {
      if (!mounted || ticket != _searchTicket) return;
      setState(() {
        _query = query;
        _results = SearchService.search(_all, query);
        _semanticBusy = false;
        _semanticFallbackCode = null;
      });
      return;
    }

    setState(() {
      _query = query;
      _results = SearchService.search(_all, query);
      _semanticBusy = true;
      _semanticFallbackCode = null;
    });

    try {
      final outcome = await _semanticCoordinator.search(
        query: query,
        memos: _all,
        persist: (memos) async {
          if (!mounted || ticket != _searchTicket) return;
          await MemoStorage.saveMemos(memos);
          if (!mounted || ticket != _searchTicket) return;
          setState(() {
            _all = List<Memo>.of(memos);
            _results = SearchService.search(_all, query);
          });
        },
      );
      if (!mounted || ticket != _searchTicket) return;
      setState(() {
        _all = outcome.memos;
        _results = outcome.results;
        _semanticBusy = false;
        _semanticFallbackCode = outcome.semantic ? null : outcome.fallbackCode;
      });
    } catch (_) {
      if (!mounted || ticket != _searchTicket) return;
      setState(() {
        _results = SearchService.search(_all, query);
        _semanticBusy = false;
        _semanticFallbackCode = 'MEMOYO_EMBED_FAILED';
      });
    }
  }

  Future<void> _openMemo(Memo memo) async {
    _debounce?.cancel();
    _searchTicket++;
    setState(() => _semanticBusy = false);
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
    await _runSearch(_controller.text);
  }

  static final _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        // 뒤로 버튼이 있으면 바로 옆에 붙이고, 없으면 화면 여백 16.
        titleSpacing: (ModalRoute.of(context)?.canPop ?? false) ? 0 : 16,
        // T-261103-001 토스톤: 회색 둥근 칸 하나 — 돋보기는 칸 안 왼쪽, 지우기는 칸 안 오른쪽.
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              cursorColor: palette.accent,
              style: TextStyle(fontSize: 16, color: palette.textPrimary),
              decoration: InputDecoration(
                hintText: AppStrings.of(context).searchHint,
                hintStyle: TextStyle(color: _sub),
                filled: true,
                fillColor: palette.surface,
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: _sub),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.cancel, size: 18, color: _sub),
                        tooltip: AppStrings.of(context).clearTooltip,
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: _fieldBorder,
                enabledBorder: _fieldBorder,
                focusedBorder: _fieldBorder,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildModePicker(),
        if (_semanticBusy)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(child: _buildResultsBody()),
      ],
    );
  }

  Widget _buildModePicker() {
    // ★말로찾기 잠금 (T-260804-086) — 세그먼트가 2개인데 하나를 못 쓰게 하면 「눌러도 안 되는
    //   버튼」이 남는다. 그래서 선택기 자체를 안 그린다. 남는 모드는 lexical 하나뿐이라
    //   SegmentedButton 이 의미를 잃기 때문이기도 하다. 어휘·레이아웃은 건드리지 않았다 —
    //   플래그를 켜면 이 블록이 통째로 원래대로 돌아온다.
    if (!kSemanticSearchEnabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<_SearchMode>(
              showSelectedIcon: false,
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  final palette = AppPalette.of(context);
                  if (states.contains(WidgetState.selected)) {
                    return palette.onAccent;
                  }
                  return palette.textPrimary;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  final palette = AppPalette.of(context);
                  if (states.contains(WidgetState.selected)) {
                    return palette.accent;
                  }
                  return palette.surface;
                }),
              ),
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  unawaited(_selectMode(selection)),
              segments: [
                ButtonSegment(
                  value: _SearchMode.lexical,
                  icon: Icon(Icons.search, size: 18),
                  label: Text(AppStrings.of(context).keywordSearch),
                ),
                ButtonSegment(
                  value: _SearchMode.semantic,
                  icon: Icon(Icons.manage_search_outlined, size: 18),
                  label: Text(AppStrings.of(context).semanticSearch),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsBody() {
    if (_query.trim().isEmpty) {
      return _CenterHint(
        icon: Icons.search_rounded,
        text: AppStrings.of(context).searchPrompt,
      );
    }
    if (_results.isEmpty) {
      return _CenterHint(
        icon: Icons.search_off_rounded,
        text: AppStrings.of(context).noSearchResults(_query.trim()),
      );
    }
    return ListView(
      // 메모 목록과 같은 여백·묶음 라벨(T-261103-001).
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        if (_semanticFallbackCode != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Text(
              AppStrings.of(context).semanticFallbackNotice,
              style: TextStyle(color: _sub, fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
          child: Text(
            AppStrings.of(context).memoResults(_results.length),
            style: TextStyle(
              color: _sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final memo in _results)
          _SearchResultCard(
            memo: memo,
            query: _query,
            onTap: () => _openMemo(memo),
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
          Icon(
            icon,
            size: 40,
            color: AppPalette.of(context).textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppPalette.of(context).textSecondary,
            ),
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
    final titleExc = SearchService.excerpt(
      memo.firstLine,
      query,
      context: 1000,
    );
    // 본문 발췌 하이라이트 (첫 매치 ±30자). 본문 미매치면 plain 미리보기.
    // T-261103-001: 제목 줄은 빼고 찾는다 — 한 줄 메모가 제목·미리보기에 두 번 나오던 것.
    final bodyExc = SearchService.excerpt(_restLines(memo.content), query);
    final bodyPreview = bodyExc.start >= 0
        ? bodyExc
        : SearchExcerpt(_plainPreview(memo.content), -1, 0);

    final palette = AppPalette.of(context);
    return TossSurfaceCard(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              if (memo.isDone)
                Padding(
                  key: const Key('search-done-mark'),
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(Icons.check_box, size: 18, color: palette.accent),
                ),
              if (memo.isFavorite)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(Icons.star, size: 18, color: palette.accent),
                ),
              if (memo.hasImages)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: AttachmentThumbnail(
                    fileName: memo.imageFiles.first,
                    size: 36,
                  ),
                ),
              Expanded(
                // 메모 목록처럼 글자 크기 설정을 따른다(기본 17).
                child: ValueListenableBuilder<double>(
                  valueListenable: SettingsService.instance.bodyFontSize,
                  builder: (context, bodyFontSize, _) {
                    final scale =
                        bodyFontSize / SettingsService.defaultBodyFontSize;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _highlight(
                          context,
                          titleExc,
                          TextStyle(
                            fontSize: 17 * scale,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            // 완료한 메모도 찾힌다 — 완료 탭처럼 흐린 취소선 (T-261113-024).
                            color: memo.isDone
                                ? palette.textSecondary
                                : palette.textPrimary,
                            decoration: memo.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: palette.textSecondary,
                          ),
                        ),
                        if (bodyPreview.text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _highlight(
                            context,
                            bodyPreview,
                            TextStyle(
                              fontSize: 14 * scale,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 첫 줄(제목)을 뺀 나머지 줄을 한 줄로 잇는다.
  String _restLines(String content) {
    final lines = content
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.length <= 1) return '';
    return lines.skip(1).join(' ').trim();
  }

  String _plainPreview(String content) {
    final rest = _restLines(content);
    return rest.length > 60 ? '${rest.substring(0, 60)}…' : rest;
  }

  // Text.rich — RichText 와 달리 앱 기본 글꼴(Pretendard)을 물려받는다(T-261103-001).
  // 강조는 바탕 칠 대신 보라 굵은 글자(토스톤).
  Widget _highlight(BuildContext context, SearchExcerpt exc, TextStyle base) {
    if (exc.start < 0) {
      return Text(
        exc.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    final end = exc.start + exc.length;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: exc.text.substring(0, exc.start)),
          TextSpan(
            text: exc.text.substring(exc.start, end),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppPalette.of(context).accent,
            ),
          ),
          TextSpan(text: exc.text.substring(end)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}
