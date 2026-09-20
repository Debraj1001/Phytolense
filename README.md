# 🌱 PhytoLens — AI Plant Health & Agronomic Intelligence

<div align="center">

[![Release](https://img.shields.io/badge/Release-v1.0.0-10B981?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Debraj1001/Phytolense/releases/tag/v1.0.0)
[![APK Download](https://img.shields.io/badge/Download-APK_(136.6_MB)-059669?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Debraj1001/Phytolense/releases/download/v1.0.0/phytolens-v1.0.0.apk)
[![Web Portal](https://img.shields.io/badge/Live_Portal-phytolense.netlify.app-00C7B7?style=for-the-badge&logo=netlify&logoColor=white)](https://phytolense.netlify.app)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod_2.6-00D2B8?style=for-the-badge)](https://riverpod.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Firebase](https://img.shields.io/badge/Cloud-Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Gemini](https://img.shields.io/badge/AI-Google_Gemini-8E75C2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)
[![Groq](https://img.shields.io/badge/LLM-Groq_Llama_3-F55036?style=for-the-badge)](https://groq.com)
[![Razorpay](https://img.shields.io/badge/Payments-Razorpay-0C2340?style=for-the-badge&logo=razorpay&logoColor=white)](https://razorpay.com)
[![SQLite](https://img.shields.io/badge/Offline-SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org)

**An intelligent, multi-engine agronomic health platform that diagnoses plant pathologies, tracks local outbreaks, calculates optimal spray windows, and connects farmers with verified agro-retailers.**

[Overview](#-overview) •
[Official Release & Download](#-official-release--downloads) •
[Key Features](#-key-features) •
[Web Admin Portal](#-web-admin-portal--landing-page) •
[System Architecture](#-system-architecture) •
[Ecosystem Workflow](#-ecosystem-workflow) •
[Project Structure](#-project-structure) •
[Getting Started](#-getting-started) •
[Environment Configuration](#-environment-configuration) •
[Security & Best Practices](#-security--best-practices)

</div>

---

## 🌿 Overview

**PhytoLens** is an end-to-end plant health intelligence ecosystem built for farmers, agronomists, and commercial growers. It bridges the gap between digital crop disease diagnosis and physical agricultural remedies.

Combining **on-device edge machine learning (TFLite/ONNX)** with high-throughput cloud vision models (multi-key Gemini Vision pool, PlantNet taxonomy, and Groq ultra-fast LLMs), PhytoLens delivers instant pathology identification, severity grading, curative chemical & organic protocols, real-time community epidemic tracking, and direct links to certified agro-dealers.

The ecosystem includes:
1. **Mobile Application (Flutter)**: Biophilic Neumorphic interface, camera scanner, offline-first SQLite cache, split online/offline AI usage tracking, and real-time fleet enforcement.
2. **Web Portal & Fleet Command (React + Vite)**: Live landing page with a dynamic camera-scannable QR code generator, real-time fleet management, lockdown controls, and agronomic analytics.

---

## 📦 Official Release & Downloads

| Platform | Channel | Status / Link |
| :--- | :--- | :--- |
| **Android APK** | Direct GitHub CDN | [**Download `phytolens-v1.0.0.apk` (136.6 MB)**](https://github.com/Debraj1001/Phytolense/releases/download/v1.0.0/phytolens-v1.0.0.apk) |
| **Release Page** | GitHub Releases | [**PhytoLens v1.0.0 Release Notes & Assets**](https://github.com/Debraj1001/Phytolense/releases/tag/v1.0.0) |
| **Live Web App** | Netlify Production | [**phytolense.netlify.app**](https://phytolense.netlify.app) |
| **Google Play Store** | Official Distribution | ⏳ *In Review — Direct APK available above* |
| **Apple App Store** | iOS TestFlight | ⏳ *Closed Beta Preview in progress* |
| **Other Stores** | Amazon / F-Droid | ⏳ *Submissions queued* |

---

## ✨ Key Features

### 🔍 Dual-Engine AI Pathology & Species ID
- **On-Device Edge ML**: Bundled TensorFlow Lite models provide instant, zero-latency disease diagnosis even in remote fields without cell reception.
- **Multi-Key Vision Auto-Rotation Pool**: Resilient multi-key Google Gemini Vision integration that automatically fails over across backup keys on HTTP 429 rate limits.
- **82,000+ Plant Species Classification**: Powered by the PlantNet API for botanical taxonomy and species classification across global flora.
- **Curative Agronomic Protocols**: Rapid prescriptions via Groq LLM detailing exact active ingredients, mixing ratios, application precautions, and organic bio-control alternatives.
- **Split AI Usage Analytics**: Dedicated tracking for **Online AI** vs. **Offline Edge AI** queries with real-time quota meters.

### 🛡️ Real-Time Fleet Security & Lockdown
- **Instant Fleet Ban & Unban**: Administrative user suspensions propagate in real-time via Supabase PostgreSQL CDC websockets; banned devices immediately transition to a security restriction screen.
- **Global Maintenance Lockdown**: Live toggle to suspend fleet operations during system upgrades with an instant lockdown barrier.
- **Account Data Wipe**: Deleting a user in the Admin Portal automatically purges all related database rows and forces an immediate remote logout.

### 🩺 Emergency Doctor Pass (₹10 Micropayment)
- **Low-Barrier Urgent Access**: Provides a 24-hour high-priority consultation pass for farmers facing sudden, severe crop failure without requiring long-term subscriptions.
- **Priority Agronomist Queue**: Bypasses daily free limits and opens deep-dive interactive chat sessions with the AI Plant Doctor.
- **Automated Razorpay Checkout**: Seamless in-app micro-transaction flow that activates 1-day Pro benefits and opens the emergency consultation session immediately upon confirmation.

### 📡 Community Radar (Epidemic Early Warning)
- **Localized Outbreak Telemetry**: Monitors crop diagnoses within a 10 km geographic radius to detect outbreaks early (e.g., Late Blight, Downy Mildew, Rust).
- **Preventative Action Prompts**: Alerts neighboring growers before airborne or pest-borne pathogens reach their fields, allowing preventative bio-sprays.

### 🌦️ Weather & Optimal Spray Window
- **Atmospheric Spray Advisory**: Evaluates live temperature, humidity, wind velocity, and precipitation probability to calculate whether spraying conditions are **Optimal** or **Not Ideal**.
- **Runoff & Evaporation Prevention**: Prevents wasted chemical investments by warning against spraying before rain or in high heat/wind.

### 🏪 Nearby Retailers (B2B Directory)
- **Remedy Fulfillment**: Connects diagnosed pathology prescriptions directly to local agricultural input centers and fertilizer suppliers.
- **Verified Dealer Roster**: Displays store addresses, ratings, and one-tap direct calling (`tel:`) to check product availability immediately.

### 🌿 Garden Roster & Multi-Plot Management
- **Plot & Crop History**: Full historical log of past scans, severity percentages, recovery stages, and confidence scores.
- **Plant Profile Vault**: Maintain custom digital gardens, track watering schedules, and monitor healing progress over time.
- **Voice Read-Aloud**: Integrated Text-to-Speech (`flutter_tts`) reads treatment recipes and dosage instructions aloud in field conditions.

---

## 🌐 Web Admin Portal & Landing Page

The web portal ([phytolense.netlify.app](https://phytolense.netlify.app)) serves as both the public product showcase and the operational control center for farm fleet telemetry:

### ⚡ Dynamic Real-Time QR Code Generator
- **Instant Camera Scanning**: Generates a high-contrast vector SVG QR code with Error Correction Level `M`/`H` that standard smartphone cameras and Google Lens can scan in milliseconds.
- **Live Database Sync**: Connected to Supabase WebSockets. When an administrator modifies the QR foreground color, error correction level, logo badge, or target destination in the Admin Panel, the public landing page updates **live in real time without refreshing**.
- **Lossless Zoom Viewer**: Modal viewer enabling high-resolution SVG and 2048px PNG QR downloads for field signage and printed packaging.

### 🖥️ Admin Operations Dashboard
- **Telemetry & KPIs**: Real-time counters for active scans, registered users, outbreak alerts, and payment transactions.
- **User Management**: Neobrutalist confirmation modals with double-click debounce prevention to edit user roles, toggle bans, or wipe accounts.
- **Global App Configuration**: Live adjustments for daily scan quotas, AI usage limits, trial durations, and pricing tiers.

---

## 🏗️ System Architecture

```mermaid
graph TD
    User([Farmer / Grower]) -->|Captures Leaf Photo| Cam[Camera / Viewfinder]
    Cam --> QuotaGate[Scan Limiter & Quota Gate]
    
    subgraph AI Pipeline
        QuotaGate --> AIRouter{AI Inference Router}
        AIRouter -->|Online Vision & Pathology| GemPool[Gemini Vision Multi-Key Pool]
        AIRouter -->|Botanical Taxonomy| PlantNet[PlantNet API]
        AIRouter -->|Offline On-Device| TFLite[TFLite Edge Classifier]
        
        GemPool --> GroqEngine[Groq LLaMA-3 Agronomy Engine]
        PlantNet --> GroqEngine
        TFLite --> GroqEngine
        GroqEngine -->|Structured Diagnosis & Remedy| DiagnosticResult[Scan Result Model]
    end

    subgraph Field Intelligence & Action
        DiagnosticResult --> SprayWindow[Weather Service: Optimal Spray Window]
        DiagnosticResult --> RadarAlert[Community Radar: Outbreak Telemetry]
        DiagnosticResult --> DoctorPass[Emergency Doctor Pass ₹10]
        DiagnosticResult --> B2BDirectory[Nearby Retailers B2B Directory]
    end

    subgraph Data & Sync Layer
        DiagnosticResult --> LocalDB[(SQLite Local Database)]
        LocalDB <-->|Bidirectional Sync| SupabaseDB[(Supabase PostgreSQL: users, scans, config)]
        Cam -->|Cloud Backup| SupabaseStorage[(Supabase Storage: scans)]
    end

    subgraph Realtime Fleet Telemetry
        SupabaseDB <-->|PostgreSQL CDC WebSocket| WebPortal[Web Admin Portal & QR Manager]
        SupabaseDB <-->|Realtime Fleet Channel| SecurityGate[Lockdown & Ban Screen Gate]
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
│   ├── ios/                         # Native iOS build configuration
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
│   │   │   ├── subscription/        # Upgrade, Trial Activation & Transformation
│   │   │   └── system/              # Real-Time Lockdown & Ban Enforcement Screens
│   │   ├── services/                # Supabase, Gemini, Groq, Weather, Payment, ML
│   │   ├── theme/                   # Biophilic Neumorphism Theme & Tokens
│   │   └── widgets/                 # Modals, DoctorPassSheet, GlassButtons, Snackbars
│   ├── pubspec.yaml                 # Dependencies & asset declarations
│   └── .env.example                 # Environment variables template
│
├── web/                             # 🌐 React + Vite Public Portal & Admin Dashboard
│   ├── src/
│   │   ├── components/
│   │   │   ├── Admin/               # User Manager, QR Config, Outbreaks, Config Manager
│   │   │   ├── LandingPage/         # Hero, Features, Showcase, QrDownloadSection, Footer
│   │   │   ├── Navbar.jsx           # Public Navigation & Admin Login Modal Trigger
│   │   │   └── QrZoomModal.jsx      # High-Resolution Vector QR Export & Zoom Tool
│   │   ├── context/
│   │   │   └── AppContext.jsx       # Supabase Realtime Provider & Fleet State
│   │   ├── services/
│   │   │   └── supabase.js          # Public + Privileged Supabase Admin API Clients
│   │   └── App.jsx                  # Main View Switcher (Landing vs. Admin Portal)
│   ├── dist/                        # Production compiled bundle deployed to Netlify
│   └── package.json                 # Web dependencies (qrcode, lucide-react, supabase)
│
├── .gitignore                       # Ignored build outputs and secret keys
├── LICENSE                          # MIT License
└── README.md                        # Project documentation & reference
```

---

## 🚀 Getting Started

### Mobile Application (Flutter)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Debraj1001/Phytolense.git
   cd Phytolense/phytolens
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure environment variables:**
   ```bash
   cp .env.example .env
   # Populate with your Supabase, Gemini, and Groq API keys
   ```

4. **Build or Run:**
   ```bash
   # Run on connected device
   flutter run

   # Compile release APK
   flutter build apk --release
   ```

---

### Web Portal & Admin Dashboard (React + Vite)

1. **Navigate to the web directory:**
   ```bash
   cd Phytolense/web
   ```

2. **Install npm dependencies:**
   ```bash
   npm install
   ```

3. **Start the local development server:**
   ```bash
   npm run dev
   # Accessible at http://localhost:5173
   ```

4. **Build and deploy to Netlify:**
   ```bash
   npm run build
   netlify deploy --prod --dir=dist
   ```

---

## 🔑 Environment Configuration

Create a `.env` file in the `phytolens/` root directory based on `.env.example`:

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

- **Zero Secret Exposure**: `.env`, keystores, and credentials are completely excluded via `.gitignore`.
- **Row-Level Security (RLS)**: Supabase PostgreSQL tables enforce RLS policies; administrative updates use scoped service role handlers.
- **Debounced Admin Actions**: Critical administrative mutations (bans, deletions, lockdown) utilize Neobrutalist confirmation dialogs with double-click debounce prevention.
- **Client-Side Image Optimization**: High-resolution camera captures are compressed on-device before transmission to minimize rural bandwidth consumption.
- **Offline Data Integrity**: Diagnoses and treatments are cached in SQLite with checksum verification to guarantee data safety in remote farmlands.

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
