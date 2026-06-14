# 🛺 AutoMate

**An exclusive student travel coordination platform for the B.M.S. College of Engineering (BMSCE) community.**

AutoMate simplifies ride-sharing, ensuring secure and efficient transit to common destinations for students. By connecting campus peers, it reduces travel costs, optimizes commutes, and enhances safety through targeted coordination features.

---

## ✨ Current Features

* **Campus-Exclusive Ride Sharing:** Dedicated network restricted to BMSCE students for finding and coordinating travel mates to common destinations.
* **Security-First Coordination:** Integrated gender-specific matching and verification features to prioritize rider safety.
* **Cross-Platform Mobile App:** High-performance frontend built with Flutter, delivering a fluid user experience.
* **Polished UI/UX Elements:** Custom-designed native splash screens and Android Adaptive Icons configured for modern devices.
* **Robust Backend API:** Powered by Node.js and Express, securely deployed and health-checked on Render.
* **Scalable Database Architecture:** Integrated with Supabase (PostgreSQL) utilizing optimized SSL connection pooling.
* **Containerized Environment:** Fully managed local development and deployment workflow using Docker and Docker Compose (optimized with build caching).

---

## 🛠 Tech Stack

### Frontend
* Flutter & Dart
* Custom Native Asset Generators (`flutter_native_splash`, `flutter_launcher_icons`)

### Backend & Database
* Node.js & Express.js
* Supabase (PostgreSQL)

### DevOps & Deployment
* Docker & Docker Compose
* Render (Cloud Hosting)

---

## 🚀 Future Implementations (Roadmap)

The following features are planned for upcoming releases to further enhance the platform:

* **UPI Payment Integration:** Seamless in-app expense splitting and direct UPI payments between travel mates.
* **AI-Powered Insights:** Smart suggestions for optimal travel routes, times, and dynamic matchmaking using the Gemini API.
* **Real-time Live Location Tracking:** In-app map integration to track incoming travel mates before pickup.
* **In-App Messaging:** Secure, real-time chat between matched riders without exposing personal phone numbers.

---

## 📦 Installation & Local Setup

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.0.0+)
* [Node.js](https://nodejs.org/) (v18+)
* [Docker & Docker Compose](https://www.docker.com/)

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/AutoMate.git
cd AutoMate
```

### 2. Backend Setup

```bash
cd backend
npm install

# Note: Ensure your .env file is populated with your Render/Supabase credentials

docker-compose up --build
```

### 3. Frontend Setup

```bash
cd ../frontend/flutter_app
flutter clean
flutter pub get
flutter run
```

---

## 📱 Download the App

The latest stable Android release (`AutoMate.apk`) is available for download.

**[👉 Download v1.0.0 Here](https://github.com/Thilak-K2121/AutoMate/releases/latest)**

*Note: You must grant "Install from Unknown Sources" permissions on your Android device to install the APK.*
