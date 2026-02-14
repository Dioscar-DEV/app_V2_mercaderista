import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disbattery_trade/app.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: DisbatteryTradeApp(),
      ),
    );

    // Verify that the app loads (should show splash screen initially)
    // We can't check for specific content because Supabase needs to be initialized
    // This test just ensures the app doesn't crash on startup
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
