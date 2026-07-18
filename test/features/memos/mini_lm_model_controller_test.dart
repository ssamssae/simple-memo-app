import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_controller.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_installer.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_runtime.dart';
import 'package:simple_memo_app/features/memos/services/xlm_roberta_sentencepiece.dart';

void main() {
  group('refresh', () {
    test('starts checking and transitions to unsupported', () async {
      final runtime = _FakeRuntime(supported: false);
      final controller = _controller(runtime: runtime);
      final states = _listenStates(controller);

      expect(controller.state, MiniLmModelState.checking);
      await controller.refresh();

      expect(states, [MiniLmModelState.checking, MiniLmModelState.unsupported]);
      expect(controller.errorCode, isNull);
      controller.dispose();
    });

    test(
      'transitions to absent when supported model is not installed',
      () async {
        final installer = _FakeInstaller(installed: false);
        final controller = _controller(installer: installer);

        await controller.refresh();

        expect(controller.state, MiniLmModelState.absent);
        expect(installer.statusCalls, 1);
        controller.dispose();
      },
    );

    test('transitions to ready when supported model is installed', () async {
      final installer = _FakeInstaller(installed: true);
      final controller = _controller(installer: installer);

      await controller.refresh();

      expect(controller.state, MiniLmModelState.ready);
      controller.dispose();
    });

    test('maps status exceptions to status error code', () async {
      final installer = _FakeInstaller(
        statusError: StateError('status failed'),
      );
      final controller = _controller(installer: installer);

      await controller.refresh();

      expect(controller.state, MiniLmModelState.error);
      expect(controller.errorCode, 'MEMOYO_MINILM_STATUS_FAILED');
      controller.dispose();
    });

    // T-260719-018: isInstalled 가 기록한 점검 실패 사유를 '미설치'로 위장하지 않고 표면화.
    test('surfaces recorded check failure instead of masquerading as absent',
        () async {
      final installer = _FakeInstaller(
        installed: false,
        checkFailure: const EmbeddingFailure(
          EmbeddingFailureKind.hashMismatch,
          'MEMOYO_MINILM_MANIFEST_INVALID',
        ),
      );
      final controller = _controller(installer: installer);

      await controller.refresh();

      expect(controller.state, MiniLmModelState.error);
      expect(controller.errorCode, 'MEMOYO_MINILM_MANIFEST_INVALID');
      controller.dispose();
    });

    // T-260719-018: refresh 중 typed 실패는 code 그대로 전파 (기존엔 STATUS_FAILED 로 뭉갬).
    test('preserves typed refresh failure code', () async {
      final installer = _FakeInstaller(
        statusError: const EmbeddingFailure(
          EmbeddingFailureKind.loadFailed,
          'MEMOYO_MINILM_STATUS_TYPED',
        ),
      );
      final controller = _controller(installer: installer);

      await controller.refresh();

      expect(controller.state, MiniLmModelState.error);
      expect(controller.errorCode, 'MEMOYO_MINILM_STATUS_TYPED');
      controller.dispose();
    });
  });

  group('install', () {
    test('transitions installing through progress to ready', () async {
      final pending = Completer<MiniLmInstalledPaths>();
      final installer = _FakeInstaller(installCompleter: pending);
      final controller = _controller(installer: installer);
      final states = _listenStates(controller);

      final future = controller.install();
      expect(controller.state, MiniLmModelState.installing);
      expect(controller.progress, 0);

      installer.emitProgress(received: 3, total: 4);
      expect(controller.progress, 0.75);
      pending.complete(_paths);
      await future;

      expect(controller.state, MiniLmModelState.ready);
      expect(controller.progress, 1);
      expect(states.first, MiniLmModelState.installing);
      expect(states.last, MiniLmModelState.ready);
      controller.dispose();
    });

    test(
      'ignores reentrant install while the first install is running',
      () async {
        final pending = Completer<MiniLmInstalledPaths>();
        final installer = _FakeInstaller(installCompleter: pending);
        final controller = _controller(installer: installer);

        final first = controller.install();
        await controller.install();

        expect(installer.installCalls, 1);
        expect(controller.state, MiniLmModelState.installing);
        pending.complete(_paths);
        await first;
        expect(controller.state, MiniLmModelState.ready);
        controller.dispose();
      },
    );

    test('preserves typed install failure code', () async {
      final installer = _FakeInstaller(
        installError: const EmbeddingFailure(
          EmbeddingFailureKind.hashMismatch,
          'MEMOYO_MINILM_HASH_MISMATCH',
        ),
      );
      final controller = _controller(installer: installer);

      await controller.install();

      expect(controller.state, MiniLmModelState.error);
      expect(controller.errorCode, 'MEMOYO_MINILM_HASH_MISMATCH');
      controller.dispose();
    });

    // T-260719-018: 실패 3사유(네트워크/검증/저장공간) code 가 상태에 그대로 보존됨을 고정.
    for (final failure in const [
      EmbeddingFailure(
        EmbeddingFailureKind.downloadFailed,
        'MEMOYO_MINILM_DOWNLOAD_FAILED',
      ),
      EmbeddingFailure(
        EmbeddingFailureKind.insufficientSpace,
        'MEMOYO_MINILM_INSUFFICIENT_SPACE',
      ),
      EmbeddingFailure(
        EmbeddingFailureKind.hashMismatch,
        'MEMOYO_MINILM_HASH_MISMATCH',
      ),
    ]) {
      test('preserves ${failure.code} on install failure', () async {
        final installer = _FakeInstaller(installError: failure);
        final controller = _controller(installer: installer);

        await controller.install();

        expect(controller.state, MiniLmModelState.error);
        expect(controller.errorCode, failure.code);
        controller.dispose();
      });
    }

    test('maps unexpected install failure to generic install code', () async {
      final installer = _FakeInstaller(
        installError: StateError('unexpected install failure'),
      );
      final controller = _controller(installer: installer);

      await controller.install();

      expect(controller.state, MiniLmModelState.error);
      expect(controller.errorCode, 'MEMOYO_MINILM_INSTALL_FAILED');
      controller.dispose();
    });

    test(
      'continues install after dispose without notifying disposed notifier',
      () async {
        final pending = Completer<MiniLmInstalledPaths>();
        final installer = _FakeInstaller(installCompleter: pending);
        final runtime = _FakeRuntime();
        final controller = _controller(installer: installer, runtime: runtime);

        final future = controller.install();
        expect(controller.state, MiniLmModelState.installing);

        controller.dispose();
        expect(runtime.closeCalls, 1);
        expect(
          () => installer.emitProgress(received: 1, total: 2),
          returnsNormally,
        );

        pending.complete(_paths);
        await expectLater(future, completes);
        expect(installer.installCalls, 1);
        expect(controller.progress, 1);
        expect(controller.state, MiniLmModelState.ready);
      },
    );
  });

  group('delete', () {
    test('closes runtime, deletes files, and transitions to absent', () async {
      final installer = _FakeInstaller(installed: true);
      final runtime = _FakeRuntime();
      final controller = _controller(installer: installer, runtime: runtime);
      await controller.refresh();

      await controller.delete();

      expect(runtime.closeCalls, 1);
      expect(installer.deleteCalls, 1);
      expect(controller.state, MiniLmModelState.absent);
      expect(controller.progress, 0);
      controller.dispose();
    });

    test('maps delete exceptions to delete error code', () async {
      final installer = _FakeInstaller(
        deleteError: StateError('delete failed'),
      );
      final controller = _controller(installer: installer);

      await controller.delete();

      expect(controller.state, MiniLmModelState.error);
      expect(controller.errorCode, 'MEMOYO_MINILM_DELETE_FAILED');
      controller.dispose();
    });
  });
}

