// lib/screens/profile/edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/app_user.dart';
import '../../services/supabase_service.dart';
import '../../theme/colors.dart';
import '../../widgets/bouncing_button.dart';
import '../../providers/user_provider.dart';
import 'avatar_picker_screen.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;

  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _supabase = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _bioCtrl;

  late String _currentAvatarUrl;
  String? _selectedGardenType;
  bool _isSaving = false;

  final List<String> _gardenOptions = [
    '🪴 Balcony / Indoor',
    '🏡 Backyard Garden',
    '🚜 Farm / Orchard',
    '🌿 Greenhouse / Nursery',
    '💧 Hydroponics',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
    _locationCtrl = TextEditingController(text: widget.user.location ?? '');
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
    _currentAvatarUrl = widget.user.avatarUrl ?? '';
    _selectedGardenType = widget.user.gardenType ?? _gardenOptions.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGooglePhoto() async {
    final googlePhoto = Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'] as String?;
    if (googlePhoto != null && googlePhoto.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() => _currentAvatarUrl = googlePhoto);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF00E5A3), size: 18),
              SizedBox(width: 8),
              Text('Fetched Google profile picture!'),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No photo found in your Google Account.'),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickAvatar() async {
    final newUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AvatarPickerScreen(
          currentAvatarUrl: _currentAvatarUrl,
        ),
      ),
    );

    if (newUrl != null && newUrl.isNotEmpty) {
      setState(() => _currentAvatarUrl = newUrl);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final uid = widget.user.uid;
      final newName = _nameCtrl.text.trim();
      final newPhone = _phoneCtrl.text.trim();
      final newLocation = _locationCtrl.text.trim();
      final newBio = _bioCtrl.text.trim();

      // Update Supabase
      await _supabase.updateUserProfile(
        uid,
        displayName: newName,
        avatarUrl: _currentAvatarUrl,
        phone: newPhone.isEmpty ? null : newPhone,
        location: newLocation.isEmpty ? null : newLocation,
        bio: newBio.isEmpty ? null : newBio,
        gardenType: _selectedGardenType,
      );

      // Update Supabase user metadata if possible
      try {
        if (_currentAvatarUrl.isNotEmpty || newName.isNotEmpty) {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {
              if (newName.isNotEmpty) 'full_name': newName,
              if (_currentAvatarUrl.isNotEmpty) 'avatar_url': _currentAvatarUrl,
            }),
          );
        }
      } catch (_) {}

      // Invalidate Riverpod currentUser
      ref.invalidate(currentUserProvider);

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF00E5A3), size: 20),
              SizedBox(width: 10),
              Text('Profile updated successfully! ✨'),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFarm = widget.user.isFarm;
    final isPro = widget.user.isPro && !isFarm;
    final tierColor = isFarm
        ? const Color(0xFFFFD700)
        : (isPro ? const Color(0xFF00BCD4) : AppColors.primary);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Avatar Centerpiece
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: tierColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: tierColor.withValues(alpha: 0.25),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _currentAvatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _currentAvatarUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: AppColors.cardDark,
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => _buildFallbackInitial(),
                                )
                              : _buildFallbackInitial(),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: BouncingButton(
                          onTap: _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tierColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.backgroundDark, width: 2.5),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Avatar Switch Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BouncingButton(
                        onTap: _fetchGooglePhoto,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.lightBorder),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.g_mobiledata_rounded, color: Colors.redAccent, size: 22),
                              SizedBox(width: 4),
                              Text(
                                'Fetch Google Photo',
                                style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      BouncingButton(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.lightBorder),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.palette_outlined, color: AppColors.primaryDark, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Avatar Presets',
                                style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Tier Badge indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tierColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(
                    isFarm ? Icons.agriculture_rounded : (isPro ? Icons.workspace_premium_rounded : Icons.eco_rounded),
                    color: tierColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.user.isPaidActive ? widget.user.subscriptionTier.toUpperCase() : 'TRIAL'} MEMBER',
                          style: TextStyle(
                            color: tierColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Level ${widget.user.level} • ${widget.user.levelTitle}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Form Fields
            _buildSectionHeader('PERSONAL DETAILS'),
            const SizedBox(height: 12),

            // Display Name
            _buildTextField(
              controller: _nameCtrl,
              label: 'Display Name',
              hint: 'e.g. Priyanshu Pradhan',
              icon: Icons.person_outline_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name cannot be empty' : null,
            ),
            const SizedBox(height: 16),

            // Email (Locked / Read-Only)
            _buildLockedEmailField(),
            const SizedBox(height: 16),

            // Phone Number (Optional)
            _buildTextField(
              controller: _phoneCtrl,
              label: 'Phone Number (Optional)',
              hint: '+91 98765 43210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('BOTANY & LOCATION'),
            const SizedBox(height: 12),

            // Location
            _buildTextField(
              controller: _locationCtrl,
              label: 'Farm / City Location',
              hint: 'e.g. Bangalore, Karnataka',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 18),

            // Garden Type
            const Text(
              'Primary Garden Type',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _gardenOptions.map((opt) {
                final isSelected = _selectedGardenType == opt;
                return BouncingButton(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedGardenType = opt);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.lightBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Bio / Farming Notes
            _buildSectionHeader('BIO & NOTES'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _bioCtrl,
              label: 'About Your Crops / Garden',
              hint: 'e.g. Growing organic tomatoes, chillies, and terrace herbs.',
              icon: Icons.notes_rounded,
              maxLines: 3,
            ),

            const SizedBox(height: 36),

            // Big Save Button
            BouncingButton(
              onTap: _isSaving ? null : _saveProfile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tierColor,
                      tierColor.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: tierColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSaving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: isFarm ? const Color(0xFF1A1200) : Colors.white,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isFarm ? const Color(0xFF1A1200) : Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 70),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackInitial() {
    final initial = widget.user.displayName.isNotEmpty
        ? widget.user.displayName[0].toUpperCase()
        : 'P';
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildLockedEmailField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Email Address',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lightCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textMuted),
                    SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.user.email,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Google Authenticated • Email cannot be changed for account security',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.primaryDark, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
