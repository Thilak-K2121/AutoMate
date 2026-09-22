# AutoMate — Firebase FCM Push Notifications: Complete Architecture, Troubleshooting & Implementation Log

---

## 📌 1. Overview & $0 Cost Architecture

AutoMate implements real-time **System Push Notifications** (in the Android status bar and system tray) for both ride events and chat messaging across background, foreground, and terminated app states with a strict **$0.00 / month cost guarantee** running exclusively on Google Firebase Cloud Messaging (FCM Spark Free Tier).

```
                        ┌─────────────────────────────────────────────────────────────┐
                        │             AutoMate Mobile App (Flutter)                   │
                        │                                                             │
                        │  1. Request Notification Permissions                        │
                        │  2. Fetch FCM Device Token from Firebase                    │
                        │  3. Register Token with Backend (POST /api/auth/fcm-token)  │
                        └───────────────────────┬─────────────────────────────────────┘
                                                │
                                                ▼
                        ┌─────────────────────────────────────────────────────────────┐
                        │          PostgreSQL Database (Render Cloud)                 │
                        │                                                             │
                        │  Table: user_devices                                        │
                        │  - user_id (UUID)                                           │
                        │  - fcm_token (TEXT UNIQUE)                                  │
                        │  - device_type ('android' / 'ios')                          │
                        │  - updated_at (TIMESTAMP)                                   │
                        └───────────────────────▲─────────────────────────────────────┘
                                                │
┌────────────────────────────┐                  │ (Query Target User Tokens)
│       User Action          │                  │
│  - Passenger Joins Ride    │                  │
│  - Host Cancels Ride       │─────────►┌───────┴─────────────────────────────────────┐
│  - Host Ends Ride          │          │           AutoMate Node.js Backend          │
│  - New Chat Message        │          │                                             │
└────────────────────────────┘          │  1. notificationService.sendToUser() /      │
                                        │     sendToUsers()                           │
                                        │  2. Dispatch Multicast Push Payload         │
                                        └───────────────────────┬─────────────────────┘
                                                                │
                                                                ▼
                                        ┌─────────────────────────────────────────────┐
                                        │      Firebase Cloud Messaging (FCM API)     │
                                        └───────────────────────┬─────────────────────┘
                                                                │ (Deliver over APNs / FCM)
                                                                ▼
                                        ┌─────────────────────────────────────────────┐
                                        │     Recipient Android / iOS Device          │
                                        │                                             │
                                        │  🔔 System Tray Heads-Up Banner Pop-up      │
                                        │  👉 Tapping Banner Deep-Links to Ride / Chat│
                                        └─────────────────────────────────────────────┘
```

---

## 🚀 2. Notification Triggers & Payloads

| Trigger Event | Backend Endpoint | Target Audience | Notification Title & Content | Deep-Link Route |
| :--- | :--- | :--- | :--- | :--- |
| **Passenger Joins Ride** | `POST /api/rides/join` | Ride Host (Creator) | **Title:** `"New Passenger! 🚗"`<br>**Body:** `"[Passenger] just joined your ride to [Destination]."` | Opens `MetroRideDetailsPage` |
| **Host Cancels Ride** | `POST /api/rides/cancel` | All booked passengers | **Title:** `"Ride Cancelled ⚠️"`<br>**Body:** `"Your ride to [Destination] was cancelled by the host."` | Opens `MetroRideDetailsPage` |
| **Host Ends Ride** | `POST /api/rides/end` | All booked passengers | **Title:** `"Ride Completed 🎉"`<br>**Body:** `"You have arrived at [Destination]. Thank you for riding with AutoMate!"` | Opens `MetroRideDetailsPage` |
| **New Chat Message** | `POST /api/messages/send` | Offline / Background Participants | **Title:** `"💬 [Sender Name]"`<br>**Body:** `"[Message content]"` | Opens `ChatPage` |

---

## 🧠 3. Smart In-App Chat Suppression

To prevent annoying redundant notifications when a user is actively typing and reading messages inside `ChatPage`:
* When `ChatPage` opens: `FcmService.currentActiveChatRideId = widget.rideId;`
* When incoming message arrives in foreground: `if (type == 'CHAT_MESSAGE' && currentActiveChatRideId == rideId) return;`
* When `ChatPage` is closed / popped: `FcmService.currentActiveChatRideId = null;`

---

## 🛠️ 4. Comprehensive Issues, Root Causes & Code Diffs

During implementation, multiple real-world compilation, platform architecture, and SDK version mismatch issues were resolved. Here is the full breakdown with **Before vs. After** code diffs:

---

### 🚨 Problem 1: `firebase-admin` Modular Import Error (`admin.messaging is not a function`)
* **Error Encountered:**
  ```
  TypeError: admin.messaging is not a function
      at Object.sendToUser (notificationService.js:82:32)
  ```
