import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Native iOS 16+ UIPasteControl wrapper. Tapping it pastes clipboard
/// contents without triggering the "Paste from other apps" prompt.
/// On non-iOS platforms this returns an empty SizedBox.
class PasteButton extends StatefulWidget {
  final double width;
  final double height;
  final ValueChanged<String> onPaste;

  const PasteButton({
    super.key,
    this.width = 72,
    this.height = 30,
    required this.onPaste,
  });

  @override
  State<PasteButton> createState() => _PasteButtonState();
}

class _PasteButtonState extends State<PasteButton> {
  int? _viewId;

  void _onPlatformViewCreated(int id) {
    _viewId = id;
    MethodChannel('memoyo/paste_button_$id').setMethodCallHandler((call) async {
      if (call.method == 'onPaste') {
        final text = call.arguments as String? ?? '';
        if (text.isNotEmpty) widget.onPaste(text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isIOS) return const SizedBox.shrink();
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: UiKitView(
        viewType: 'memoyo/paste_button',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
