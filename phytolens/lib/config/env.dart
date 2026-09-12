// lib/config/env.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get supabaseServiceKey => dotenv.env['SUPABASE_SERVICE_KEY'] ?? '';
  static String get razorpayTestKeyId => dotenv.env['RAZORPAY_TEST_KEY_ID'] ?? '';
  static String get razorpayTestKeySecret => dotenv.env['RAZORPAY_TEST_KEY_SECRET'] ?? '';
  static String get groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static String get groqApiKey2 => dotenv.env['GROQ_API_KEY_2'] ?? '';
  static String get groqApiKey3 => dotenv.env['GROQ_API_KEY_3'] ?? '';
  static String get plantnetApiKey => dotenv.env['PLANTNET_API_KEY'] ?? '';
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get geminiApiKey2 => dotenv.env['GEMINI_API_KEY_2'] ?? '';
  static String get geminiApiKey3 => dotenv.env['GEMINI_API_KEY_3'] ?? '';
  static String get geminiApiKey4 => dotenv.env['GEMINI_API_KEY_4'] ?? '';
  static String get geminiApiKey5 => dotenv.env['GEMINI_API_KEY_5'] ?? '';
}
