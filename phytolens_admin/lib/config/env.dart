// lib/config/env.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get supabaseServiceKey => dotenv.env['SUPABASE_SERVICE_KEY'] ?? '';
  static String get adminPin => dotenv.env['ADMIN_PIN'] ?? '1234';
}
