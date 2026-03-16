// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecg_mobile/main.dart';

void main() {
  testWidgets('MLHADP app test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ECGMobileApp());

    // Verify that our splash screen loads.
    expect(find.text('MLHADP'), findsOneWidget);
    expect(
      find.text('ML Based Heart Attack Detection and Prediction'),
      findsOneWidget,
    );

    // Wait for the splash screen timer and any other pending operations
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
