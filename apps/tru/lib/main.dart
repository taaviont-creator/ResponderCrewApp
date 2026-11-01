import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'domain.dart';
import 'schedule.dart';
import 'theme/app_theme.dart';

void main() => runApp(const TruApp());

class TruApp extends StatelessWidget {
  const TruApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TRU', debugShowCheckedModeBanner: false, theme: AppTheme.light,
    locale: const Locale('et'), supportedLocales: const [Locale('et')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const Workspace(),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({super.key});
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  final store = DemoStore();
  static const member = 'Näidisliige Taavi';
  int page = 0;
  String region = 'Ida';
  static const labels = ['Töölaud', 'Sündmused', 'Õpe', 'Varustus', 'Info'];
  static const icons = [Icons.dashboard_outlined, Icons.event_outlined,
    Icons.school_outlined, Icons.construction_outlined, Icons.campaign_outlined];
  bool visible(String target) => region == 'Kõik' || target == 'Kõik' || target == region;
  String kindLabel(Kind kind) => switch (kind) {
    Kind.incident => 'Sündmus', Kind.training => 'Koolitus', Kind.exercise => 'Õppus'};
  String replyLabel(Reply? reply) => switch (reply) {
    Reply.yes => 'Osalen', Reply.no => 'Ei osale', Reply.later => 'Täpsustan hiljem', null => 'Vastamata'};
  void message(Object value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$value')));
  Widget heading(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge));
  Widget panel(List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)));
  Widget gap() => const SizedBox(height: 12);

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      heading(labels[page]),
      Text('Tehnilise pääste üksus · $region', style: Theme.of(context).textTheme.bodyMedium), gap(),
      ...switch (page) {0 => dashboard(), 1 => events(false), 2 => events(true), 3 => inventory(), _ => information()},
      const SizedBox(height: 40),
    ];
    final body = ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content))),
    ]);
    return Scaffold(
      appBar: AppBar(title: const Text('TRU'), actions: [
        DropdownButton<String>(value: region, underline: const SizedBox.shrink(),
          items: ['Ida', 'Lääne', 'Lõuna', 'Põhja', 'Kõik'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (value) => setState(() => region = value!)), const SizedBox(width: 16),
      ]),
      body: Column(children: [
        Container(width: double.infinity, color: AppColors.delayedSurface,
          padding: const EdgeInsets.all(12),
          child: const Text('PROOVIVERSIOON · näidisandmed · muudatused säilivad ainult avatud seansi jooksul. Telefoniteavitusi ei saadeta.')),
        Expanded(child: LayoutBuilder(builder: (context, constraints) => constraints.maxWidth >= 900
          ? Row(children: [NavigationRail(selectedIndex: page, extended: true,
              onDestinationSelected: (v) => setState(() => page = v),
              destinations: List.generate(labels.length, (i) => NavigationRailDestination(
                icon: Icon(icons[i]), label: Text(labels[i])))), Expanded(child: body)])
          : body)),
      ]),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 900 ? NavigationBar(
        selectedIndex: page, onDestinationSelected: (v) => setState(() => page = v),
        destinations: List.generate(labels.length, (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i])),
      ) : null,
    );
  }

  List<Widget> dashboard() {
    final open = store.events.where((e) => visible(e.region) && !e.closed).toList();
    final unread = store.notices.where((n) => visible(n.region) && !n.readBy.contains(member)).length;
    return [
      panel([Text('Tere, Taavi', style: Theme.of(context).textTheme.headlineSmall),
        const Text('Üksuse info, tegevused ja varustus ühes kohas.'), gap(),
        Text('${open.length} eelseisvat või käimasolevat tegevust · $unread lugemata teadet'),
        Text('${open.where((e) => e.participants[member]?.reply == null).length} tegevust ootab sinu vastust'),
      ]), heading('Lähenevad tegevused'),
      ...open.map(eventCard),
      heading('Kalender'),
      ...([...open]..sort((a, b) => a.start.compareTo(b.start))).map((e) => ListTile(
        leading: Icon(e.kind == Kind.incident ? Icons.event : Icons.school),
        title: Text(e.title), subtitle: Text('${ActivitySchedule.format(e.start)} · ${kindLabel(e.kind)}'),
        onTap: () => eventDetails(e))),
    ];
  }

  List<Widget> events(bool education) => [
    Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
      onPressed: () => createEvent(education), icon: const Icon(Icons.add),
      label: Text(education ? 'Lisa koolitus või õppus' : 'Loo sündmus'))), gap(),
    ...store.events.where((e) => visible(e.region) && (education ? e.kind != Kind.incident : e.kind == Kind.incident)).map(eventCard),
  ];

  Widget eventCard(TruEvent event) => Padding(padding: const EdgeInsets.only(bottom: 12), child: panel([
    Text('${kindLabel(event.kind)} · ${event.region} · ${event.closed ? 'Lõpetatud' : 'Avatud'}',
      style: const TextStyle(color: AppColors.deepSeaBlue)),
    Text(event.title, style: Theme.of(context).textTheme.titleLarge),
    Text(event.location), Text(ActivitySchedule.format(event.start)),
    Text('Minu vastus: ${replyLabel(event.participants[member]?.reply)}'), gap(),
    OutlinedButton(onPressed: () => eventDetails(event), child: const Text('Vaata ja vasta')),
  ]));

  Future<void> eventDetails(TruEvent event) async {
    await showDialog<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, refresh) {
      void change(VoidCallback fn) {setState(fn); refresh(() {});}
      final own = event.response(member);
      return AlertDialog(title: Text(event.title), content: SizedBox(width: 640, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(event.location), Text('Algus: ${ActivitySchedule.format(event.start)}'),
          Text('Lõpp: ${ActivitySchedule.format(event.end)}'), gap(),
          Text('Minu vastus: ${replyLabel(own.reply)}'),
          if (!event.closed) Wrap(spacing: 8, children: Reply.values.map((r) => ChoiceChip(
            label: Text(replyLabel(r)), selected: own.reply == r,
            onSelected: (_) => change(() => event.answer(member, r)))).toList()),
          if (!event.closed) TextButton.icon(icon: const Icon(Icons.add),
            label: const Text('Lisa osalemisaeg (ka hilisem liitumine)'), onPressed: () async {
              final values = await fields('Osalemisaeg', ['Algus (PP.KK.AAAA HH:MM)', 'Lõpp (PP.KK.AAAA HH:MM)'],
                [stamp(event.start), stamp(event.end ?? event.start.add(const Duration(hours: 8)))]);
              if (values == null || !mounted || !context.mounted) return;
              try {
                final from = ActivitySchedule.parse(values[0]), until = ActivitySchedule.parse(values[1]);
                if (from == null || until == null) throw ArgumentError('Kontrolli kuupäeva ja kellaaega.');
                change(() => event.addSlot(member, TimeSlot(from, until)));
              } catch (e) {message(e);}
            }),
          ...List.generate(own.slots.length, (i) => ListTile(contentPadding: EdgeInsets.zero,
            title: Text(own.slots[i].label), trailing: event.closed ? null : IconButton(
              tooltip: 'Eemalda osalemisaeg', icon: const Icon(Icons.delete_outline),
              onPressed: () => change(() => own.slots.removeAt(i))))),
          if (own.reply == Reply.yes && own.slots.isEmpty)
            const Text('Lisa osalemisaeg. Ilma ajata vastus ei lähe ajalise katvuse arvestusse.'),
          if (!event.closed) DropdownButtonFormField<String>(initialValue: own.presence,
            decoration: const InputDecoration(labelText: 'Minu tegelik kohalolek'),
            items: ['Pole saabunud', 'Teel', 'Kohal', 'Lahkunud'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => change(() => own.presence = v!)),
          heading('Meeskonna plaan'),
          ...event.participants.entries.map((p) => Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text('${p.key}: ${replyLabel(p.value.reply)} · ${p.value.presence}\n${p.value.slots.map((s) => s.label).join('\n')}'))),
          heading('Katvus osalemisplaani järgi'),
          if (event.end == null) const Text('Lõpp on lahtine: allpool on esimese 72 tunni plaan.'),
          ...event.coverageUntil(event.end ?? event.start.add(const Duration(days: 3))).map((segment) =>
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(
              '${segment.period.label}: ${segment.count} / ${event.requiredCrew}${segment.count < event.requiredCrew ? ' · inimesi puudu' : ''}'))),
          if (!event.closed) TextButton(onPressed: () async {
            final values = await fields('Pikenda sündmust', ['Uus lõpp (PP.KK.AAAA HH:MM)'], [stamp(event.end ?? event.start)]);
            if (values == null || !mounted || !context.mounted) return;
            final until = ActivitySchedule.parse(values.first);
            if (until == null || !until.isAfter(event.end ?? event.start)) {message('Uus lõpp peab olema senisest hilisem.'); return;}
            change(() => event.end = until);
          }, child: const Text('Pikenda lõppaega')),
          if (!event.closed) TextButton(onPressed: () => change(() => event.closed = true), child: const Text('Lõpeta sündmus')),
        ],
      ))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sulge'))]);
    }));
  }

  String stamp(DateTime time) {
    final t = ActivitySchedule.inEstonia(time);
    return '${ActivitySchedule.date(t)} ${ActivitySchedule.two(t.hour)}:${ActivitySchedule.two(t.minute)}';
  }

  Future<void> createEvent(bool education) async {
    final start = ActivitySchedule.inEstonia(DateTime.now()).add(const Duration(days: 1));
    final values = await fields(education ? 'Uus koolitus või õppus' : 'Uus sündmus', [
      'Pealkiri', 'Asukoht', 'Regioon: Kõik / Ida / Lääne / Lõuna / Põhja',
      if (education) 'Liik: Koolitus / Õppus',
      'Algus (PP.KK.AAAA HH:MM)', 'Lõpp (sündmusel võib jätta tühjaks)', 'Vajalik liikmete arv',
    ], ['', '', region, if (education) 'Koolitus', stamp(start), stamp(start.add(const Duration(hours: 8))), '2']);
    if (values == null || !mounted) return;
    final offset = education ? 1 : 0;
    final from = ActivitySchedule.parse(values[3 + offset]);
    final rawEnd = values[4 + offset];
    final until = rawEnd.isEmpty ? null : ActivitySchedule.parse(rawEnd);
    final crew = int.tryParse(values[5 + offset]);
    if (values[0].isEmpty || values[1].isEmpty || !['Kõik', 'Ida', 'Lääne', 'Lõuna', 'Põhja'].contains(values[2]) ||
      (education && !['Koolitus', 'Õppus'].contains(values[3])) || from == null ||
      (rawEnd.isNotEmpty && until == null) || (until != null && !until.isAfter(from)) ||
      (education && until == null) || crew == null || crew < 1) {
      message('Tegevust ei loodud. Kontrolli välju, ajavahemikku ja liikmete arvu.'); return;
    }
    setState(() => store.events.add(TruEvent(title: values[0], location: values[1], region: values[2],
      kind: education ? (values[3] == 'Õppus' ? Kind.exercise : Kind.training) : Kind.incident,
      start: from, end: until, requiredCrew: crew)));
  }

  List<Widget> inventory() => [
    const Text('Kogu TRU varustus · kuuluvus ja püsiasukoht säilivad ka üleandmisel.'), gap(),
    ...store.equipment.map((item) => Padding(padding: const EdgeInsets.only(bottom: 12), child: panel([
      Text(item.name, style: Theme.of(context).textTheme.titleLarge),
      Text('Kuuluvus: ${item.owner} · püsiasukoht: ${item.home}'),
      Text('Praegu: ${item.location} · vastutaja: ${item.custodian}'), gap(),
      DropdownButtonFormField<String>(initialValue: item.condition,
        decoration: const InputDecoration(labelText: 'Tehniline seisukord'),
        items: ['Töökorras', 'Vajab hooldust', 'Rikkis', 'Hoolduses'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) => setState(() => item.condition = v!)), gap(),
      OutlinedButton(onPressed: () async {
        final result = await fields('Varustuse üleandmine', ['Sihtkoht (regioon / ladu / sündmus)', 'Vastuvõtja'], ['', '']);
        if (result == null || !mounted) return;
        try {setState(() => item.transfer(result[0], result[1], DateTime.now()));} catch (e) {message(e);}
      }, child: const Text('Anna üle / muuda asukohta')),
      ...item.transfers.reversed.map((t) => Text('${ActivitySchedule.format(t.at)} · ${t.from} → ${t.to} · vastu võttis ${t.receiver}')),
    ]))),
  ];

  List<Widget> information() => [
    FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Lisa teade'), onPressed: () async {
      final result = await fields('Uus teade', ['Pealkiri', 'Sisu', 'Regioon: Kõik / Ida / Lääne / Lõuna / Põhja'], ['', '', region]);
      if (result == null || !mounted) return;
      if (result.any((v) => v.isEmpty) || !['Kõik', 'Ida', 'Lääne', 'Lõuna', 'Põhja'].contains(result[2])) {
        message('Teadet ei lisatud. Täida väljad ja kontrolli regiooni.'); return;
      }
      setState(() => store.notices.insert(0, Notice(result[0], result[1], result[2])));
    }), gap(),
    ...store.notices.where((n) => visible(n.region)).map((n) => Padding(padding: const EdgeInsets.only(bottom: 12), child: panel([
      Text('${n.region} · ${n.readBy.contains(member) ? 'Loetud' : 'Lugemata'}'),
      Text(n.title, style: Theme.of(context).textTheme.titleLarge), Text(n.body),
      if (!n.readBy.contains(member)) TextButton(onPressed: () => setState(() => n.readBy.add(member)),
        child: const Text('Kinnitan, et olen lugenud')),
    ]))),
    heading('Juhendid ja kontaktid'),
    panel([const Text('Näidisjuhend: varustuse üleandmine'),
      const Text('1. Kontrolli seisukorda.\n2. Märgi sihtkoht ja vastuvõtja.\n3. Kontrolli, et üleandmine ilmub ajalukku.'),
      gap(), const Text('Päris dokumendid, liikmete kontaktid ja pädevused lisame järgmises etapis.')]),
  ];

  Future<List<String>?> fields(String title, List<String> labels, List<String> initial) async {
    final controllers = initial.map((v) => TextEditingController(text: v)).toList();
    final form = GlobalKey<FormState>();
    final result = await showDialog<List<String>>(context: context, builder: (context) => AlertDialog(
      title: Text(title), content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: form,
        child: Column(mainAxisSize: MainAxisSize.min, children: List.generate(labels.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: controllers[i],
            maxLines: labels[i] == 'Sisu' ? 4 : 1,
            decoration: InputDecoration(labelText: labels[i]),
          ))))))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Loobu')),
        FilledButton(onPressed: () => Navigator.pop(context, controllers.map((c) => c.text.trim()).toList()), child: const Text('Salvesta'))],
    ));
    // Wait until the dialog route has finished removing its text fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in controllers) {c.dispose();}
    return result;
  }
}
