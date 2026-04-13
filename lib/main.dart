import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_preferences.dart';
import 'services/user_firestore_service.dart';
import 'services/firebase_helper.dart';
import 'effect/app_transitions.dart';
import 'services/notification_service.dart';
import 'screen/welcome.dart';
import 'shoppingservice/shopping_store_screen.dart';
import 'widget/ccp_logo.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

void _handleNotificationTapPayload(Map<String, dynamic> payload) {
  final String type = (payload['type'] ?? '').toString().trim().toLowerCase();
  if (type != 'new_service' &&
      type != 'promotion' &&
      type != 'uu_dai' &&
      type != 'shopping_discount') {
    return;
  }

  final String targetServiceId =
      (payload['service_id'] ??
              payload['serviceId'] ??
              payload['targetServiceId'] ??
              '')
          .toString()
          .trim();
  if (targetServiceId.isEmpty) {
    return;
  }

  final NavigatorState? navigator = _rootNavigatorKey.currentState;
  if (navigator == null) {
    return;
  }

  navigator.push(
    MaterialPageRoute<void>(
      settings: RouteSettings(
        arguments: <String, dynamic>{
          'isFromNotification': true,
          'targetServiceId': targetServiceId,
        },
      ),
      builder: (_) => ShoppingStoreScreen(
        isFromNotification: true,
        targetServiceId: targetServiceId,
        highlightServiceId: targetServiceId,
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const _AppBootstrapGate());
}

class _AppBootstrapGate extends StatefulWidget {
  const _AppBootstrapGate();

  @override
  State<_AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<_AppBootstrapGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareStartup());
  }

  Future<void> _prepareStartup() async {
    try {
      await AppPreferences.instance.loadSavedLocale().timeout(
        const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('Load locale failed: $e');
    }

    NotificationService().setOnNotificationTapHandler(
      _handleNotificationTapPayload,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    try {
      await dotenv.load(fileName: '.env').timeout(const Duration(seconds: 2));
      final String? clientId = dotenv.env['VIETQR_CLIENT_ID'];
      if (clientId != null && clientId.isNotEmpty) {
        final int previewLength = clientId.length < 5 ? clientId.length : 5;
        debugPrint('DotEnv loaded: ${clientId.substring(0, previewLength)}***');
      }
    } catch (e) {
      debugPrint('Error loading .env: $e');
    }

    try {
      await FirebaseHelper.initializeFirebase().timeout(
        const Duration(seconds: 6),
      );
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }

    try {
      await UserFirestoreService.instance.syncCurrentUserData().timeout(
        const Duration(seconds: 6),
      );
    } catch (e) {
      debugPrint('Initial user sync failed: $e');
    }

    try {
      await NotificationService().init().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Local notification init failed: $e');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const MyApp();
    }

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CCPLogoWidget()),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = AppPreferences.instance.locale;

  @override
  void initState() {
    super.initState();
    AppPreferences.instance.addListener(_handlePreferencesChanged);
  }

  @override
  void dispose() {
    AppPreferences.instance.removeListener(_handlePreferencesChanged);
    super.dispose();
  }

  void _handlePreferencesChanged() {
    if (!mounted) {
      return;
    }

    final Locale nextLocale = AppPreferences.instance.locale;
    if (nextLocale == _locale) {
      return;
    }

    setState(() {
      _locale = nextLocale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CCPBank',
      locale: _locale,
      supportedLocales: AppPreferences.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FD),
        textTheme: GoogleFonts.poppinsTextTheme(),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: GentlePageTransitionsBuilder(),
            TargetPlatform.iOS: GentlePageTransitionsBuilder(),
          },
        ),
        appBarTheme: AppBarTheme(
          toolbarHeight: 64,
          centerTitle: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0.5,
          shadowColor: Colors.black12,
          iconTheme: const IconThemeData(color: Color(0xFF000DC0)),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}
