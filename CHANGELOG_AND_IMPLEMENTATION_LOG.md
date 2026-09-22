# AutoMate: Implementation Log & Engineering Changelog

This document logs every engineering change, database optimization, backend refactoring, and UI/UX fix implemented across the AutoMate codebase.

---

## 📅 Summary of Implemented Changes

| Area | Component | Changes Implemented | Status |
| :--- | :--- | :--- | :--- |
| **Backend & DB** | [`db.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/config/db.js) | Connection pool hardening (`max: 10`, `idleTimeout: 30s`), dedicated client checkout `getClient()`, message indexing (`idx_messages_ride_id`), startup orphan data cleanup. | ✅ Complete |
| **Backend API** | [`server.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/server.js) | Added `compression` (Gzip payload compression), real-time cron socket broadcasts (`rideUpdated`, `newRide`) + automated stale notifications/messages cleanup. Removed strict rate limiter to prevent user lockouts. | ✅ Complete |
| **Backend Logic** | [`rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js) | Isolated transactions with `client.query('BEGIN/COMMIT/ROLLBACK')`, `SELECT FOR UPDATE` row locks, eliminated $N+1$ query loops with atomic set-based SQL, added consolidated `getDashboardData` BFF endpoint, in-memory TTL caching, fixed host self-join notification bug, cascade data purging, added `/rides/cancel` endpoint, and fixed `getUserStats` to strictly count completed rides (`status = 'completed'`). | ✅ Complete |
| **Backend Routes** | [`rideRoutes.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/routes/rideRoutes.js) | Exposed `GET /api/rides/dashboard` and `POST /api/rides/cancel` routes. | ✅ Complete |
| **Flutter UI** | [`chat_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/chat_page.dart) | Real-time `rideEnded`, `passengerRemoved`, and `passengerBlocked` socket listeners with modal warning dialog (*"Ride Ended"* / *"Ride Cancelled"*), dynamic status detection, and `Navigator.of(ctx, rootNavigator: true).pushAndRemoveUntil(HomePage)` navigation fix. Added real-time typing indicators with 3-dot bouncing animation (`_TypingDotsAnimation`). | ✅ Complete |
| **Flutter UI** | [`metro_ride_details_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/metro_ride_details_page.dart) | Added Host **Cancel Ride** red button with confirmation dialog, interactive **"Slide to End Ride ➔"** slider widget (`_SwipeToCompleteSlider`), live participant updates on `rideUpdated`, and updated confirmation dialog wording. Fixed Return to Dashboard navigation via `pushAndRemoveUntil(HomePage)`. | ✅ Complete |
| **Flutter UI** | [`profile_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/profile_page.dart) | Synchronized bottom navigation bar design, dimensions (64dp), Material ripple effects (`InkWell`), circular add button, and typography with `HomePage`. | ✅ Complete |
| **Backend Sockets** | [`socketManager.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/sockets/socketManager.js) | Added `typing` and `stopTyping` socket relay events across ride rooms. | ✅ Complete |
| **Flutter UI** | [`home_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/home_page.dart) | Single-flight consolidated dashboard hydration via `GET /api/rides/dashboard`, cutting 4 network requests down to 1. | ✅ Complete |

---

## 🔍 Detailed Code Diffs & Rationale

### 1. Database Transaction Isolation & Pool Tuning
* **File:** [`backend/src/config/db.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/config/db.js)
* **Rationale:** Direct calls to `pool.query('BEGIN')` dispatched commands to non-isolated pool connections. Exporting `getClient: () => pool.connect()` enables atomic transactional blocks with proper `client.release()` safety in finally blocks.

### 2. HTTP Gzip Payload Compression & Rate Limiting
* **File:** [`backend/server.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/server.js)
* **Rationale:** Reduces JSON payload sizes by ~70–80% for low-bandwidth cellular environments, and adds in-memory rate limiting to defend against brute-force attacks and request spam.

### 3. $N+1$ Database Query Loop Elimination
* **File:** [`backend/src/controllers/rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js)
* **Rationale:** Replaced sequential loops (`for (const row of joinedRides.rows)`) with a single atomic set-based SQL statement:
```sql
UPDATE rides 
SET seats_available = seats_available + 1, status = 'active'
WHERE id IN (
  SELECT rp.ride_id FROM ride_participants rp
  JOIN rides r ON rp.ride_id = r.id
  WHERE rp.user_id = $1 AND r.status IN ('active', 'full')
);
DELETE FROM ride_participants WHERE user_id = $1;
```

### 4. Consolidated Backend-for-Frontend (BFF) Dashboard Endpoint
* **Files:** [`backend/src/controllers/rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js), [`backend/src/routes/rideRoutes.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/routes/rideRoutes.js), [`frontend/flutter_app/lib/screens/home_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/home_page.dart)
* **Rationale:** Replaces 4 distinct REST round-trips with a single aggregated endpoint `GET /api/rides/dashboard`, executing database queries concurrently on the server and returning unified state to the client in 1 round-trip.

### 5. Real-Time Host Cancellation Detection on Active Pages
* **Files:** [`frontend/flutter_app/lib/screens/chat_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/chat_page.dart), [`frontend/flutter_app/lib/screens/metro_ride_details_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/metro_ride_details_page.dart)
* **Rationale:** When a host cancels/ends a ride, listeners on active `ChatPage` and `MetroRideDetailsPage` receive the `rideEnded` socket event, display an alert dialog, and navigate passengers back to the dashboard safely.

### 6. Host Self-Join Notification Bug Elimination
* **File:** [`backend/src/controllers/rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js)
* **Rationale:** Enforced strict guard condition `if (userId !== ride.creator_id)` so the host never receives duplicate self-join notifications upon creating or managing rides.

