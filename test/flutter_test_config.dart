import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('memoyo/minilm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(channel, (call) async {
    return switch (call.method) {
      'isSupported' => false,
      'close' => null,
      _ => throw PlatformException(
        code: 'UNEXPECTED_MINILM_TEST_CALL',
        message: call.method,
      ),
    };
  });

  try {
    await testMain();
  } finally {
    messenger.setMockMethodCallHandler(channel, null);
  }
}
