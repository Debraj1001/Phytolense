# 🌱 PhytoLens — AI-Powered Plant Health & Disease Diagnosis

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod_2.6-00D2B8?style=for-the-badge)](https://riverpod.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Firebase](https://img.shields.io/badge/Cloud-Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Gemini](https://img.shields.io/badge/AI-Google_Gemini-8E75C2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)
[![Groq](https://img.shields.io/badge/LLM-Groq_Llama_3-F55036?style=for-the-badge)](https://groq.com)
[![Razorpay](https://img.shields.io/badge/Payments-Razorpay-0C2340?style=for-the-badge&logo=razorpay&logoColor=white)](https://razorpay.com)
[![SQLite](https://img.shields.io/badge/Offline-SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org)

**An intelligent, multi-provider agronomic assistant that diagnoses plant pathologies, tracks local outbreaks, provides optimal spray windows, and connects farmers with nearby verified retailers.**

[Overview](#-overview) •
[Key Features](#-key-features) •
[System Architecture](#-system-architecture) •
[Ecosystem Workflow](#-ecosystem-workflow) •
[Project Structure](#-project-structure) •
[Getting Started](#-getting-started) •
[Environment Configuration](#-environment-configuration) •
[Security & Best Practices](#-security--best-practices)

</div>

---

## 🌿 Overview

**PhytoLens** is a mobile health intelligence platform built for farmers, agronomists, and gardeners. It bridges the gap between digital crop disease diagnosis and physical remedy implementation.

Combining on-device machine learning with high-throughput cloud vision models (multi-key Gemini Vision pool, PlantNet species identification, and Groq ultra-fast LLMs), PhytoLens delivers instant pathology identification, severity grading, step-by-step organic/chemical treatment protocols, real-time community epidemic tracking, and direct links to certified agro-dealers.

Designed with a **Soft Botanical Minimalist** design system, featuring emerald and mint hues, tactile bouncing interactions, dark/light adaptive theming, fluid micro-animations, and offline-first database synchronization.

---

## ✨ Key Features

### 🔍 Multimodal AI Disease Diagnosis & Species ID
- **Multi-Key Vision Auto-Rotation Pool**: Resilient multi-key Gemini Vision integration that automatically fails over across backup keys upon hitting provider rate limits.
- **82,000+ Plant Species Identification**: Powered by the PlantNet API for botanical taxonomy and species classification across global flora.
- **On-Device Edge Inference**: Integrated TensorFlow Lite (`tflite_flutter`) and ONNX runtime support for low-latency offline diagnosis without internet connectivity.
- **Automated Agronomic Protocols**: Rapid curative prescriptions via Groq LLM detailing exact chemical active ingredients, mixing ratios, application precautions, and organic homemade alternatives.

### 🩺 Emergency Doctor Pass (₹10 Micropayment)
- **Low-Barrier Urgent Access**: Provides a 24-hour high-priority consultation pass for farmers facing sudden, severe crop failure without requiring long-term subscriptions.
- **Priority Agronomist Queue**: Bypasses daily free limits and opens deep-dive interactive chat sessions with the AI Plant Doctor.
- **Automated Razorpay Checkout**: Seamless in-app micro-transaction flow that activates 1-day Pro benefits and opens the emergency consultation session immediately upon confirmation.

### 📡 Community Radar (Epidemic Early Warning)
- **Localized Disease Tracking**: Monitors crowdsourced crop diagnoses within a 10 km geographic radius to detect outbreaks early (e.g., Late Blight, Downy Mildew).
- **Preventative Action Prompts**: Notifies neighboring growers before airborne or pest-borne pathogens reach their fields, allowing preventative bio-sprays.

### 🌦️ Weather & Optimal Spray Window
- **Atmospheric Spray Advisory**: Evaluates live temperature, humidity, wind velocity, and precipitation probability to calculate whether spraying conditions are **Optimal** or **Not Ideal**.
- **Runoff & Evaporation Prevention**: Prevents wasted chemical investments by warning against spraying before rain or in strong winds.

### 🏪 Nearby Retailers (B2B Directory)
- **Closing the Remedy Loop**: Connects diagnosed pathology prescriptions directly to local agricultural input centers and fertilizer suppliers.
- **Verified Dealer Roster**: Displays store addresses, ratings, and one-tap direct calling (`tel:`) to check product availability immediately.
- **B2B Agricultural Commerce**: Enables certified distributors to list genuine inputs, protecting growers against counterfeit pesticides.

### 🌿 Garden Roster & Multi-Plot Management
- **Plot & Crop History**: Full historical log of past scans, severity percentages, recovery stages, and confidence scores.
- **Plant Profile Vault**: Maintain custom digital gardens, track watering schedules, and monitor healing progress over time.
- **Voice Read-Aloud**: Integrated Text-to-Speech (`flutter_tts`) reads treatment recipes and dosage instructions aloud in field conditions.

### 💾 Offline-First Architecture
- **SQLite Local Database (`sqflite`)**: Caches scans, garden profiles, and stats locally so the app remains fully functional without cell towers.
- **Auto-Sync Engine**: Queues actions taken in offline mode and synchronizes with Supabase PostgreSQL as soon as connectivity is restored.

### 💳 Tiered Subscriptions & Quota Management
- **Flexible Tiers**: 2-Day Free Trial (₹0 / 15 scans & AI chats/day), Emergency Doctor Pass (₹10/24h), Pro Plan (₹49/30d), and Farm Pack (₹199/30d).
- **Payment Verification**: Secure payment verification through Supabase Edge Functions with Razorpay integration.

---

## 🏗️ System Architecture

```mermaid
graph TD
    User([Farmer / Gardener]) -->|Captures Leaf Photo| Cam[Camera / Viewfinder]
    Cam --> ScanEngine[Scan Limiter & Quota Gate]
    
    subgraph AI Pipeline
        ScanEngine --> AIRouter{AI Routing Engine}
        AIRouter -->|Online Vision & Pathology| GemPool[Gemini Vision Multi-Key Pool]
        AIRouter -->|Botanical Taxonomy| PlantNet[PlantNet API]
        AIRouter -->|Offline On-Device| TFLite[TFLite / ONNX Runtime]
        
        GemPool --> GroqEngine[Groq LLaMA-3 Agronomy Engine]
        PlantNet --> GroqEngine
        TFLite --> GroqEngine
        GroqEngine -->|Structured Diagnosis & Prescription| DiagnosticResult[Scan Result Model]
    end

    subgraph Field Intelligence & Assistance
        DiagnosticResult --> SprayWindow[Weather Service: Spray Window]
        DiagnosticResult --> RadarAlert[Community Radar: Outbreak Telemetry]
        DiagnosticResult --> DoctorPass[Emergency Doctor Pass ₹10]
        DiagnosticResult --> B2BDirectory[Nearby Retailers B2B Directory]
    end

    subgraph Data & Sync Layer
        DiagnosticResult --> LocalDB[(SQLite Local Database)]
        LocalDB <-->|Bidirectional Sync| SupabaseDB[(Supabase PostgreSQL: users, scans, plants, payments)]
        Cam -->|Image Upload| SupabaseStorage[(Supabase Storage: scans bucket)]
    end

    subgraph Identity & Notifications
        User -->|Authentication| SupabaseAuth[Supabase Auth / Firebase Auth]
        DiagnosticResult --> NotifService[FCM & Local Reminders]
    end
```

---

## 🔄 Ecosystem Workflow

```mermaid
graph LR
    A[1. Community Radar alerts nearby outbreak] --> B[2. Farmer scans crop via PhytoLens Camera]
    B --> C[3. Multi-Engine AI returns diagnosis & severity]
    C --> D[4. Weather service checks optimal spray window]
    C --> E[5. Emergency Doctor Pass provides 1-on-1 guidance]
    C --> F[6. B2B Directory connects farmer to local input retailer]
```

---

## 📂 Project Structure

```
Plant-life/
├── phytolens/                       # 📱 Primary Flutter Mobile Application
│   ├── android/                     # Native Android build & Gradle configuration
│   ├── ios/                         # Native iOS build configuration & Pods
│   ├── assets/
│   │   ├── images/                  # Botanical vectors, illustrations, icons
│   │   ├── animations/              # Lottie animations & micro-interactions
│   │   ├── models/                  # On-device ML models (.tflite, .onnx)
│   │   └── data/                    # Offline agronomy knowledge base (JSON)
│   ├── lib/
│   │   ├── config/                  # App constants, routes, environment config
│   │   ├── data/                    # Agronomy knowledge base & SQLite local database
│   │   ├── models/                  # AppUser, ScanResult, Plant, AppConfig models
│   │   ├── providers/               # Riverpod state management & quota providers
│   │   ├── screens/
│   │   │   ├── ai/                  # AI Doctor Interactive Chatbot
│   │   │   ├── auth/                # Login, Signup, Email Verification
│   │   │   ├── business/            # Nearby Retailers (B2B) Directory
│   │   │   ├── dashboard/           # Home Dashboard, Radar & Status Cards
│   │   │   ├── history/             # Scan History, Diagnostics & Analytics
│   │   │   ├── home/                # Bottom Navigation Shell
│   │   │   ├── onboarding/          # User Welcome & Permissions Flow
│   │   │   ├── profile/             # Profile, Garden Roster & Plant Details
│   │   │   ├── scanner/             # Live Camera Viewfinder & Result Screen
│   │   │   ├── settings/            # Settings & On-Device Model Manager
│   │   │   ├── splash/              # Animated Brand Launch Screen
│   │   │   └── subscription/        # Upgrade, Trial Activation & Transformation
│   │   ├── services/                # Supabase, Gemini, Groq, Weather, Payment, ML
│   │   ├── theme/                   # Dual-Theme (Dark/Light), Colors & Typography
│   │   └── widgets/                 # EmergencyDoctorPassSheet, BouncingButton, Cards
│   ├── pubspec.yaml                 # Dependencies & asset declarations
│   └── .env.example                 # Environment variables template
├── .gitignore                       # Ignored build outputs and secret keys
├── LICENSE                          # MIT License
└── README.md                        # Documentation & setup guide
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.0.0`)
- [Dart SDK](https://dart.dev/get-dart) (`>= 3.0.0 < 4.0.0`)
- Android Studio / VS Code with Flutter extension
- Connected physical Android/iOS device or emulator
- Supabase Project & Firebase Project

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Debraj1001/Phytolense.git
   cd Phytolense
   ```

2. **Navigate to the application directory:**
   ```bash
   cd phytolens
   ```

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Configure environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env and supply your credentials (see below)
   ```

5. **Run on your connected device:**
   ```bash
   # List connected devices
   flutter devices

   # Run on selected device
   flutter run
   ```

---

## 🔑 Environment Configuration

Create a `.env` file in the `phytolens/` root directory using `.env.example`:

```ini
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_supabase_service_role_key
SUPABASE_DB_URL=https://your-project.supabase.co

# Razorpay Keys (Test / Live Mode)
RAZORPAY_TEST_KEY_ID=rzp_test_xxxxxxxxxxxxxx
RAZORPAY_TEST_KEY_SECRET=your_razorpay_secret

# Groq API (Primary + Fallback Pool)
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GROQ_API_KEY_2=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# PlantNet API (82,000+ species taxonomy)
PLANTNET_API_KEY=your_plantnet_api_key

# Gemini Vision API Keys (Multi-Key Pool with Auto-Rotation)
GEMINI_API_KEY=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GEMINI_API_KEY_2=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GEMINI_API_KEY_3=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GEMINI_API_KEY_4=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GEMINI_API_KEY_5=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Direct Database Connection String (Optional)
DATABASE_URL=postgresql://postgres:password@db.your-project.supabase.co:5432/postgres
```

---

## 🔒 Security & Best Practices

- **Never Commit Secrets**: `.env` and sensitive credential files (`google-services.json`, keystores) are excluded via `.gitignore`.
- **Multi-Key API Resiliency**: Gemini Vision keys auto-rotate upon receiving HTTP 429 (Rate Limit) or 503 errors, ensuring 99.9% uptime.
- **Client-Side Image Optimization**: Images are automatically compressed and resized before transmission to minimize mobile data usage.
- **Offline Data Integrity**: Scans and treatments are backed up to local SQLite storage with checksums to prevent data loss in remote areas.

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