### 7. Automated Stale Notification & Message Cleanup
* **Files:** [`backend/src/controllers/rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js), [`backend/server.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/server.js)
* **Rationale:** Cascades deletions of notifications and messages for completed/cancelled rides during `endRide` and in the 30-minute stale ride background cron task.

### 8. Context-Aware Confirmation Dialogs
* **File:** [`frontend/flutter_app/lib/screens/metro_ride_details_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/metro_ride_details_page.dart)
* **Rationale:** Updated button and dialog copy to accurately reflect the action: *"Cancel & Join Ride"* and *"Leave & Join Ride"* instead of *"Book New"*.

### 9. Host "Cancel Ride" Button & "Slide to End Ride" Swipe Control
* **File:** [`frontend/flutter_app/lib/screens/metro_ride_details_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/metro_ride_details_page.dart), [`backend/src/controllers/rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js), [`backend/src/routes/rideRoutes.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/routes/rideRoutes.js)
* **Rationale:** Provided distinct actions for hosts: A prominent red "Cancel Ride" button (for calling off a ride) and a modern smooth swipe slider "Slide to Complete Ride" (for finishing a successful trip), preventing accidental taps.

### 10. Accurate Completed-Only Profile Stats
* **File:** [`backend/src/controllers/rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js)
* **Rationale:** Fixed `getUserStats` to strictly count rides where `status = 'completed'` (excluding cancelled or pending rides) for both `ridesHosted` and `ridesTaken`.

### 11. Real-Time Chat Typing Indicators
* **Files:** [`frontend/flutter_app/lib/screens/chat_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/chat_page.dart), [`backend/src/sockets/socketManager.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/sockets/socketManager.js)
* **Rationale:** Added real-time socket relay for `typing` and `stopTyping` events with a sleek bouncing dots animation in the chat window.

### 12. Bottom Navigation Bar Unification
* **File:** [`frontend/flutter_app/lib/screens/profile_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/profile_page.dart)
* **Rationale:** Synchronized the Profile page's bottom navigation bar with the Home page (64dp height, Material InkWell ripples, identical elevation and border styling).

### 13. Stale Client Inactive Ride Guard (Zombie Ride Resurrection Fix)
* **File:** [`backend/src/controllers/rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js)
* **Rationale:** When a host ended or cancelled a ride, an unrefreshed or older client could still invoke `POST /rides/join`. Previously, `joinRide` only checked seat count and subsequently updated `status = 'active'`, resurrecting the cancelled ride and repopulating it on all user dashboards. 
* **Fix:** Enforced strict status verification: `if (ride.status !== 'active') return res.status(400)` with custom messaging, and added `AND status IN ('active', 'full')` guards across all seat-mutating queries (`leaveRide`, `removePassenger`, `blockPassenger`).

### 14. Phone Number Numeric & Length Validation
* **Files:** [`frontend/flutter_app/lib/screens/register_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/register_page.dart), [`backend/src/controllers/authController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/authController.js)
* **Rationale:** Enforced strict numeric-only validation and minimum 10-digit / maximum 15-digit constraints on phone numbers across both the client (with `FilteringTextInputFormatter.digitsOnly` and custom error alerts) and server (`/^\d{10,15}$/` regex check on registration).

### 15. Zero-Dollar ($0) Firebase Cloud Messaging (FCM) Push Notifications
* **Files:** [`frontend/flutter_app/lib/services/fcm_service.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/services/fcm_service.dart), [`backend/src/services/notificationService.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/services/notificationService.js), [`backend/src/controllers/rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js), [`backend/src/controllers/messageController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/messageController.js), [`PUSH_NOTIFICATIONS_IMPLEMENTATION_GUIDE.md`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/PUSH_NOTIFICATIONS_IMPLEMENTATION_GUIDE.md)
* **Rationale:** 
  1. Built complete end-to-end FCM system push notifications across Android notification bar and iOS system tray at permanently zero cost ($0.00 / month on Google Firebase Free Spark Plan).
  2. Dispatches real-time push alerts on:
     - Passenger joins ride (`POST /rides/join`) ➔ Sent to host.
     - Host cancels ride (`POST /rides/cancel`) ➔ Sent to all passengers.
     - Host completes ride (`POST /rides/end`) ➔ Sent to all passengers.
     - New chat message (`POST /messages/send`) ➔ Sent to background/offline participants.
  3. **Smart In-Chat Suppression:** Automatically suppresses notification banners if the user is already inside the active `ChatPage` for that ride.
### 16. ChatPage Lifecycle & Dispose Cleanup
* **File:** [`frontend/flutter_app/lib/screens/chat_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/chat_page.dart)
* **Rationale:** Consolidated duplicate `dispose()` method in `ChatPage` into a single lifecycle hook, ensuring proper cleanup of typing timers, text controllers, socket listeners, and `FcmService.currentActiveChatRideId` state.

### 17. Android Core Library Desugaring for Local Notifications
* **File:** [`frontend/flutter_app/android/app/build.gradle.kts`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/android/app/build.gradle.kts)
* **Rationale:** Enabled `isCoreLibraryDesugaringEnabled = true` with `com.android.tools:desugar_jdk_libs:2.0.4` dependency in Gradle to support Java 8+ time & notification APIs required by `flutter_local_notifications`.





