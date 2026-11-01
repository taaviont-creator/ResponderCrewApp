import 'schedule.dart';

enum Reply { yes, no, later }
enum Kind { incident, training, exercise }

class TimeSlot {
  TimeSlot(this.start, this.end) {
    if (!end.isAfter(start)) throw ArgumentError('Lõpp peab olema pärast algust.');
  }
  final DateTime start;
  final DateTime end;
  bool overlaps(TimeSlot other) => start.isBefore(other.end) && end.isAfter(other.start);
  bool contains(DateTime instant) => !instant.isBefore(start) && instant.isBefore(end);
  String get label => '${ActivitySchedule.format(start)} – ${ActivitySchedule.format(end)}';
}

class Participation {
  Reply? reply;
  final List<TimeSlot> slots = [];
  String presence = 'Pole saabunud';
}

class TruEvent {
  TruEvent({required this.title, required this.location, required this.region,
    required this.kind, required this.start, this.end, this.requiredCrew = 2});
  final String title;
  final String location;
  final String region;
  final Kind kind;
  final DateTime start;
  DateTime? end;
  final int requiredCrew;
  final Map<String, Participation> participants = {};
  bool closed = false;
  Participation response(String member) => participants.putIfAbsent(member, Participation.new);
  void answer(String member, Reply value) {
    if (closed) throw StateError('Sündmus on lõpetatud.');
    final p = response(member);
    p.reply = value;
    if (value != Reply.yes) p.slots.clear();
  }
  void addSlot(String member, TimeSlot slot) {
    if (closed) throw StateError('Sündmus on lõpetatud.');
    if (slot.start.isBefore(start) || (end != null && slot.end.isAfter(end!))) {
      throw ArgumentError('Osalemisaeg peab jääma sündmuse ajavahemikku.');
    }
    final p = response(member);
    if (p.slots.any((s) => s.overlaps(slot))) {
      throw ArgumentError('Sinu osalemisajad kattuvad.');
    }
    p.reply = Reply.yes;
    p.slots.add(slot);
    p.slots.sort((a, b) => a.start.compareTo(b.start));
  }
  int plannedAt(DateTime time) => participants.values.where(
    (p) => p.reply == Reply.yes && p.slots.any((s) => s.contains(time))).length;
}

class Transfer {
  Transfer(this.from, this.to, this.receiver, this.at);
  final String from;
  final String to;
  final String receiver;
  final DateTime at;
}

class Equipment {
  Equipment(this.name, this.home, this.location, this.condition);
  final String name;
  final String owner = 'TRU';
  final String home;
  String location;
  String condition;
  String custodian = 'Laovastutaja';
  final List<Transfer> transfers = [];
  void transfer(String destination, String receiver, DateTime at) {
    if (destination.trim().isEmpty || receiver.trim().isEmpty) {
      throw ArgumentError('Määra sihtkoht ja vastuvõtja.');
    }
    if (destination.trim() == location) throw ArgumentError('Varustus on juba selles asukohas.');
    transfers.add(Transfer(location, destination.trim(), receiver.trim(), at));
    location = destination.trim();
    custodian = receiver.trim();
  }
}

class Notice {
  Notice(this.title, this.body, this.region);
  final String title;
  final String body;
  final String region;
  final Set<String> readBy = {};
}

class DemoStore {
  DemoStore() {
    final today = ActivitySchedule.inEstonia(DateTime.now());
    final start = ActivitySchedule.fromSelection(DateTime(today.year, today.month, today.day + 1), 8, 0)!;
    final end = ActivitySchedule.fromSelection(DateTime(today.year, today.month, today.day + 3), 20, 0)!;
    events.addAll([
      TruEvent(title: 'Tormikahjude kõrvaldamine', location: 'Ida-Virumaa · kogunemine laos', region: 'Ida',
        kind: Kind.incident, start: start, end: end, requiredCrew: 3),
      TruEvent(title: 'Mootorsae ohutu kasutamine', location: 'Õppeväljak', region: 'Kõik',
        kind: Kind.training, start: start.add(const Duration(days: 5)), end: end.add(const Duration(days: 3))),
      TruEvent(title: 'Regioonide koostööõppus', location: 'Kogunemiskoht täpsustamisel', region: 'Kõik',
        kind: Kind.exercise, start: start.add(const Duration(days: 9)), end: end.add(const Duration(days: 7))),
    ]);
    events.first.addSlot('Näidisliige Mari', TimeSlot(start, start.add(const Duration(hours: 8))));
    equipment.addAll([
      Equipment('Generaator TRU-001', 'Ida ladu', 'Ida ladu', 'Töökorras'),
      Equipment('Mootorsaag TRU-002', 'Ida ladu', 'Lääne regioon', 'Vajab hooldust'),
      Equipment('Valgustuskomplekt TRU-003', 'Kesklaos', 'Kesklaos', 'Töökorras'),
    ]);
    notices.add(Notice('Uuenda oma osalemisaegu', 'Tormisündmus kestab mitu päeva. Märgi kõik ajad, millal saad aidata.', 'Ida'));
    notices.add(Notice('Varustuse kontroll', 'Kontrolli enne kasutamist varustuse seisukorda ja märgi puudused.', 'Kõik'));
  }
  final List<TruEvent> events = [];
  final List<Equipment> equipment = [];
  final List<Notice> notices = [];
}
