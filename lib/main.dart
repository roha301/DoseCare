import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'core/email/caregiver_email_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/controllers/app_controller.dart';
import 'presentation/screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set system UI overlay style matching Serene Clinical
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize SQLite DB, Notifications & Initial state
  await AppController.instance.initialize();

  // Background email reports run through Android's WorkManager; only
  // meaningful on Android, where the caregiver email toggles live.
  if (defaultTargetPlatform == TargetPlatform.android) {
    await Workmanager().initialize(caregiverEmailCallbackDispatcher);
  }

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