const _paths = MiniLmInstalledPaths(
  modelPath: '/tmp/model.onnx',
  tokenizerPath: '/tmp/tokenizer.model',
);

MiniLmModelController _controller({
  _FakeInstaller? installer,
  _FakeRuntime? runtime,
}) {
  return MiniLmModelController(
    installer: installer ?? _FakeInstaller(),
    runtime: runtime ?? _FakeRuntime(),
  );
}

List<MiniLmModelState> _listenStates(MiniLmModelController controller) {
  final states = <MiniLmModelState>[];
  controller.addListener(() => states.add(controller.state));
  return states;
}

class _FakeInstaller extends MiniLmModelInstaller {
  _FakeInstaller({
    this.installed = false,
    this.statusError,
    this.installError,
    this.deleteError,
    this.installCompleter,
    this.checkFailure,
  }) : super(freeSpaceProvider: (_) async => 1 << 30);

  bool installed;
  final Object? statusError;
  final Object? installError;
  final Object? deleteError;
  final Completer<MiniLmInstalledPaths>? installCompleter;
  final EmbeddingFailure? checkFailure;

  int statusCalls = 0;
  int installCalls = 0;
  int deleteCalls = 0;
  void Function(MiniLmInstallProgress progress)? _onProgress;

  @override
  Future<bool> isInstalled() async {
    statusCalls++;
    if (statusError case final error?) throw error;
    lastCheckFailure = checkFailure;
    return installed;
  }

  @override
  Future<MiniLmInstalledPaths> install({
    void Function(MiniLmInstallProgress progress)? onProgress,
  }) {
    installCalls++;
    _onProgress = onProgress;
    if (installError case final error?) return Future.error(error);
    return installCompleter?.future ?? Future.value(_paths);
  }

  void emitProgress({required int received, required int total}) {
    _onProgress?.call(MiniLmInstallProgress(received: received, total: total));
  }

  @override
  Future<void> delete() async {
    deleteCalls++;
    if (deleteError case final error?) throw error;
    installed = false;
  }
}

class _FakeRuntime implements MiniLmRuntime {
  _FakeRuntime({this.supported = true});

  final bool supported;
  int closeCalls = 0;

  @override
  Future<int> availableBytes(String directoryPath) async => 1 << 30;

  @override
  Future<void> close() async {
    closeCalls++;
  }

  @override
  Future<List<double>> embed(XlmRobertaEncoding encoding) async => const [];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> load(String modelPath) async {}
}
