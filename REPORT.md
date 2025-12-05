# Final Project Report — Firebase Chat App

## Introduction
This project is a Flutter chat application built to demonstrate key Firebase concepts taught in the Mobile Computing course: Firebase Authentication, Firebase Realtime Database, and Firebase Firestore. The app supports user registration and login, user presence tracking (online/offline), persistent user profiles, chat rooms, direct messages, and real-time messaging.

## Implementation Details
This section explains how each required Firebase service was integrated into the project and where to find the corresponding code.

- **Firebase Authentication**
  - Location: `lib/services/auth_service.dart`
  - Implementation: The app uses the official `firebase_auth` Flutter SDK. Registration uses `createUserWithEmailAndPassword`, and login uses `signInWithEmailAndPassword`. The auth state is exposed via a stream and the app listens to `FirebaseAuth.authStateChanges()` to react to sign-in/sign-out events. After a successful registration, a user profile document is written into Firestore under `users/{uid}` and a copy is saved to the Realtime Database for presence and directory purposes.
  - Why used: `firebase_auth` provides secure, managed authentication with email/password, session handling, and integration with other Firebase products.

- **Firebase Realtime Database**
  - Location: `lib/services/realtime_database_service.dart`
  - Implementation: Realtime Database stores user presence and a lightweight user directory. Presence entries are written under `presence/{uid}` with fields `online` and `lastSeen`. The app updates presence on sign-in and sign-out and exposes streams for presence updates so the UI can show online indicators in real time.
  - Why used: Realtime Database provides low-latency presence management and onValue streams that are ideal for presence indicators. Its child-level update semantics are convenient for online/offline toggles.

- **Firebase Firestore**
  - Location: `lib/services/firestore_service.dart`
  - Implementation: Firestore stores chats, chat metadata and message content. Chats are stored in `chats/{chatId}`, and messages are stored in subcollections `messages/{chatId}/messages/{messageId}` which are queried with ordering and pagination. Firestore also stores user profile documents under `users/{uid}` for richer profile data and queries (e.g., searching users by display name).
  - Why used: Firestore provides flexible querying, indexed queries, transactions, and scalability suited for message history storage and chat metadata.

- **Chat Application Flow**
  - Registration: User registers via `auth_service.registerWithEmailPassword`. This creates a Firebase Authentication account, writes Firestore profile data, writes Realtime Database user directory data, and sets presence online.
  - Login: `auth_service.loginWithEmailPassword` signs the user in through Firebase Auth, loads profile data from Firestore (or creates a minimal profile if missing), sets presence online, and notifies the UI.
  - Messaging: `firestore_service.sendMessage` writes message documents under `messages/{chatId}/messages`, and updates `chats/{chatId}` metadata (last message/time). Message streams are returned as Firestore query snapshots so the UI updates in real time.
  - Presence: Presence is managed by `realtime_database_service.setUserOnline` and `setUserOffline`, and the UI subscribes to presence streams to show live indicators.

## Justification for Each Service
- **Authentication**: Using `firebase_auth` is the recommended secure approach and integrates with Firebase's security model and rules. It avoids reimplementing auth and leverages built-in protections.
- **Realtime Database**: Chosen for presence because it offers lower-latency and simpler child-level updates for presence toggles than Firestore.
- **Firestore**: Chosen for message storage because of its query capabilities, transactions, and scalable structure. It supports ordering, pagination, and complex queries useful for chat history and search.

## Screenshots
Include screenshots of the running app in these states (place image files in the repo `screenshots/` folder):

- `screenshots/login.png` — login screen
- `screenshots/registration.png` — registration screen
- `screenshots/home.png` — home with chats list
- `screenshots/chat.png` — chat screen with messages
- `screenshots/presence.png` — users list showing online/offline indicators

(These screenshots are not included here; please run the app and capture them using your device/emulator.)

## How to Run
1. Install Flutter and ensure it's on your PATH.
2. From the project root:

```bash
flutter pub get
flutterfire configure   # optional but recommended; updates firebase_options.dart
flutter run
```

Notes:
- `firebase_options.dart` contains the Firebase configuration for your project. If you run `flutterfire configure`, it will replace this file with your project's credentials.
- Ensure Firebase Authentication (Email/Password), Firestore and Realtime Database are enabled in the Firebase Console.

## Security and Rules
- Firestore and Realtime Database should have security rules configured so that users can only write their own presence and profile, and only chat members can read/write chat messages. Example rules are provided in `FIRESTORE_RULES.txt` and should be adapted for your app.

## Repository Contents Required for Submission
- All source code (this repository)
- `README.md` with setup and run instructions
- `REPORT.md` (this file) detailing implementation and justifications
- Screenshots (add under `screenshots/` before submission)

## Final Notes
This project now uses Firebase Authentication for login/registration, Realtime Database for presence, and Firestore for messages and chat management. If you want, I can:

- Run a linter or format code
- Add basic Firestore/Realtime security rules examples in `firestore.rules` and `database.rules.json`
- Create a `screenshots/` folder and example placeholder images


---

Created for: Mobile Computing Course — Final Submission
