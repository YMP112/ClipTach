import 'package:cliptach/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ClipTach app builds', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ClipTachApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
