import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/center_context.dart';

/// UI discovery only. Every future operational request must authorize on server.
class CenterAccessService extends ChangeNotifier {
  CenterAccessService({required this.load, this.invalidations}) {
    _subscription = invalidations?.listen((_) {
      if (_foreground) {
        unawaited(refresh());
      } else {
        invalidate();
      }
    }, onError: _watchFailed);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      notifyListeners(); // Enforce expiry even without a Firestore event.
      if (_foreground && _elapsed.elapsed.inSeconds >= 20 && !_loading) {
        unawaited(refresh(invalidateFirst: false));
      }
    });
    unawaited(refresh());
  }

  factory CenterAccessService.firebase(String uid) => CenterAccessService(
    load: () async {
      final result =
          await FirebaseFunctions.instanceFor(region: 'europe-north1')
              .httpsCallable(
                'getCenterContexts',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 40),
                ),
              )
              .call();
      return Map<String, dynamic>.from(result.data as Map);
    },
    invalidations: FirebaseFirestore.instance
        .collection('centerAccess')
        .doc(uid)
        .collection('grants')
        .snapshots(),
  );

  final Future<Map<String, dynamic>> Function() load;
  final Stream<Object?>? invalidations;
  final Stopwatch _elapsed = Stopwatch()..start();
  Timer? _ticker;
  StreamSubscription<Object?>? _subscription;
  List<CenterContext> _contexts = [];
  DateTime? _serverTime;
  bool _disposed = false, _loading = false, _trusted = false;
  bool _foreground = true;
  bool _initialized = false;
  int _generation = 0;
  String? error;

  bool get loading => _loading;
  bool get initialized => _initialized;
  DateTime? get checkedAt => _serverTime;
  List<CenterContext> get contexts {
    if (!_trusted || _serverTime == null || _elapsed.elapsed.inSeconds >= 45) {
      return [];
    }
    final now = _serverTime!.add(_elapsed.elapsed);
    return _contexts
        .where((c) => c.validUntil == null || c.validUntil!.isAfter(now))
        .toList();
  }

  void _watchFailed(Object _) {
    if (_disposed) return;
    if (!_foreground) {
      invalidate();
    } else if (!_loading) {
      // A watch transport/rules failure is not an access decision. Recheck on
      // the authoritative callable now, not on the next polling tick. If a
      // check is already running, keep it: invalidate() would discard its
      // successful response and leave the initial screen unresolved for 20 s.
      unawaited(refresh());
    }
  }

  void invalidate() {
    _generation++;
    _trusted = false;
    _loading = false;
    if (!_disposed) notifyListeners();
  }

  void pause() {
    if (!_foreground) return;
    _foreground = false;
    invalidate();
  }

  void resume() {
    if (_foreground) return;
    _foreground = true;
    unawaited(refresh());
  }

  Future<void> refresh({bool invalidateFirst = true}) async {
    if (_disposed || !_foreground) return;
    // A later revocation/refresh must not be overwritten by an older response.
    final generation = ++_generation;
    if (invalidateFirst) _trusted = false;
    _loading = true;
    if (!_disposed) notifyListeners();
    final roundTrip = Stopwatch()..start();
    try {
      final result = await load().timeout(const Duration(seconds: 40));
      if (_disposed || generation != _generation) return;
      final time = result['serverNowMs'];
      if (time is! int ||
          time.abs() > 8640000000000000 ||
          result['contexts'] is! List) {
        throw const FormatException('Invalid center access response');
      }
      _contexts = (result['contexts'] as List)
          .whereType<Map>()
          .map((d) => CenterContext.fromMap(Map<String, dynamic>.from(d)))
          .whereType<CenterContext>()
          .toList();
      // Conservative expiry: account for response transit time rather than
      // granting extra time when a network response arrives late.
      _serverTime = DateTime.fromMillisecondsSinceEpoch(
        time,
        isUtc: true,
      ).add(roundTrip.elapsed);
      _elapsed.reset();
      _trusted = true;
      _initialized = true;
      error = null;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error =
          'Keskuse õiguste kontroll ebaõnnestus. Kontrolli ühendust ja proovi uuesti.';
      _trusted = false;
      _initialized = true;
      _contexts = [];
      _elapsed.reset();
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _ticker?.cancel();
    _subscription?.cancel();
    _elapsed.stop();
    super.dispose();
  }
}
