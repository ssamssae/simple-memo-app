import 'dart:async';

import '../../../models/memo.dart';
import '../../../services/search_service.dart';
import 'embedding_engine.dart';
import 'semantic_search_service.dart';

typedef SemanticIndexPersist = Future<void> Function(List<Memo> memos);

class SemanticReindexProgress {
  const SemanticReindexProgress({required this.completed, required this.total});

  final int completed;
  final int total;
}

class SemanticSearchOutcome {
  const SemanticSearchOutcome({
    required this.memos,
    required this.results,
    required this.semantic,
    required this.changed,
    this.engineId,
    this.fallbackCode,
  });

  final List<Memo> memos;
  final List<Memo> results;
  final bool semantic;
  final bool changed;
  final String? engineId;
  final String? fallbackCode;
}

class SemanticSearchCoordinator {
  SemanticSearchCoordinator({
    required this.policy,
    this.onDeviceEngine,
    this.batchSize = 16,
  });

  final SemanticEnginePolicy policy;
  final EmbeddingEngine? onDeviceEngine;
  final int batchSize;

  Future<SemanticSearchOutcome> search({
    required String query,
    required List<Memo> memos,
    required SemanticIndexPersist persist,
    void Function(SemanticReindexProgress progress)? onProgress,
  }) async {
    if (policy == SemanticEnginePolicy.lexical) {
      return _lexical(memos, query, code: 'MEMOYO_SEMANTIC_POLICY_LEXICAL');
    }

    final candidates = <EmbeddingEngine>[];
    String? lastFailureCode;
    if (policy == SemanticEnginePolicy.ondevicePreferred) {
      final engine = onDeviceEngine;
      if (engine == null) {
        lastFailureCode = 'MEMOYO_MINILM_UNSUPPORTED';
      } else {
        try {
          final capability = await engine.capability();
          if (capability.supported && capability.ready) {
            candidates.add(engine);
          } else {
            lastFailureCode = capability.supported
                ? 'MEMOYO_MINILM_MODEL_MISSING'
                : 'MEMOYO_MINILM_UNSUPPORTED';
          }
        } catch (_) {
          lastFailureCode = 'MEMOYO_MINILM_UNSUPPORTED';
        }
      }
    }
    // ★유료 후보가 아예 없다 (T-260830-013). 여기 있던
    //   `if (policy == gemini) candidates.add(_geminiEngineFactory(userId))` 를 걷었다.
    //
    //   경위: 종전에는 이 add 가 policy 와 무관하게 무조건 실행돼서, ondevice_preferred
    //   인데 온디바이스가 부재·미지원·실패인 순간 후보가 유료 임베딩 엔드포인트
    //   하나만 남아 아니키 비용으로 호출됐다. T-260806-022 가
    //   그걸 「policy 가 명시적으로 gemini 일 때만」으로 좁혔고, 기본값이
    //   ondevice_preferred 라 출고 빌드에선 도달 불가능해졌다. 즉 그 시점부터 이미
    //   죽은 가지였는데, 남은 선언이 MEMOYO_API 를 붙들어 스토어 업로드 관문을 막았다.
    //   그래서 가지째 걷었다 — 애초에 그 백엔드는 만들어진 적도 없다.
    //
    //   ondevice_preferred 의 뜻은 「온디바이스를 먼저 쓴다」가 아니라
    //   ★「온디바이스로만 쓴다, 안 되면 공짜 경로로 내려간다」이다. 온디바이스가 없거나
    //   실패하면 후보가 비고, 아래 루프를 그냥 지나쳐 lexical(문자열 검색)로 강등된다.
    //   기능이 조금 나빠지는 것과 비용이 새는 것 중 후자를 막는 쪽을 고른 것이다
    //   (아니키 2026-08-04 「내 api 로 비용은 못내겠어」, 본진 판정 옵션1 T-260806-022).
    //
    //   회귀축 = test/features/memos/semantic_ondevice_cost_axis_test.dart

    var working = List<Memo>.of(memos);
    var changed = false;
    for (final engine in candidates) {
      try {
        final outcome = await _searchWithEngine(
          engine: engine,
          query: query,
          memos: working,
          persist: persist,
          onProgress: onProgress,
        );
        return SemanticSearchOutcome(
          memos: outcome.memos,
          results: outcome.results,
          semantic: true,
          changed: changed || outcome.changed,
          engineId: outcome.engineId,
        );
      } on _EmbeddingAttemptFailure catch (failure) {
        working = failure.memos;
        changed = changed || failure.changed;
        lastFailureCode = failure.error.code;
      } on EmbeddingFailure catch (failure) {
        lastFailureCode = failure.code;
      } finally {
        try {
          await engine.close();
        } catch (_) {
          // Session release must not suppress a valid result or fallback.
        }
      }
    }
    return _lexical(
      working,
      query,
      code: lastFailureCode ?? 'MEMOYO_EMBED_FAILED',
      changed: changed,
    );
  }

