import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'embedding_engine.dart';
import 'mini_lm_model_manifest.dart';

typedef MiniLmDirectoryProvider = Future<Directory> Function();
typedef MiniLmFreeSpaceProvider = Future<int> Function(String directoryPath);
typedef MiniLmManifestVerifier = Future<void> Function();

class MiniLmInstallProgress {
  const MiniLmInstallProgress({required this.received, required this.total});

  final int received;
  final int total;

  double get fraction => total == 0 ? 0 : (received / total).clamp(0, 1);
}

class MiniLmInstalledPaths {
  const MiniLmInstalledPaths({
    required this.modelPath,
    required this.tokenizerPath,
  });

  final String modelPath;
  final String tokenizerPath;
}

class MiniLmModelInstaller {
  MiniLmModelInstaller({
    http.Client? client,
    MiniLmDirectoryProvider? directoryProvider,
    required MiniLmFreeSpaceProvider freeSpaceProvider,
    MiniLmManifestVerifier? manifestVerifier,
    List<MiniLmArtifact>? artifacts,
    this.maxAttempts = 3,
  }) : _client = client ?? http.Client(),
       _directoryProvider = directoryProvider ?? _defaultDirectory,
       _freeSpaceProvider = freeSpaceProvider,
       _artifacts = artifacts ?? MiniLmModelManifest.artifacts,
       _manifestVerifier =
           manifestVerifier ?? MiniLmModelManifest.verifyBundled;

  static const safetyBytes = 64 * 1024 * 1024;

  final http.Client _client;
  final MiniLmDirectoryProvider _directoryProvider;
  final MiniLmFreeSpaceProvider _freeSpaceProvider;
  final MiniLmManifestVerifier _manifestVerifier;
  final List<MiniLmArtifact> _artifacts;
  final int maxAttempts;
  bool _verifiedInstall = false;

