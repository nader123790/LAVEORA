import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'dart:js' as js;
import 'dart:html' as html;

import 'firebase_options.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> sendTelegramMessage(String message) async {
  try {
    var url = Uri.parse(
      "https://onesignal-server-nine.vercel.app/api/telegram",
    );
    var response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"message": message}),
    );
    print("Telegram Status: ${response.statusCode}");
    print("Telegram Response: ${response.body}");
  } catch (e) {
    print("Telegram Error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }
  runApp(const LaveoraLuxuryApp());
}

class CafeTheme {
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color darkBg = Color(0xFF000000);
  static const Color surface = Color(0xFF161616);
  static const Color accentGreen = Color(0xFF4CAF50);
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
        return StatefulBuilder(builder: (context, setSheetState) {
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
                      prefixIcon: const Icon(Icons.search,
                          color: CafeTheme.primaryGold),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  color: selected ? Colors.black : Colors.white,
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
        });
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
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          var data = change.doc.data() as Map<String, dynamic>;
          String status = data['status'];
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
    });
  }

  void _showStatusSnackBar(String message, Color color) {
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
              _devLink(Icons.chat_bubble_outline, "WhatsApp", Colors.green,
                  "https://wa.me/qr/QS4SMJ54AKJMF1"),
              _devLink(Icons.facebook_outlined, "Facebook", Colors.blueAccent,
                  "https://www.facebook.com/share/1ByWx21qNW/"),
              _devLink(
                  Icons.camera_alt_outlined,
                  "Instagram",
                  Colors.pinkAccent,
                  "https://www.instagram.com/nadersoltan294?igsh=bDB5eTB3Z2NrMmF6"),
              _devLink(Icons.video_collection_outlined, "TikTok", Colors.white,
                  "https://www.tiktok.com/@nadersoltan6?_r=1&_t=ZS-93Uf8vOauIB"),
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
            onPressed: () {
              if (passwordCtrl.text == "1234") {
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
                    icon: const Icon(Icons.lock_person,
                        color: CafeTheme.primaryGold, size: 18),
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
        CustomScrollView(
          slivers: [
            _buildAppBar(),
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
                  Icon(Icons.code_rounded,
                      color: CafeTheme.primaryGold, size: 20),
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
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
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
                    CafeTheme.primaryGold);
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
                color: CafeTheme.primaryGold
                    .withOpacity(0.4 + (0.6 * _glowController.value)),
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
                                  ? const Icon(Icons.restaurant,
                                      color: CafeTheme.primaryGold)
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
                            horizontal: 18, vertical: 12),
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
                                        Color(0xFFB8860B)
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
                          child: const Icon(Icons.fastfood,
                              color: CafeTheme.primaryGold),
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
        return StatefulBuilder(builder: (context, setDialogState) {
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
                        color: Colors.white70, fontWeight: FontWeight.bold),
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
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 13),
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
        });
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
                  ],
                ),
              );
            },
          ),
        );
      },
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

  Widget _buildCheckoutBar() {
    double currentBasketTotal = basket.fold(
      0.0,
      (previousValue, item) =>
          previousValue + ((item['price'] as num) * (item['quantity'] as num)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 20, 35, 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "المبلغ الحالي",
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              Text(
                "${currentBasketTotal.toStringAsFixed(2)} ج.م",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: CafeTheme.primaryGold,
                ),
              ),
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
                onPressed: basket.isEmpty ? null : _sendOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CafeTheme.primaryGold,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
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
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 16),
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

  void _sendOrder() async {
    if (basket.isEmpty || registeredName == null) return;

    Map<String, dynamic> orderData = {
      'customer_name': registeredName,
      'order_type': 'داخل المكان',
      'table_number': currentTable,
      'items_with_qty':
          basket.map((e) => {'name': e['name'], 'qty': e['quantity']}).toList(),
      'note': basket.any((e) => e['note'] != "بدون إضافات")
          ? basket.firstWhere((e) => e['note'] != "بدون إضافات")['note']
          : "بدون إضافات",
      'total_price': basket.fold(
        0.0,
        (previousValue, item) =>
            previousValue +
            ((item['price'] as num) * (item['quantity'] as num)),
      ),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'قيد الانتظار',
    };

    await FirebaseFirestore.instance.collection('orders').add(orderData);

    await sendTelegramMessage(
        "🚀 طلب جديد من $registeredName - طاولة $currentTable");

    setState(() {
      basket.clear();
    });
    _showStatusSnackBar("تم إرسال طلبك! 🚀", Colors.greenAccent);
  }

  void _callWaiter() async {
    if (_isWaiterAlertActive || registeredName == null) return;
    setState(() => _isWaiterAlertActive = true);
    await FirebaseFirestore.instance.collection('alerts').add({
      'customer_name': registeredName,
      'table_number': currentTable,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await sendTelegramMessage(
        "🔔 نداء ويتر من طاولة $currentTable - العميل: $registeredName");
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
        return StatefulBuilder(builder: (context, setDialogState) {
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
                        color: Colors.white70, fontWeight: FontWeight.bold),
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
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 13),
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
                    String note =
                        noteCtrl.text.isEmpty ? "بدون ملاحظات" : noteCtrl.text;

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
        });
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

    await FirebaseFirestore.instance.collection('orders').add({
      'customer_name': customerName,
      'order_type': 'داخل المكان',
      'table_number': tableCtrl.text,
      'items_with_qty': waiterBasket
          .map((e) => {'name': e['name'], 'qty': e['qty']})
          .toList(),
      'note': notesStr,
      'total_price': total,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'قيد الانتظار',
      'source': 'waiter',
    });

    await sendTelegramMessage(
        "🤵 ويتر أضاف طلب - طاولة ${tableCtrl.text} - $customerName");

    setState(() => waiterBasket.clear());
    _showSnack("تم الإرسال للباريستا ✅", Colors.green);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black)),
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
                    prefixIcon: const Icon(Icons.table_restaurant,
                        color: CafeTheme.primaryGold),
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
                    prefixIcon:
                        const Icon(Icons.person, color: CafeTheme.primaryGold),
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
                    prefixIcon:
                        const Icon(Icons.search, color: CafeTheme.primaryGold),
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
                          horizontal: 20, vertical: 8),
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
                  child:
                      CircularProgressIndicator(color: CafeTheme.primaryGold),
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
                                ? Image.network(imgUrl,
                                    width: 55, height: 55, fit: BoxFit.cover)
                                : const Icon(Icons.fastfood,
                                    color: CafeTheme.primaryGold, size: 40),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
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

  Widget _buildOrdersManagementView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: CafeTheme.primaryGold));
        }
        var orders = snapshot.data!.docs;
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
                            horizontal: 12, vertical: 5),
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

  Widget _statusButton(
      String label, Color color, String currentStatus, String docId) {
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
            border: Border.all(
              color: isSelected ? color : Colors.white10,
            ),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
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
