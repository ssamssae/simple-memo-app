// T-261103-008: the app icon was replaced (#156) but the start screen kept the old
// dark notepad, because the in-app splash and flutter_native_splash read
// assets/images/app_icon.png while the launcher icon comes from assets/icon/app_icon.png.
// This test fails when one of the two pictures changes without the other.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _tinyRgba(String path) async {
  final codec = await ui.instantiateImageCodec(
    File(path).readAsBytesSync(),
    targetWidth: 8,
    targetHeight: 8,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start screen picture is the current app icon', () async {
    final icon = await _tinyRgba('assets/icon/app_icon.png');
    final splash = await _tinyRgba('assets/images/app_icon.png');
    expect(splash.length, icon.length);
    var diff = 0;
    for (var i = 0; i < icon.length; i++) {
      diff += (icon[i] - splash[i]).abs();
    }
    // Same picture at another size stays within a few levels per channel;
    // the old dark notepad against the yellow mascot averages well over 100.
    expect(diff / icon.length, lessThan(12));
  });
}
