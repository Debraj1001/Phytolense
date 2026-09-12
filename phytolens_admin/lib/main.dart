// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/constants.dart';
import 'config/env.dart';
import 'screens/login/admin_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Admin .env load error: $e');
  }

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Admin Supabase init error: $e');
  }

  runApp(const ProviderScope(child: PhytoLensAdminApp()));
}

class PhytoLensAdminApp extends StatelessWidget {
  const PhytoLensAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AdminColors.darkBg,
        colorScheme: const ColorScheme.dark(
          primary: AdminColors.primary,
          secondary: AdminColors.secondary,
          surface: AdminColors.darkSurface,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        useMaterial3: true,
      ),
      home: const AdminLoginScreen(),
    );
  }
}
