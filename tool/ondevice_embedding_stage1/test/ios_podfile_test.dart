import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS pods use static frameworks required by native runtimes', () {
    final podfile = File('ios/Podfile').readAsStringSync();

    expect(podfile, contains('use_frameworks! :linkage => :static'));
  });
}
