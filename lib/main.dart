import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Thêm cái này để chỉnh thanh trạng thái
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_preferences.dart';
import 'core/local_notification_service.dart';
import 'data/user_firestore_service.dart';
import 'data/firebase_helper.dart';
import 'effect/app_transitions.dart';
import 'screen/welcome.dart';

void main() async {
  // 1. Khởi tạo ràng buộc Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Chỉnh thanh trạng thái (Status Bar) cho giống App ngân hàng thật
  // Giúp thanh pin, sóng trông trong suốt và đẹp hơn trên nền trắng
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          Brightness.dark, // Icon màu đen vì nền app mình màu sáng
    ),
  );

  // 3. Nạp chìa khóa bí mật (.env)
  try {
    await dotenv.load(fileName: ".env");
    // ignore: avoid_print
    print('Kiểm tra .env: ${dotenv.env.keys}');
    debugPrint(
      '✅ DotEnv loaded: ${dotenv.env['VIETQR_CLIENT_ID']?.substring(0, 5)}***',
    );
  } catch (e) {
    debugPrint('❌ Error loading .env: $e');
  }

  // 4. Khởi tạo Firebase
  try {
    await FirebaseHelper.initializeFirebase();
  } catch (e) {
    debugPrint('❌ Firebase init failed: $e');
  }

  // 5. Đồng bộ dữ liệu User (Nên chạy sau khi Firebase đã OK)
  try {
    await UserFirestoreService.instance.syncCurrentUserData();
  } catch (e) {
    debugPrint('❌ Initial user sync failed: $e');
  }

  // 6. Khởi tạo local notification để hiển thị popup kiểu SMS.
  try {
    await LocalNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('❌ Local notification init failed: $e');
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
          title: 'CCPBank', // Đặt tên app ở đây luôn bro
          locale: AppPreferences.instance.locale,
          supportedLocales: AppPreferences.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true, // Bật Material 3 cho giao diện hiện đại
            scaffoldBackgroundColor: const Color(
              0xFFF8F9FD,
            ), // Nền xám nhạt "quý tộc"
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
              toolbarHeight: 64,
              centerTitle: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent, // Tránh bị đổi màu khi cuộn
              elevation: 0.5, // Đổ bóng nhẹ thôi cho sang
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
