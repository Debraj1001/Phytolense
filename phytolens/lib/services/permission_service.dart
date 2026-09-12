// lib/services/permission_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/colors.dart';
import '../theme/design_tokens.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request camera permission for real-time plant diagnostics
  Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied || result.isDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context: context,
          title: 'Camera Access Needed',
          message: 'PhytoLens requires camera access to scan leaves, identify crop diseases, and provide instant agronomy treatments.',
          icon: Icons.camera_alt_rounded,
        );
      }
      return false;
    }
    return result.isGranted;
  }

  /// Request storage/photos permission to select images from gallery or save scan reports
  Future<bool> requestStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    // Check current statuses
    final photosStatus = await Permission.photos.status;
    final storageStatus = await Permission.storage.status;

    if (photosStatus.isGranted || photosStatus.isLimited || storageStatus.isGranted) {
      return true;
    }

    // Request permissions dynamically
    final statuses = await [
      Permission.photos,
      Permission.storage,
    ].request();

    final isGranted = (statuses[Permission.photos]?.isGranted ?? false) ||
        (statuses[Permission.photos]?.isLimited ?? false) ||
        (statuses[Permission.storage]?.isGranted ?? false);

    if (isGranted) return true;

    // If denied on device, display the PhytoLens Storage Permission modal
    if (context.mounted) {
      _showPermissionDialog(
        context: context,
        title: 'Storage & Photos Access Needed',
        message: 'PhytoLens needs access to your gallery and storage to pick plant photos, save diagnostic reports, and export farm health records.',
        icon: Icons.photo_library_rounded,
      );
    }

    // Return true on modern Android to let system photo picker attempt selection if user proceeds
    return false;
  }

  /// Prompt user to open device settings if permissions were permanently blocked
  void _showPermissionDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLG)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryLight, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusPill)),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
