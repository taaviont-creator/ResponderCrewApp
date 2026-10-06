import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../models/geofence_region.dart';

@pragma('vm:entry-point')
Future<void> respondCrewGeofenceCallback(GeofenceCallbackParams event) async {
  WidgetsFlutterBinding.ensureInitialized();
  const budget = MethodChannel('respondcrew/geofence-budget');
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  if (ios) await budget.invokeMethod<bool>('begin');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Never log callback parameters: the native event can contain personal GPS.
    final sessions = event.geofences
        .map((g) => g.id.split(':'))
        .where((p) => p.length == 3 && p[0] == 'rcg')
        .map((p) => p[1])
        .toSet();
    for (final session in sessions) {
      try {
        await GeofenceService(background: true).sample(session);
      } catch (_) {
        // A stale sample is never replayed. Next callback/resume obtains a new fix.
        await SharedPreferencesAsync().setString(
          'rcg-error:$session',
          'Piirkonna edastamine ebaõnnestus. Ava valmisolek ja kontrolli ühendust.',
        );
      }
    }
  } finally {
    if (ios) await budget.invokeMethod<void>('end');
  }
}

class GeofenceService with WidgetsBindingObserver {
  GeofenceService({this.background = false});
  final bool background;
  static bool get supported =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform);
  static final lifecycle = GeofenceService();
  late final _preferences = SharedPreferencesAsync();
  StreamSubscription<User?>? _auth;
  bool _refreshing = false;
  Future<Map<String, dynamic>> call(
    String org,
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    final result = await FirebaseFunctions.instanceFor(region: 'europe-north1')
        .httpsCallable(
          'geofenceReadiness',
          options: HttpsCallableOptions(
            timeout: Duration(seconds: background ? 10 : 25),
          ),
        )
        .call<Map<String, dynamic>>({
          'organizationId': org,
          'action': action,
          ...fields,
        });
    return Map<String, dynamic>.from(result.data);
  }

  Future<void> initialize() async {
    if (!supported) return;
    WidgetsBinding.instance.addObserver(this);
    await NativeGeofenceManager.instance.initialize();
    _auth ??= FirebaseAuth.instance.authStateChanges().listen((_) {
      unawaited(refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (!supported || _refreshing) return;
    _refreshing = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final keys = await _preferences.getKeys();
      for (final key in keys.where((key) => key.startsWith('rcg-session:'))) {
        final session = key.substring('rcg-session:'.length);
        final local = await localSession(session);
        if (local == null) continue;
        if (local['uid'] != uid) {
          await removeLocal(session);
          continue;
        }
        try {
          await sample(session);
        } catch (_) {
          await _preferences.setString(
            'rcg-error:$session',
            'Andmeid ei saanud värskendada. Kontrolli ühendust.',
          );
        }
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<Map<String, dynamic>?> localSession(String session) async {
    final raw = await _preferences.getString('rcg-session:$session');
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> stopBeforeSignOut() async {
    if (!supported) return;
    final keys = await _preferences.getKeys();
    await Future.wait(
      keys.where((key) => key.startsWith('rcg-session:')).map((key) async {
        final session = key.substring('rcg-session:'.length);
        final local = await localSession(session);
        if (local == null) return;
        try {
          if (local['uid'] == FirebaseAuth.instance.currentUser?.uid) {
            await call(local['organizationId'] as String, 'disable', {
              'sessionId': session,
            }).timeout(const Duration(seconds: 8));
          }
        } catch (_) {
          /* Offline leases still expire on the server. */
        }
        await removeLocal(session);
      }),
    );
  }

  Future<void> removeLocal(String session) async {
    // Remove consent first; a racing callback then cannot publish another event.
    await _preferences.remove('rcg-session:$session');
    await _preferences.remove('rcg-error:$session');
    for (final radius in ['inner', 'outer']) {
      await NativeGeofenceManager.instance.removeGeofenceById(
        'rcg:$session:$radius',
      );
    }
  }

  Future<bool> permissionsReady() async =>
      supported &&
      await Geolocator.isLocationServiceEnabled() &&
      await Geolocator.checkPermission() == LocationPermission.always &&
      await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.precise;

  Future<void> requestPermissions() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always) {
      await Geolocator.openAppSettings();
    }
  }

  Future<String> enable(String org) async {
    await NativeGeofenceManager.instance.initialize();
    if (!await permissionsReady()) {
      throw StateError(
        'Luba telefoni seadetes täpne asukoht „Alati“ ja lülita asukohateenus sisse.',
      );
    }
    final registered = await NativeGeofenceManager.instance
        .getRegisteredGeofences();
    final current = await call(org, 'get');
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final limits = await const MethodChannel(
        'respondcrew/geofence-capabilities',
      ).invokeMapMethod<String, dynamic>('limits');
      if (limits?['available'] != true ||
          limits?['backgroundRefresh'] != true ||
          (limits?['maximumRadius'] as num? ?? 0) <
              ((current['config'] as Map)['outerMeters'] as num)) {
        throw StateError(
          'iPhone ei saa seda piirkonda taustal jälgida. Kontrolli taustavärskendust; piirkonna raadius peab mahtuma telefoni toetatud piiridesse.',
        );
      }
    }
    final previous = current['state'] as Map?;
    final previousSession = previous?['sessionId'] as String?;
    final previousIsLocal =
        previousSession != null && await localSession(previousSession) != null;
    if (!previousIsLocal && registered.length + 2 > 20) {
      throw StateError(
        'Telefonis saab jälgida kuni kümne ühingu piirkondi. Peata enne mõne teise ühingu automaatika.',
      );
    }
    final result = await call(org, 'enable');
    final state = Map<String, dynamic>.from(result['state'] as Map);
    final config = Map<String, dynamic>.from(result['config'] as Map);
    final session = state['sessionId'] as String;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (previousIsLocal) await removeLocal(previousSession);
    await _preferences.setString(
      'rcg-session:$session',
      jsonEncode({
        'uid': uid,
        'organizationId': org,
        'sessionId': session,
        'config': config,
      }),
    );
    try {
      for (final zone in ['inner', 'outer']) {
        await NativeGeofenceManager.instance.createGeofence(
          Geofence(
            id: 'rcg:$session:$zone',
            location: Location(
              latitude: (config['latitude'] as num).toDouble(),
              longitude: (config['longitude'] as num).toDouble(),
            ),
            radiusMeters: (config['${zone}Meters'] as num).toDouble(),
            triggers: {
              GeofenceEvent.enter,
              GeofenceEvent.exit,
              if (defaultTargetPlatform == TargetPlatform.android)
                GeofenceEvent.dwell,
            },
            iosSettings: const IosGeofenceSettings(initialTrigger: false),
            androidSettings: const AndroidGeofenceSettings(
              initialTriggers: {},
              loiteringDelay: Duration(minutes: 2),
              notificationResponsiveness: Duration(minutes: 2),
            ),
          ),
          respondCrewGeofenceCallback,
        );
      }
      await sample(session);
      return session;
    } catch (_) {
      await removeLocal(session);
      await call(org, 'disable', {'sessionId': session});
      rethrow;
    }
  }

  Future<void> disable(String org, String? session) async {
    // Server success is required before the UI reports that status was changed.
    if (session != null && supported) await removeLocal(session);
    await call(org, 'disable', {'sessionId': session});
  }

  Future<int?> sample(String session) async {
    final local = await localSession(session);
    if (local == null) return null;
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user?.uid != local['uid']) {
      await removeLocal(session);
      return null;
    }
    final org = local['organizationId'] as String;
    // Background execution is bounded by the OS. The event endpoint rechecks
    // membership, consent, configuration and session atomically; no preflight
    // network request is needed there.
    if (!background) {
      final latest = await call(org, 'get');
      final state = latest['state'] as Map?;
      if (state?['enabled'] != true || state?['sessionId'] != session) {
        await removeLocal(session);
        return null;
      }
    }
    final config = Map<String, dynamic>.from(local['config'] as Map);
    String zone = 'unknown';
    var at = DateTime.now().millisecondsSinceEpoch;
    if (await permissionsReady()) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        if (DateTime.now().difference(position.timestamp).abs() <
            const Duration(minutes: 2)) {
          at = position.timestamp.millisecondsSinceEpoch;
          zone = geofenceRegion(
            distance: Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              (config['latitude'] as num).toDouble(),
              (config['longitude'] as num).toDouble(),
            ),
            accuracy: position.accuracy,
            inner: (config['innerMeters'] as num).toDouble(),
            outer: (config['outerMeters'] as num).toDouble(),
          );
        }
      } catch (_) {
        /* A failed fix explicitly removes automatic availability. */
      }
    }
    if (await localSession(session) == null) return null;
    Map<String, dynamic> result;
    try {
      result = await call(org, 'event', {
        'sessionId': session,
        'zone': zone,
        'observedAtMs': at,
      });
    } on FirebaseFunctionsException catch (error) {
      if ({'permission-denied', 'unauthenticated'}.contains(error.code)) {
        await removeLocal(session);
      }
      rethrow;
    }
    if (result['stopped'] == true) {
      await removeLocal(session);
      return null;
    }
    await _preferences.remove('rcg-error:$session');
    return at;
  }

  Future<void> confirm(String org, String session) async {
    final at = await sample(session);
    if (at == null) {
      throw StateError('Lülita automaatika selles telefonis uuesti sisse.');
    }
    await call(org, 'confirm', {'sessionId': session, 'observedAtMs': at});
  }

  Future<String?> error(String session) =>
      _preferences.getString('rcg-error:$session');
}
