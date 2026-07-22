import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codesage_app/main.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const CodeSageApp());
    expect(find.text('CodeSage App'), findsOneWidget);
  });
