import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_preferences.dart';
import 'data/firebase_helper.dart';
import 'screen/welcome.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FirebaseHelper.initializeFirebase();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: AppPreferences.instance.locale,
          supportedLocales: AppPreferences.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            textTheme: GoogleFonts.poppinsTextTheme(
              Theme.of(context).textTheme,
            ),
            appBarTheme: AppBarTheme(
              toolbarHeight: 60,
              centerTitle: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 2,
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
      },
    );
  }
}
