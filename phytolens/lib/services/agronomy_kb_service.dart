// lib/services/agronomy_kb_service.dart
//
// Instant Offline Agronomy Knowledge Base Service.
// Provides zero-latency, zero-internet disease treatment protocols
// by looking up the bundled agronomy_kb.dart dictionary.
// This is the FIRST fallback (Tier 0) before the heavy SLM model.

import '../data/agronomy_kb.dart';
import 'language_service.dart';

class AgronomyKBService {
  static final AgronomyKBService _instance = AgronomyKBService._internal();
  factory AgronomyKBService() => _instance;
  AgronomyKBService._internal();

  /// Look up an agronomy entry by the raw TFLite label string.
  /// Returns null if the label is not in the knowledge base.
  AgronomyEntry? lookup(String tfliteLabel) {
    return agronomyKB[tfliteLabel];
  }

  /// Fuzzy lookup by plant name + disease name (for cases where
  /// exact TFLite label isn't available, e.g., from PlantNet results).
  AgronomyEntry? lookupByNames(String plantName, String diseaseName) {
    final plantLower = plantName.toLowerCase().trim();
    final diseaseLower = diseaseName.toLowerCase().trim();

    for (final entry in agronomyKB.values) {
      if (entry.plantName.toLowerCase().contains(plantLower) &&
          entry.diseaseName.toLowerCase().contains(diseaseLower)) {
        return entry;
      }
    }

    // Try partial match on disease only
    for (final entry in agronomyKB.values) {
      if (entry.diseaseName.toLowerCase().contains(diseaseLower)) {
        return entry;
      }
    }

    return null;
  }

