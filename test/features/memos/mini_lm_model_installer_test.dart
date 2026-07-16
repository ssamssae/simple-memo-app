import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_installer.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_manifest.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_runtime.dart';
import 'package:simple_memo_app/features/memos/services/xlm_roberta_sentencepiece.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late List<MiniLmArtifact> artifacts;
  final modelBytes = utf8.encode('abc');
  final tokenizerBytes = utf8.encode('xy');

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('memoyo-minilm-test-');
    artifacts = [
      MiniLmArtifact(
        name: 'model.onnx',
        repositoryPath: 'model.onnx',
        size: modelBytes.length,
        sha256: sha256.convert(modelBytes).toString(),
        downloadUriOverride: Uri.parse('https://models.test/model.onnx'),
      ),
      MiniLmArtifact(
        name: 'tokenizer.model',
        repositoryPath: 'tokenizer.model',
        size: tokenizerBytes.length,
        sha256: sha256.convert(tokenizerBytes).toString(),
        downloadUriOverride: Uri.parse('https://models.test/tokenizer.model'),
      ),
    ];
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  MiniLmModelInstaller installer(http.Client client, {int maxAttempts = 3}) {
    return MiniLmModelInstaller(
      client: client,
      directoryProvider: () async => temp,
      freeSpaceProvider: (_) async => 1024 * 1024 * 1024,
      manifestVerifier: () async {},
      artifacts: artifacts,
      maxAttempts: maxAttempts,
    );
  }

  test(
    'bundled signed manifest matches its compiled digest and exact ID',
    () async {
      await MiniLmModelManifest.verifyBundled();
      expect(MiniLmModelManifest.totalDownloadBytes, 123481449);
      expect(
        MiniLmModelManifest.engineId,
        contains(MiniLmModelManifest.revision),
      );
      expect(
        MiniLmModelManifest.engineId,
        contains(MiniLmModelManifest.model.sha256),
      );
      expect(
        MiniLmModelManifest.engineId,
        contains(MiniLmModelManifest.tokenizer.sha256),
      );
      expect(MiniLmModelManifest.engineId, endsWith('dim:384'));
    },
  );

  test(
    'install resumes partial bytes, verifies hashes, and can delete',
    () async {
      await File(
        '${temp.path}/model.onnx.part',
      ).writeAsBytes(modelBytes.take(1).toList());
      var sawRange = false;
      final progress = <double>[];
      final store = installer(
        MockClient((request) async {
          if (request.url.path.endsWith('model.onnx')) {
            sawRange = request.headers['range'] == 'bytes=1-';
            return http.Response.bytes(
              modelBytes.skip(1).toList(),
              HttpStatus.partialContent,
            );
          }
          return http.Response.bytes(tokenizerBytes, HttpStatus.ok);
        }),
      );

      final paths = await store.install(
        onProgress: (value) => progress.add(value.fraction),
      );

      expect(sawRange, isTrue);
      expect(await File(paths.modelPath).readAsBytes(), modelBytes);
      expect(await File(paths.tokenizerPath).readAsBytes(), tokenizerBytes);
      expect(await store.isInstalled(), isTrue);
      expect(progress.last, 1);
      await store.delete();
      expect(await store.isInstalled(), isFalse);
    },
  );

  test(
    'complete verified partials are atomically promoted without network',
    () async {
      await File('${temp.path}/model.onnx.part').writeAsBytes(modelBytes);
      await File(
        '${temp.path}/tokenizer.model.part',
      ).writeAsBytes(tokenizerBytes);
      var networkCalls = 0;
      final store = installer(
        MockClient((_) async {
          networkCalls++;
          return http.Response('', HttpStatus.internalServerError);
        }),
      );

      final installed = await store.install();

      expect(networkCalls, 0);
      expect(await File(installed.modelPath).readAsBytes(), modelBytes);
      expect(await File(installed.tokenizerPath).readAsBytes(), tokenizerBytes);
      expect(await store.isInstalled(), isTrue);
    },
  );

  test('same-length tampered model fails with typed hash mismatch', () async {
    final store = installer(
      MockClient((_) async => http.Response('abd', HttpStatus.ok)),
    );

    await expectLater(
      store.install(),
      throwsA(
        isA<EmbeddingFailure>()
            .having(
              (error) => error.kind,
              'kind',
              EmbeddingFailureKind.hashMismatch,
            )
            .having(
              (error) => error.code,
              'code',
              'MEMOYO_MINILM_HASH_MISMATCH',
            ),
      ),
    );
    expect(await File('${temp.path}/model.onnx').exists(), isFalse);
  });

  test('HTTP retry exhaustion is a typed download failure', () async {
    var attempts = 0;
    final store = installer(
      MockClient((_) async {
        attempts++;
        return http.Response('unavailable', HttpStatus.serviceUnavailable);
      }),
      maxAttempts: 2,
    );

    await expectLater(
      store.install(),
      throwsA(
        isA<EmbeddingFailure>().having(
          (error) => error.kind,
          'kind',
          EmbeddingFailureKind.downloadFailed,
        ),
      ),
    );
    expect(attempts, 2);
  });

  test('free-space preflight blocks network before download', () async {
    var networkCalls = 0;
    final store = MiniLmModelInstaller(
      client: MockClient((_) async {
        networkCalls++;
        return http.Response('', HttpStatus.ok);
      }),
      directoryProvider: () async => temp,
      freeSpaceProvider: (_) async => 0,
      manifestVerifier: () async {},
      artifacts: artifacts,
    );

    await expectLater(
      store.install(),
      throwsA(
        isA<EmbeddingFailure>().having(
          (error) => error.kind,
          'kind',
          EmbeddingFailureKind.insufficientSpace,
        ),
      ),
    );
    expect(networkCalls, 0);
  });

  test('native model load error becomes a typed load failure', () async {
    await File('${temp.path}/model.onnx').writeAsBytes(modelBytes);
    await File('${temp.path}/tokenizer.model').writeAsBytes(tokenizerBytes);
    final store = installer(MockClient((_) async => http.Response('', 500)));
    final engine = MiniLmEmbeddingEngine(
      installer: store,
      runtime: _LoadFailingRuntime(),
      tokenizerLoader: (_) async => _FakeTokenizer(),
    );

    await expectLater(
      engine.embedQuery('검색'),
      throwsA(
        isA<EmbeddingFailure>()
            .having(
              (error) => error.kind,
              'kind',
              EmbeddingFailureKind.loadFailed,
            )
            .having((error) => error.code, 'code', 'MEMOYO_MINILM_LOAD_FAILED'),
      ),
    );
  });
}

class _FakeTokenizer implements MiniLmTokenizer {
  @override
  XlmRobertaEncoding encode(String text) => const XlmRobertaEncoding(
    ids: [0, 2],
    attentionMask: [1, 1],
    typeIds: [0, 0],
  );
}

class _LoadFailingRuntime implements MiniLmRuntime {
  @override
  Future<int> availableBytes(String directoryPath) async => 1 << 30;

  @override
  Future<void> close() async {}

  @override
  Future<List<double>> embed(XlmRobertaEncoding encoding) async => const [];

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> load(String modelPath) async {
    throw PlatformException(code: 'LOAD_FAILED');
  }
}
