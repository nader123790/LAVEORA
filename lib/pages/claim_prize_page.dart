import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../models/prize_position.dart';
import '../models/active_prize.dart';
import '../services/match_service.dart';
import '../services/prize_redemption_service.dart';

class ClaimPrizePage extends StatefulWidget {
  const ClaimPrizePage({super.key});

  @override
  State<ClaimPrizePage> createState() => _ClaimPrizePageState();
}

class _ClaimPrizePageState extends State<ClaimPrizePage>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  late AnimationController _fadeCtrl;
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim().toUpperCase();
    if (phone.isEmpty || code.isEmpty) {
      setState(() => _error = 'Enter phone number and winner code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final data = await ClaimService.verifyClaim(phone: phone, code: code);
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _loading = false;
          _error = 'Invalid phone number or winner code.';
        });
        return;
      }
      setState(() {
        _loading = false;
        _result = data;
      });
      if (data['redeemed'] != true && data['_docPath'] is String) {
        // Activate this prize so it can be auto-applied at checkout
        // (discount / buy-x-get-y / free item) and to prevent it being
        // redeemed twice.
        PrizeRedemptionService.activate(
          ActivePrize.fromMap(data, data['_docPath'] as String, phone),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not verify your code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 500;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF050E1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF050E1A),
          title: const Text('Claim Prize',
              style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FadeTransition(
          opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 32 : 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('🏆',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    const Text(
                      'Claim Your Prize',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your phone number and winner code to verify your prize.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white54, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('Phone Number', Icons.phone),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _codeCtrl,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      decoration: _dec('Winner Code (e.g. WC-8FQ21A)',
                          Icons.confirmation_number),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00843D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Verify Prize',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                    if (_result != null) _resultCard(_result!),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> data) {
    final redeemed = data['redeemed'] == true;
    final pos = (data['position'] as num?)?.toInt() ?? 1;
    final medal = PrizePosition(
      position: pos,
      prizeType: data['prizeType']?.toString() ?? '',
      prizeDescription: data['prizeDescription']?.toString() ?? '',
    ).medal;

    if (redeemed) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
        ),
        child: const Column(
          children: [
            Icon(Icons.info_outline, color: Colors.orangeAccent, size: 40),
            SizedBox(height: 12),
            Text(
              'This prize has already been redeemed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ],
        ),
      );
    }

    String submitted = '—';
    if (data['submissionTimestamp'] is Timestamp) {
      submitted = intl.DateFormat('yyyy-MM-dd HH:mm')
          .format((data['submissionTimestamp'] as Timestamp).toDate());
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00843D).withValues(alpha: 0.15),
            const Color(0xFF0D1B2A),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(medal, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('Position $pos',
              style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          const SizedBox(height: 16),
          _row('Prize Type', data['prizeType']?.toString() ?? ''),
          _row('Prize', data['prizeDescription']?.toString() ?? ''),
          _row('Winner Code', data['winnerCode']?.toString() ?? '',
              highlight: true),
          _row('Claim Status', 'Valid — Not Redeemed'),
          _row('Submitted', submitted),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00843D).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _prizeUsageMessage(ActivePrize.fromMap(
                  data, data['_docPath']?.toString() ?? '', _phoneCtrl.text)),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Show this screen to staff to collect your prize.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _prizeUsageMessage(ActivePrize prize) {
    if (prize.isDiscount) {
      return 'Your discount has been applied — it will show automatically on the checkout screen.';
    }
    if (prize.isBuyXGetY) {
      return 'Add the required item(s) to your cart, then your free item "${prize.freeItemName ?? ''}" will be added automatically at checkout.';
    }
    if (prize.isFreeItem) {
      return 'Your free item "${prize.freeItemName ?? prize.prizeDescription}" will be added to your cart automatically at checkout.';
    }
    return 'Your prize is ready — return to the menu and continue to checkout.';
  }

  Widget _row(String label, String value, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12))),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: highlight ? const Color(0xFFFFD700) : Colors.white,
                  fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                  fontSize: highlight ? 16 : 13,
                ),
              ),
            ),
          ],
        ),
      );

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      );
}
