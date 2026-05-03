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

// ← غيّر ده بالـ URL بتاع Vercel بعد الـ deploy
const String _baseUrl = 'https://onesignal-server-naders-projects-748217a7.vercel.app';

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

  Map<String, String> get _publicHeaders => {'Content-Type': 'application/json'};

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
