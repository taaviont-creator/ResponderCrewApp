import 'statistics_model.dart';

/// Uses the same confirmed attendance entries as the report totals. One shared
/// activity contributes each participant's hours; duty time is not contribution.
class ContributionBreakdown {
  ContributionBreakdown._(this.rows);

  factory ContributionBreakdown.fromMembers(
    Iterable<MemberContribution> members,
  ) {
    final groups = <String, ContributionSlice>{};
    for (final member in members) {
      for (final entry in member.entries) {
        if (entry['confirmed'] != true) continue;
        final category = entry['kind'] == 'callout'
            ? 'callout'
            : entry['category'] as String? ?? 'other';
        final row = groups.putIfAbsent(
          category,
          () => ContributionSlice(category),
        );
        row.count++;
        final hours = entry['hours'];
        if (hours is num && hours.isFinite && hours >= 0) {
          row.hours += hours.toDouble();
          row.knownHoursCount++;
        } else {
          row.unknownHoursCount++;
        }
      }
    }
    final rows = groups.values.toList()
      ..sort((a, b) {
        final byHours = b.hours.compareTo(a.hours);
        return byHours != 0 ? byHours : a.label.compareTo(b.label);
      });
    return ContributionBreakdown._(rows);
  }

  final List<ContributionSlice> rows;
  double get hours => rows.fold(0, (sum, row) => sum + row.hours);
  int get unknownHoursCount =>
      rows.fold(0, (sum, row) => sum + row.unknownHoursCount);
}

class ContributionSlice {
  ContributionSlice(this.category);
  final String category;
  String get label => category == 'callout'
      ? 'Väljakutsed'
      : contributionTypes[category] ?? 'Muu tegevus ($category)';
  double hours = 0;
  int count = 0, knownHoursCount = 0, unknownHoursCount = 0;
}

class CalloutBreakdown {
  CalloutBreakdown(this.events);
  final Map<String, dynamic> events;

  int? count(String key) {
    final value = events[key];
    return value is num &&
            value.isFinite &&
            value >= 0 &&
            value == value.roundToDouble()
        ? value.toInt()
        : null;
  }

  /// Missing/contradictory type counts are not interpreted as a zero slice.
  bool get hasDistribution =>
      count('period') != null &&
      count('sar') != null &&
      count('tross') != null &&
      count('sar')! + count('tross')! <= count('period')!;
  Map<String, int> get slices => !hasDistribution
      ? {}
      : {
          'SAR': count('sar')!,
          'Trossi mereabi': count('tross')!,
          if (count('period')! > count('sar')! + count('tross')!)
            'Muu / määramata':
                count('period')! - count('sar')! - count('tross')!,
        };
}
