import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tru_app/main.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets('Workspace navigation at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TruApp());
      await tester.pumpAndSettle();
      expect(find.text('Tere, Taavi'), findsOneWidget);
      await tester.tap(find.text('Varustus').last);
      await tester.pumpAndSettle();
      expect(find.text('Generaator TRU-001'), findsOneWidget);
      await tester.tap(find.text('Õpe').last);
      await tester.pumpAndSettle();
      expect(find.text('Mootorsae ohutu kasutamine'), findsOneWidget);
      await tester.tap(find.text('Info').last);
      await tester.pumpAndSettle();
      expect(find.text('Lisa teade'), findsOneWidget);
      await tester.tap(find.text('Kinnitan, et olen lugenud').first);
      await tester.pumpAndSettle();
      expect(find.text('Ida · Loetud'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