  Future<SemanticSearchOutcome> _searchWithEngine({
    required EmbeddingEngine engine,
    required String query,
    required List<Memo> memos,
    required SemanticIndexPersist persist,
    void Function(SemanticReindexProgress progress)? onProgress,
  }) async {
    final updated = List<Memo>.of(memos);
    EmbeddingBatch? prefetchedQuery;
    int? declaredDimensions = engine.dimensions > 0 ? engine.dimensions : null;
    if (declaredDimensions == null) {
      prefetchedQuery = await engine.embedQuery(query.trim());
      _validateEngineResult(engine, prefetchedQuery, 1);
      declaredDimensions = prefetchedQuery.dimensions;
    }
    final stale = SemanticSearchService.staleMemos(
      updated,
      engineId: engine.engineId,
      dimensions: declaredDimensions,
    ).toList(growable: false);
    var changed = false;
    int? effectiveDimensions = declaredDimensions;

    try {
      for (var start = 0; start < stale.length; start += batchSize) {
        final batch = stale.skip(start).take(batchSize).toList(growable: false);
        final result = await engine.embedDocuments(
          batch.map((memo) => memo.content).toList(growable: false),
        );
        _validateEngineResult(engine, result, batch.length);
        effectiveDimensions ??= result.dimensions;
        if (result.dimensions != effectiveDimensions) {
          throw const EmbeddingFailure(
            EmbeddingFailureKind.invalidResponse,
            'MEMOYO_EMBEDDING_DIMENSION_CHANGED',
          );
        }
        for (var index = 0; index < batch.length; index++) {
          final staleMemo = batch[index];
          final target = updated.indexWhere((memo) => memo.id == staleMemo.id);
          if (target == -1) continue;
          final current = updated[target];
          updated[target] = current.copyWith(
            semanticEmbedding: result.embeddings[index],
            semanticEmbeddingModel: result.engineId,
            semanticEmbeddingSource: SemanticSearchService.embeddingSourceFor(
              current,
            ),
          );
        }
        changed = true;
        await persist(List<Memo>.unmodifiable(updated));
        onProgress?.call(
          SemanticReindexProgress(
            completed: (start + batch.length).clamp(0, stale.length),
            total: stale.length,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      final queryResult =
          prefetchedQuery ?? await engine.embedQuery(query.trim());
      _validateEngineResult(engine, queryResult, 1);
      effectiveDimensions ??= queryResult.dimensions;
      if (queryResult.dimensions != effectiveDimensions ||
          SemanticSearchService.staleMemos(
            updated,
            engineId: engine.engineId,
            dimensions: effectiveDimensions,
          ).isNotEmpty) {
        throw const EmbeddingFailure(
          EmbeddingFailureKind.invalidResponse,
          'MEMOYO_SEMANTIC_INDEX_INCOMPLETE',
        );
      }
      return SemanticSearchOutcome(
        memos: updated,
        results: SemanticSearchService.search(
          updated,
          queryResult.embeddings.single,
          engineId: engine.engineId,
          dimensions: effectiveDimensions,
        ),
        semantic: true,
        changed: changed,
        engineId: engine.engineId,
      );
    } on EmbeddingFailure catch (error) {
      throw _EmbeddingAttemptFailure(error, updated, changed: changed);
    } catch (error) {
      throw _EmbeddingAttemptFailure(
        EmbeddingFailure(
          EmbeddingFailureKind.unavailable,
          'MEMOYO_EMBED_FAILED',
          error,
        ),
        updated,
        changed: changed,
      );
    }
  }

  void _validateEngineResult(
    EmbeddingEngine engine,
    EmbeddingBatch result,
    int expectedCount,
  ) {
    result.validate(expectedCount: expectedCount);
    if (result.engineId != engine.engineId ||
        (engine.dimensions > 0 && result.dimensions != engine.dimensions)) {
      throw const EmbeddingFailure(
        EmbeddingFailureKind.invalidResponse,
        'MEMOYO_EMBEDDING_ENGINE_MISMATCH',
      );
    }
  }

  SemanticSearchOutcome _lexical(
    List<Memo> memos,
    String query, {
    required String code,
    bool changed = false,
  }) {
    return SemanticSearchOutcome(
      memos: memos,
      results: SearchService.search(memos, query),
      semantic: false,
      changed: changed,
      fallbackCode: code,
    );
  }
}

class _EmbeddingAttemptFailure implements Exception {
  const _EmbeddingAttemptFailure(
    this.error,
    this.memos, {
    required this.changed,
  });

  final EmbeddingFailure error;
  final List<Memo> memos;
  final bool changed;
}
