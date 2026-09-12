// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final freeIconPath = r'C:\Users\USER\.gemini\antigravity-ide\brain\900f6f9e-e595-4a4a-8870-b28c87a1d56c\phytolens_free_icon_1788459617196.jpg';
  final proIconPath = r'C:\Users\USER\.gemini\antigravity-ide\brain\900f6f9e-e595-4a4a-8870-b28c87a1d56c\phytolens_pro_icon_1788459628404.jpg';
  final farmIconPath = r'C:\Users\USER\.gemini\antigravity-ide\brain\900f6f9e-e595-4a4a-8870-b28c87a1d56c\phytolens_farm_icon_1788459653771.jpg';

  final resPath = r'd:\WEBSITES BUILT\Hack2UK\Plant-life\phytolens\android\app\src\main\res';
  final iosPath = r'd:\WEBSITES BUILT\Hack2UK\Plant-life\phytolens\ios\Runner';

  final androidSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  // Also copy to assets/images for splash screen use
  final assetsImagesPath = r'd:\WEBSITES BUILT\Hack2UK\Plant-life\phytolens\assets\images';

  await processIcon(freeIconPath, 'ic_launcher', resPath, androidSizes, iosPath, 'AppIcon');
  await processIcon(proIconPath, 'ic_pro', resPath, androidSizes, iosPath, 'pro_icon');
  await processIcon(farmIconPath, 'ic_farm', resPath, androidSizes, iosPath, 'farm_icon');

  // Copy to assets/images for in-app use
  await copyToAssets(freeIconPath, assetsImagesPath, 'icon_free.png');
  await copyToAssets(proIconPath, assetsImagesPath, 'icon_pro.png');
  await copyToAssets(farmIconPath, assetsImagesPath, 'icon_farm.png');
  
  print('Icons successfully generated!');
}

Future<void> copyToAssets(String sourceFile, String assetsPath, String fileName) async {
  final file = File(sourceFile);
  if (!file.existsSync()) {
    print('File not found for assets copy: $sourceFile');
    return;
  }
  final image = img.decodeImage(file.readAsBytesSync());
  if (image == null) return;
  
  final resized = img.copyResize(image, width: 512, height: 512);
  final outPath = '$assetsPath\\$fileName';
  File(outPath).writeAsBytesSync(img.encodePng(resized));
  print('Copied to assets: $outPath');
}

Future<void> processIcon(
  String sourceFile, 
  String androidName, 
  String resPath, 
  Map<String, int> androidSizes,
  String iosPath,
  String iosName,
) async {
  print('Processing $sourceFile...');
  final file = File(sourceFile);
  if (!file.existsSync()) {
    print('File not found: $sourceFile');
    return;
  }
  
  final image = img.decodeImage(file.readAsBytesSync());
  if (image == null) {
    print('Failed to decode image');
    return;
  }
  
  // Android
  for (var entry in androidSizes.entries) {
    final folder = entry.key;
    final size = entry.value;
    final resized = img.copyResize(image, width: size, height: size);
    
    final dir = Directory('$resPath\\$folder');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    
    final outPath = '$resPath\\$folder\\$androidName.png';
    File(outPath).writeAsBytesSync(img.encodePng(resized));
    print('Created $outPath');
  }
  
  // iOS (1024x1024 base icon)
  final iosResized = img.copyResize(image, width: 1024, height: 1024);
  final iosOutPath = '$iosPath\\$iosName.png';
  File(iosOutPath).writeAsBytesSync(img.encodePng(iosResized));
  print('Created $iosOutPath');
}