  int get _totalDownloadBytes =>
      _artifacts.fold(0, (total, artifact) => total + artifact.size);

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/semantic_models/minilm');
  }

  Future<MiniLmInstalledPaths> paths() async {
    final directory = await _directoryProvider();
    return MiniLmInstalledPaths(
      modelPath: '${directory.path}/${_artifacts.first.name}',
      tokenizerPath: '${directory.path}/${_artifacts.last.name}',
    );
  }

  Future<bool> isInstalled() async {
    try {
      await _manifestVerifier();
      final directory = await _directoryProvider();
      if (_verifiedInstall) {
        for (final artifact in _artifacts) {
          final file = File('${directory.path}/${artifact.name}');
          if (!await file.exists() || await file.length() != artifact.size) {
            _verifiedInstall = false;
            return false;
          }
        }
        return true;
      }
      for (final artifact in _artifacts) {
        if (!await _isValid(
          File('${directory.path}/${artifact.name}'),
          artifact,
        )) {
          return false;
        }
      }
      _verifiedInstall = true;
      return true;
    } catch (_) {
      _verifiedInstall = false;
      return false;
    }
  }

  Future<MiniLmInstalledPaths> install({
    void Function(MiniLmInstallProgress progress)? onProgress,
  }) async {
    _verifiedInstall = false;
    try {
      await _manifestVerifier();
    } catch (error) {
      throw EmbeddingFailure(
        EmbeddingFailureKind.hashMismatch,
        'MEMOYO_MINILM_MANIFEST_INVALID',
        error,
      );
    }

    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final alreadyValid = <String, bool>{};
    var remainingBytes = 0;
    var completed = 0;
    for (final artifact in _artifacts) {
      final destination = File('${directory.path}/${artifact.name}');
      final valid = await _isValid(destination, artifact);
      alreadyValid[artifact.name] = valid;
      if (valid) {
        completed += artifact.size;
        continue;
      }
      if (await destination.exists()) await destination.delete();
      final partial = File('${destination.path}.part');
      var partialLength = await partial.exists() ? await partial.length() : 0;
      if (partialLength >= artifact.size) {
        if (partialLength == artifact.size &&
            await _isValid(partial, artifact)) {
          await partial.rename(destination.path);
          alreadyValid[artifact.name] = true;
          completed += artifact.size;
          continue;
        }
        await partial.delete();
        partialLength = 0;
      }
      remainingBytes +=
          artifact.size - partialLength.clamp(0, artifact.size).toInt();
    }
    if (remainingBytes == 0) {
      _verifiedInstall = true;
      return paths();
    }

    final available = await _freeSpaceProvider(directory.path);
    if (available < remainingBytes + safetyBytes) {
      throw const EmbeddingFailure(
        EmbeddingFailureKind.insufficientSpace,
        'MEMOYO_MINILM_INSUFFICIENT_SPACE',
      );
    }

    for (final artifact in _artifacts) {
      if (alreadyValid[artifact.name] == true) continue;
      final destination = File('${directory.path}/${artifact.name}');
      await _downloadWithRetry(
        artifact,
        destination,
        onProgress: (artifactReceived) {
          onProgress?.call(
            MiniLmInstallProgress(
              received: completed + artifactReceived,
              total: _totalDownloadBytes,
            ),
          );
        },
      );
      completed += artifact.size;
      onProgress?.call(
        MiniLmInstallProgress(received: completed, total: _totalDownloadBytes),
      );
    }
    _verifiedInstall = true;
    return paths();
  }

  Future<void> _downloadWithRetry(
    MiniLmArtifact artifact,
    File destination, {
    required void Function(int received) onProgress,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _downloadOnce(artifact, destination, onProgress: onProgress);
        return;
      } on EmbeddingFailure catch (error) {
        if (error.kind == EmbeddingFailureKind.hashMismatch) rethrow;
        lastError = error;
      } catch (error) {
        lastError = error;
      }
    }
    throw EmbeddingFailure(
      EmbeddingFailureKind.downloadFailed,
      'MEMOYO_MINILM_DOWNLOAD_FAILED',
      lastError,
    );
  }

  Future<void> _downloadOnce(
    MiniLmArtifact artifact,
    File destination, {
    required void Function(int received) onProgress,
  }) async {
    final partial = File('${destination.path}.part');
    var existing = await partial.exists() ? await partial.length() : 0;
    if (existing == artifact.size && await _isValid(partial, artifact)) {
      if (await destination.exists()) await destination.delete();
      await partial.rename(destination.path);
      onProgress(artifact.size);
      return;
    }
    if (existing > artifact.size) {
      await partial.delete();
      existing = 0;
    }

    final request = http.Request('GET', artifact.downloadUri);
    if (existing > 0) request.headers['range'] = 'bytes=$existing-';
    final response = await _client.send(request);
    final resumes =
        existing > 0 && response.statusCode == HttpStatus.partialContent;
    if (response.statusCode != HttpStatus.ok && !resumes) {
      throw EmbeddingFailure(
        EmbeddingFailureKind.downloadFailed,
        'MEMOYO_MINILM_HTTP_${response.statusCode}',
      );
    }
    if (!resumes) {
      existing = 0;
      if (await partial.exists()) await partial.delete();
    }

    final sink = partial.openWrite(
      mode: resumes ? FileMode.append : FileMode.write,
    );
    var received = existing;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (received != artifact.size) {
      throw const EmbeddingFailure(
        EmbeddingFailureKind.downloadFailed,
        'MEMOYO_MINILM_DOWNLOAD_INCOMPLETE',
      );
    }
    if (!await _isValid(partial, artifact)) {
      await partial.delete();
      throw const EmbeddingFailure(
        EmbeddingFailureKind.hashMismatch,
        'MEMOYO_MINILM_HASH_MISMATCH',
      );
    }
    if (await destination.exists()) await destination.delete();
    await partial.rename(destination.path);
  }

  Future<bool> _isValid(File file, MiniLmArtifact artifact) async {
    if (!await file.exists() || await file.length() != artifact.size) {
      return false;
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == artifact.sha256;
  }

  Future<void> delete() async {
    _verifiedInstall = false;
    final directory = await _directoryProvider();
    for (final artifact in _artifacts) {
      for (final suffix in ['', '.part']) {
        final file = File('${directory.path}/${artifact.name}$suffix');
        if (await file.exists()) await file.delete();
      }
    }
  }
}
