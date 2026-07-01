import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'server_time_service.dart';

class MatchService {
  static final _db = FirebaseFirestore.instance;

  // Sentinel values returned by the fingerprint/device helpers when a real,
  // stable identifier could not be derived (e.g. native mobile builds that
  // don't yet ship a hardware-backed identifier plugin, or a browser API
  // failure). These must NEVER be used as anti-duplicate lock keys because
  // they are identical for every user on that platform — locking against
  // them would either do nothing (if simply skipped, current behaviour) or,
  // worse, block every future legitimate user after the first one. Keeping
  // this as an explicit, named set makes the intent obvious at every call
  // site instead of repeating string comparisons.
  static const Set<String> _nonUniqueIdentifiers = {
    'mobile_device',
    'mobile_device_id_fallback',
    'web_device_id_fallback',
    'web_fingerprint_fallback',
  };

  static Stream<QuerySnapshot> watchMatches() {
    return _db.collection('matches').snapshots();
  }

  // ── Normalization helpers ──────────────────────────────────
  // Centralised here so every place that stores or compares phone numbers,
  // scores or team names goes through exactly one code path. Predictions are
  // matched against the saved match result elsewhere in the system (admin /
  // backend); any drift between how a value is normalized at write-time vs
  // read-time is what causes "no correct predictions found" style bugs, so
  // these helpers are intentionally simple, deterministic and reused
  // everywhere (submitPrediction, hasPredicted, ClaimService, etc).

