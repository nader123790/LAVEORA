// lib/api_service.dart
// ============================================================
// LAVEORA — Security Contract:
//   - NO Telegram BOT_TOKEN or chat ID in this file
//   - NO hardcoded passwords
//   - JWT stored in memory only
//   - ALL writes go through backend API
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String _baseUrl = 'https://onesignal-server-nine.vercel.app';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  String? _token;

  bool get isAuthenticated => _token != null;

  Map<String, String> get _publicHeaders =>
      {'Content-Type': 'application/json'};

  Map<String, String> get _authHeaders {
    if (_token == null) throw const ApiException(401, 'Not authenticated.');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Map<String, dynamic> _parse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException(response.statusCode, 'Invalid response format');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = (decoded['error'] as String?) ?? 'Unknown error';
        throw ApiException(response.statusCode, message);
      }
      return decoded;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(response.statusCode, 'Server error: ${response.body}');
    }
  }

  // ── Auth ──────────────────────────────────────────────────

  /// تسجيل دخول الويتر — الباك اند هو اللي بيتحقق من الباسورد
  Future<bool> loginWaiter(String password) async {
    try {
      final response = await http.post(
        _uri('/api/auth/waiter'),
        headers: _publicHeaders,
        body: jsonEncode({'password': password}),
      );
      final data = _parse(response);
      _token = data['token'] as String;
      return true;
    } catch (e) {
      debugPrint('[ApiService] loginWaiter error: $e');
      return false;
    }
  }

  void logout() => _token = null;

  // ── Orders ────────────────────────────────────────────────

  /// إنشاء أوردر جديد من العميل أو الويتر
  Future<String?> createOrder({
    required String customerName,
    required String tableNumber,
    required List<Map<String, dynamic>> itemsWithQty,
    required double totalPrice,
    String note = 'بدون إضافات',
    String orderType = 'داخل المكان',
    String source = 'customer',
    // Full breakdown of any prize/discount used on this order (winner
    // code, discount %/amount, subtotal before/after, free item name,
    // etc.) — see MainCafeState._prizeInfoForOrder. Sent as-is so the
    // backend/admin panel can persist and display it alongside the order.
    // NOTE: your backend's /api/orders handler needs to accept and store
    // this 'prize_info' field for it to actually show up wherever you
    // read orders from (Firestore / admin site) — if it currently drops
    // unknown fields, this key will be silently ignored until that's
    // updated on the backend side.
    Map<String, dynamic>? prizeInfo,
    // Extra, order-level pricing/metadata fields requested for the
    // full order-summary feature (customer summary, Telegram, admin
    // card, Firestore). All optional so existing callers (e.g. the
    // waiter/barista flow, which has no reward concept) keep working
    // unchanged. Same NOTE as above applies: the backend must persist
    // unknown top-level fields for these to actually be readable later.
    String? customerPhone,
    String? orderNumber,
    double? originalTotal,
    String? rewardType,
    String? rewardDescription,
    double? discountAmount,
    double? freeItemValue,
    String? winnerCode,
    double? deliveryFee,
    double? grandTotal,
    String? paymentMethod,
    String? clientOrderTime,
    // Explicit, unambiguous "was a reward used on this order" flag. Sent
    // alongside the other reward_* fields so any consumer of the order
    // document (Telegram formatter, admin panel, future reporting) can
    // answer "did the customer use a reward?" with a single boolean read
    // instead of having to infer it from whether reward_type happens to be
    // non-null.
    bool? rewardApplied,
  }) async {
    try {
      final response = await http.post(
        _uri('/api/orders'),
        headers: _publicHeaders,
        body: jsonEncode({
          'customer_name': customerName,
          'table_number': tableNumber,
          'items_with_qty': itemsWithQty,
          'total': totalPrice,
          'note': note,
          'order_type': orderType,
          'source': source,
          if (prizeInfo != null) 'prize_info': prizeInfo,
          if (customerPhone != null && customerPhone.isNotEmpty)
            'customer_phone': customerPhone,
          if (orderNumber != null) 'order_number': orderNumber,
          if (originalTotal != null) 'original_total': originalTotal,
          if (rewardType != null) 'reward_type': rewardType,
          if (rewardDescription != null)
            'reward_description': rewardDescription,
          if (discountAmount != null) 'discount_amount': discountAmount,
          if (freeItemValue != null) 'free_item_value': freeItemValue,
          if (winnerCode != null) 'winner_code': winnerCode,
          if (deliveryFee != null) 'delivery_fee': deliveryFee,
          if (grandTotal != null) 'grand_total': grandTotal,
          if (paymentMethod != null) 'payment_method': paymentMethod,
          if (clientOrderTime != null) 'client_order_time': clientOrderTime,
          if (rewardApplied != null) 'reward_applied': rewardApplied,
        }),
      );
      final data = _parse(response);
      return data['id'] as String;
    } catch (e) {
      debugPrint('[ApiService] createOrder error: $e');
      return null;
    }
  }

  /// تحديث حالة الأوردر — يحتاج JWT
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await http.put(
        _uri('/api/orders/$orderId'),
        headers: _authHeaders,
        body: jsonEncode({'status': status}),
      );
      _parse(response);
      return true;
    } catch (e) {
      debugPrint('[ApiService] updateOrderStatus error: $e');
      return false;
    }
  }

  // ── Alerts ────────────────────────────────────────────────

  /// نداء الويتر من العميل
  Future<void> callWaiter({
    required String customerName,
    required String tableNumber,
  }) async {
    try {
      final response = await http.post(
        _uri('/api/orders/alerts'),
        headers: _publicHeaders,
        body: jsonEncode({
          'customer_name': customerName,
          'table_number': tableNumber,
        }),
      );
      _parse(response);
    } catch (e) {
      debugPrint('[ApiService] callWaiter error: $e');
    }
  }

  // ── Telegram ──────────────────────────────────────────────

  /// إرسال رسالة تليجرام — التوكن على السيرفر بس
  Future<void> sendTelegramMessage(String message) async {
    try {
      final response = await http.post(
        _uri('/api/telegram'),
        headers: _publicHeaders,
        body: jsonEncode({'message': message}),
      );
      _parse(response);
    } catch (e) {
      debugPrint('[ApiService] sendTelegramMessage error: $e');
    }
  }
}

/// Singleton — استخدمه في كل الـ app
final ApiService apiService = ApiService();
