import 'dart:async';

import '../../../models/memo.dart';
import '../../../services/search_service.dart';
import 'embedding_engine.dart';
import 'semantic_search_service.dart';

typedef GeminiEngineFactory = EmbeddingEngine Function(String userId);
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
    required GeminiEngineFactory geminiEngineFactory,
    this.onDeviceEngine,
    this.batchSize = 16,
  }) : _geminiEngineFactory = geminiEngineFactory;

  final SemanticEnginePolicy policy;
  final GeminiEngineFactory _geminiEngineFactory;
  final EmbeddingEngine? onDeviceEngine;
  final int batchSize;

  Future<SemanticSearchOutcome> search({
    required String userId,
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
    candidates.add(_geminiEngineFactory(userId));

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