  static const _arabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩'
  ];
  static const _persianDigits = [
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹'
  ];
  static const _englishDigits = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9'
  ];

  static String _toEnglishDigits(String s) {
    String clean = s;
    for (int i = 0; i < 10; i++) {
      clean = clean.replaceAll(_arabicDigits[i], _englishDigits[i]);
      clean = clean.replaceAll(_persianDigits[i], _englishDigits[i]);
    }
    return clean;
  }

  static String normalizePhone(String s) {
    return _toEnglishDigits(s.trim());
  }

  /// Strips formatting characters (spaces, dashes, parentheses) so the same
  /// phone number always maps to the same Firestore document id, no matter
  /// how the user typed it.
  static String cleanPhone(String s) {
    return normalizePhone(s).replaceAll(RegExp(r'[\s\-()]'), '');
  }

  static String normalizeScore(String s) {
    String clean = _toEnglishDigits(s.trim());
    clean = clean.replaceAll(RegExp(r'\s+'), '');
    // NOTE: the dash MUST come first (or be escaped) inside the character
    // class below. The previous version used `[:-–—]`, which Dart's regex
    // engine parses as a *range* from ':' (U+003A) all the way to '–'
    // (U+2013) — silently swallowing every uppercase/lowercase letter and a
    // pile of punctuation in between. Putting `\-` first/escaped makes every
    // character a literal, matching only the intended separators.
    clean = clean.replaceAll(RegExp(r'[\-:–—−]'), '-');
    return clean.toLowerCase();
  }

  /// Normalizes a team name for *comparison* purposes only (collapse
  /// whitespace, trim, lowercase). The original, human-readable casing is
  /// always what gets stored/displayed — this is only used to validate that
  /// a submitted prediction actually refers to one of the two real teams.
  static String _normalizeTeamForCompare(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static String getBrowserFingerprint() {
    if (!kIsWeb) return 'mobile_device';
    try {
      final userAgent = html.window.navigator.userAgent;
      final language = html.window.navigator.language;
      final screenWidth = html.window.screen?.width ?? 0;
      final screenHeight = html.window.screen?.height ?? 0;
      final platform = html.window.navigator.platform ?? '';
      final memory = html.window.navigator.deviceMemory ?? 0;
      final cores = html.window.navigator.hardwareConcurrency ?? 0;
      return '${userAgent}_${language}_${screenWidth}x${screenHeight}_${platform}_${memory}_$cores';
    } catch (_) {
      return 'web_fingerprint_fallback';
    }
  }

  static String getLocalDeviceId() {
    if (!kIsWeb) return 'mobile_device_id_fallback';
    try {
      var id = html.window.localStorage['local_device_id'];
      if (id == null || id.isEmpty) {
        id = 'dev_${DateTime.now().microsecondsSinceEpoch}_${_randomString(8)}';
        html.window.localStorage['local_device_id'] = id;
      }
      return id;
    } catch (_) {
      return 'web_device_id_fallback';
    }
  }

  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = math.Random();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  /// Firestore-safe document id (letters/digits/underscore only).
  static String _safeKey(String value) =>
      value.replaceAll(RegExp(r'[^\w]'), '_');

  static String _safePhone(String phone) => _safeKey(phone);

  static Future<bool> hasPredicted(String matchId, String phone) async {
    final safePhone = _safePhone(cleanPhone(phone));
    final doc = await _db
        .collection('matches')
        .doc(matchId)
        .collection('predictions')
        .doc(safePhone)
        .get();
    return doc.exists;
  }

  static Future<String?> submitPrediction({
    required String matchId,
    required String phone,
    required String winningTeam,
    required String predictedScore,
  }) async {
    try {
      await ServerTimeService.syncIfStale();

      final normalizedPhone = normalizePhone(phone);
      if (normalizedPhone.isEmpty) return 'Please enter your phone number.';

      final phoneDigits = cleanPhone(phone);
      if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(phoneDigits)) {
        return 'Please enter a valid phone number (8-15 digits, e.g. 01012345678).';
      }

      final score = normalizeScore(predictedScore);
      if (score.isEmpty) return 'Please enter your predicted score (e.g. 3-1).';
      if (!RegExp(r'^\d+-\d+$').hasMatch(score)) {
        return 'Score format should be like 3-1 or 2-0.';
      }

      final team = winningTeam.trim();
      if (team.isEmpty) return 'Please select the winning team.';

      final matchRef = _db.collection('matches').doc(matchId);
      final matchDoc = await matchRef.get();
      if (!matchDoc.exists) return 'Match not found.';
      final matchData = matchDoc.data()!;

      // Validate the chosen team actually belongs to this match. This keeps
      // the data clean for whatever downstream logic (admin / backend)
      // calculates winners — a stray/garbled team name can never silently
      // fail to match team1/team2 later.
      final team1 = matchData['team1']?.toString() ?? '';
      final team2 = matchData['team2']?.toString() ?? '';
      final teamNorm = _normalizeTeamForCompare(team);
      String canonicalTeam;
      if (teamNorm == _normalizeTeamForCompare(team1)) {
        canonicalTeam = team1;
      } else if (teamNorm == _normalizeTeamForCompare(team2)) {
        canonicalTeam = team2;
      } else {
        return 'Please choose a valid team for this match.';
      }

      final closesAt = matchData['predictionClosesAt'];
      if (closesAt is Timestamp) {
        await ServerTimeService.sync();
        if (!ServerTimeService.now.isBefore(closesAt.toDate())) {
          return 'Predictions are closed for this match.';
        }
      }
      final status = matchData['matchStatus']?.toString() ?? 'Upcoming';
      if (matchData['enabled'] == false ||
          status == 'Disabled' ||
          status == 'Live' ||
          status == 'Finished') {
        return 'Predictions are closed for this match.';
      }

      // Fast client-side short-circuit (cheap UX win, NOT a security
      // boundary — it can be cleared by the user). The authoritative check
      // happens server-side inside the Firestore transaction below.
      if (kIsWeb) {
        try {
          if (html.window.localStorage['pred_sub_$matchId'] == 'true') {
            return 'You have already submitted a prediction for this match on this device.';
          }
        } catch (_) {}
      }

      final deviceId = getLocalDeviceId();
      final fingerprint = getBrowserFingerprint();
      final deviceIsUnique = !_nonUniqueIdentifiers.contains(deviceId);
      final fingerprintIsUnique = !_nonUniqueIdentifiers.contains(fingerprint);

      final safePhone = _safePhone(phoneDigits);
      final predRef = matchRef.collection('predictions').doc(safePhone);
      final deviceLockRef = deviceIsUnique
          ? matchRef.collection('deviceLocks').doc(_safeKey(deviceId))
          : null;
      final fingerprintLockRef = fingerprintIsUnique
          ? matchRef.collection('fingerprintLocks').doc(_safeKey(fingerprint))
          : null;

      String? failureReason;

      // All reads + the existence checks + the writes happen inside a single
      // Firestore transaction. This is the part that actually enforces "one
      // prediction per device per match AND one per phone per match" against
      // the server — two simultaneous submissions (e.g. a double-tap, or two
      // tabs) can no longer both slip through the way they could with the old
      // sequential get()-then-where()-then-set() approach, which had a race
      // window between the duplicate check and the write.
      try {
        await _db.runTransaction((tx) async {
          final predSnap = await tx.get(predRef);
          if (predSnap.exists) {
            failureReason =
                'This phone number already submitted a prediction for this match.';
            return;
          }

          if (deviceLockRef != null) {
            final deviceSnap = await tx.get(deviceLockRef);
            if (deviceSnap.exists) {
              failureReason =
                  'This device has already submitted a prediction for this match.';
              return;
            }
          }

          if (fingerprintLockRef != null) {
            final fpSnap = await tx.get(fingerprintLockRef);
            if (fpSnap.exists) {
              failureReason =
                  'This browser has already submitted a prediction for this match.';
              return;
            }
          }

          tx.set(predRef, {
            'phoneNumber': phoneDigits,
            'matchId': matchId,
            'winningTeam': canonicalTeam,
            'predictedScore': score,
            'deviceId': deviceId,
            'fingerprint': fingerprint,
            'timestamp': FieldValue.serverTimestamp(),
          });

          if (deviceLockRef != null) {
            tx.set(deviceLockRef, {
              'phoneNumber': phoneDigits,
              'predictionRef': predRef.path,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
          if (fingerprintLockRef != null) {
            tx.set(fingerprintLockRef, {
              'phoneNumber': phoneDigits,
              'predictionRef': predRef.path,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        });
      } catch (e) {
        return 'Could not save your prediction. Please try again.';
      }

      if (failureReason != null) return failureReason;

      // Best-effort local flag — failures here must never affect the
      // already-successful save, so they are swallowed.
      if (kIsWeb) {
        try {
          html.window.localStorage['pred_sub_$matchId'] = 'true';
        } catch (_) {}
      }

      return null;
    } catch (e) {
      // Final safety net: the prediction may or may not have been written
      // depending on where this was thrown, but either way we must never let
      // an exception escape uncaught into the caller's widget tree.
      return 'Could not save your prediction. Please try again.';
    }
  }
}

class ClaimService {
  static final _db = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>?> verifyClaim({
    required String phone,
    required String code,
  }) async {
    try {
      final cleanPhone = MatchService.cleanPhone(phone);
      final cleanCode = code.trim().toUpperCase();
      if (cleanPhone.isEmpty || cleanCode.isEmpty) return null;
      final snap = await _db
          .collection('winners')
          .where('phoneNumber', isEqualTo: cleanPhone)
          .where('winnerCode', isEqualTo: cleanCode)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = Map<String, dynamic>.from(snap.docs.first.data());
      data['_docPath'] = snap.docs.first.reference.path;
      return data;
    } catch (e) {
      return null;
    }
  }

  /// Marks a prize as redeemed. Uses a transaction so two staff members
  /// tapping "redeem" on the same code at the same moment can't both
  /// succeed.
  static Future<bool> markRedeemed(String phone, String code) async {
    try {
      final cleanPhone = MatchService.cleanPhone(phone);
      final cleanCode = code.trim().toUpperCase();
      final snap = await _db
          .collection('winners')
          .where('phoneNumber', isEqualTo: cleanPhone)
          .where('winnerCode', isEqualTo: cleanCode)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return false;
      return markRedeemedByPath(snap.docs.first.reference.path);
    } catch (e) {
      return false;
    }
  }

  /// Same as [markRedeemed] but operates directly on a known Firestore
  /// document path (used when the doc was already fetched, e.g. by
  /// PrizeRedemptionService after a coupon was applied at checkout).
  /// Transaction-guarded to prevent double-spending a discount/free item.
  static Future<bool> markRedeemedByPath(String docPath) async {
    try {
      final ref = _db.doc(docPath);
      return _db.runTransaction<bool>((tx) async {
        final fresh = await tx.get(ref);
        if (!fresh.exists) return false;
        if (fresh.data()?['redeemed'] == true) return false;
        tx.update(ref, {
          'redeemed': true,
          'redeemedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      return false;
    }
  }
}
