import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/colors.dart';

class AvatarPickerScreen extends StatelessWidget {
  final String currentAvatarUrl;

  const AvatarPickerScreen({super.key, required this.currentAvatarUrl});

  @override
  Widget build(BuildContext context) {
    // Generate 100 avatar URLs
    final List<String> avatars = List.generate(
      100,
      (index) => 'https://api.dicebear.com/7.x/bottts/png?seed=${index + 1}',
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text('Choose Avatar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: avatars.length,
        itemBuilder: (context, index) {
          final url = avatars[index];
          final isSelected = url == currentAvatarUrl;

          return GestureDetector(
            onTap: () {
              Navigator.pop(context, url);
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: AppColors.error),
                ),
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: (index % 10) * 20)).scale(),
          );
        },
      ),
    );
  }
}
