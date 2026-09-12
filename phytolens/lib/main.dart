// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/constants.dart';
import 'config/env.dart';
import 'theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env variables
  await dotenv.load(fileName: '.env');

  // Status bar overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,   // dark icons on light bg
      statusBarBrightness: Brightness.light,       // iOS
    ),
  );

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('Make sure you have configured Firebase using "flutterfire configure"');
  }

  // Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // Sync Service for offline caching and syncing
  SyncService().initialize();

  // Initialize FCM Push Notifications & Device Token Sync
  NotificationService().initialize();

  runApp(const ProviderScope(child: PhytoLensApp()));
}

class PhytoLensApp extends StatelessWidget {
  const PhytoLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhytoLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppConstants.routeSplash,
      routes: {
        AppConstants.routeSplash: (_) => const SplashScreen(),
        AppConstants.routeOnboarding: (_) => const OnboardingScreen(),
        AppConstants.routeLogin: (_) => const LoginScreen(),
        AppConstants.routeHome: (_) => const HomeScreen(),
      },
    );
  }
}