* **Root Cause:** In modern `firebase-admin` (v12+ / v13+), messaging functions are no longer exposed on the default root `admin` object. They are decoupled into the `firebase-admin/messaging` submodule requiring `getMessaging(app)`.
* **Code Difference:**

#### ❌ BEFORE ([notificationService.js](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/services/notificationService.js)):
```javascript
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.cert(serviceAccount)
});

// Throws TypeError: admin.messaging is not a function
const response = await admin.messaging().sendEachForMulticast(messagePayload);
```

#### ✅ AFTER ([notificationService.js](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/services/notificationService.js)):
```javascript
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

const app = getApps().length > 0 
  ? getApps()[0] 
  : initializeApp({ credential: cert(serviceAccount) });

const messagingInstance = getMessaging(app);

// Works reliably across all Node.js environments
const response = await messagingInstance.sendEachForMulticast(messagePayload);
```

---

### 🚨 Problem 2: Render Startup Crash (`Cannot read properties of undefined (reading 'cert')`)
* **Error Encountered:**
  ```
  ❌ Failed to initialize Firebase Admin SDK: Cannot read properties of undefined (reading 'cert')
  ```
* **Root Cause:** Calling `admin.credential.cert(...)` on modern `firebase-admin` threw an undefined exception because `credential` helper was migrated to `cert` directly under `firebase-admin/app`.
* **Code Difference:**

#### ❌ BEFORE:
```javascript
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
```

#### ✅ AFTER:
```javascript
const { initializeApp, cert } = require('firebase-admin/app');

initializeApp({
  credential: cert(serviceAccount)
});
```

---

### 🚨 Problem 3: App Crashing on Physical Android Phone (Architecture & Manifest Permissions)
* **Error Encountered:**
  The app opened on PC Android emulator without issues, but immediately crashed upon launch on real physical Android smartphones.
* **Root Causes:**
  1. **CPU ABI Architecture Mismatch:** `flutter run` on an emulator produces a JIT debug build compiled exclusively for `x86_64` CPU. Real physical smartphones run on ARM processors (`arm64-v8a` / `armeabi-v7a`). Loading an `x86_64` `libflutter.so` on an ARM device caused an instant native crash.
  2. **Missing Android 13+ Notification Permissions:** Android 13+ (API level 33+) requires runtime permission declarations for notifications in `AndroidManifest.xml`.
* **Code Difference:**

#### ❌ BEFORE ([AndroidManifest.xml](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/android/app/src/main/AndroidManifest.xml)):
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET" />
  <application ...>
```

#### ✅ AFTER ([AndroidManifest.xml](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/android/app/src/main/AndroidManifest.xml)):
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
  <uses-permission android:name="android.permission.VIBRATE" />
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

  <application ...>
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="automate_rides_channel" />
```

#### 🔨 Solution for APK:
Ran `flutter build apk --release` to generate a standalone fat multi-architecture AOT binary supporting `arm64-v8a`, `armeabi-v7a`, and `x86_64` (`AutoMate-v7.apk`).

---

### 🚨 Problem 4: Gradle Build Failure (`desugar_jdk_libs` version mismatch)
* **Error Encountered:**
  ```
  Execution failed for task ':app:checkDebugAarMetadata'.
  > An issue was found when checking AAR metadata:
      1. Dependency ':flutter_local_notifications' requires desugar_jdk_libs version to be
         2.1.4 or above for :app, which is currently 2.0.4
  ```
* **Root Cause:** `flutter_local_notifications: ^20.1.0` requires Java 8+ API desugaring version 2.1.4+.
* **Code Difference:**

#### ❌ BEFORE ([build.gradle.kts](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/android/app/build.gradle.kts)):
```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

#### ✅ AFTER ([build.gradle.kts](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/android/app/build.gradle.kts)):
```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

---

### 🚨 Problem 5: `flutter_local_notifications` 20.1+ Breaking API Signature Change
* **Error Encountered:**
  ```
  lib/services/fcm_service.dart:63:30: Error: Too many positional arguments: 1 allowed, but 2 found.
  lib/services/fcm_service.dart:94:32: Error: Too many positional arguments: 4 allowed, but 5 found.
  ```
* **Root Cause:** `flutter_local_notifications` version 20.1+ changed methods to strictly use named parameters.
* **Code Difference:**

#### ❌ BEFORE ([fcm_service.dart](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/services/fcm_service.dart)):
```dart
await _localNotifications.initialize(
  initSettings,
  onDidReceiveNotificationResponse: (response) { ... }
);

_localNotifications.show(
  notification.hashCode,
  notification.title,
  notification.body,
  NotificationDetails(...)
);
```