  /// Generate a formatted offline report from the agronomy KB.
  /// [reportType]: 'basic', 'detailed', or 'full'
  String generateReport({
    required String plantName,
    required String diseaseName,
    required int healthScore,
    int? severityPercent,
    String reportType = 'detailed',
    String? tfliteLabel,
  }) {
    // Try exact label match first, then fuzzy name match
    final entry = tfliteLabel != null
        ? (agronomyKB[tfliteLabel] ?? lookupByNames(plantName, diseaseName))
        : lookupByNames(plantName, diseaseName);

    if (entry == null) {
      return _genericFallback(plantName, diseaseName, healthScore, reportType);
    }

    switch (reportType) {
      case 'basic':
        return _formatBasicReport(entry, healthScore);
      case 'full':
        return _formatFullReport(entry, healthScore, severityPercent);
      default:
        return _formatDetailedReport(entry, healthScore, severityPercent);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REPORT FORMATTERS
  // ═══════════════════════════════════════════════════════════════════════

  String _formatBasicReport(AgronomyEntry entry, int healthScore) {
    if (entry.pathogenType == 'healthy') {
      return '✅ **${entry.plantName}** looks healthy! Health score: $healthScore/100.\n\n'
          '${entry.quickSummary}';
    }

    final urgencyEmoji = entry.severity == 'critical'
        ? '🚨'
        : (entry.severity == 'high' ? '⚠️' : '🔍');

    return '$urgencyEmoji **${entry.diseaseName}** detected on **${entry.plantName}**. '
        'Health score: $healthScore/100.\n\n'
        '${entry.quickSummary}\n\n'
        '**Immediate Action:** ${entry.immediateActions.first}\n\n'
        '**Quick Remedy:** ${entry.organicRemedy.name} — ${entry.organicRemedy.dosage}';
  }

  String _formatDetailedReport(AgronomyEntry entry, int healthScore, int? severity) {
    final ls = LanguageService();
    if (entry.pathogenType == 'healthy') {
      return '## ✅ ${entry.plantName} — ${ls.tr("healthy")}\n\n'
          '**${ls.tr("report_health_score")}:** $healthScore/100\n\n'
          '${entry.quickSummary}\n\n'
          '### ${ls.tr("report_preventive_care")}\n'
          '${entry.preventionTips.map((t) => '- $t').join('\n')}\n\n'
          '### ${ls.tr("report_organic_boost")}\n'
          '- **${entry.organicRemedy.name}**: ${entry.organicRemedy.preparation}\n'
          '- ${ls.tr("report_dosage")}: ${entry.organicRemedy.dosage}\n'
          '- ${ls.tr("report_frequency")}: ${entry.organicRemedy.frequency}';
    }

    final severityStr = severity != null ? ' | ${ls.tr("severity")}: $severity%' : '';

    return '## ${entry.diseaseName} on ${entry.plantName}\n\n'
        '**${ls.tr("report_health_score")}:** $healthScore/100$severityStr\n'
        '**${ls.tr("report_type_label")}:** ${entry.pathogenType.toUpperCase()} | **${ls.tr("report_risk_label")}:** ${entry.severity.toUpperCase()}\n\n'
        '### ${ls.tr("report_what_is_this")}\n'
        '${entry.quickSummary}\n\n'
        '### ${ls.tr("report_immediate_actions")}\n'
        '${entry.immediateActions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}\n\n'
        '### ${ls.tr("report_organic_remedy")}\n'
        '- **${entry.organicRemedy.name}**\n'
        '- ${ls.tr("report_preparation")}: ${entry.organicRemedy.preparation}\n'
        '- ${ls.tr("report_dosage")}: ${entry.organicRemedy.dosage}\n'
        '- ${ls.tr("report_frequency")}: ${entry.organicRemedy.frequency}\n\n'
        '### ${ls.tr("report_chemical_treatment")}\n'
        '- **Active Ingredient:** ${entry.chemicalRemedy.activeIngredient}\n'
        '- **Trade Name (India):** ${entry.chemicalRemedy.tradeName}\n'
        '- **${ls.tr("report_dosage")}:** ${entry.chemicalRemedy.dosage}\n'
        '- **${ls.tr("report_spray_schedule")}:** ${entry.chemicalRemedy.spraySchedule}\n'
        '- **${ls.tr("report_safety_interval")} (PHI):** ${entry.chemicalRemedy.safetyInterval}\n\n'
        '### ${ls.tr("report_prevention")}\n'
        '${entry.preventionTips.map((t) => '- $t').join('\n')}\n\n'
        '### ${ls.tr("report_yield_impact")}\n'
        '${entry.yieldImpact}\n\n'
        '_📱 Instant offline diagnosis powered by PhytoLens Agronomy KB._';
  }

  String _formatFullReport(AgronomyEntry entry, int healthScore, int? severity) {
    if (entry.pathogenType == 'healthy') {
      return _formatDetailedReport(entry, healthScore, severity);
    }

    final severityStr = severity != null ? ' | Severity: $severity%' : '';

    return '# 📋 Comprehensive Crop Health Report\n\n'
        '## ${entry.diseaseName} on ${entry.plantName}\n'
        '**Health Score:** $healthScore/100$severityStr\n'
        '**Pathogen Type:** ${entry.pathogenType.toUpperCase()} | **Risk Level:** ${entry.severity.toUpperCase()}\n\n'
        '---\n\n'
        '### 1. Disease Identification\n'
        '${entry.quickSummary}\n\n'
        '### 2. Immediate Treatment Plan\n'
        '${entry.immediateActions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}\n\n'
        '### 3. 🌿 Organic / Natural Remedies\n'
        '**${entry.organicRemedy.name}**\n'
        '- **How to prepare:** ${entry.organicRemedy.preparation}\n'
        '- **Dosage:** ${entry.organicRemedy.dosage}\n'
        '- **How often:** ${entry.organicRemedy.frequency}\n\n'
        '### 4. 💊 Chemical Treatment Options\n'
        '| Parameter | Details |\n'
        '| :--- | :--- |\n'
        '| **Active Ingredient** | ${entry.chemicalRemedy.activeIngredient} |\n'
        '| **Trade Name (India)** | ${entry.chemicalRemedy.tradeName} |\n'
        '| **Dosage** | ${entry.chemicalRemedy.dosage} |\n'
        '| **Spray Schedule** | ${entry.chemicalRemedy.spraySchedule} |\n'
        '| **Pre-Harvest Safety** | ${entry.chemicalRemedy.safetyInterval} |\n\n'
        '### 5. Prevention Tips\n'
        '${entry.preventionTips.map((t) => '- $t').join('\n')}\n\n'
        '### 6. Yield Impact Assessment\n'
        '${entry.yieldImpact}\n\n'
        '---\n'
        '_📱 Instant offline diagnosis powered by PhytoLens Agronomy Knowledge Base._';
  }

  String _genericFallback(String plantName, String diseaseName, int healthScore, String reportType) {
    if (diseaseName.toLowerCase().contains('healthy')) {
      return '✅ **$plantName** looks healthy! Health score: $healthScore/100.\n\n'
          'Continue with regular watering, balanced nutrition, and weekly monitoring.';
    }

    return '⚠️ **$diseaseName** detected on **$plantName**.\n'
        'Health score: $healthScore/100.\n\n'
        '### General Treatment\n'
        '1. Remove affected leaves immediately\n'
        '2. Improve air circulation around plants\n'
        '3. Apply neem oil spray (5ml per litre water) every 7 days\n'
        '4. If fungal: try baking soda spray (1 tsp per litre water)\n'
        '5. If bacterial: apply copper-based spray (3gm per litre water)\n\n'
        '_Connect to the internet for AI-enhanced, disease-specific treatment plan._';
  }
}
