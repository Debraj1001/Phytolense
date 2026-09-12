// lib/config/constants.dart

import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'PhytoLens Admin';

  // Supabase Tables
  static const String tableUsers = 'users';
  static const String tableScanHistory = 'scan_history';
  static const String tableAiUsage = 'ai_usage';
  static const String tablePayments = 'payments';
  static const String tableCoupons = 'coupons';
  static const String tableAppConfig = 'app_config';

  // Tiers
  static const String tierFree = 'free';
  static const String tierPro = 'pro';
  static const String tierFarm = 'farm';
}

class AdminColors {
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color primary = Color(0xFF10B981);
  static const Color primaryLight = Color(0xFF34D399);
  static const Color secondary = Color(0xFF06B6D4);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFF334155);
}
