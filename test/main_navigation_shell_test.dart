import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/screens/main_navigation_shell.dart';

void main() {
  testWidgets(
    'details retain navigation and switching tabs clears old details',
    (tester) async {
      var selected = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MainNavigationShell(
                currentIndex: selected,
                onDestinationSelected: (index) =>
                    setState(() => selected = index),
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        Text('Page $selected'),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => Scaffold(
                                appBar: AppBar(title: const Text('Detail')),
                                body: TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => Scaffold(
                                        appBar: AppBar(
                                          title: const Text('Nested detail'),
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: const Text('Open nested'),
                                ),
                              ),
                            ),
                          ),
                          child: const Text('Open detail'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.text('Menüü').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Open nested'));
      await tester.pumpAndSettle();
      expect(find.text('Ühingu valmidus').hitTestable(), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
      await tester.tap(find.text('Ühingu valmidus'));
      await tester.pumpAndSettle();
      expect(find.text('Page 3'), findsOneWidget);
      expect(find.text('Detail'), findsNothing);
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      // Notification-driven selection must also dismiss the previous detail.
      rebuild(() => selected = 1);
      await tester.pumpAndSettle();
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Detail'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('system back closes a detail inside the persistent bar', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationShell(
          navigatorKey: key,
          currentIndex: 0,
          onDestinationSelected: (_) {},
          child: const Scaffold(body: Text('Dashboard')),
        ),
      ),
    );
    key.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Profile')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Menüü'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
