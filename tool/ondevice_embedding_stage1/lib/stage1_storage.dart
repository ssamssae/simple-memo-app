import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'model_specs.dart';

class Stage1Storage {
  Stage1Storage._(this.root);

  final Directory root;

  static Future<Stage1Storage> open() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}${Platform.pathSeparator}stage1');
    await root.create(recursive: true);
    return Stage1Storage._(root);
  }

  File get configFile =>
      File('${root.path}${Platform.pathSeparator}config.json');
  File get resultFile =>
      File('${root.path}${Platform.pathSeparator}result.json');
  File get crashFile => File('${root.path}${Platform.pathSeparator}crash.json');
  File get stateFile => File('${root.path}${Platform.pathSeparator}state.json');
  File get eventsFile =>
      File('${root.path}${Platform.pathSeparator}events.jsonl');

  Future<Stage1Config> readConfig() async {
    if (!await configFile.exists()) {
      throw StateError('stage1/config.json is missing; run the staging script');
    }
    final decoded = jsonDecode(await configFile.readAsString());
    if (decoded is! Map) {
      throw const FormatException('stage1 config must be a JSON object');
    }
    return Stage1Config.fromJson(Map<String, Object?>.from(decoded));
  }

  File modelFile(EngineSpec spec) => File(
    '${root.path}${Platform.pathSeparator}models${Platform.pathSeparator}'
    '${spec.id}${Platform.pathSeparator}${spec.modelFileName}',
  );

  File tokenizerFile(EngineSpec spec) => File(
    '${root.path}${Platform.pathSeparator}models${Platform.pathSeparator}'
    '${spec.id}${Platform.pathSeparator}${spec.tokenizerFileName}',
  );

  Future<void> verifyArtifacts(EngineSpec spec) async {
    final model = modelFile(spec);
    final tokenizer = tokenizerFile(spec);
    if (!await model.exists() || !await tokenizer.exists()) {
      throw StateError('Staged model files are missing for ${spec.id}');
    }
    final modelDigest = await sha256.bind(model.openRead()).first;
    final tokenizerDigest = await sha256.bind(tokenizer.openRead()).first;
    if (modelDigest.toString() != spec.modelSha256) {
      throw const FormatException(
        'Model SHA256 does not match the pinned artifact',
      );
    }
    if (tokenizerDigest.toString() != spec.tokenizerSha256) {
      throw const FormatException(
        'Tokenizer SHA256 does not match the pinned artifact',
      );
    }
  }

  Future<void> resetOutputs() async {
    for (final file in [resultFile, crashFile]) {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> writeState(String phase, {String? engine}) {
    return _writeJsonAtomic(stateFile, {
      'schemaVersion': 1,
      'task': 'T-260713-55',
      'phase': phase,
      'engine': ?engine,
      'timestampUtc': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> writeResult(Map<String, Object?> result) {
    return _writeJsonAtomic(resultFile, result);
  }

  Future<void> writeCrash(
    Object error,
    StackTrace stackTrace, {
    String? engine,
  }) {
    return _writeJsonAtomic(crashFile, {
      'schemaVersion': 1,
      'task': 'T-260713-55',
      'engine': ?engine,
      'timestampUtc': DateTime.now().toUtc().toIso8601String(),
      'errorType': error.runtimeType.toString(),
      'message': error.toString(),
      'stack': stackTrace.toString(),
    });
  }

  Future<void> appendEvent(String phase, {String? engine}) async {
    final event = {
      'schemaVersion': 1,
      'task': 'T-260713-55',
      'phase': phase,
      'engine': ?engine,
      'timestampUtc': DateTime.now().toUtc().toIso8601String(),
    };
    final line = jsonEncode(event);
    stdout.writeln('STAGE1_EVENT $line');
    await eventsFile.writeAsString(
      '$line\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<void> _writeJsonAtomic(
    File destination,
    Map<String, Object?> data,
  ) async {
    await destination.parent.create(recursive: true);
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
      flush: true,
    );
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
  }
}
