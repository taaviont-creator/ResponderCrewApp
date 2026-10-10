import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/geofence_region.dart';
import 'package:respondcrew_app/models/availability_model.dart';

void main() {
  test(
    'Only entry into this session duty radius requests return confirmation',
    () {
      bool candidate(List<String> ids, {bool entering = true}) =>
          geofenceReturnCandidate(
            fenceIds: ids,
            session: 'mine',
            entering: entering,
          );
      expect(candidate(['rcg:mine:inner']), isTrue);
      expect(candidate(['rcg:mine:outer']), isFalse);
      expect(candidate(['rcg:other:inner']), isFalse);
      expect(candidate(['rcg:mine:inner'], entering: false), isFalse);
      expect(candidate(['rcg:mine:outer', 'rcg:mine:inner']), isTrue);
    },
  );
  test(
    'Region classification uses uncertainty instead of pretending to be inside',
    () {
      String region(double distance, double accuracy) => geofenceRegion(
        distance: distance,
        accuracy: accuracy,
        inner: 3000,
        outer: 8000,
      );
      expect(region(1000, 20), 'inner');
      expect(region(4000, 20), 'ring');
      expect(region(9000, 20), 'outside');
      expect(region(2990, 20), 'unknown');
      expect(region(8005, 20), 'unknown');
      expect(region(100, 300), 'unknown');
      expect(region(double.nan, 20), 'unknown');
    },
  );
  test(
    'Personal view expires automatic status but preserves manual/legacy availability',
    () {
      final at = DateTime(2020);
      AvailabilityModel member(DateTime update) => AvailabilityModel(
        id: 'u_o',
        userId: 'u',
        organizationId: 'o',
        commandId: 'o',
        status: 'onDuty',
        manualStatus: 'onDuty',
        updatedAt: update,
        geofenceAppliedAt: at,
        geofenceUntil: at.add(const Duration(days: 1)),
      );
      expect(member(at).status, 'offDuty');
      expect(member(at).manualStatus, 'offDuty');
      expect(
        member(at).geofenceExpiredAt(at.add(const Duration(hours: 23))),
        false,
      );
      expect(member(at.add(const Duration(seconds: 1))).status, 'onDuty');
    },
  );
}
