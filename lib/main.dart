import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'dart:js' as js;
import 'dart:html' as html;
import 'dart:math' as math;

import 'firebase_options.dart';
import 'api_service.dart';
import 'pages/match_predictions_page.dart';
import 'pages/claim_prize_page.dart';
import 'widgets/draggable_soccer_ball.dart';
import 'services/prize_redemption_service.dart';
import 'services/match_service.dart';
import 'models/active_prize.dart';

// Friendly fallback shown instead of Flutter's default red error screen if
// a widget ever fails to build. This is a last line of defense — the real
// fixes are catching errors at their source (see e.g. MatchPredictionsPage
// and the Firestore stream listeners below) — but it guarantees a customer
// never sees a raw crash screen even for an error nobody anticipated.
Widget _friendlyErrorBuilder(FlutterErrorDetails details) {
  debugPrint('Widget build error: ${details.exception}\n${details.stack}');
  return const Material(
    color: Color(0xFF050E1A),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'حصل خطأ بسيط، برجاء إعادة تحميل الصفحة.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    ),
  );
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Route any error thrown while building a widget through our friendly
    // fallback instead of the default red error screen.
    ErrorWidget.builder = _friendlyErrorBuilder;

    // Catch (and log, instead of crashing) any Flutter framework error
    // that isn't already handled locally — e.g. an exception thrown
    // inside a Firestore stream `.listen()` callback, which Flutter would
    // otherwise let escape uncaught.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint("Firebase Init Error: $e");
    }
    runApp(const LaveoraLuxuryApp());
  }, (error, stack) {
    // Catches anything thrown outside the Flutter framework's own error
    // zone (e.g. inside an async gap in a stream listener) so it is
    // logged instead of silently/visibly crashing the app.
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

class CafeTheme {
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color darkBg = Color(0xFF000000);
  static const Color surface = Color(0xFF161616);
  static const Color accentGreen = Color(0xFF4CAF50);

  // ألوان كأس العالم
  static const Color wcGreen = Color(0xFF00843D);
  static const Color wcRed = Color(0xFFE63946);
  static const Color wcBlue = Color(0xFF023E8A);
  static const Color wcGoldShine = Color(0xFFFFD700);
}

// ==========================================
// ويدجت الكورة المتحركة في الخلفية
// ==========================================
class FloatingSoccerBall extends StatefulWidget {
  const FloatingSoccerBall({super.key});
  @override
  State<FloatingSoccerBall> createState() => _FloatingSoccerBallState();
}

class _FloatingSoccerBallState extends State<FloatingSoccerBall>
    with TickerProviderStateMixin {
  late AnimationController _moveController;
  late AnimationController _rotateController;
  late Animation<double> _xAnim;
  late Animation<double> _yAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _xAnim = Tween<double>(begin: 0, end: 60).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
    );
    _yAnim = Tween<double>(begin: 0, end: 40).animate(
      CurvedAnimation(
        parent: _moveController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );
    _rotateAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      _rotateController,
    );
  }

  @override
  void dispose() {
    _moveController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_moveController, _rotateController]),
      builder: (context, child) {
        return Positioned(
          left: 20 + _xAnim.value,
          top: 120 + _yAnim.value,
          child: Opacity(
            opacity: 0.13,
            child: Transform.rotate(
              angle: _rotateAnim.value,
              child: const Text(
                "⚽",
                style: TextStyle(fontSize: 70),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// بانر كأس العالم المتحرك
// ==========================================
class WorldCupBanner extends StatefulWidget {
  const WorldCupBanner({super.key});
  @override
  State<WorldCupBanner> createState() => _WorldCupBannerState();
}

class _WorldCupBannerState extends State<WorldCupBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                CafeTheme.wcGreen.withOpacity(0.85),
                CafeTheme.wcBlue
                    .withOpacity(0.85 + 0.1 * _shimmerController.value),
                CafeTheme.wcGreen.withOpacity(0.85),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: CafeTheme.wcGoldShine.withOpacity(
                0.4 + 0.5 * _shimmerController.value,
              ),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: CafeTheme.wcGreen.withOpacity(0.25),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "⚽ كأس العالم 2026",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CafeTheme.wcGoldShine.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: CafeTheme.wcGoldShine.withOpacity(0.5)),
                ),
                child: const Text(
                  "🏆 USA · MEX · CAN",
                  style: TextStyle(
                    color: CafeTheme.wcGoldShine,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// زرار توقعات الماتشات الكبير
// ==========================================
class MatchPredictionButton extends StatelessWidget {
  const MatchPredictionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MatchPredictionsPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a472a), Color(0xFF023E8A), Color(0xFF1a472a)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: CafeTheme.wcGoldShine.withValues(alpha: 0.45), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: CafeTheme.wcGreen.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: CafeTheme.wcGoldShine.withValues(alpha: 0.35)),
              ),
              child: const Center(
                  child: Text('⚽', style: TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚽ Match Predictions',
                    style: TextStyle(
                      color: CafeTheme.wcGoldShine,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Predict the score and win prizes',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: CafeTheme.wcGoldShine.withValues(alpha: 0.8), size: 18),
          ],
        ),
      ),
    );
  }
}

class ClaimPrizeButton extends StatelessWidget {
  const ClaimPrizeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ClaimPrizePage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: CafeTheme.wcGoldShine.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: CafeTheme.wcGoldShine.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏆', style: TextStyle(fontSize: 22)),
            SizedBox(width: 10),
            Text(
              'Claim Prize',
              style: TextStyle(
                color: CafeTheme.wcGoldShine,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// رسام خطوط الملعب للصفحة الرئيسية
class _HomeFieldLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double y = 0; y < size.height; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawCircle(Offset(size.width / 2, size.height / 3), 80, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const String localBackgroundImage = 'assets/images/laveora_bg.jpg';
const String localLogoImage = 'assets/images/laveora_logo.png';

class LaveoraLuxuryApp extends StatelessWidget {
  const LaveoraLuxuryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LAVEORA | Luxury Experience',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CafeTheme.darkBg,
        fontFamily: 'Tajawal',
        splashColor: CafeTheme.primaryGold.withOpacity(0.3),
        highlightColor: CafeTheme.primaryGold.withOpacity(0.2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: CafeTheme.primaryGold,
          brightness: Brightness.dark,
          surface: CafeTheme.surface,
          onSurface: Colors.white,
        ),
      ),
      home: const MenuPage(),
    );
  }
}

Widget buildLaveoraLogo({double size = 60, Color? color}) {
  return Image.asset(
    localLogoImage,
    width: size,
    height: size,
    color: color,
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) =>
        Icon(Icons.restaurant_menu, size: size, color: CafeTheme.primaryGold),
  );
}

