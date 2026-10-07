import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/widgets/member_directory.dart';
import 'package:respondcrew_app/widgets/own_profile_editor.dart';

const members = [
  DirectoryMember(
    id: 'me',
    name: 'Taavi',
    role: 'member',
    level: 'level1',
    status: 'Valves',
    isSelf: true,
  ),
  DirectoryMember(
    id: 'mari',
    name: 'Mari',
    role: 'orgAdmin',
    level: 'level2',
    status: 'Hilinemisega',
  ),
];
void main() {
  testWidgets(
    'directory export follows organization management presentation and disappears when role changes',
    (tester) async {
      Widget screen(bool admin) => MaterialApp(
        home: Scaffold(
          body: MemberDirectory(
            members: members,
            onOpen: (_) {},
            onContact: (_, _) {},
            showExport: admin,
          ),
        ),
      );
      await tester.pumpWidget(screen(false));
      expect(find.text('Liikmed CSV'), findsNothing);
      expect(find.text('Minu andmed'), findsOneWidget);
      expect(find.byTooltip('Helista: Mari'), findsOneWidget);
      await tester.pumpWidget(screen(true));
      expect(find.text('Liikmed CSV'), findsOneWidget);
      await tester.pumpWidget(screen(false));
      expect(find.text('Liikmed CSV'), findsNothing);
    },
  );
  testWidgets(
    'own member opens own profile, peer contact uses exact member, search filters',
    (tester) async {
      String? opened, contact;
      bool? sms;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberDirectory(
              members: members,
              onOpen: (id) => opened = id,
              onContact: (id, s) => {contact = id, sms = s},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Minu andmed'));
      expect(opened, 'me');
      await tester.tap(find.byTooltip('SMS: Mari'));
      expect(contact, 'mari');
      expect(sms, isTrue);
      await tester.enterText(find.byType(TextField), 'taav');
      await tester.pump();
      expect(find.text('Taavi · Mina'), findsOneWidget);
      expect(find.text('Mari'), findsNothing);
      await tester.enterText(find.byType(TextField), 'puudub');
      await tester.pump();
      expect(
        find.text('Otsingule vastavaid liikmeid ei leitud.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('directory level filter and large text fit narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: MemberDirectory(
            members: members,
            onOpen: (_) {},
            onContact: (_, _) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Filtrid ja järjestus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kõik astmed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('II aste').last);
    await tester.pumpAndSettle();
    expect(find.text('Mari'), findsOneWidget);
    expect(find.text('Taavi · Mina'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'CSV contains only visible directory fields and neutralizes formulas',
    () {
      final csv = memberDirectoryCsv([
        const DirectoryMember(
          id: 'id',
          name: '=SUM(1)',
          role: 'member',
          level: 'none',
          status: 'Valves',
        ),
      ]);
      expect(csv, contains("'=SUM(1)"));
      expect(csv, contains('Määramata'));
      expect(csv, isNot(contains('userId')));
    },
  );
  testWidgets(
    'own editor validates data and retains dialog after failure then saves',
    (tester) async {
      var attempts = 0;
      String? savedName, savedPhone;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => OwnProfileEditor(
                    name: 'Taavi',
                    phone: '',
                    save: (name, phone) async {
                      attempts++;
                      if (attempts == 1) throw StateError('offline');
                      savedName = name;
                      savedPhone = phone;
                    },
                  ),
                ),
                child: const Text('Ava'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ava'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.tap(find.text('Salvesta'));
      await tester.pump();
      expect(find.text('Sisesta nimi.'), findsOneWidget);
      expect(attempts, 0);
      await tester.enterText(find.byType(TextFormField).first, 'Taavi Uus');
      await tester.enterText(find.byType(TextFormField).last, '+372 555 1234');
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(
        find.text('Andmeid ei saanud salvestada. Proovi uuesti.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Salvesta'));
      await tester.pumpAndSettle();
      expect(savedName, 'Taavi Uus');
      expect(savedPhone, '+372 555 1234');
      expect(find.byType(OwnProfileEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
