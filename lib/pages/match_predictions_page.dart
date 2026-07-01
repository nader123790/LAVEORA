import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'dart:html' as html;

import '../models/match_model.dart';
import '../services/match_service.dart';
import '../services/server_time_service.dart';

class WcTheme {
  static const Color green = Color(0xFF00843D);
  static const Color gold = Color(0xFFFFD700);
  static const Color blue = Color(0xFF023E8A);
  static const Color bg = Color(0xFF050E1A);
  static const Color card = Color(0xFF0D1B2A);
}

class MatchPredictionsPage extends StatefulWidget {
  const MatchPredictionsPage({super.key});

  @override
  State<MatchPredictionsPage> createState() => _MatchPredictionsPageState();
}

class _MatchPredictionsPageState extends State<MatchPredictionsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterController;
  final _phoneCtrl = TextEditingController();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    ServerTimeService.sync();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      ServerTimeService.syncIfStale();
      if (mounted) setState(() {});
    });
    if (kIsWeb) {
      final saved = html.window.localStorage['prediction_phone'];
      if (saved != null && saved.isNotEmpty) _phoneCtrl.text = saved;
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    _phoneCtrl.dispose();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _submit(
    BuildContext dlgCtx,
    MatchModel match,
    String phone,
    String team,
    String score,
  ) async {
    if (kIsWeb && phone.trim().isNotEmpty) {
      try {
        html.window.localStorage['prediction_phone'] = phone.trim();
      } catch (_) {}
    }

    // Capture the ScaffoldMessenger BEFORE the async gap. Resolving it
    // afterwards (once the dialog has already been popped / the tree has
    // changed) is what was throwing an uncaught "look up a deactivated
    // widget's ancestor" exception and surfacing as the red error screen,
    // even though the prediction itself had already been written
    // successfully to Firestore. The lookup itself is also guarded, since
    // even resolving it can fail if the tree changed unexpectedly.
    ScaffoldMessengerState? messenger;
    try {
      messenger = ScaffoldMessenger.of(context);
    } catch (_) {
      messenger = null;
    }

    String? err;
    try {
      err = await MatchService.submitPrediction(
        matchId: match.id,
        phone: phone,
        winningTeam: team,
        predictedScore: score,
      );
    } catch (e, st) {
      // Any unexpected error (network blip, malformed Firestore response,
      // etc.) must never escape this function uncaught - that is exactly
      // what produces Flutter's red error screen. Convert it into a normal
      // user-facing message instead.
      debugPrint('submitPrediction failed: $e\n$st');
      err = 'Could not save your prediction. Please try again.';
    }

    if (!mounted) return;

    // Everything from here on is pure UI feedback (closing the dialog /
    // showing a snackbar). The Firestore write has already either
    // succeeded or failed by this point, so a failure in this UI cleanup
    // code (e.g. the dialog context having already been torn down) must
    // NEVER be allowed to crash the app and show the red error screen —
    // especially not after a successful save.
    try {
      if (err != null) {
        messenger?.showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.orangeAccent),
        );
        return;
      }

      // Success path: close the dialog first (guarded), then confirm on
      // the page itself using the messenger captured before the async gap.
      if (dlgCtx.mounted) {
        Navigator.of(dlgCtx).pop();
      }
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Prediction saved successfully! Good luck.'),
          backgroundColor: WcTheme.green,
        ),
      );

      // Per request: after a successful submission, take the customer back
      // to the home page instead of leaving them on the matches list.
      // A short delay lets them actually see the confirmation snackbar
      // before the page navigates away.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    } catch (e, st) {
      debugPrint(
          'Post-submit UI update failed (prediction was still saved): $e\n$st');
    }
  }

  void _openPredict(MatchModel match) {
    String phone = _phoneCtrl.text;
    String? team;
    final scoreCtrl = TextEditingController();
    bool loading = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'predict',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return Transform.scale(
          scale: 0.92 + 0.08 * curve.value,
          child: Opacity(
            opacity: curve.value,
            child: StatefulBuilder(
              builder: (ctx, setDlg) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        color: WcTheme.card.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: WcTheme.gold.withValues(alpha: 0.35)),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(match.matchName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: WcTheme.gold,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                )),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _phoneCtrl,
                              onChanged: (v) => setDlg(() => phone = v),
                              keyboardType: TextInputType.phone,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                              decoration:
                                  _inputDeco('Phone Number', Icons.phone),
                            ),
                            const SizedBox(height: 6),
                            const Text('One prediction per phone per match',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                            const SizedBox(height: 20),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Text('Winning Team',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 10),
                            _teamBtn(match.team1, match.team1Logo, team,
                                (v) => setDlg(() => team = v)),
                            const SizedBox(height: 8),
                            _teamBtn(match.team2, match.team2Logo, team,
                                (v) => setDlg(() => team = v)),
                            const SizedBox(height: 18),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Text('Correct Score',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: scoreCtrl,
                              onChanged: (_) => setDlg(() {}),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                              decoration:
                                  _inputDeco('e.g. 3-1', Icons.sports_score),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: loading
                                        ? null
                                        : () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: WcTheme.gold,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    onPressed: team == null ||
                                            scoreCtrl.text.trim().isEmpty ||
                                            phone.trim().isEmpty ||
                                            loading
                                        ? null
                                        : () async {
                                            setDlg(() => loading = true);
                                            try {
                                              await _submit(ctx, match, phone,
                                                  team!, scoreCtrl.text);
                                            } finally {
                                              if (ctx.mounted) {
                                                setDlg(() => loading = false);
                                              }
                                            }
                                          },
                                    child: loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.black,
                                            ),
                                          )
                                        : const Text('Submit',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) => scoreCtrl.dispose());
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: WcTheme.gold, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      );

  Widget _teamBtn(
      String name, String logo, String? sel, void Function(String) onTap) {
    final active = sel == name;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(name),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? WcTheme.green.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? WcTheme.green : Colors.white12,
                width: active ? 2 : 1),
          ),
          child: Row(
            children: [
              _logo(logo, 36),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: active ? Colors.white : Colors.white70))),
              if (active)
                const Icon(Icons.check_circle, color: WcTheme.green, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo(String url, double size) {
    if (url.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white10,
        child: const Icon(Icons.sports_soccer, color: WcTheme.gold, size: 18),
      );
    }
    return ClipOval(
      child: Image.network(url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
                radius: size / 2,
                child: const Icon(Icons.flag, size: 18),
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 720;
    final serverNow = ServerTimeService.now;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: WcTheme.bg,
        body: FadeTransition(
          opacity:
              CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: wide ? 180 : 150,
                pinned: true,
                backgroundColor: WcTheme.bg,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: WcTheme.gold),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: const Text(
                    '⚽ Match Predictions',
                    style: TextStyle(
                        color: WcTheme.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 18),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          WcTheme.green.withValues(alpha: 0.3),
                          WcTheme.bg
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                    horizontal: wide ? 32 : 16, vertical: 8),
                sliver: StreamBuilder<QuerySnapshot>(
                  stream: MatchService.watchMatches(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: WcTheme.gold)),
                        ),
                      );
                    }
                    final docs =
                        List<QueryDocumentSnapshot>.from(snap.data!.docs)
                          ..sort((a, b) {
                            final aD = a.data() as Map<String, dynamic>;
                            final bD = b.data() as Map<String, dynamic>;
                            final aTs = aD['kickoffAt'] is Timestamp
                                ? (aD['kickoffAt'] as Timestamp).toDate()
                                : DateTime.fromMillisecondsSinceEpoch(
                                    9999999999999);
                            final bTs = bD['kickoffAt'] is Timestamp
                                ? (bD['kickoffAt'] as Timestamp).toDate()
                                : DateTime.fromMillisecondsSinceEpoch(
                                    9999999999999);
                            return aTs.compareTo(bTs);
                          });

                    if (docs.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(64),
                          child: Center(
                            child: Text('No matches available',
                                style: TextStyle(color: Colors.white38)),
                          ),
                        ),
                      );
                    }

                    if (wide) {
                      return SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 520,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (c, i) => _MatchCard(
                            match: MatchModel.fromFirestore(docs[i]),
                            serverNow: serverNow,
                            onPredict: _openPredict,
                            logo: _logo,
                          ),
                          childCount: docs.length,
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (c, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _MatchCard(
                            match: MatchModel.fromFirestore(docs[i]),
                            serverNow: serverNow,
                            onPredict: _openPredict,
                            logo: _logo,
                          ),
                        ),
                        childCount: docs.length,
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchModel match;
  final DateTime serverNow;
  final void Function(MatchModel) onPredict;
  final Widget Function(String, double) logo;

  const _MatchCard({
    required this.match,
    required this.serverNow,
    required this.onPredict,
    required this.logo,
  });

  String _countdown(Duration? d) {
    if (d == null) return '--:--:--';
    return '${d.inHours.toString().padLeft(2, '0')}:'
        '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Open':
        return Colors.lightBlueAccent;
      case 'Live':
        return Colors.greenAccent;
      case 'Finished':
        return Colors.orangeAccent;
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = match.isPredictionClosed(serverNow);
    final status = match.predictionStatus(serverNow);
    final remaining = match.remainingUntilClose(serverNow);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: closed
              ? [const Color(0xFF141414), const Color(0xFF0C0C0C)]
              : [
                  WcTheme.green.withValues(alpha: 0.14),
                  WcTheme.card,
                  WcTheme.blue.withValues(alpha: 0.12)
                ],
        ),
        border: Border.all(
          color: closed ? Colors.white12 : WcTheme.gold.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(match.matchName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: closed ? Colors.white38 : WcTheme.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                )),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(children: [
                    logo(match.team1Logo, 60),
                    const SizedBox(height: 8),
                    Text(match.team1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: match.resultSaved
                      ? Text(
                          '${match.team1Goals} - ${match.team2Goals}',
                          style: const TextStyle(
                            color: WcTheme.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        )
                      : Text('VS',
                          style: TextStyle(
                            color: closed ? Colors.white24 : WcTheme.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 2,
                          )),
                ),
                Expanded(
                  child: Column(children: [
                    logo(match.team2Logo, 60),
                    const SizedBox(height: 8),
                    Text(match.team2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Text('${match.date}  ${match.time} ${match.timePeriod}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),
            ...match.prizePositions.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: WcTheme.gold.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: WcTheme.gold.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      Text(p.medal, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.prizeType,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white54)),
                            Text(p.prizeDescription,
                                style: const TextStyle(
                                  color: WcTheme.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _box('Status', status, _statusColor(status)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _box(
                    closed ? 'Closed' : 'Closes In',
                    closed ? '—' : _countdown(remaining),
                    closed ? Colors.redAccent : WcTheme.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: closed ? Colors.white10 : WcTheme.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: closed ? 0 : 4,
                ),
                onPressed: closed ? null : () => onPredict(match),
                child: Text(
                  closed ? 'Prediction Closed' : '⚽ Predict',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.white54)),
            const SizedBox(height: 4),
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: label == 'Closes In' ? 16 : 12,
                  fontFeatures: label == 'Closes In'
                      ? const [FontFeature.tabularFigures()]
                      : null,
                )),
          ],
        ),
      );
}