// ==========================================
// صفحة المنيو الرئيسية
// ==========================================
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with TickerProviderStateMixin {
  String? currentCat;
  final TextEditingController _catSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> basket = [];
  String? registeredName;
  String? currentTable;

  bool _isEntryComplete = false;
  bool _hasSavedName = false;
  bool _isWaiterAlertActive = false;

  late AnimationController _glowController;
  late AnimationController _devPulseController;
  late AnimationController _changeTablePulseController;

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _nameEntryController = TextEditingController();
  final TextEditingController _tableEntryController = TextEditingController();

  // ── Winner Code / prize redemption at checkout ──────────────
  final TextEditingController _couponPhoneCtrl = TextEditingController();
  final TextEditingController _couponCodeCtrl = TextEditingController();
  bool _couponLoading = false;
  String? _couponError;
  bool _couponExpanded = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _devPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _changeTablePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _checkSavedData();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _devPulseController.dispose();
    _changeTablePulseController.dispose();
    _couponPhoneCtrl.dispose();
    _couponCodeCtrl.dispose();
    super.dispose();
  }

  void _showCategoriesSheet(List<QueryDocumentSnapshot> cats) {
    _catSearchCtrl.clear();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            List<QueryDocumentSnapshot> filteredCats = cats;

            String q = _catSearchCtrl.text.trim();
            if (q.isNotEmpty) {
              filteredCats = cats.where((doc) {
                String name = (doc['name'] ?? "").toString();
                return name.contains(q);
              }).toList();
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 15,
                right: 15,
                top: 15,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "اختر القسم",
                      style: TextStyle(
                        color: CafeTheme.primaryGold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _catSearchCtrl,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: "ابحث عن قسم...",
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: CafeTheme.primaryGold,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: GridView.builder(
                        itemCount: filteredCats.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, i) {
                          String catName =
                              (filteredCats[i]['name'] ?? "").toString();
                          bool selected = currentCat == catName;

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              setState(() => currentCat = catName);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? CafeTheme.primaryGold
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? CafeTheme.primaryGold
                                      : Colors.white10,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  catName,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        selected ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _checkSavedData() {
    if (kIsWeb) {
      final savedName = html.window.localStorage['customer_name'];
      if (savedName != null && savedName.isNotEmpty) {
        setState(() {
          registeredName = savedName;
          _hasSavedName = true;
        });
      }
    }
  }

  void _openUrl(String url) => js.context.callMethod('open', [url]);

  void _playSound(String url) {
    if (kIsWeb) {
      js.context.callMethod('eval', [
        "(function() { var audio = new Audio('$url'); audio.play(); })();",
      ]);
    }
  }

  void _playMicrowaveWorking() =>
      _playSound("https://files.catbox.moe/ct6wzl.mp3");
  void _playMicrowaveDone() =>
      _playSound("https://files.catbox.moe/hecpqn.mp3");
  void _playWaiterBell() => _playSound("https://files.catbox.moe/y77se9.mp3");

  void _initStatusListeners() {
    if (registeredName == null) return;

    FirebaseFirestore.instance
        .collection('alerts')
        .where('customer_name', isEqualTo: registeredName)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty && _isWaiterAlertActive) {
        setState(() => _isWaiterAlertActive = false);
        _playWaiterBell();
        _showStatusSnackBar(
          "الويتر جاي لك دلوقتي يا فندم 😊",
          CafeTheme.primaryGold,
        );
      }
    });

    FirebaseFirestore.instance
        .collection('orders')
        .where('customer_name', isEqualTo: registeredName)
        .snapshots()
        .listen((snapshot) {
      try {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            var data = change.doc.data() as Map<String, dynamic>? ?? {};
            String status = data['status']?.toString() ?? '';
            if (status == 'جاري التجهيز') {
              _playMicrowaveWorking();
              _showStatusSnackBar(
                "بدأنا نجهز طلبك بكل حب.. ✨",
                Colors.orangeAccent,
              );
            } else if (status == 'جاهز') {
              _playMicrowaveDone();
              _showStatusSnackBar(
                "طلبك جاهز يا $registeredName! بالهناء والشفاء ✨",
                Colors.greenAccent,
              );
            }
          }
        }
      } catch (e, st) {
        debugPrint('Order status listener error: $e\n$st');
      }
    });
  }

  void _showStatusSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  void _showDeveloperContact() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F0F0F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: const BorderSide(color: CafeTheme.primaryGold, width: 0.5),
          ),
          title: const Text(
            "تواصل مع المطور 👨‍💻",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CafeTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Nader Soltan",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Text(
                "AI Engineer",
                style: TextStyle(
                  fontSize: 12,
                  color: CafeTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              _devLink(
                Icons.chat_bubble_outline,
                "WhatsApp",
                Colors.green,
                "https://wa.me/qr/QS4SMJ54AKJMF1",
              ),
              _devLink(
                Icons.facebook_outlined,
                "Facebook",
                Colors.blueAccent,
                "https://www.facebook.com/share/1ByWx21qNW/",
              ),
              _devLink(
                Icons.camera_alt_outlined,
                "Instagram",
                Colors.pinkAccent,
                "https://www.instagram.com/nadersoltan294?igsh=bDB5eTB3Z2NrMmF6",
              ),
              _devLink(
                Icons.video_collection_outlined,
                "TikTok",
                Colors.white,
                "https://www.tiktok.com/@nadersoltan6?_r=1&_t=ZS-93Uf8vOauIB",
              ),
              const Divider(color: Colors.white10, height: 30),
              const Text(
                "Call: 01012078944",
                style: TextStyle(
                  color: CafeTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _devLink(IconData icon, String label, Color color, String url) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () => _openUrl(url),
    );
  }

  void _showWaiterLogin() {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: const BorderSide(color: CafeTheme.primaryGold, width: 0.5),
        ),
        title: const Text(
          'دخول الويتر 🤵',
          textAlign: TextAlign.center,
          style: TextStyle(color: CafeTheme.primaryGold),
        ),
        content: TextField(
          controller: passwordCtrl,
          obscureText: true,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'أدخل كلمة السر',
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CafeTheme.primaryGold,
            ),
            onPressed: () async {
              final ok = await apiService.loginWaiter(passwordCtrl.text);
              if (!context.mounted) return;
              if (ok) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WaiterTerminal(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة السر خاطئة!'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'دخول',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            _buildMainContent(),
            if (!_isEntryComplete) _buildEntryOverlay(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // شاشة الدخول - داخل المكان فقط
  // ==========================================
  Widget _buildEntryOverlay() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(35),
              width: 380,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: CafeTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildLaveoraLogo(size: 100),
                  const SizedBox(height: 10),
                  const Text(
                    "LAVEORA",
                    style: TextStyle(
                      color: CafeTheme.primaryGold,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "مرحباً بك في تجربة الرفاهية ✨",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 30),

                  // حقل الاسم
                  if (!_hasSavedName) ...[
                    _entryField(
                      _nameEntryController,
                      "اسمك الكريم..",
                      Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 15),
                  ],

                  // حقل رقم الطاولة
                  _entryField(
                    _tableEntryController,
                    "رقم الطاولة..",
                    Icons.table_restaurant_rounded,
                    isNumber: true,
                  ),

                  const SizedBox(height: 25),

                  // زرار البداية
                  _buildAnimatedButton(
                    onPressed: _validateAndStart,
                    child: const Text(
                      "ابدأ تجربة الرفاهية ✨",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // زرار تسجيل الدخول كويتر
                  TextButton.icon(
                    onPressed: _showWaiterLogin,
                    icon: const Icon(
                      Icons.lock_person,
                      color: CafeTheme.primaryGold,
                      size: 18,
                    ),
                    label: const Text(
                      "الدخول كويتر",
                      style: TextStyle(
                        color: CafeTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      textAlign: TextAlign.center,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: CafeTheme.primaryGold, size: 20),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _validateAndStart() {
    String name =
        _hasSavedName ? registeredName! : _nameEntryController.text.trim();

    if (name.isEmpty) {
      _showStatusSnackBar("يرجى إدخال الاسم", Colors.redAccent);
      return;
    }

    if (_tableEntryController.text.trim().isEmpty) {
      _showStatusSnackBar("يرجى تحديد رقم الطاولة", Colors.redAccent);
      return;
    }

    currentTable = _tableEntryController.text.trim();

    if (kIsWeb) html.window.localStorage['customer_name'] = name;

    setState(() {
      registeredName = name;
      _isEntryComplete = true;
    });
    _initStatusListeners();
  }

  Widget _buildAnimatedButton({
    required VoidCallback onPressed,
    required Widget child,
    Color color = CafeTheme.primaryGold,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            localBackgroundImage,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.85),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Colors.black),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  CafeTheme.wcGreen.withOpacity(0.12),
                  Colors.transparent,
                  CafeTheme.wcBlue.withOpacity(0.08),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _HomeFieldLinesPainter()),
        ),
        const FloatingSoccerBall(),
        const DraggableSoccerBall(),
        CustomScrollView(
          slivers: [
            _buildAppBar(),
            const SliverToBoxAdapter(child: WorldCupBanner()),
            const SliverToBoxAdapter(child: MatchPredictionButton()),
            const SliverToBoxAdapter(child: ClaimPrizeButton()),
            _buildBestSellers(),
            _buildCategoryBar(),
            _buildProductList(),
            const SliverToBoxAdapter(child: SizedBox(height: 550)),
          ],
        ),
        _buildBottomActionArea(),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      backgroundColor: Colors.transparent,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                CafeTheme.wcGreen.withOpacity(0.25),
                CafeTheme.wcBlue.withOpacity(0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {
                if (kIsWeb) {
                  html.window.location.reload();
                }
              },
              child: buildLaveoraLogo(size: 40),
            ),
            const SizedBox(height: 5),
            const Text(
              "LAVEORA",
              style: TextStyle(
                color: CafeTheme.primaryGold,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
                fontSize: 22,
              ),
            ),
            if (registeredName != null)
              Text(
                "طاولة $currentTable | $registeredName",
                style: const TextStyle(fontSize: 10, color: Colors.white60),
              ),
            const SizedBox(height: 15),
          ],
        ),
      ),
      leadingWidth: 150,
      leading: Center(
        child: ScaleTransition(
          scale: Tween(begin: 0.95, end: 1.05).animate(
            CurvedAnimation(
              parent: _devPulseController,
              curve: Curves.easeInOut,
            ),
          ),
          child: GestureDetector(
            onTap: _showDeveloperContact,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: CafeTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.code_rounded,
                    color: CafeTheme.primaryGold,
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "تواصل مع المطور",
                    style: TextStyle(
                      color: CafeTheme.primaryGold,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        // زرار تغيير الطاولة
        Padding(
          padding: const EdgeInsets.only(left: 5, top: 15),
          child: ScaleTransition(
            scale: Tween(begin: 0.95, end: 1.05).animate(
              CurvedAnimation(
                parent: _changeTablePulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: GestureDetector(
              onTap: _changeTableDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: CafeTheme.primaryGold.withOpacity(0.4),
                  ),
                ),
                child: const Icon(
                  Icons.sync_alt_rounded,
                  color: CafeTheme.primaryGold,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
        _buildWaiterButton(),
      ],
    );
  }

  void _changeTableDialog() {
    _tableEntryController.text = currentTable ?? "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        title: const Text(
          "تغيير الطاولة 🪑",
          textAlign: TextAlign.center,
          style: TextStyle(color: CafeTheme.primaryGold),
        ),
        content: TextField(
          controller: _tableEntryController,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 24),
          decoration: InputDecoration(
            hintText: "رقم الطاولة الجديد",
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CafeTheme.primaryGold,
            ),
            onPressed: () {
              if (_tableEntryController.text.isNotEmpty) {
                setState(() => currentTable = _tableEntryController.text);
                Navigator.pop(context);
                _showStatusSnackBar(
                  "تم تغيير الطاولة إلى ${_tableEntryController.text} 🪑",
                  CafeTheme.primaryGold,
                );
              }
            },
            child: const Text(
              "تحديث",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiterButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 15, top: 15),
      child: GestureDetector(
        onTap: _callWaiter,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: CafeTheme.primaryGold.withOpacity(
                  0.4 + (0.6 * _glowController.value),
                ),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Text(
                  _isWaiterAlertActive ? "جاري.." : "نداء",
                  style: const TextStyle(
                    color: CafeTheme.primaryGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Icon(
                  Icons.notifications_active_rounded,
                  color: CafeTheme.primaryGold,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBestSellers() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 30, 25, 15),
            child: Text(
              "الأكثر طلباً 🔥",
              style: TextStyle(
                color: CafeTheme.primaryGold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 140,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .limit(6)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                var items = snapshot.data!.docs;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    var item = items[index].data() as Map<String, dynamic>;
                    String? imgUrl = item['image_url'];
                    return GestureDetector(
                      onTap: () => _showAddDialog(item),
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundImage:
                                  (imgUrl != null && imgUrl.isNotEmpty)
                                      ? NetworkImage(imgUrl)
                                      : null,
                              backgroundColor: Colors.white10,
                              child: (imgUrl == null || imgUrl.isEmpty)
                                  ? const Icon(
                                      Icons.restaurant,
                                      color: CafeTheme.primaryGold,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['name'] ?? "",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .orderBy('index')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: SizedBox());
        }
        var cats = snapshot.data!.docs;
        if (currentCat == null && cats.isNotEmpty) {
          currentCat = cats.first['name'];
        }
        return SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            child: Container(
              color: Colors.black.withOpacity(0.9),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CafeTheme.primaryGold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => _showCategoriesSheet(cats),
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: const Text(
                        "كل الأقسام",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: cats.length,
                      itemBuilder: (c, i) {
                        bool isSelected = currentCat == cats[i]['name'];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => currentCat = cats[i]['name']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 15,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFD4AF37),
                                        Color(0xFFB8860B),
                                      ],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Text(
                                cats[i]['name'] ?? "",
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('cat', isEqualTo: currentCat)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(
              child: CircularProgressIndicator(color: CafeTheme.primaryGold),
            ),
          );
        }
        var items = snapshot.data!.docs;
        return SliverList(
          delegate: SliverChildBuilderDelegate((c, i) {
            var item = items[i].data() as Map<String, dynamic>;
            String? imgUrl = item['image_url'];
            bool hasSizes =
                item['sizes'] != null && (item['sizes'] as List).isNotEmpty;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(15),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: (imgUrl != null && imgUrl.isNotEmpty)
                      ? Image.network(
                          imgUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: Colors.white10,
                          child: const Icon(
                            Icons.fastfood,
                            color: CafeTheme.primaryGold,
                          ),
                        ),
                ),
                title: Text(
                  item['name'] ?? "",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  hasSizes ? "أحجام مختلفة" : "${item['price']} ج.م",
                  style: TextStyle(
                    color:
                        hasSizes ? Colors.orangeAccent : CafeTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: hasSizes ? 14 : 16,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: CafeTheme.primaryGold,
                    size: 40,
                  ),
                  onPressed: () => _showAddDialog(item),
                ),
              ),
            );
          }, childCount: items.length),
        );
      },
    );
  }

  void _showAddDialog(Map<String, dynamic> item) {
    _noteController.clear();

    List<dynamic>? sizes = item['sizes'];
    Map<String, dynamic>? selectedSize;
    double currentPrice = (item['price'] as num).toDouble();

    if (sizes != null && sizes.isNotEmpty) {
      selectedSize = sizes.first;
      currentPrice = (selectedSize!['price'] as num).toDouble();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151515),
              title: Text(
                "تخصيص ${item['name']}",
                textAlign: TextAlign.right,
                style: const TextStyle(color: CafeTheme.primaryGold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sizes != null && sizes.isNotEmpty) ...[
                    const Text(
                      "اختر الحجم:",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: sizes.map((s) {
                        bool isSelected = selectedSize == s;
                        return ChoiceChip(
                          label: Text("${s['name']} - ${s['price']} ج.م"),
                          selected: isSelected,
                          selectedColor: CafeTheme.primaryGold,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (bool selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedSize = s;
                                currentPrice = (s['price'] as num).toDouble();
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  TextField(
                    controller: _noteController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: "أي إضافات تحب نجهزها لك؟",
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CafeTheme.primaryGold,
                  ),
                  onPressed: () {
                    setState(() {
                      String userNote = _noteController.text.isEmpty
                          ? "بدون إضافات"
                          : _noteController.text;

                      String itemName = item['name'];
                      if (selectedSize != null) {
                        itemName += " (${selectedSize!['name']})";
                      }

                      int index = basket.indexWhere(
                        (e) =>
                            e['name'] == itemName &&
                            e['note'] == userNote &&
                            e['price'] == currentPrice,
                      );

                      if (index != -1) {
                        basket[index]['quantity']++;
                      } else {
                        basket.add({
                          'name': itemName,
                          'price': currentPrice,
                          'image_url': item['image_url'],
                          'note': userNote,
                          'quantity': 1,
                        });
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "إضافة",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomActionArea() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(45)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              border: const Border(
                top: BorderSide(color: CafeTheme.primaryGold, width: 1.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActiveOrdersTracker(),
                _buildBasketRow(),
                _buildCouponSection(),
                _buildCheckoutBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ميزة جديدة: تتبع الطلبات النشطة مع التصميم المحسّن
  // ==========================================
  Widget _buildActiveOrdersTracker() {
    if (registeredName == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customer_name', isEqualTo: registeredName)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }
        var orders = snapshot.data!.docs;
        return SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 25),
            itemCount: orders.length,
            itemBuilder: (c, i) {
              var data = orders[i].data() as Map<String, dynamic>;
              String status = data['status'] ?? "قيد الانتظار";
              Color sColor = status == "جاهز"
                  ? Colors.greenAccent
                  : (status == "جاري التجهيز"
                      ? Colors.orangeAccent
                      : Colors.white38);

              // أيقونة الحالة
              IconData statusIcon = status == "جاهز"
                  ? Icons.check_circle_rounded
                  : (status == "جاري التجهيز"
                      ? Icons.local_cafe_rounded
                      : Icons.hourglass_top_rounded);

              return Container(
                width: 170,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: sColor.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, color: sColor, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: TextStyle(
                        color: sColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ميزة جديدة: عرض عدد الأصناف
                    if (data['items_with_qty'] != null)
                      Text(
                        "${(data['items_with_qty'] as List).length} صنف",
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 4),
                    // الفاتورة: الإجمالي قبل الخصم وبعده لو فيه هدية
                    // مُطبَّقة على الطلب ده، وإلا الإجمالي بس — عشان
                    // الزبون يشوف قيمة فاتورته هنا برضه مش بس وقت الدفع.
                    _trackerTotalText(data),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // نسخة مختصرة (نص واحد أو اتنين سطر) من عرض إجمالي الطلب، مخصوصة لكارت
  // تتبع الطلبات الصغير بتاع الزبون. بتفرق بين الحالتين:
  //  - فيه هدية/خصم مُطبَّق على الطلب: بيعرض "قبل: X" بخط مشطوب و"بعد: Y"
  //    بخط أوضح تحته.
  //  - مفيش خصم: بيعرض "الإجمالي: X" بس.
  Widget _trackerTotalText(Map<String, dynamic> data) {
    final orderTotal = (data['total'] as num?)?.toDouble();
    final prizeInfo = data['prize_info'] is Map
        ? Map<String, dynamic>.from(data['prize_info'] as Map)
        : null;
    final isDiscount = (prizeInfo?['prize_type']?.toString() ?? '')
        .toLowerCase()
        .contains('discount');
    final subtotal = isDiscount
        ? (prizeInfo?['subtotal_before_discount'] as num?)?.toDouble()
        : null;
    final finalTotal = isDiscount
        ? ((prizeInfo?['total_after_discount'] as num?)?.toDouble() ??
            orderTotal)
        : orderTotal;

    if (finalTotal == null) return const SizedBox.shrink();

    if (isDiscount && subtotal != null) {
      return Column(
        children: [
          Text(
            "قبل: ${subtotal.toStringAsFixed(2)} ج.م",
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Text(
            "بعد: ${finalTotal.toStringAsFixed(2)} ج.م",
            style: const TextStyle(
              color: CafeTheme.primaryGold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Text(
      "الإجمالي: ${finalTotal.toStringAsFixed(2)} ج.م",
      style: const TextStyle(
        color: CafeTheme.primaryGold,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBasketRow() {
    if (basket.isEmpty) return const SizedBox();
    return Container(
      height: 150,
      padding: const EdgeInsets.only(top: 15),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: basket.length,
        itemBuilder: (c, i) => Container(
          width: 180,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: CafeTheme.primaryGold.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                basket[i]['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => setState(() {
                      if (basket[i]['quantity'] > 1) {
                        basket[i]['quantity']--;
                      } else {
                        basket.removeAt(i);
                      }
                    }),
                  ),
                  Text(
                    "${basket[i]['quantity']}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.greenAccent,
                    ),
                    onPressed: () => setState(() => basket[i]['quantity']++),
                  ),
                ],
              ),
              if (basket[i]['note'] != "بدون إضافات")
                Text(
                  "📝 ${basket[i]['note']}",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.orangeAccent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Winner Code redemption at checkout ───────────────────────

  Future<void> _applyCoupon() async {
    final phone = _couponPhoneCtrl.text.trim();
    final code = _couponCodeCtrl.text.trim();
    if (phone.isEmpty || code.isEmpty) {
      setState(() => _couponError = 'Enter your phone number and winner code.');
      return;
    }
    setState(() {
      _couponLoading = true;
      _couponError = null;
    });
    try {
      final data = await ClaimService.verifyClaim(phone: phone, code: code);
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _couponLoading = false;
          _couponError = 'Invalid phone number or winner code.';
        });
        return;
      }
      if (data['redeemed'] == true) {
        setState(() {
          _couponLoading = false;
          _couponError = 'This prize has already been redeemed.';
        });
        return;
      }
      final docPath = data['_docPath']?.toString();
      if (docPath == null) {
        setState(() {
          _couponLoading = false;
          _couponError = 'Could not verify this code. Please try again.';
        });
        return;
      }
      final prize = ActivePrize.fromMap(data, docPath, phone);
      PrizeRedemptionService.activate(prize);
      _applyPrizeEffects(prize, showWarnings: true);
      setState(() => _couponLoading = false);
      if (mounted) {
        await _showRewardConfirmationDialog(prize);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _couponLoading = false;
        _couponError = 'Could not verify this code. Please try again.';
      });
    }
  }

  /// Applies the side-effects of a verified prize to the current basket:
  /// Free Item / Buy X Get Y add a free line item (once); Discount is
  /// applied live when the total is computed, so it needs no basket change.
  void _applyPrizeEffects(ActivePrize prize, {bool showWarnings = false}) {
    if (prize.isFreeItem && prize.freeItemName != null) {
      _addPrizeItemIfMissing(prize.freeItemName!);
    } else if (prize.isBuyXGetY && prize.freeItemName != null) {
      final requiredOk = prize.requiredItemName == null ||
          basket.any((e) =>
              e['name'] == prize.requiredItemName &&
              (e['quantity'] as num) >= (prize.requiredItemQty ?? 1));
      if (requiredOk) {
        _addPrizeItemIfMissing(prize.freeItemName!);
      } else if (showWarnings) {
        _couponError =
            'Add ${prize.requiredItemQty ?? 1}x "${prize.requiredItemName ?? 'the required item'}" to your cart, then re-apply the code.';
      }
    }
  }

  void _addPrizeItemIfMissing(String itemName) {
    final exists =
        basket.any((e) => e['name'] == itemName && e['isPrize'] == true);
    if (exists) return;
    setState(() {
      basket.add({
        'name': itemName,
        'price': 0,
        'quantity': 1,
        'note': 'بدون إضافات',
        'isPrize': true,
      });
    });
  }

  void _removeCoupon() {
    setState(() {
      basket.removeWhere((e) => e['isPrize'] == true);
      _couponError = null;
    });
    PrizeRedemptionService.clear();
  }

  // Professional "reward verified" confirmation, shown BEFORE the order is
  // placed, right after a valid Winner Code is applied. Reassures the
  // customer their reward was found and will be applied automatically —
  // deliberately not just a bare "Code Accepted" toast.
  Future<void> _showRewardConfirmationDialog(ActivePrize prize) {
    final rewardType = _rewardTypeLabel(prize);
    return showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                const Text(
                  'مبروك! تم التحقق من مكافأتك بنجاح',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CafeTheme.accentGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your reward has been verified successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CafeTheme.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: CafeTheme.accentGreen.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المكافأة / Reward: $rewardType',
                        style: const TextStyle(
                            color: CafeTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      if (prize.prizeDescription.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          prize.prizeDescription,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'سيتم تطبيق هذه المكافأة تلقائيًا على طلبك الحالي.\n'
                  'This reward will be applied automatically to your current order.\n'
                  'يرجى مراجعة ملخص الطلب المحدث قبل تأكيد الطلب.\n'
                  'Please review the updated order summary before confirming your order.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white54, fontSize: 11.5, height: 1.5),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CafeTheme.accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('تم / Great!',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCouponSection() {
    final prize = PrizeRedemptionService.active;
    if (prize != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(35, 0, 35, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CafeTheme.accentGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: CafeTheme.accentGreen.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer,
                color: CafeTheme.accentGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      prize.prizeDescription.isEmpty
                          ? prize.prizeType
                          : prize.prizeDescription,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const Text('Winner prize applied',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
              onPressed: _removeCoupon,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 0, 35, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _couponExpanded = !_couponExpanded),
            icon: Icon(
              _couponExpanded
                  ? Icons.expand_less
                  : Icons.confirmation_number_outlined,
              color: CafeTheme.primaryGold,
              size: 18,
            ),
            label: const Text('Have a Winner Code?',
                style: TextStyle(color: CafeTheme.primaryGold, fontSize: 12)),
          ),
          if (_couponExpanded) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Phone Number',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _couponCodeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Coupon Code',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _couponLoading ? null : _applyCoupon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CafeTheme.primaryGold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _couponLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('Apply',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            if (_couponError != null) ...[
              const SizedBox(height: 6),
              Text(_couponError!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 11)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    double currentBasketTotal = basket.fold(
      0.0,
      (previousValue, item) =>
          previousValue + ((item['price'] as num) * (item['quantity'] as num)),
    );
    final discount = PrizeRedemptionService.discountFor(currentBasketTotal);
    final finalTotal = currentBasketTotal - discount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 20, 35, 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // المبلغ الحالي = سعر الأوردر الأصلي زي ما هو من غير أي خصم.
              // ولو فيه خصم مُطبَّق (هدية/كوبون)، بيتحسب على السعر ده
              // وبيتعرض تحته "المبلغ بعد الخصم" بالرقم النهائي اللي هيتدفع
              // فعلاً — عشان الزبون يشوف الاتنين مع بعض ويكون فاهم الفرق.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    "المبلغ الحالي: ",
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  Text(
                    "${currentBasketTotal.toStringAsFixed(2)} ج.م",
                    style: TextStyle(
                      fontSize: discount > 0 ? 14 : 22,
                      fontWeight:
                          discount > 0 ? FontWeight.normal : FontWeight.w900,
                      color:
                          discount > 0 ? Colors.white38 : CafeTheme.primaryGold,
                      decoration:
                          discount > 0 ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
              if (discount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      "المبلغ بعد الخصم: ",
                      style: TextStyle(
                        color: CafeTheme.accentGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${finalTotal.toStringAsFixed(2)} ج.م",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: CafeTheme.primaryGold,
                      ),
                    ),
                  ],
                ),
                Text(
                  "خصم ${discount.toStringAsFixed(2)} ج.م مُطبَّق",
                  style: const TextStyle(
                      color: CafeTheme.accentGreen, fontSize: 11),
                ),
              ],
              // ميزة جديدة: عرض عدد الأصناف في السلة
              if (basket.isNotEmpty)
                Text(
                  "${basket.length} صنف في السلة",
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
            ],
          ),
          Column(
            children: [
              ElevatedButton(
                onPressed: basket.isEmpty ? null : _confirmAndSendOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CafeTheme.primaryGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  "تأكيد الطلب ⚡",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              // ميزة جديدة: زرار مسح السلة
              if (basket.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() => basket.clear());
                    _showStatusSnackBar("تم مسح السلة", Colors.redAccent);
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  label: const Text(
                    "مسح السلة",
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Order pricing / reward summary ──────────────────────────────────
  // Everything below computes ONE canonical breakdown of an order's price
  // (original total, reward applied, discount/free-item value, final total,
  // delivery fee, grand total, order number, etc). It is computed exactly
  // once per order (in _buildPricingBreakdown) and the same map is then
  // reused for: the customer confirmation summary, the Firestore payload,
  // and the Telegram message — so the three can never drift apart or
  // recompute (and possibly disagree) on the numbers.

  // Dine-in only app right now (no delivery flow / address / courier
  // anywhere in the UI), so delivery is always 0. Kept as a named constant
  // (instead of a bare 0.0 scattered around) so wiring up real delivery
  // orders later only means changing this one place.
  static const double _dineInDeliveryFee = 0.0;
  static const String _defaultPaymentMethod = 'الدفع نقدي عند الطلب';

  String _rewardTypeLabel(ActivePrize prize) {
    if (prize.isDiscount) return 'خصم';
    if (prize.isBuyXGetY) return 'اشتري واحصل على هدية';
    if (prize.isFreeItem) return 'هدية مجانية';
    return prize.prizeType;
  }

  String _generateOrderNumber() {
    final now = DateTime.now();
    final ms = now.millisecondsSinceEpoch.toString();
    final tail = ms.substring(ms.length - 6);
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = math.Random();
    final suffix =
        List.generate(3, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'ORD-$tail$suffix';
  }

  // Best-effort lookup of a free/gift item's normal price from the
  // 'products' collection, so we can show "Free Item Value" to the
  // customer/Telegram/admin. If the product can't be found (renamed,
  // deleted, or the name doesn't match exactly) this simply returns null
  // and every caller already treats a null value as "unknown" instead of
  // crashing or showing a fake 0.
  Future<double?> _lookupFreeItemValue(String? name) async {
    if (name == null || name.trim().isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: name.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final price = snap.docs.first.data()['price'];
      if (price is num) return price.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Computes the single canonical pricing/reward breakdown for whatever is
  /// currently in [basket] + whatever prize is currently active. Called once
  /// per checkout attempt (from the confirm-summary flow), then the exact
  /// same map is reused all the way through to Firestore + Telegram, so the
  /// numbers shown to the customer are guaranteed to be the numbers saved
  /// and the numbers sent to Telegram/admin.
  Future<Map<String, dynamic>> _buildPricingBreakdown() async {
    final originalTotal = basket.fold<double>(
      0.0,
      (previousValue, item) =>
          previousValue + ((item['price'] as num) * (item['quantity'] as num)),
    );
    final prize = PrizeRedemptionService.active;
    final discount = PrizeRedemptionService.discountFor(originalTotal);
    final finalTotal = originalTotal - discount;

    double? freeItemValue;
    if (prize != null && (prize.isBuyXGetY || prize.isFreeItem)) {
      freeItemValue = await _lookupFreeItemValue(prize.freeItemName);
    }

    const deliveryFee = _dineInDeliveryFee;
    final grandTotal = finalTotal + deliveryFee;

    return {
      'order_number': _generateOrderNumber(),
      'customer_name': registeredName ?? '',
      'customer_phone': prize?.phone ?? '',
      'table_number': currentTable ?? '?',
      'original_total': originalTotal,
      'discount_amount': discount,
      'final_total': finalTotal,
      'delivery_fee': deliveryFee,
      'grand_total': grandTotal,
      'payment_method': _defaultPaymentMethod,
      'prize': prize,
      'reward_type': prize != null ? _rewardTypeLabel(prize) : null,
      'reward_description': prize?.prizeDescription,
      'winner_code': prize?.winnerCode,
      'free_item_name': prize?.freeItemName,
      'free_item_value': freeItemValue,
      'required_item_name': prize?.requiredItemName,
      'required_item_qty': prize?.requiredItemQty,
      'client_order_time': DateTime.now().toIso8601String(),
    };
  }

  // Structured prize/reward data saved directly on the order document (in
  // addition to the flattened top-level fields sent by _sendOrderWith), so
  // an admin panel reading straight from Firestore always has one place —
  // 'prize_info' — with everything about the reward, laid out consistently.
  Map<String, dynamic>? _prizeInfoForOrder(Map<String, dynamic> b) {
    final ActivePrize? prize = b['prize'] as ActivePrize?;
    if (prize == null) return null;
    return {
      'reward_applied': true,
      'winner_code': prize.winnerCode,
      'prize_type': prize.prizeType,
      'reward_type': b['reward_type'],
      'prize_description': prize.prizeDescription,
      'discount_percent': prize.discountPercent,
      'discount_amount': prize.discountAmount,
      'free_item_name': prize.freeItemName,
      'free_item_value': b['free_item_value'],
      'required_item_name': prize.requiredItemName,
      'required_item_qty': prize.requiredItemQty,
      'subtotal_before_discount': b['original_total'],
      'discount_applied': b['discount_amount'],
      'total_after_discount': b['final_total'],
    };
  }

  // Human-readable reward block, shared by the Telegram message and (via
  // the same strings) the customer confirmation dialog below.
  String _prizeDetailsBlock(Map<String, dynamic> b) {
    final ActivePrize? prize = b['prize'] as ActivePrize?;
    if (prize == null) return '';
    final discount = b['discount_amount'] as double;
    final freeItemValue = b['free_item_value'] as double?;
    final bx = StringBuffer();
    bx.writeln('━━━━━━━━━━━━━━━━━━');
    bx.writeln('🎁 تفاصيل الجائزة المستخدمة');
    bx.writeln('🏷️ كود الهدية : ${prize.winnerCode}');
    bx.writeln('📌 نوع الجائزة : ${b['reward_type']}');
    if (prize.prizeDescription.isNotEmpty) {
      bx.writeln('📝 الوصف : ${prize.prizeDescription}');
    }
    if (prize.isDiscount) {
      if (prize.discountPercent != null) {
        bx.writeln('📉 نسبة الخصم : ${prize.discountPercent}%');
      } else if (prize.discountAmount != null) {
        bx.writeln(
            '📉 قيمة الخصم الثابتة : ${prize.discountAmount!.toStringAsFixed(2)} ج.م');
      }
      bx.writeln(
          '💸 قيمة الخصم المطبَّق : -${discount.toStringAsFixed(2)} ج.م');
    } else if (prize.isBuyXGetY) {
      bx.writeln('🎁 الهدية المكتسبة : ${prize.freeItemName ?? '—'}');
      if (prize.requiredItemName != null) {
        bx.writeln(
            '🛒 المنتجات المؤهلة : ${prize.requiredItemQty ?? 1} × ${prize.requiredItemName}');
      }
      if (freeItemValue != null) {
        bx.writeln('💵 قيمة الهدية : ${freeItemValue.toStringAsFixed(2)} ج.م');
      }
    } else if (prize.isFreeItem) {
      bx.writeln(
          '🎁 الهدية المكتسبة : ${prize.freeItemName ?? prize.prizeDescription}');
      if (freeItemValue != null) {
        bx.writeln('💵 قيمة الهدية : ${freeItemValue.toStringAsFixed(2)} ج.م');
      }
    }
    return bx.toString();
  }

  // ── Customer-facing confirmation summary ──────────────────────────────
  // Shown right before the order is actually sent, so the customer sees
  // exactly what they'll pay (original total, reward, discount/free item,
  // final total) and has to explicitly confirm — instead of the order going
  // out the instant they tap the checkout button.
  Future<void> _confirmAndSendOrder() async {
    if (basket.isEmpty || registeredName == null) return;
    final breakdown = await _buildPricingBreakdown();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _OrderSummaryDialog(breakdown: breakdown),
    );
    if (confirmed == true) {
      await _sendOrderWith(breakdown);
    }
  }

  Future<void> _sendOrderWith(Map<String, dynamic> breakdown) async {
    final ActivePrize? usedPrize = breakdown['prize'] as ActivePrize?;
    final originalTotal = breakdown['original_total'] as double;
    final discount = breakdown['discount_amount'] as double;
    final finalTotal = breakdown['final_total'] as double;
    final deliveryFee = breakdown['delivery_fee'] as double;
    final grandTotal = breakdown['grand_total'] as double;

    try {
      // IMPORTANT: createOrder returns null when the write fails (e.g. the
      // backend URL in api_service.dart is unreachable/misconfigured, or a
      // network error). This used to be ignored — the app would show
      // "تم إرسال طلبك! 🚀" and clear the basket even though NOTHING was
      // ever saved anywhere. That is why orders could appear to send
      // successfully on screen but never show up in Firestore at all. Now
      // we check the result and only treat it as success if an order id
      // actually came back.
      final orderId = await apiService.createOrder(
        customerName: registeredName!,
        tableNumber: currentTable ?? '?',
        itemsWithQty: basket
            .map((e) => {'name': e['name'], 'qty': e['quantity']})
            .toList(),
        totalPrice: finalTotal,
        note: basket.any((e) => e['note'] != "بدون إضافات")
            ? basket.firstWhere((e) => e['note'] != "بدون إضافات")['note']
            : "بدون إضافات",
        prizeInfo: _prizeInfoForOrder(breakdown),
        customerPhone: breakdown['customer_phone'] as String?,
        orderNumber: breakdown['order_number'] as String?,
        originalTotal: originalTotal,
        rewardType: breakdown['reward_type'] as String?,
        rewardDescription: breakdown['reward_description'] as String?,
        discountAmount: discount > 0 ? discount : null,
        freeItemValue: breakdown['free_item_value'] as double?,
        winnerCode: breakdown['winner_code'] as String?,
        deliveryFee: deliveryFee,
        grandTotal: grandTotal,
        paymentMethod: breakdown['payment_method'] as String?,
        clientOrderTime: breakdown['client_order_time'] as String?,
        rewardApplied: usedPrize != null,
      );

      if (orderId == null) {
        if (!mounted) return;
        _showStatusSnackBar(
          "تعذر إرسال الطلب، تأكد من الاتصال وحاول مرة أخرى.",
          Colors.redAccent,
        );
        return;
      }

      await apiService.sendTelegramMessage(
        _buildTelegramOrderMessage(breakdown, usedPrize),
      );

      // Lock the winner code so it can never be redeemed twice. This is
      // best-effort — if it fails the order itself has still gone through.
      if (usedPrize != null) {
        await PrizeRedemptionService.markRedeemed();
      }

      if (!mounted) return;
      setState(() {
        basket.clear();
      });
      _showStatusSnackBar("تم إرسال طلبك! 🚀", Colors.greenAccent);
    } catch (e) {
      debugPrint('sendOrder error: $e');
      if (!mounted) return;
      _showStatusSnackBar("تعذر إرسال الطلب، حاول مرة أخرى.", Colors.redAccent);
    }
  }

  // Builds the Telegram notification exactly per the required layout, so
  // the cashier can tell at a glance whether a reward was used, what it
  // was, how much discount/free item value it represents, what to hand
  // over, and how much cash to collect — all from one message.
  String _buildTelegramOrderMessage(
      Map<String, dynamic> b, ActivePrize? prize) {
    final originalTotal = b['original_total'] as double;
    final discount = b['discount_amount'] as double;
    final finalTotal = b['final_total'] as double;
    final deliveryFee = b['delivery_fee'] as double;
    final grandTotal = b['grand_total'] as double;
    final freeItemValue = b['free_item_value'] as double?;
    final phone = (b['customer_phone'] as String?)?.trim();

    final itemLines =
        basket.map((e) => '  • ${e['name']} × ${e['quantity']}').join('\n');

    final bx = StringBuffer();

    bx.writeln('🧾 طلب جديد #${b['order_number']}');
    bx.writeln('👤 $registeredName');
    bx.writeln('📞 ${phone?.isNotEmpty == true ? phone : "—"}');
    bx.writeln('🪑 طاولة: $currentTable');
    bx.writeln('');

    bx.writeln('🍕 الطلب:');
    bx.writeln(itemLines);
    bx.writeln('');

    if (prize != null) {
      bx.writeln('🎁 الجائزة: ${prize.prizeDescription}');

      if (prize.isDiscount) {
        bx.writeln(
            '💸 قبل: ${originalTotal.toStringAsFixed(2)} ج | خصم: ${discount.toStringAsFixed(2)} ج');
      } else {
        bx.writeln(
            '🎉 الهدية: ${prize.freeItemName ?? prize.prizeDescription}');
      }

      bx.writeln('🏷️ الكود: ${prize.winnerCode}');
      bx.writeln('');
    }

    bx.writeln('💰 المطلوب: ${grandTotal.toStringAsFixed(2)} ج');
    bx.writeln('💳 ${b['payment_method']}');
    bx.writeln('🕒 ${DateTime.now().toString().substring(0, 16)}');

    return bx.toString();
  }

  void _callWaiter() async {
    if (_isWaiterAlertActive || registeredName == null) return;
    setState(() => _isWaiterAlertActive = true);
    await apiService.callWaiter(
      customerName: registeredName!,
      tableNumber: currentTable ?? '?',
    );
    await apiService.sendTelegramMessage(
      '━━━━━━━━━━━━━━━━━━\n'
      '🔔 نداء ويتر — LAVEORA\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '👤 العميل : $registeredName\n'
      '🪑 الطاولة : $currentTable\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '⚡ العميل يطلب مساعدة الويتر!',
    );
  }
}

// ── Customer order summary confirmation dialog ──────────────────────────
// Shown right before an order is sent, built from the exact same
// breakdown map (see _MenuPageState._buildPricingBreakdown) that later
// gets saved to Firestore and sent to Telegram, so nothing shown here can
// ever disagree with what actually happens after the customer confirms.
class _OrderSummaryDialog extends StatelessWidget {
  final Map<String, dynamic> breakdown;
  const _OrderSummaryDialog({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final ActivePrize? prize = breakdown['prize'] as ActivePrize?;
    final originalTotal = breakdown['original_total'] as double;
    final discount = breakdown['discount_amount'] as double;
    final finalTotal = breakdown['final_total'] as double;
    final freeItemValue = breakdown['free_item_value'] as double?;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'الجائزه التي سوف تطبق على طلبك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CafeTheme.primaryGold,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              if (prize != null) ...[
                const Divider(color: Colors.white12, height: 24),
                _row('نوع الجائزة', breakdown['reward_type']?.toString() ?? ''),
                if ((prize.prizeDescription).isNotEmpty)
                  _row('الوصف', prize.prizeDescription),
                if (prize.isDiscount)
                  _row('قيمة الخصم', '-${discount.toStringAsFixed(2)} ج.م',
                      valueColor: CafeTheme.accentGreen),
                if (prize.isBuyXGetY) ...[
                  if (prize.requiredItemName != null)
                    _row('المنتجات المؤهلة',
                        '${prize.requiredItemQty ?? 1} × ${prize.requiredItemName}'),
                  _row('الهدية المجانية', prize.freeItemName ?? '—'),
                  if (freeItemValue != null)
                    _row('قيمة الهدية',
                        '${freeItemValue.toStringAsFixed(2)} ج.م',
                        valueColor: CafeTheme.accentGreen),
                ],
                if (prize.isFreeItem) ...[
                  _row('الهدية المجانية',
                      prize.freeItemName ?? prize.prizeDescription),
                  if (freeItemValue != null)
                    _row('قيمة الهدية',
                        '${freeItemValue.toStringAsFixed(2)} ج.م',
                        valueColor: CafeTheme.accentGreen),
                ],
              ],
              const Divider(color: Colors.white12, height: 24),
              _row('الإجمالي النهائي (قبل) الخصم',
                  '${finalTotal.toStringAsFixed(2)} ج.م',
                  big: true),
              const Divider(color: Colors.white12, height: 24),
              _row('الإجمالي النهائي (بعد) الخصم', 'سيتم حسابها عند الكاشير',
                  big: true),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('رجوع',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CafeTheme.primaryGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('تأكيد الطلب',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {bool big = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white54,
                fontSize: big ? 14 : 12,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.left,
            style: TextStyle(
              color: valueColor ?? (big ? CafeTheme.primaryGold : Colors.white),
              fontSize: big ? 20 : 13,
              fontWeight: big ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _HeaderDelegate({required this.child});
  @override
  double get minExtent => 90;
  @override
  double get maxExtent => 90;
  @override
  Widget build(c, o, p) => child;
  @override
  bool shouldRebuild(o) => true;
}

// ==========================================
// صفحة الويتر
// ==========================================
class WaiterTerminal extends StatefulWidget {
  const WaiterTerminal({super.key});

  @override
  State<WaiterTerminal> createState() => _WaiterTerminalState();
}

class _WaiterTerminalState extends State<WaiterTerminal> {
  int _currentTabIndex = 0;

  final List<Map<String, dynamic>> waiterBasket = [];
  final tableCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String? selectedCategory;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _initWaiterAlerts();
  }

  void _playSound(String url) {
    if (kIsWeb) {
      js.context.callMethod('eval', [
        "(function() { var audio = new Audio('$url'); audio.play(); })();",
      ]);
    }
  }

  void _playBell() => _playSound(
        "https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3",
      );

  void _playWorkingSound() =>
      _playSound("https://www.soundjay.com/misc/sounds/microwave-hum-1.mp3");

  void _initWaiterAlerts() {
    FirebaseFirestore.instance.collection('orders').snapshots().listen((
      snapshot,
    ) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          var data = change.doc.data() as Map<String, dynamic>;
          String status = data['status'] ?? "";
          String customer = data['customer_name'] ?? "عميل";
          String table = data['table_number']?.toString() ?? "?";

          if (status == 'جاهز') {
            _playBell();
            _showSnack(
              "✅ طلب $customer (طاولة $table) جاهز الآن!",
              Colors.green,
            );
          } else if (status == 'جاري التجهيز') {
            _playWorkingSound();
            _showSnack(
              "☕ بدأ تجهيز طلب $customer (طاولة $table)",
              Colors.orangeAccent,
            );
          }
        }
      }
    });
  }

  void _showWaiterAddDialog(Map<String, dynamic> item) {
    noteCtrl.clear();

    List<dynamic>? sizes = item['sizes'];
    Map<String, dynamic>? selectedSize;
    double currentPrice = (item['price'] as num).toDouble();

    if (sizes != null && sizes.isNotEmpty) {
      selectedSize = sizes.first;
      currentPrice = (selectedSize!['price'] as num).toDouble();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151515),
              title: Text(
                "إضافة ${item['name']}",
                textAlign: TextAlign.right,
                style: const TextStyle(color: CafeTheme.primaryGold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sizes != null && sizes.isNotEmpty) ...[
                    const Text(
                      "اختر الحجم:",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: sizes.map((s) {
                        bool isSelected = selectedSize == s;
                        return ChoiceChip(
                          label: Text("${s['name']} - ${s['price']} ج.م"),
                          selected: isSelected,
                          selectedColor: CafeTheme.primaryGold,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (bool selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedSize = s;
                                currentPrice = (s['price'] as num).toDouble();
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  TextField(
                    controller: noteCtrl,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: "ملاحظات (سكر زيادة، بدون ثلج...)",
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CafeTheme.primaryGold,
                  ),
                  onPressed: () {
                    setState(() {
                      String note = noteCtrl.text.isEmpty
                          ? "بدون ملاحظات"
                          : noteCtrl.text;

                      String itemName = item['name'];
                      if (selectedSize != null) {
                        itemName += " (${selectedSize!['name']})";
                      }

                      int idx = waiterBasket.indexWhere(
                        (e) =>
                            e['name'] == itemName &&
                            e['note'] == note &&
                            e['price'] == currentPrice,
                      );

                      if (idx != -1) {
                        waiterBasket[idx]['qty']++;
                      } else {
                        waiterBasket.add({
                          'name': itemName,
                          'price': currentPrice,
                          'qty': 1,
                          'note': note,
                        });
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "إضافة للسلة",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _sendToBarista() async {
    if (tableCtrl.text.isEmpty || waiterBasket.isEmpty) {
      _showSnack("حدد الطاولة والأصناف أولاً", Colors.orange);
      return;
    }

    double total = waiterBasket.fold(
      0.0,
      (previousValue, e) =>
          previousValue + ((e['price'] as num) * (e['qty'] as num)),
    );

    List<String> notesList = [];
    for (var item in waiterBasket) {
      if (item['note'] != "بدون ملاحظات") {
        notesList.add("${item['name']}: ${item['note']}");
      }
    }

    String notesStr =
        notesList.isEmpty ? "بدون ملاحظات" : notesList.join(" | ");
    String customerName = nameCtrl.text.isEmpty ? "عميل" : nameCtrl.text;

    final orderId = await apiService.createOrder(
      customerName: customerName,
      tableNumber: tableCtrl.text,
      itemsWithQty: waiterBasket
          .map((e) => {'name': e['name'], 'qty': e['qty']})
          .toList(),
      totalPrice: total,
      note: notesStr,
      orderType: 'داخل المكان',
      source: 'waiter',
    );

    if (orderId == null) {
      _showSnack("تعذر إرسال الطلب، تأكد من الاتصال وحاول مرة أخرى.",
          Colors.redAccent);
      return;
    }

    final itemLines =
        waiterBasket.map((e) => '  • ${e['name']} × ${e['qty']}').join('\n');
    await apiService.sendTelegramMessage(
      '━━━━━━━━━━━━━━━━━━\n'
      '🤵 طلب ويتر — LAVEORA\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '👤 العميل : $customerName\n'
      '🪑 الطاولة : ${tableCtrl.text}\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '🛒 الطلبات :\n$itemLines\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '📝 ملاحظة : $notesStr\n'
      '💰 الإجمالي : ${total.toStringAsFixed(2)} ج.م\n'
      '━━━━━━━━━━━━━━━━━━',
    );

    setState(() => waiterBasket.clear());
    _showSnack("تم الإرسال للباريستا ✅", Colors.green);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildPOSView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tableCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "رقم الطاولة",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.table_restaurant,
                      color: CafeTheme.primaryGold,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "اسم العميل",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.person,
                      color: CafeTheme.primaryGold,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (v) => setState(() => searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "ابحث عن منتج...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: CafeTheme.primaryGold,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('categories')
              .orderBy('index')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            var cats = snapshot.data!.docs;
            return SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: cats.length,
                itemBuilder: (c, i) {
                  bool isSelected = selectedCategory == cats[i]['name'];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => selectedCategory = cats[i]['name']),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CafeTheme.primaryGold
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cats[i]['name'] ?? "",
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('cat', isEqualTo: selectedCategory)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: CafeTheme.primaryGold,
                  ),
                );
              }
              var prods = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return searchQuery.isEmpty ||
                    (data['name'] ?? "").toString().contains(searchQuery);
              }).toList();

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: prods.length,
                itemBuilder: (c, i) {
                  var prod = prods[i].data() as Map<String, dynamic>;
                  bool hasSizes = prod['sizes'] != null &&
                      (prod['sizes'] as List).isNotEmpty;
                  String? imgUrl = prod['image_url'];

                  return GestureDetector(
                    onTap: () => _showWaiterAddDialog(prod),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: (imgUrl != null && imgUrl.isNotEmpty)
                                ? Image.network(
                                    imgUrl,
                                    width: 55,
                                    height: 55,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.fastfood,
                                    color: CafeTheme.primaryGold,
                                    size: 40,
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Text(
                              prod['name'],
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            hasSizes ? "أحجام مختلفة" : "${prod['price']} ج.م",
                            style: TextStyle(
                              color: hasSizes
                                  ? Colors.orangeAccent
                                  : CafeTheme.primaryGold,
                              fontWeight: FontWeight.bold,
                              fontSize: hasSizes ? 11 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (waiterBasket.isNotEmpty) _buildBasketSummary(),
      ],
    );
  }

  // Best-effort extraction of a sortable time from an order document,
  // trying every field name an order could plausibly have been stamped
  // with. Missing/unknown fields fall back to "epoch zero" instead of
  // throwing, so a document is never excluded from the list just because
  // its timestamp field doesn't match what we expected.
  DateTime _orderSortTime(Map<String, dynamic> data) {
    for (final key in const ['timestamp', 'created_at', 'createdAt']) {
      final v = data[key];
      if (v is Timestamp) return v.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _buildOrdersManagementView() {
    // NOTE: root cause fix — this used to be
    // `.orderBy('timestamp', descending: true)`. No code path in this app
    // ever writes a `timestamp` field to an order document (orders are
    // created through the backend API in api_service.dart, which never
    // sets one), so Firestore's orderBy was silently excluding EVERY order
    // from the results the moment it didn't carry that exact field —
    // orders saved successfully but the waiter/admin screen showed nothing,
    // or showed only some. Removing the server-side orderBy and sorting on
    // the client instead guarantees every saved order is always shown,
    // regardless of which timestamp field (if any) it was written with.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: CafeTheme.primaryGold),
          );
        }
        var orders = List<QueryDocumentSnapshot>.from(snapshot.data!.docs)
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>? ?? {};
            final bData = b.data() as Map<String, dynamic>? ?? {};
            return _orderSortTime(bData).compareTo(_orderSortTime(aData));
          });
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              "لا توجد طلبات حالياً",
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (c, i) {
            var data = orders[i].data() as Map<String, dynamic>;
            String status = data['status'] ?? "قيد الانتظار";
            Color sColor = status == "جاهز"
                ? Colors.greenAccent
                : (status == "جاري التجهيز"
                    ? Colors.orangeAccent
                    : Colors.white38);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sColor.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "طاولة ${data['table_number'] ?? '?'}",
                        style: const TextStyle(
                          color: CafeTheme.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: sColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: sColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['customer_name'] ?? "",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  _orderMetaSection(data),
                  _orderTotalRow(data),
                  if (data['prize_info'] is Map)
                    _prizeInfoCard(
                        Map<String, dynamic>.from(data['prize_info'] as Map))
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _badge('Reward Applied: No', Colors.white38),
                    ),
                  const SizedBox(height: 8),
                  // أزرار تغيير الحالة
                  Row(
                    children: [
                      _statusButton(
                        "قيد الانتظار",
                        Colors.white38,
                        status,
                        orders[i].id,
                      ),
                      const SizedBox(width: 8),
                      _statusButton(
                        "جاري التجهيز",
                        Colors.orangeAccent,
                        status,
                        orders[i].id,
                      ),
                      const SizedBox(width: 8),
                      _statusButton(
                        "جاهز",
                        Colors.greenAccent,
                        status,
                        orders[i].id,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // بيظهر إجمالي الطلب دايماً في لوحة الإدارة — لو الطلب فيه خصم (prize_info
  // من نوع Discount) بيعرض الإجمالي قبل الخصم وبعد الخصم مع بعض بشكل واضح،
  // ولو مفيش خصم بيعرض الإجمالي العادي بس. قبل كده لوحة الإدارة ماكنتش
  // بتعرض إجمالي الطلب خالص إلا لو فيه هدية مستخدمة.
  // رقم الطلب / رقم الهاتف / الأصناف / طريقة الدفع / وقت الطلب — كل البيانات
  // دي بتيجي من نفس الحقول اللي بيبعتها العميل مع الأوردر (المصدر الوحيد،
  // مفيش أي حسابات تتعمل تاني هنا).
  Widget _orderMetaSection(Map<String, dynamic> data) {
    final orderNumber = data['order_number']?.toString();
    final phone = data['customer_phone']?.toString();
    final paymentMethod = data['payment_method']?.toString();
    final items = data['items_with_qty'] is List
        ? List<Map<String, dynamic>>.from((data['items_with_qty'] as List).map(
            (e) =>
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
        : <Map<String, dynamic>>[];
    String? orderTime;
    if (data['client_order_time'] is String) {
      final parsed = DateTime.tryParse(data['client_order_time'] as String);
      if (parsed != null) orderTime = parsed.toString().substring(0, 16);
    }

    final rows = <Widget>[];
    if (orderNumber != null && orderNumber.isNotEmpty) {
      rows.add(_metaLine("🔢 رقم الطلب", orderNumber));
    }
    if (phone != null && phone.isNotEmpty) {
      rows.add(_metaLine("📱 الهاتف", phone));
    }
    if (items.isNotEmpty) {
      final itemsStr =
          items.map((e) => "${e['name']} × ${e['qty']}").join('، ');
      rows.add(_metaLine("🛒 الأصناف", itemsStr));
    }
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      rows.add(_metaLine("💳 الدفع", paymentMethod));
    }
    if (orderTime != null) {
      rows.add(_metaLine("🕒 الوقت", orderTime));
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }

  Widget _metaLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 11.5, color: Colors.white54),
            children: [
              TextSpan(text: "$label: "),
              TextSpan(
                text: value,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );

  Widget _orderTotalRow(Map<String, dynamic> data) {
    final orderTotal = (data['total'] as num?)?.toDouble();
    final prizeInfo = data['prize_info'] is Map
        ? Map<String, dynamic>.from(data['prize_info'] as Map)
        : null;
    final type =
        (data['reward_type'] ?? prizeInfo?['prize_type'])?.toString() ?? '';
    final isDiscount =
        type.toLowerCase().contains('discount') || type.contains('خصم');
    // Prefer the new top-level fields (sent directly with the order); fall
    // back to prize_info for orders saved before this update, so old orders
    // still display correctly.
    final subtotal = isDiscount
        ? ((data['original_total'] as num?)?.toDouble() ??
            (prizeInfo?['subtotal_before_discount'] as num?)?.toDouble())
        : null;
    final finalTotal = isDiscount
        ? ((data['final_total'] as num?)?.toDouble() ??
            (prizeInfo?['total_after_discount'] as num?)?.toDouble() ??
            orderTotal)
        : orderTotal;
    final deliveryFee = (data['delivery_fee'] as num?)?.toDouble();
    final grandTotal = (data['grand_total'] as num?)?.toDouble();

    final children = <Widget>[];

    if (isDiscount && subtotal != null && finalTotal != null) {
      children.add(Row(
        children: [
          const Text(
            "الإجمالي قبل الخصم: ",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          Text(
            "${subtotal.toStringAsFixed(2)} ج.م",
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "بعد الخصم: ",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            "${finalTotal.toStringAsFixed(2)} ج.م",
            style: const TextStyle(
              color: CafeTheme.primaryGold,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ));
    } else if (orderTotal != null) {
      children.add(Text(
        "الإجمالي: ${orderTotal.toStringAsFixed(2)} ج.م",
        style: const TextStyle(
          color: CafeTheme.primaryGold,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ));
    }

    // رسوم التوصيل + الإجمالي الكلي بيتعرضوا بس لو الطلب فعلاً فيه القيم دي
    // محفوظة (طلبات قديمة قبل التحديث مش هيبقى فيها الحقول دي، فبتتخطى).
    if (deliveryFee != null && grandTotal != null) {
      children.add(const SizedBox(height: 3));
      children.add(Text(
        "رسوم التوصيل: ${deliveryFee.toStringAsFixed(2)} ج.م  •  الإجمالي الكلي: ${grandTotal.toStringAsFixed(2)} ج.م",
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _prizeInfoCard(Map<String, dynamic> prize) {
    final type = prize['prize_type']?.toString() ?? '';
    final rewardType = prize['reward_type']?.toString();
    final isDiscount = type.toLowerCase().contains('discount');
    final subtotal = (prize['subtotal_before_discount'] as num?)?.toDouble();
    final discount = (prize['discount_applied'] as num?)?.toDouble();
    final finalTotal = (prize['total_after_discount'] as num?)?.toDouble();
    final percent = prize['discount_percent'];
    final amount = prize['discount_amount'];
    final freeItem = prize['free_item_name']?.toString();
    final freeItemValue = (prize['free_item_value'] as num?)?.toDouble();

    final lines = <String>[];
    if (isDiscount) {
      if (percent != null) lines.add('نسبة الخصم: $percent%');
      if (amount != null) lines.add('قيمة الخصم الثابتة: $amount ج.م');
      if (subtotal != null) {
        lines.add('السعر قبل الخصم: ${subtotal.toStringAsFixed(2)} ج.م');
      }
      if (discount != null) {
        lines.add('قيمة الخصم: -${discount.toStringAsFixed(2)} ج.م');
      }
      if (finalTotal != null) {
        lines.add('السعر بعد الخصم: ${finalTotal.toStringAsFixed(2)} ج.م');
      }
    } else if (freeItem != null && freeItem.isNotEmpty) {
      lines.add('الهدية المكتسبة: $freeItem');
      if (freeItemValue != null) {
        lines.add('قيمة الهدية: ${freeItemValue.toStringAsFixed(2)} ج.م');
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CafeTheme.primaryGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CafeTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Highly visible "Reward Applied: Yes" badge, so staff scanning a
          // long list of order cards can tell at a glance which orders used
          // a reward without reading every line.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _badge('🎁 Reward Applied: Yes', CafeTheme.accentGreen),
              if ((prize['winner_code'] ?? '').toString().isNotEmpty)
                _badge('كود : ${prize['winner_code']}', CafeTheme.primaryGold),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            rewardType ?? 'هدية مستخدمة',
            style: const TextStyle(
              color: CafeTheme.primaryGold,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (prize['prize_description'] != null &&
              (prize['prize_description'] as String).isNotEmpty)
            Text(
              prize['prize_description'],
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 10.5),
        ),
      );

  Widget _statusButton(
    String label,
    Color color,
    String currentStatus,
    String docId,
  ) {
    bool isSelected = currentStatus == label;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(docId)
              .update({'status': label});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.2)
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : Colors.white10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: CafeTheme.surface,
          title: const Text(
            "لوحة الويتر 🤵",
            style: TextStyle(
              color: CafeTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: CafeTheme.surface,
          selectedItemColor: CafeTheme.primaryGold,
          unselectedItemColor: Colors.white54,
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale),
              label: "نقطة البيع (POS)",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: "إدارة الطلبات",
            ),
          ],
        ),
        body: _currentTabIndex == 0
            ? _buildPOSView()
            : _buildOrdersManagementView(),
      ),
    );
  }

  Widget _buildBasketSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: CafeTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: waiterBasket.length,
              itemBuilder: (context, index) {
                var item = waiterBasket[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['name'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                if (item['qty'] > 1) {
                                  item['qty']--;
                                } else {
                                  waiterBasket.removeAt(index);
                                }
                              });
                            },
                          ),
                          Text(
                            "${item['qty']}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.greenAccent,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                item['qty']++;
                              });
                            },
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              "${(item['qty'] as num) * (item['price'] as num)} ج.م",
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 12,
                                color: CafeTheme.primaryGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item['note'] != null &&
                          item['note'] != "بدون ملاحظات")
                        Padding(
                          padding: const EdgeInsets.only(right: 5, bottom: 5),
                          child: Text(
                            "📝 ${item['note']}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _sendToBarista,
              child: const Text(
                "إرسال للباريستا 🚀",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
