import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'presentation/controllers/app_controller.dart';
import 'presentation/screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style matching Serene Clinical
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize SQLite DB, Notifications & Initial state
  await AppController.instance.initialize();

  runApp(const DoseCareApp());
}

class DoseCareApp extends StatelessWidget {
  const DoseCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoseCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.sereneClinicalTheme,
      home: const SplashScreen(),
    );
  }
}
