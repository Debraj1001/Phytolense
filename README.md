# 🌱 PhytoLens — AI-Powered Plant Health & Disease Diagnosis

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod_2.6-00D2B8?style=for-the-badge)](https://riverpod.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Firebase](https://img.shields.io/badge/Cloud-Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Gemini](https://img.shields.io/badge/AI-Google_Gemini-8E75C2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)
[![Groq](https://img.shields.io/badge/LLM-Groq_Llama_3-F55036?style=for-the-badge)](https://groq.com)

**An intelligent, multi-provider botanical assistant that diagnoses plant diseases, identifies 82,000+ species, and delivers actionable organic remedies in seconds.**

[Overview](#-overview) •
[Features](#-key-features) •
[Architecture](#-system-architecture) •
[Project Structure](#-project-structure) •
[Getting Started](#-getting-started) •
[Environment Configuration](#-environment-configuration)

</div>

---

## 🌿 Overview

**PhytoLens** empowers farmers, botanists, and indoor gardeners to instantly diagnose plant pathologies and track plant wellness. Combining on-device machine learning with high-throughput cloud vision models (Gemini Vision multi-key auto-rotation pool, PlantNet API, and Groq ultra-fast LLMs), PhytoLens delivers accurate diagnosis, severity scoring, and step-by-step chemical/organic treatment roadmaps.

Designed with a **Soft Botanical Minimalist** UI/UX philosophy, featuring calm sage-emerald hues, feather-soft elevation shadows, fluid animations, and Google Fonts typography.

---

## ✨ Key Features

### 🔍 Multimodal AI Disease Diagnosis & Species ID
- **Multi-Key Vision Auto-Rotation**: Resilient multi-key Gemini Vision pool that seamlessly rotates through fallback keys upon hitting rate limits.
- **Rapid Agronomic Advice**: Powered by Groq LLM to generate instant remediation protocols, organic home remedies, chemical treatments, and preventive measures.
- **Extensive Botanical Library**: PlantNet API integration for recognizing over 82,000 plant species across global flora.
- **On-Device Inference**: TensorFlow Lite (`tflite_flutter`) for rapid, low-latency offline plant health verification.

### 📱 Premium Soft Botanical UI / UX
- **Calm, High-Readability Palette**: Sage green (`#2E7D5B`), crisp card surfaces (`#FFFFFF`), soft borders, and warm muted typography.
- **Modern Typography**: Typography system driven by `Plus Jakarta Sans` and `Inter`.
- **Delightful Micro-interactions**: Pulsing scanning crosshairs, skeleton shimmer placeholders, and smooth transitions.

### 🛡️ Garden Management & Care Routines
- **Scan History**: Full historical log of all past diagnoses, timestamps, confidence scores, and disease stages.
- **Care Reminders**: Automated background reminders for watering, fertilization, pruning, and health re-checks via `flutter_local_notifications`.
- **Plant Profile Vault**: Save individual plants, track recovery progress, and maintain health journals.

### 💳 Tiered Subscriptions & Scan Management
- **Scan Limiter Engine**: Smart quota management system tracking free vs. premium scan allowances.
- **Razorpay Payments**: Built-in support for subscription upgrades (Free, Pro, and Premium tiers) with real-time tier unlocking.

---

## 🏗️ System Architecture

```mermaid
graph TD
    User([User with Mobile App]) -->|Captures Photo| Cam[Camera / Image Picker]
    Cam --> ScanEngine[Scan Limiter & Quota Gate]
    
    subgraph AI Pipeline
        ScanEngine --> FallbackRouter{AI Router}
        FallbackRouter -->|Fast Vision & Pathology| GemPool[Gemini Vision Multi-Key Pool]
        FallbackRouter -->|Taxonomy & Species Match| PlantNet[PlantNet API]
        FallbackRouter -->|Offline Detection| TFLite[On-Device TFLite Model]
        
        GemPool --> GroqEngine[Groq LLM Engine]
        PlantNet --> GroqEngine
        TFLite --> GroqEngine
        GroqEngine -->|Structured Diagnosis & Care Plan| DiagnosticResult[Scan Result Model]
    end
    
    subgraph Identity & Messaging Layer
        User -->|Authentication Gateway| FirebaseAuth[Firebase Auth]
        DiagnosticResult --> NotifService[Firebase Cloud Messaging & Local Reminders]
    end

    subgraph Data & Storage Layer
        DiagnosticResult --> SupabaseDB[(Supabase PostgreSQL: users, scan_history, plants, payments, config)]
        Cam -->|Upload Scan Images| SupabaseStorage[(Supabase Storage: scans & avatars buckets)]
    end

    subgraph Administration
        AdminUser([Admin]) --> AdminPortal[Phytolens Admin Web/App]
        AdminPortal -->|Live Config, Moderation & Quotas| SupabaseDB
    end
```

---

## 📂 Project Structure

This monorepo contains both the primary mobile application and the administrative control dashboard:

```
Plant-life/
├── phytolens/                   # 📱 Primary Flutter Mobile Application
│   ├── android/                 # Native Android configuration & Gradle build
│   ├── ios/                     # Native iOS workspace & Pods
│   ├── assets/                  # Icons, illustrations, ML models (.tflite, labels)
│   ├── lib/
│   │   ├── config/              # App constants, routes, API endpoints
│   │   ├── data/                # Mock data, plant repositories
│   │   ├── models/              # Data models (ScanResult, User, Plant, Subscription)
│   │   ├── providers/           # Riverpod state management providers
│   │   ├── screens/             # UI screens
│   │   │   ├── auth/            # Login, Sign Up, Password Reset
│   │   │   ├── dashboard/       # Soft Botanical Home & Quick Actions
│   │   │   ├── scanner/         # Camera Viewfinder & Realtime Analysis
│   │   │   ├── history/         # Diagnostic Records & Filtering
│   │   │   ├── profile/         # User Settings & Garden Roster
│   │   │   └── subscription/    # Upgrade & Razorpay Checkout
│   │   ├── services/            # Gemini, Groq, Supabase, Limiter, Notifications
│   │   ├── theme/               # Colors, Typography, AppTheme (Light & Dark)
│   │   └── widgets/             # Reusable cards, buttons, shimmers, badges
│   ├── pubspec.yaml             # Mobile dependencies & assets
│   └── .env.example             # Mobile environment variable template
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.0.0`)
- [Dart SDK](https://dart.dev/get-dart) (`>= 3.0.0 < 4.0.0`)
- Android Studio / Xcode (for mobile device emulation)
- A Supabase Project & Firebase Project

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Debraj1001/Phytolense.git
   cd Phytolense
   ```

2. **Configure Mobile App (`phytolens`):**
   ```bash
   cd phytolens
   cp .env.example .env
   # Populate your API keys in .env
   flutter pub get
   ```

---

## 🔑 Environment Configuration

Create a `.env` file in the `phytolens/` directory using the provided `.env.example`:

```ini
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_supabase_service_role_key
SUPABASE_DB_URL=https://your-project.supabase.co

# Razorpay Keys (Test Mode)
RAZORPAY_TEST_KEY_ID=rzp_test_xxxxxxxxxxxxxx
RAZORPAY_TEST_KEY_SECRET=your_razorpay_secret

# Groq API (Primary + Secondary Fallback)
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GROQ_API_KEY_2=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# PlantNet API
PLANTNET_API_KEY=your_plantnet_api_key

# Gemini Vision API Keys (Multi-Key Failover Pool)
GEMINI_API_KEY=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GEMINI_API_KEY_2=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GEMINI_API_KEY_3=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GEMINI_API_KEY_4=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GEMINI_API_KEY_5=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 🏃 Running the Application

### Running Mobile App (Android / iOS)
```bash
cd phytolens
flutter run
```

---

## 🔒 Security & Best Practices

- **Never commit `.env` files**: All secret keys and database URLs are ignored via `.gitignore`.
- **API Key Pool Failover**: Avoids single-point-of-failure outages during hackathons or heavy usage spikes.
- **Client-Side Sanitization**: Image payloads are compressed and resized before transmission to reduce bandwidth and inference latency.

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
