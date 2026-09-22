# AutoMate: Implementation Log & Engineering Changelog

This document logs every engineering change, database optimization, backend refactoring, and UI/UX fix implemented across the AutoMate codebase.

---

## 📅 Summary of Implemented Changes

| Area | Component | Changes Implemented | Status |
| :--- | :--- | :--- | :--- |
| **Backend & DB** | [`db.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/config/db.js) | Connection pool hardening (`max: 10`, `idleTimeout: 30s`), dedicated client checkout `getClient()`, message indexing (`idx_messages_ride_id`), startup orphan data cleanup. | ✅ Complete |
| **Backend API** | [`server.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/server.js) | Added `compression` (Gzip payload compression), `express-rate-limit` for auth and rides, real-time cron socket broadcasts (`rideUpdated`, `newRide`) + automated stale notifications/messages cleanup. | ✅ Complete |
| **Backend Logic** | [`rideController.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/controllers/rideController.js) | Isolated transactions with `client.query('BEGIN/COMMIT/ROLLBACK')`, `SELECT FOR UPDATE` row locks, eliminated $N+1$ query loops with atomic set-based SQL, added consolidated `getDashboardData` BFF endpoint, in-memory TTL caching, fixed host self-join notification bug, and added cascade data purging on ride completion. | ✅ Complete |
| **Backend Routes** | [`rideRoutes.js`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/backend/src/routes/rideRoutes.js) | Exposed `GET /api/rides/dashboard` BFF route. | ✅ Complete |
| **Flutter UI** | [`chat_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/chat_page.dart) | Real-time `rideEnded`, `passengerRemoved`, and `passengerBlocked` socket listeners with modal warning dialog (*"This ride has been ended by the host"*) and automatic navigation back to dashboard. | ✅ Complete |
| **Flutter UI** | [`metro_ride_details_page.dart`](file:///c:/Users/user/Desktop/AutoMate/AutoMate/frontend/flutter_app/lib/screens/metro_ride_details_page.dart) | Added Socket.io integration to `ride_<id>` room, real-time `rideEnded` listener with dismissal dialog, live participant list updates on `rideUpdated`, and updated confirmation dialog wording to *"Cancel & Join Ride"* and *"Leave & Join Ride"*. | ✅ Complete |
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
