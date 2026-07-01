import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

import '../models/active_prize.dart';
import 'match_service.dart';

/// Holds the single "active" verified-but-not-yet-redeemed prize for this
/// browser/session, and is responsible for marking it redeemed in Firestore
/// (transaction-guarded) exactly once an order is actually placed with it,
/// so the same Winner Code can never be used twice — even across reloads,
/// since the active prize is mirrored into localStorage on web.
class PrizeRedemptionService {
  static ActivePrize? _active;
  static const _storageKey = 'laveora_active_prize_v1';

  static ActivePrize? get active {
    if (_active != null) return _active;
    if (kIsWeb) {
      try {
        final raw = html.window.localStorage[_storageKey];
        if (raw != null && raw.isNotEmpty) {
          _active = ActivePrize.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
        }
      } catch (_) {}
    }
    return _active;
  }

  static void activate(ActivePrize prize) {
    _active = prize;
    if (kIsWeb) {
      try {
        html.window.localStorage[_storageKey] = jsonEncode(prize.toJson());
      } catch (_) {}
    }
  }

  static void clear() {
    _active = null;
    if (kIsWeb) {
      try {
        html.window.localStorage.remove(_storageKey);
      } catch (_) {}
    }
  }

  /// Computes the discount (in currency units) a Discount-type prize should
  /// take off the given subtotal. Returns 0 for non-discount prizes.
  static double discountFor(double subtotal) {
    final prize = active;
    if (prize == null || !prize.isDiscount) return 0;
    double discount = 0;
    if (prize.discountPercent != null) {
      discount = subtotal * (prize.discountPercent!.toDouble() / 100);
    } else if (prize.discountAmount != null) {
      discount = prize.discountAmount!.toDouble();
    }
    if (discount < 0) discount = 0;
    if (discount > subtotal) discount = subtotal;
    return discount;
  }

  /// Marks the active prize as redeemed server-side (transaction-guarded
  /// against double use) and clears local state. Call this once, right
  /// after the order that used the prize has been successfully created.
  /// Returns false (and leaves the prize active) if it could not be marked,
  /// e.g. because it was already redeemed elsewhere in the meantime.
  static Future<bool> markRedeemed() async {
    final prize = active;
    if (prize == null) return false;
    final ok = await ClaimService.markRedeemedByPath(prize.docPath);
    if (ok) clear();
    return ok;
  }
}
