import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/tru_session.dart';
import 'package:respondcrew_app/screens/operational_workspace_screen.dart';
import 'package:respondcrew_app/services/tru_access_service.dart';

Map<String, dynamic> response({bool active = true}) => {
  'serverNowMs': DateTime.now().millisecondsSinceEpoch,
  'membership': active ? {'role':'coordinator', 'regions':['Ida'], 'revision':1, 'validUntilMs':null} : null,
};
void main() {
  testWidgets('one signed-in identity selects TRU and returns to the workspace picker', (tester) async {
    final access = TruAccessService(load: () async => response());
    String path = '/';
    TruSession? session;
    Widget host() => MaterialApp(home: OperationalWorkspaceScreen(
      key:const ValueKey('user'), userId:'uid', displayName:'Katsetaja', path:path,
      navigate:(p) => path = p, access:access, marineHome:const Text('Merepääste vorm'),
      truBuilder:(_, s, change) {session = s; return TextButton(onPressed:change, child:const Text('TRU avatud'));},
    ));
    await tester.pumpWidget(host()); await tester.pumpAndSettle();
    expect(find.text('Vali töökeskkond'), findsOneWidget);
    await tester.tap(find.text('TRU')); await tester.pumpWidget(host()); await tester.pumpAndSettle();
    expect(session!.userId, 'uid'); expect(session!.displayName, 'Katsetaja');
    expect(session!.regions, ['Ida']); expect(session!.canManage, isTrue);
    await tester.tap(find.text('TRU avatud')); expect(path, '/tookeskkonnad');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('revocation and network failure remove the active TRU view', (tester) async {
    var active = true, fail = false;
    final access = TruAccessService(load: () async {if (fail) throw Exception('offline'); return response(active:active);});
    await tester.pumpWidget(MaterialApp(home: OperationalWorkspaceScreen(
      userId:'uid', displayName:'Liige', path:'/tru', navigate:(_) {}, access:access,
      marineHome:const Text('Merepääste'), truBuilder:(_, s, c) => const Text('Private TRU view'))));
    await tester.pumpAndSettle(); expect(find.text('Private TRU view'), findsOneWidget);
    active = false; await access.refresh(); await tester.pumpAndSettle();
    expect(find.text('Private TRU view'), findsNothing);
    active = true; await access.refresh(); await tester.pumpAndSettle();
    expect(find.text('Private TRU view'), findsOneWidget);
    fail = true; await access.refresh(invalidateFirst:false); await tester.pumpAndSettle();
    expect(find.text('Private TRU view'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('marine drafts survive membership changes and failed refresh', (tester) async {
    var active = false, fail = false;
    final input = TextEditingController();
    final access = TruAccessService(load:() async {if (fail) throw Exception('offline'); return response(active:active);});
    await tester.pumpWidget(MaterialApp(home:OperationalWorkspaceScreen(
      userId:'uid', displayName:'Liige', path:'/uhingud', navigate:(_) {}, access:access,
      marineHome:TextField(controller:input), truBuilder:(_,s,c) => const Text('TRU'))));
    await tester.pumpAndSettle(); await tester.enterText(find.byType(TextField), 'Salvestamata');
    active = true; await access.refresh(); await tester.pumpAndSettle();
    fail = true; await access.refresh(); await tester.pumpAndSettle();
    expect(find.text('Salvestamata'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); input.dispose();
  });
  testWidgets('host without private TRU module rejects a direct TRU URL', (tester) async {
    await tester.pumpWidget(MaterialApp(home:OperationalWorkspaceScreen(
      userId:'uid', displayName:'Liige', path:'/tru', navigate:(_) {},
      marineHome:const Text('Merepääste'), truBuilder:null)));
    expect(find.text('TRU ligipääs puudub või liikmesus ei ole aktiivne.'), findsOneWidget);
  });
  testWidgets('old access response cannot overwrite a later revocation', (tester) async {
    final old = Completer<Map<String,dynamic>>();
    var calls = 0;
    final access = TruAccessService(load:() => ++calls == 1 ? old.future : Future.value(response(active:false)));
    await access.refresh(); old.complete(response()); await tester.pump();
    expect(access.membership, isNull); access.dispose();
  });
  testWidgets('expired and malformed grants are rejected and pause removes access', (tester) async {
    var data = response();
    final access = TruAccessService(load:() async => data);
    await tester.pump(); expect(access.membership, isNotNull);
    access.pause(); expect(access.membership, isNull);
    access.resume(); await tester.pump(); expect(access.membership, isNotNull);
    data = response(); (data['membership'] as Map)['validUntilMs'] = DateTime.now().millisecondsSinceEpoch - 1000;
    await access.refresh(); expect(access.membership, isNull);
    data = response(); (data['membership'] as Map)['regions'] = ['Kõik'];
    await access.refresh(); expect(access.membership, isNull); expect(access.error, isNotNull);
    access.dispose();
  });
  testWidgets('pending TRU check never blocks a directly selected marine workspace', (tester) async {
    final pending = Completer<Map<String,dynamic>>();
    final access = TruAccessService(load:() => pending.future);
    await tester.pumpWidget(MaterialApp(home:OperationalWorkspaceScreen(
      userId:'uid', displayName:'Liige', path:'/uhingud', navigate:(_) {}, access:access,
      marineHome:const Text('Merepääste avatud'), truBuilder:(_,s,c) => const Text('TRU'))));
    expect(find.text('Merepääste avatud'), findsOneWidget);
    pending.complete(response(active:false)); await tester.pumpAndSettle();
    expect(find.text('Merepääste avatud'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

}
