import 'package:flutter/material.dart';
import 'package:flutter_application_2/splash_screen.dart';
// استيراد إحدى الشاشات الجديدة كنقطة بداية

// أو import 'signup_screen.dart'; إذا أردت البدء بإنشاء الحساب

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // تعريف الألوان الأساسية للثيم (تبقى كما هي)
    const Color primaryColor = Color.fromRGBO(105, 124, 107, 1);
    const Color backgroundColor = Color.fromRGBO(242, 222, 197, 1);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Handyman App',
      theme: ThemeData( // الثيم الموحد يبقى كما هو
          primaryColor: primaryColor,
          scaffoldBackgroundColor: backgroundColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor,
            background: backgroundColor,
            primary: primaryColor,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
             style: ElevatedButton.styleFrom(
               backgroundColor: primaryColor,
               foregroundColor: Colors.white,
               padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
               textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
             )
          ),
          inputDecorationTheme: InputDecorationTheme(
             filled: true,
             fillColor: Colors.white.withOpacity(0.8),
             contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 15.0),
             border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
             ),
             enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
             ),
             focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: primaryColor, width: 1.5),
             ),
             labelStyle: TextStyle(color: Colors.grey[800], fontSize: 14, fontWeight: FontWeight.w500),
             floatingLabelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
             prefixIconColor: primaryColor.withOpacity(0.7),
          ),
          checkboxTheme: CheckboxThemeData(
             fillColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) return primaryColor;
                return null;
             }),
             checkColor: MaterialStateProperty.all(Colors.white),
             side: BorderSide(color: Colors.grey.shade500)
          ),
          radioTheme: RadioThemeData(
            fillColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) return primaryColor;
                return Colors.grey.shade600;
             }),
          ),
          useMaterial3: true,
       ),
       // --- تحديد شاشة البداية ---
      home: const WelcomeScreen(), // ابدأ بشاشة تسجيل الدخول
      // أو home: const SignUpScreen(), // إذا أردت البدء بشاشة إنشاء الحساب
    );
  }
}