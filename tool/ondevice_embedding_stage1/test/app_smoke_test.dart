import 'package:flutter_test/flutter_test.dart';
import 'package:memoyo_embedding_stage1/main.dart';

void main() {
  testWidgets('stage1 app is visibly marked as experimental', (tester) async {
    await tester.pumpWidget(const Stage1App(autoRun: false));

    expect(find.text('Memoyo embedding stage1 spike'), findsOneWidget);
    expect(
      find.text('Experimental branch · not a production feature'),
      findsOneWidget,
    );
    expect(find.text('Run again'), findsOneWidget);
  });
}