#### ✅ AFTER ([fcm_service.dart](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/services/fcm_service.dart)):
```dart
await _localNotifications.initialize(
  settings: initSettings,
  onDidReceiveNotificationResponse: (NotificationResponse response) { ... }
);

_localNotifications.show(
  id: notification.hashCode,
  title: notification.title,
  body: notification.body,
  notificationDetails: NotificationDetails(...)
);
```

---

### 🚨 Problem 6: Duplicate `dispose()` Declaration in `ChatPage`
* **Error Encountered:**
  ```
  lib/screens/chat_page.dart:329:8: Error: 'dispose' is already declared in this scope.
  ```
* **Root Cause:** Two separate `dispose()` methods were created during incremental state updates.
* **Code Difference:**

#### ❌ BEFORE ([chat_page.dart](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/chat_page.dart)):
```dart
@override
void dispose() {
  _messageController.dispose();
  _scrollController.dispose();
  super.dispose();
}

// ... hundreds of lines down ...

@override
void dispose() {
  _typingTimer?.cancel();
  _socket?.disconnect();
  FcmService.currentActiveChatRideId = null;
  super.dispose();
}
```

#### ✅ AFTER ([chat_page.dart](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/chat_page.dart)):
```dart
@override
void dispose() {
  _typingTimer?.cancel();
  _messageController.dispose();
  _scrollController.dispose();
  _socket?.emit('leaveChat', widget.rideId);
  _socket?.disconnect();
  _socket?.dispose();
  FcmService.currentActiveChatRideId = null;
  super.dispose();
}
```

---

### 🚨 Problem 7: Git Credential Security & Ignore Protection
* **Problem:** Secret keys (`google-services.json` and `serviceAccountKey.json`) must never be leaked to public/shared git repositories.
* **Solution:**
  1. Added explicit `.gitignore` rules in the project root:
     ```gitignore
     *serviceAccountKey*.json
     *google-services*.json
     serviceAccountKey.json
     google-services.json
     ```
  2. Untracked any staged credentials using `git rm --cached` and confirmed clean `git status`.
  3. Render environment configures credentials through the `FIREBASE_SERVICE_ACCOUNT` environment variable.

---

## 📋 5. Summary of Modified Files

| File Path | Description of Changes |
| :--- | :--- |
| [`frontend/flutter_app/lib/services/fcm_service.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/services/fcm_service.dart) | Core FCM service managing permission requests, token generation, token synchronization, background handlers, heads-up foreground banners, in-chat suppression, and deep linking. |
| [`frontend/flutter_app/lib/main.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/main.dart) | Initializes Firebase Core and calls `FcmService.initialize()`. |
| [`frontend/flutter_app/lib/screens/chat_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/chat_page.dart) | Sets `FcmService.currentActiveChatRideId` in `initState` and clears it in consolidated `dispose()`. |
| [`frontend/flutter_app/lib/screens/home_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/home_page.dart) | Triggers `FcmService.syncDeviceToken()` to ensure token registration after authentication. |
| [`frontend/flutter_app/android/app/src/main/AndroidManifest.xml`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/android/app/src/main/AndroidManifest.xml) | Added Android 13+ `POST_NOTIFICATIONS`, `VIBRATE`, and `RECEIVE_BOOT_COMPLETED` permissions and default notification channel metadata. |
| [`frontend/flutter_app/android/app/build.gradle.kts`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/android/app/build.gradle.kts) | Added Google Services Gradle plugin, enabled `isCoreLibraryDesugaringEnabled`, and bumped `desugar_jdk_libs` to `2.1.4`. |
| [`frontend/flutter_app/android/settings.gradle.kts`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/android/settings.gradle.kts) | Added Google Services plugin `com.google.gms.google-services:4.4.2`. |
| [`backend/src/config/db.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/config/db.js) | Created `user_devices` table and indexed `idx_user_devices_user_id` for fast token queries. |
| [`backend/src/services/notificationService.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/services/notificationService.js) | Implemented modular `firebase-admin/app` & `firebase-admin/messaging` SDK integration, token storage, multicast dispatching, and dead-token pruning. |
| [`backend/src/controllers/authController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/authController.js) | Added `POST /api/auth/fcm-token` device registration endpoint. |
| [`backend/src/controllers/rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js) | Dispatches push notifications on ride join, cancellation, and ride completion. |
| [`backend/src/controllers/messageController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/messageController.js) | Dispatches push notifications on new chat messages to offline/background ride participants. |

---

## 🏁 6. Final Status & Verification

* ✅ **$0 Monthly Cost:** Spark Free Tier active.
* ✅ **Real-Time Push Delivery:** Verified working on both Android Emulator and Physical Smartphone.
* ✅ **Multi-Arch Release Build:** Generated `AutoMate-v7.apk` (~62.7 MB) with full ARM64 + ARM32 + x86_64 support.
* ✅ **Production Cloud Backend:** Render service live with `FIREBASE_SERVICE_ACCOUNT` environment variable.
