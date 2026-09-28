import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/membership_model.dart';

class CalloutAttendanceService {
  final _db = FirebaseFirestore.instance;
  Stream<bool> canManage({
    required String organizationId,
    required String userId,
  }) => _db
      .collection('memberships')
      .doc('${userId}_$organizationId')
      .snapshots()
      .map((doc) {
        final data = doc.data();
        if (data == null ||
            data['userId'] != userId ||
            (data['organizationId'] ?? data['commandId']) != organizationId ||
            (data['organizationId'] != null &&
                data['commandId'] != null &&
                data['organizationId'] != data['commandId'])) {
          return false;
        }
        final member = MembershipModel.fromMap(id: doc.id, data: data);
        return member.isActive &&
            (member.isOrgAdmin || member.isSeaRescueLevel2);
      });
  Stream<List<Map<String, dynamic>>> participants(
    String organizationId,
    String calloutId,
  ) => _db
      .collection('calloutAttendance')
      .where('organizationId', isEqualTo: organizationId)
      .where('calloutId', isEqualTo: calloutId)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => d.data()).toList()
          ..sort(
            (a, b) => (a['userName'] as String? ?? '').compareTo(
              b['userName'] as String? ?? '',
            ),
          ),
      );
  Stream<List<Map<String, dynamic>>> history(
    String organizationId,
    String calloutId,
  ) => _db
      .collection('callouts')
      .doc(calloutId)
      .collection('attendanceHistory')
      .where('organizationId', isEqualTo: organizationId)
      .where('calloutId', isEqualTo: calloutId)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => d.data()).toList()
          ..sort(
            (a, b) => (a['createdAt'] as Timestamp).compareTo(
              b['createdAt'] as Timestamp,
            ),
          ),
      );
}
