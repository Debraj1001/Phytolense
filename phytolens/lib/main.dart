// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/constants.dart';
import 'config/env.dart';
import 'theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'services/language_service.dart';
import 'providers/language_provider.dart';
import 'widgets/app_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env variables
  await dotenv.load(fileName: '.env');

  // Initialize language service (loads persisted language preference)
  await LanguageService().init();

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

  // Supabase — wrapped for offline cold-start resilience
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('⚠️ Supabase initialization failed (likely offline): $e');
    debugPrint('App will continue in offline mode.');
  }

  // Non-blocking background services — don't hold up app launch
  Future.microtask(() {
    SyncService().initialize();
    NotificationService().initialize();
  });

  runApp(const ProviderScope(child: PhytoLensApp()));
}

class PhytoLensApp extends ConsumerWidget {
  const PhytoLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langService = ref.watch(languageProvider);
    final locale = Locale(langService.languageCode);

    return MaterialApp(
      title: 'PhytoLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('hi', 'IN'),
        Locale('bn', 'IN'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: appNavigatorKey,
      initialRoute: AppConstants.routeSplash,
      routes: {
        AppConstants.routeSplash: (_) => const SplashScreen(),
        AppConstants.routeOnboarding: (_) => const OnboardingScreen(),
        AppConstants.routeLogin: (_) => const LoginScreen(),
        AppConstants.routeHome: (_) => const HomeScreen(),
      },
      builder: (context, child) => AppGuard(child: child ?? const SizedBox.shrink()),
    );
  }
}
