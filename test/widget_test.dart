import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_time/main.dart';

void main() {
  testWidgets('App smoke test loads fallback setup screen when offline',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: OrbitFamilyApp(isFirebaseReady: false),
      ),
    );

    expect(find.text('Firebase Project Required'), findsOneWidget);
  });
}
