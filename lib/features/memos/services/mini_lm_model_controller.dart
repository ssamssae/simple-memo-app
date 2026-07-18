import 'dart:async';

import 'package:flutter/foundation.dart';

import 'embedding_engine.dart';
import 'mini_lm_model_installer.dart';
import 'mini_lm_runtime.dart';

enum MiniLmModelState {
  checking,
  unsupported,
  absent,
  installing,
  ready,
  error,
}

abstract class MiniLmModelManager extends ChangeNotifier {
  MiniLmModelState get state;

  double get progress;

  String? get errorCode;

  Future<void> refresh();

  Future<void> install();

  Future<void> delete();
}

class MiniLmModelController extends MiniLmModelManager {
  MiniLmModelController({
    required MiniLmModelInstaller installer,
    required MiniLmRuntime runtime,
  }) : _installer = installer,
       _runtime = runtime;

  final MiniLmModelInstaller _installer;
  final MiniLmRuntime _runtime;

  MiniLmModelState _state = MiniLmModelState.checking;
  double _progress = 0;
  String? _errorCode;
  bool _disposed = false;

  @override
  MiniLmModelState get state => _state;

  @override
  double get progress => _progress;

  @override
  String? get errorCode => _errorCode;

  @override
  Future<void> refresh() async {
    _setState(MiniLmModelState.checking);
    try {
      if (!await _runtime.isSupported()) {
        _setState(MiniLmModelState.unsupported);
        return;
      }
      if (await _installer.isInstalled()) {
        _setState(MiniLmModelState.ready);
        return;
      }
      // T-260719-018: 점검 실패 사유가 기록됐으면 '미설치'로 위장하지 않고 error 로 표면화.
      final checkFailure = _installer.lastCheckFailure;
      if (checkFailure != null) {
        _setState(MiniLmModelState.error, errorCode: checkFailure.code);
        return;
      }
      _setState(MiniLmModelState.absent);
    } on EmbeddingFailure catch (error) {
      _setState(MiniLmModelState.error, errorCode: error.code);
    } catch (_) {
      _setState(
        MiniLmModelState.error,
        errorCode: 'MEMOYO_MINILM_STATUS_FAILED',
      );
    }
  }

  @override
  Future<void> install() async {
    if (_state == MiniLmModelState.installing) return;
    _progress = 0;
    _setState(MiniLmModelState.installing);
    try {
      await _installer.install(
        onProgress: (value) {
          _progress = value.fraction;
          if (!_disposed) notifyListeners();
        },
      );
      _progress = 1;
      _setState(MiniLmModelState.ready);
    } on EmbeddingFailure catch (error) {
      _setState(MiniLmModelState.error, errorCode: error.code);
    } catch (_) {
      _setState(
        MiniLmModelState.error,
        errorCode: 'MEMOYO_MINILM_INSTALL_FAILED',
      );
    }
  }

  @override
  Future<void> delete() async {
    try {
      await _runtime.close();
      await _installer.delete();
      _progress = 0;
      _setState(MiniLmModelState.absent);
    } catch (_) {
      _setState(
        MiniLmModelState.error,
        errorCode: 'MEMOYO_MINILM_DELETE_FAILED',
      );
    }
  }

  void _setState(MiniLmModelState value, {String? errorCode}) {
    _state = value;
    _errorCode = errorCode;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_runtime.close());
    super.dispose();
  }
}
