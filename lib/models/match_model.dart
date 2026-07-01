import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'prize_position.dart';

class MatchModel {
  final String id;
  final String matchName;
  final String team1;
  final String team2;
  final String team1Logo;
  final String team2Logo;
  final String date;
  final String time;
  final String timePeriod;
  final List<PrizePosition> prizePositions;
  final String matchStatus;
  final bool enabled;
  final DateTime? createdAt;
  final DateTime? kickoffAt;
  final DateTime? predictionClosesAt;
  final int? team1Goals;
  final int? team2Goals;
  final bool resultSaved;
  final bool winnersLocked;
  final List<Map<String, dynamic>> pendingWinners;

  const MatchModel({
    required this.id,
    required this.matchName,
    required this.team1,
    required this.team2,
    required this.team1Logo,
    required this.team2Logo,
    required this.date,
    required this.time,
    required this.timePeriod,
    required this.prizePositions,
    required this.matchStatus,
    required this.enabled,
    required this.createdAt,
    required this.kickoffAt,
    required this.predictionClosesAt,
    required this.team1Goals,
    required this.team2Goals,
    required this.resultSaved,
    required this.winnersLocked,
    required this.pendingWinners,
  });

  /// Safely reads a numeric field as an [int], regardless of whether
  /// Firestore actually stored it as an int or a double.
  ///
  /// Root cause of the "red error screen right after submitting a
  /// prediction": this used to be `data['team1Goals'] as int?`. Any backend
  /// or admin tool that writes scores as a JS/num value (e.g. `2.0`) stores
  /// it in Firestore as a double. The moment that match document is
  /// re-emitted on the `watchMatches()` stream (which happens live, and can
  /// coincide with a customer just having submitted a prediction for that
  /// match), that direct cast throws a real `TypeError` — synchronously,
  /// inside the SliverList/SliverGrid item builder — which breaks the whole
  /// matches list and forces a reload. Parsing through `num` first and
  /// converting makes this immune to either representation.
  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    try {
      return _fromFirestoreUnsafe(doc);
    } catch (e, st) {
      // Last-resort safety net: never let a malformed/unexpected Firestore
      // document crash the predictions list. Fall back to a disabled
      // placeholder match instead of throwing, so one bad document can never
      // take down the whole page.
      debugPrint('MatchModel.fromFirestore failed for ${doc.id}: $e\n$st');
      return MatchModel(
        id: doc.id,
        matchName: 'Match unavailable',
        team1: 'Team One',
        team2: 'Team Two',
        team1Logo: '',
        team2Logo: '',
        date: '',
        time: '',
        timePeriod: 'PM',
        prizePositions: const [],
        matchStatus: 'Disabled',
        enabled: false,
        createdAt: null,
        kickoffAt: null,
        predictionClosesAt: null,
        team1Goals: null,
        team2Goals: null,
        resultSaved: false,
        winnersLocked: false,
        pendingWinners: const [],
      );
    }
  }

  static MatchModel _fromFirestoreUnsafe(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final team1 = data['team1']?.toString() ?? 'Team One';
    final team2 = data['team2']?.toString() ?? 'Team Two';

    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    }
    DateTime? kickoff;
    if (data['kickoffAt'] is Timestamp) {
      kickoff = (data['kickoffAt'] as Timestamp).toDate();
    }
    DateTime? closes;
    if (data['predictionClosesAt'] is Timestamp) {
      closes = (data['predictionClosesAt'] as Timestamp).toDate();
    }

    List<PrizePosition> prizes = [];
    if (data['prizePositions'] is List) {
      prizes = (data['prizePositions'] as List)
          .map(
              (e) => PrizePosition.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    }

    String status = data['matchStatus']?.toString() ?? 'Upcoming';
    if (!['Upcoming', 'Live', 'Finished', 'Disabled'].contains(status)) {
      status = 'Upcoming';
    }

    List<Map<String, dynamic>> pending = [];
    if (data['pendingWinners'] is List) {
      pending = (data['pendingWinners'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return MatchModel(
      id: doc.id,
      matchName: data['matchName']?.toString() ?? '$team1 VS $team2',
      team1: team1,
      team2: team2,
      team1Logo: data['team1Logo']?.toString() ?? '',
      team2Logo: data['team2Logo']?.toString() ?? '',
      date: data['date']?.toString() ?? '',
      time: data['time']?.toString() ?? '',
      timePeriod: data['timePeriod']?.toString() ?? 'PM',
      prizePositions: prizes,
      matchStatus: status,
      enabled: data['enabled'] != false && status != 'Disabled',
      createdAt: created,
      kickoffAt: kickoff,
      predictionClosesAt: closes,
      team1Goals: _asInt(data['team1Goals']),
      team2Goals: _asInt(data['team2Goals']),
      resultSaved: data['resultSaved'] == true,
      winnersLocked: data['winnersLocked'] == true,
      pendingWinners: pending,
    );
  }

  bool isPredictionClosed(DateTime serverNow) {
    if (!enabled) return true;
    if (matchStatus == 'Disabled' ||
        matchStatus == 'Live' ||
        matchStatus == 'Finished') {
      return true;
    }
    if (predictionClosesAt != null &&
        !serverNow.isBefore(predictionClosesAt!)) {
      return true;
    }
    if (kickoffAt != null && !serverNow.isBefore(kickoffAt!)) return true;
    return false;
  }

  String predictionStatus(DateTime serverNow) {
    if (!enabled || matchStatus == 'Disabled') return 'Disabled';
    if (isPredictionClosed(serverNow)) {
      if (matchStatus == 'Live') return 'Live';
      if (matchStatus == 'Finished') return 'Finished';
      return 'Closed';
    }
    return 'Open';
  }

  Duration? remainingUntilClose(DateTime serverNow) {
    final target = predictionClosesAt ?? kickoffAt;
    if (target == null) return null;
    final diff = target.difference(serverNow);
    return diff.isNegative ? Duration.zero : diff;
  }
}
