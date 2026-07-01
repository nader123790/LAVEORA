import 'package:cloud_firestore/cloud_firestore.dart';

class ServerTimeService {
  static Duration _offset = Duration.zero;
  static DateTime? _lastSync;

  // All countdowns / "is prediction closed" / winner-ordering decisions must
  // be based on this clock, never on raw DateTime.now() from the device,
  // since a user can trivially change their local clock.
  static DateTime get now => DateTime.now().add(_offset);

  static Future<void> sync() async {
    try {
      final requestStart = DateTime.now();
      final ref = FirebaseFirestore.instance.collection('_server').doc('time');
      await ref.set({'t': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      final snap = await ref.get(const GetOptions(source: Source.server));
      final ts = snap.data()?['t'];
      if (ts is Timestamp) {
        // Compensate for round-trip network latency by comparing the server
        // timestamp against the midpoint of the request, rather than the
        // time the response happened to arrive back. This keeps the offset
        // accurate even on a slow connection.
        final requestEnd = DateTime.now();
        final roundTrip = requestEnd.difference(requestStart);
        final midpoint = requestStart.add(roundTrip ~/ 2);
        _offset = ts.toDate().difference(midpoint);
        _lastSync = DateTime.now();
      }
    } catch (_) {}
  }

  static Future<void> syncIfStale() async {
    if (_lastSync == null || DateTime.now().difference(_lastSync!) > const Duration(minutes: 2)) {
      await sync();
    }
  }
}
