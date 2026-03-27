import 'package:audiokit/app/audio_kit_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AudioKit app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AudioKitApp());

    // Verify the app title and tabs are present.
    expect(find.text('AudioKit'), findsOneWidget);
    expect(find.text('Video to Audio'), findsOneWidget);
    expect(find.text('Audio Merger'), findsOneWidget);
  });
}
