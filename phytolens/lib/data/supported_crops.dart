// lib/data/supported_crops.dart

class CropModel {
  final String name;
  final String emoji;
  final String imageUrl; // Wikimedia Commons CDN — royalty-free
  final List<String> conditions;

  const CropModel({
    required this.name,
    required this.emoji,
    required this.imageUrl,
    required this.conditions,
  });
}

const List<CropModel> supportedCrops = [
  CropModel(
    name: 'Apple',
    emoji: '🍎',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Red_Apple.jpg/480px-Red_Apple.jpg',
    conditions: [
      'Apple Scab',
      'Black Rot',
      'Cedar Apple Rust',
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Blueberry',
    emoji: '🫐',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Blueberries_bush.jpg/480px-Blueberries_bush.jpg',
    conditions: [
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Cherry',
    emoji: '🍒',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Cherry_Stella444.jpg/480px-Cherry_Stella444.jpg',
    conditions: [
      'Powdery Mildew',
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Corn (Maize)',
    emoji: '🌽',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/480px-Camponotus_flavomarginatus_ant.jpg',
    conditions: [
      'Cercospora Leaf Spot / Gray Leaf Spot',
      'Common Rust',
      'Northern Leaf Blight',
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Grape',
    emoji: '🍇',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Merlot_Gaillac_AOC.jpg/480px-Merlot_Gaillac_AOC.jpg',
    conditions: [
      'Black Rot',
      'Esca (Black Measles)',
      'Leaf Blight (Isariopsis Leaf Spot)',
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Orange',
    emoji: '🍊',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Oranges_and_orange_juice.jpg/480px-Oranges_and_orange_juice.jpg',
    conditions: [
      'Haunglongbing (Citrus Greening)',
    ],
  ),
  CropModel(
    name: 'Peach',
    emoji: '🍑',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Georgia_peaches.jpg/480px-Georgia_peaches.jpg',
    conditions: [
      'Bacterial Spot',
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Pepper (Bell)',
    emoji: '🫑',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Capsicum_annuum_variety_fruits.jpg/480px-Capsicum_annuum_variety_fruits.jpg',
    conditions: [
      'Bacterial Spot',
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Potato',
    emoji: '🥔',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Potato_and_cross_section.jpg/480px-Potato_and_cross_section.jpg',
    conditions: [
      'Early Blight',
      'Late Blight',
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Raspberry',
    emoji: '🍓',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Hapus_Mango.jpg/480px-Hapus_Mango.jpg',
    conditions: [
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Soybean',
    emoji: '🌱',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f8/Soybean.USDA.jpg/480px-Soybean.USDA.jpg',
    conditions: [
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Squash',
    emoji: '🎃',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Squash_growing.jpg/480px-Squash_growing.jpg',
    conditions: [
      'Powdery Mildew',
    ],
  ),
  CropModel(
    name: 'Strawberry',
    emoji: '🍓',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/PerfectStrawberry.jpg/480px-PerfectStrawberry.jpg',
    conditions: [
      'Leaf Scorch',
      'Healthy',
    ],
  ),
  CropModel(
    name: 'Tomato',
    emoji: '🍅',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/89/Tomato_je.jpg/480px-Tomato_je.jpg',
    conditions: [
      'Bacterial Spot',
      'Early Blight',
      'Late Blight',
      'Leaf Mold',
      'Septoria Leaf Spot',
      'Spider Mites (Two-spotted spider mite)',
      'Target Spot',
      'Tomato Yellow Leaf Curl Virus',
      'Tomato Mosaic Virus',
      'Healthy',
    ],
  ),
];
