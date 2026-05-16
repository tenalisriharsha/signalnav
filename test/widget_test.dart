// SignalNav - Basic Widget Test
//
// TODO: Replace with comprehensive test suite per TESTING CHECKLIST

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:signalnav/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SignalNavApp(),
      ),
    );

    // Verify that the splash screen is shown.
    expect(find.text('SignalNav'), findsOneWidget);
    expect(find.text('Green Wave Assistant'), findsOneWidget);
  });
}
