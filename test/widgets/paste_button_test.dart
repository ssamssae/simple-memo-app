import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/widgets/paste_button.dart';

void main() {
  testWidgets('PasteButton shrinks without UiKitView on non-iOS',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasteButton(onPaste: (_) {}),
        ),
      ),
    );

    expect(find.byType(UiKitView), findsNothing);
    expect(
      find.descendant(
        of: find.byType(PasteButton),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 0 && widget.height == 0,
        ),
      ),
      findsOneWidget,
    );
  });
}
