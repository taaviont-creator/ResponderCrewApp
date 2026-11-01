import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/tru_session.dart';

/// Access discovery only; each future TRU data operation must also authorize
/// membership on the server. Never trust a cached membership after a failure.
class TruAccessService extends ChangeNotifier {
  TruAccessService({required this.load}) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      notifyListeners();
      if (_foreground && _elapsed.elapsed.inSeconds >= 20 && !loading) {
        unawaited(refresh(invalidateFirst: false));
      }
    });
    unawaited(refresh());
  }
  factory TruAccessService.firebase() => TruAccessService(load: () async {
    final result = await FirebaseFunctions.instanceFor(region: 'europe-north1')
      .httpsCallable('getTruContext', options: HttpsCallableOptions(timeout: const Duration(seconds: 40)))
      .call();
    return Map<String, dynamic>.from(result.data as Map);
  });
  final Future<Map<String, dynamic>> Function() load;
  final Stopwatch _elapsed = Stopwatch()..start();
  Timer? _timer;
  TruMembership? _membership;
  DateTime? _serverTime;
  bool _trusted = false, _disposed = false, _foreground = true;
  int _generation = 0;
  bool loading = false, initialized = false;
  String? error;
  TruMembership? get membership {
    if (!_trusted || _serverTime == null || _elapsed.elapsed.inSeconds >= 45) return null;
    final until = _membership?.validUntil;
    if (until != null && !until.isAfter(_serverTime!.add(_elapsed.elapsed))) return null;
    return _membership;
  }
  void pause() {
    if (!_foreground) return;
    _foreground = false;
    _generation++;
    _trusted = false;
    loading = false;
    notifyListeners();
  }
  void resume() {
    if (_foreground || _disposed) return;
    _foreground = true;
    unawaited(refresh());
  }
  Future<void> refresh({bool invalidateFirst = true}) async {
    if (_disposed || !_foreground) return;
    final generation = ++_generation;
    if (invalidateFirst) _trusted = false;
    loading = true;
    notifyListeners();
    final trip = Stopwatch()..start();
    try {
      final data = await load().timeout(const Duration(seconds: 40));
      if (_disposed || generation != _generation) return;
      final time = data['serverNowMs'];
      final raw = data['membership'];
      final parsed = TruMembership.fromMap(raw);
      if (time is! int || time.abs() > 8640000000000000 ||
          !data.containsKey('membership') || (raw != null && parsed == null)) {
        throw const FormatException('Invalid TRU context');
      }
      _membership = parsed;
      _serverTime = DateTime.fromMillisecondsSinceEpoch(time, isUtc: true).add(trip.elapsed);
      _elapsed.reset();
      _trusted = true;
      error = null;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _trusted = false;
      _membership = null;
      _elapsed.reset();
      error = 'TRU liikmesuse kontroll ebaõnnestus. Kontrolli ühendust ja proovi uuesti.';
    } finally {
      if (!_disposed && generation == _generation) {
        initialized = true;
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
    super.dispose();
  }
}
