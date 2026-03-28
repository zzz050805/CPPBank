import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_preferences.dart';
import 'data/user_firestore_service.dart';
import 'data/firebase_helper.dart';
import 'effect/app_transitions.dart';
import 'screen/welcome.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

void main() async {
  // 1. Khởi tạo ràng buộc Flutter (Bắt buộc khi dùng async trong main)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. NẠP CHÌA KHÓA TỪ FILE .ENV (Thêm phần này vào nè bro)
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('DotEnv loaded successfully!');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
    // Nếu lỗi, bro kiểm tra xem đã khai báo file .env trong pubspec.yaml chưa nhé
  }

  // 3. Khởi tạo Firebase
  try {
    await FirebaseHelper.initializeFirebase();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // 4. Đồng bộ dữ liệu User
  try {
    await UserFirestoreService.instance.syncCurrentUserData();
  } catch (e) {
    debugPrint('Initial user sync failed: $e');
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
            // Hiệu ứng chuyển trang mượt mà bro đang dùng
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: GentlePageTransitionsBuilder(),
                TargetPlatform.iOS: GentlePageTransitionsBuilder(),
              },
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