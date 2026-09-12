import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:phytolens/theme/colors.dart';
import 'package:phytolens/screens/home/home_screen.dart';
import 'package:phytolens/services/supabase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumTransformationScreen extends ConsumerStatefulWidget {
  final String tier;

  const PremiumTransformationScreen({super.key, required this.tier});

  @override
  ConsumerState<PremiumTransformationScreen> createState() => _PremiumTransformationScreenState();
}

class _PremiumTransformationScreenState extends ConsumerState<PremiumTransformationScreen> with SingleTickerProviderStateMixin {
  bool _startTear = false;
  bool _isAnimatingOut = false;

  @override
  void initState() {
    super.initState();
    _startTransformation();
  }

  Future<void> _startTransformation() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initial pause before tear begins
    await Future.delayed(const Duration(milliseconds: 400));
    
    if (mounted) {
      setState(() => _startTear = true);
    }

    // Fetch user data
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final user = await SupabaseService().getUser(uid);
      if (user != null) {
        // AppUser fetched, HomeScreen will rebuild and fetch it again anyway.
      }
    }

    try {
      if (await FlutterDynamicIconPlus.supportsAlternateIcons) {
        final iconName = widget.tier == 'pro' ? 'pro_icon' : 'farm_icon';
        await FlutterDynamicIconPlus.setAlternateIconName(iconName: iconName);
      }
    } catch (e) {
      debugPrint('Failed to set dynamic icon: \$e');
    }

    // Wait for the designer reveal to complete its majestic sequence
    await Future.delayed(const Duration(milliseconds: 3500));

    if (!mounted) return;
    setState(() {
      _isAnimatingOut = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = widget.tier == 'pro';
    final primaryColor = isPro ? AppColors.primary : AppColors.warning;
    
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black, // Revealed background is deep black
      body: Stack(
        children: [
          // 1. The Revealed Premium Layer (Underneath the tear)
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Ambient Glow
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.15),
                          blurRadius: 100,
                          spreadRadius: 50,
                        ),
                      ],
                    ),
                  ),
                ).animate(target: _startTear ? 1 : 0).scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 1500.ms, curve: Curves.easeOutCubic),
                
                // Typography and Elegance
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isPro ? 'PRO' : 'FARM',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w200, // Ultra-thin elegant typography
                          color: Colors.white,
                          letterSpacing: 12,
                        ),
                      )
                      .animate(target: _startTear ? 1 : 0)
                      .fadeIn(delay: 500.ms, duration: 1000.ms)
                      .slideY(begin: 0.1, end: 0, duration: 1000.ms, curve: Curves.easeOutCubic)
                      .shimmer(delay: 1500.ms, duration: 2.seconds, color: primaryColor.withValues(alpha: 0.5)),

                      const SizedBox(height: 16),

                      Text(
                        'UNLOCKED',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: 4,
                        ),
                      )
                      .animate(target: _startTear ? 1 : 0)
                      .fadeIn(delay: 800.ms, duration: 1000.ms)
                      .slideY(begin: 0.2, end: 0, duration: 1000.ms, curve: Curves.easeOutCubic),
                    ],
                  ),
                ),
              ],
            )
            .animate(target: _isAnimatingOut ? 1 : 0)
            .fadeOut(duration: 600.ms, curve: Curves.easeInOut),
          ),

          // 2. Top Half Tear (The original screen tearing away)
          ClipPath(
            clipper: _DiagonalClipper(isTop: true),
            child: Container(
              color: AppColors.backgroundDark,
              width: double.infinity,
              height: double.infinity,
            ),
          )
          .animate(target: _startTear ? 1 : 0)
          .move(
            begin: const Offset(0, 0), 
            end: Offset(-100, -height), 
            duration: 1800.ms, 
            curve: Curves.easeInOutCubic
          ),

          // 3. Bottom Half Tear
          ClipPath(
            clipper: _DiagonalClipper(isTop: false),
            child: Container(
              color: AppColors.backgroundDark,
              width: double.infinity,
              height: double.infinity,
            ),
          )
          .animate(target: _startTear ? 1 : 0)
          .move(
            begin: const Offset(0, 0), 
            end: Offset(100, height), 
            duration: 1800.ms, 
            curve: Curves.easeInOutCubic
          ),
          
          // Smooth fade overlay into home screen
          if (_isAnimatingOut)
            Positioned.fill(
              child: Container(color: AppColors.backgroundDark)
                .animate()
                .fadeIn(duration: 800.ms, curve: Curves.easeInOut),
            ),
        ],
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  final bool isTop;
  _DiagonalClipper({required this.isTop});

  @override
  Path getClip(Size size) {
    final path = Path();
    // Diagonal cut from middle-left to bottom-right
    if (isTop) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height * 0.4);
      path.lineTo(0, size.height * 0.6);
      path.close();
    } else {
      path.moveTo(0, size.height * 0.6);
      path.lineTo(size.width, size.height * 0.4);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    }
    return path;
  }
  
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
