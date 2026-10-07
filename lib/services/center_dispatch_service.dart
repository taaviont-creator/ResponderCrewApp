import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CenterDispatchService {
  static String requestId() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  static Future<Map<String, dynamic>> send(Map<String, dynamic> data) async {
    final result = await FirebaseFunctions.instanceFor(
      region: 'europe-north1',
    ).httpsCallable('centerDispatch').call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  static String error(Object e) => e is FirebaseFunctionsException
      ? e.message ?? 'Toiming ebaõnnestus.'
      : 'Ühenduse viga. Kontrolli sündmuse seisu ja proovi uuesti.';
  static String time(dynamic value) {
    final d = value is Timestamp ? value.toDate().toLocal() : null;
    if (d == null) return 'Ootel';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  static String response(dynamic value) => switch (value) {
    'accepted' => 'Ühing reageerib',
    'declined' => 'Ühing ei saa reageerida',
    _ => 'Ootab ühingu vastust',
  };
  static String status(dynamic value) => switch (value) {
    'closed' => 'Keskus lõpetas väljakutse',
    'cancelled' => 'Keskus tühistas väljakutse',
    _ => 'Aktiivne',
  };
}
