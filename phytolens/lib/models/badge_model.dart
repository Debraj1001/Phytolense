// lib/models/badge_model.dart

import 'package:flutter/material.dart';
class BadgeModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int xpReward;
  final bool isEarned;
  final DateTime? earnedAt;

  const BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.xpReward,
    this.isEarned = false,
    this.earnedAt,
  });

  static const List<BadgeModel> allBadges = [
    BadgeModel(
      id: 'first_scan',
      title: 'First Scan',
      icon: Icons.eco_outlined,
      description: 'Your journey begins!',
      xpReward: 10,
    ),
    BadgeModel(
      id: 'plant_detective',
      title: 'Plant Detective',
      icon: Icons.science_outlined,
      description: 'Scanned 10 different plants',
      xpReward: 50,
    ),
    BadgeModel(
      id: 'health_hero',
      title: 'Health Hero',
      icon: Icons.medical_services_outlined,
      description: 'Found 5 diseases early',
      xpReward: 75,
    ),
    BadgeModel(
      id: 'remedy_master',
      title: 'Remedy Master',
      icon: Icons.medication_outlined,
      description: 'Applied 10 treatments',
      xpReward: 80,
    ),
    BadgeModel(
      id: 'perfect_score',
      title: 'Perfect Score',
      icon: Icons.camera_alt_outlined,
      description: '100/100 health score!',
      xpReward: 100,
    ),
    BadgeModel(
      id: 'week_warrior',
      title: 'Week Warrior',
      icon: Icons.local_fire_department_outlined,
      description: '7-day scanning streak',
      xpReward: 100,
    ),
    BadgeModel(
      id: 'monthly_master',
      title: 'Monthly Master',
      icon: Icons.workspace_premium_outlined,
      description: '30-day scanning streak',
      xpReward: 300,
    ),
    BadgeModel(
      id: 'global_citizen',
      title: 'Global Citizen',
      icon: Icons.public_outlined,
      description: 'Scanned plants from 5 species',
      xpReward: 150,
    ),
    BadgeModel(
      id: 'ai_guru',
      title: 'AI Guru',
      icon: Icons.smart_toy_outlined,
      description: 'Used AI advice 50 times',
      xpReward: 200,
    ),
    BadgeModel(
      id: 'farmer_pro',
      title: 'Farmer Pro',
      icon: Icons.agriculture_outlined,
      description: 'Scanned 100 plants total',
      xpReward: 500,
    ),
    BadgeModel(
      id: 'phytolens_legend',
      title: 'PhytoLens Legend',
      icon: Icons.emoji_events_outlined,
      description: 'All badges collected!',
      xpReward: 1000,
    ),
  ];

  BadgeModel copyWith({bool? isEarned, DateTime? earnedAt}) => BadgeModel(
    id: id,
    title: title,
    description: description,
    icon: icon,
    xpReward: xpReward,
    isEarned: isEarned ?? this.isEarned,
    earnedAt: earnedAt ?? this.earnedAt,
  );
}
