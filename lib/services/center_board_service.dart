import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/center_board.dart';

class CenterBoardService extends ChangeNotifier {
  CenterBoardService({required this.load, bool autoRefresh = true}) {
    if (autoRefresh) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_disposed || !_foreground) return;
        notifyListeners();
        if (_lastAttempt.elapsed.inSeconds >= 30 && !loading) {
          unawaited(refresh());
        }
      });
    }
    unawaited(refresh());
  }
  factory CenterBoardService.firebase(String centerId) => CenterBoardService(
    load: () async {
      final result = await FirebaseFunctions.instanceFor(
        region: 'europe-north1',
      ).httpsCallable('getCenterReadinessBoard').call({'centerId': centerId});
      return Map<String, dynamic>.from(result.data as Map);
    },
  );
  final Future<Map<String, dynamic>> Function() load;
  final _elapsed = Stopwatch()..start();
  final _lastAttempt = Stopwatch()..start();
  Timer? _timer;
  bool _disposed = false, _foreground = true;
  int _generation = 0;
  bool loading = false, connected = false;
  String? error;
  List<CenterBoardItem> items = [];
  DateTime? checkedAt, _serverTime, _accessUntil;
  DateTime get now =>
      (_serverTime ?? DateTime.now().toUtc()).add(_elapsed.elapsed);
  bool get freshConnection =>
      connected &&
      _elapsed.elapsed.inSeconds < 90 &&
      (_accessUntil == null || _accessUntil!.isAfter(now));
  void pause() {
    if (!_foreground) return;
    _foreground = false;
    connected = false;
    _generation++;
    loading = false;
    notifyListeners();
  }

  void resume() {
    if (_foreground) return;
    _foreground = true;
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_disposed || !_foreground) return;
    final generation = ++_generation;
    _lastAttempt.reset();
    loading = true;
    notifyListeners();
    final roundTrip = Stopwatch()..start();
    try {
      final data = await load().timeout(const Duration(seconds: 40));
      if (_disposed || generation != _generation) return;
      final at = data['serverNowMs'];
      if (at is! int || at.abs() > 8640000000000000 || data['items'] is! List) {
        throw const FormatException('Invalid board');
      }
      items = (data['items'] as List)
          .whereType<Map>()
          .map((d) => CenterBoardItem.fromMap(Map<String, dynamic>.from(d)))
          .where((d) => d.id.isNotEmpty)
          .toList();
      _serverTime = DateTime.fromMillisecondsSinceEpoch(
        at,
        isUtc: true,
      ).add(roundTrip.elapsed);
      final until = data['accessValidUntilMs'];
      if (until != null && (until is! int || until.abs() > 8640000000000000)) {
        throw const FormatException('Invalid access expiry');
      }
      _accessUntil = until is int
          ? DateTime.fromMillisecondsSinceEpoch(until, isUtc: true)
          : null;
      checkedAt = DateTime.fromMillisecondsSinceEpoch(at, isUtc: true);
      _elapsed.reset();
      connected = true;
      error = null;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      connected = false;
      if (e is FirebaseFunctionsException &&
          ['permission-denied', 'unauthenticated'].contains(e.code)) {
        items = [];
        error = 'Keskuse ligipääsuõigus puudub või eemaldati.';
      } else {
        error =
            'Andmete uuendamine ebaõnnestus. Viimati laaditud info pole kinnitatud hetkeolukord.';
      }
      // Keep server clock monotonic; throttling of retry uses a separate delay below.
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _elapsed.stop();
    _lastAttempt.stop();
    super.dispose();
  }
}
