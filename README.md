# Firebase Chat App - README

A comprehensive Flutter chat application demonstrating Firebase Authentication, Realtime Database, and Firestore implementation for the Mobile Computing course.

## Features

### ✅ Firebase Authentication
- User registration with email/password
- User login with session management
- Password reset functionality
- Profile management

### ✅ Firebase Realtime Database
- Real-time online/offline status
- User presence tracking
- Last seen timestamps
- User directory synchronization

### ✅ Firebase Firestore
- Message storage and retrieval
- Chat room management
- Transaction support (prevent duplicate chats)
- Read receipts
- Message querying and pagination

### ✅ Chat Application
- Real-time messaging
- Private and group chats
- User presence indicators
- Direct messaging with search
- Message timestamps
- Clean, intuitive UI

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── models/
│   ├── user_model.dart
│   ├── message_model.dart
│   └── chat_model.dart
├── services/
│   ├── auth_service.dart       # Firebase Auth
│   ├── firestore_service.dart  # Firestore operations
│   └── realtime_database_service.dart  # Realtime DB
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── registration_screen.dart
│   ├── home_screen.dart
│   └── chat_screen.dart
└── widgets/
    └── (custom widgets here)
```

## Dependencies

```yaml
firebase_core: ^2.24.0
firebase_auth: ^4.14.0
cloud_firestore: ^4.14.0
firebase_database: ^10.4.0
provider: ^6.0.0
uuid: ^4.0.0
intl: ^0.19.0
```

## Installation & Setup

### 1. Create Firebase Project
```
Go to https://console.firebase.google.com
1. Create new project
2. Enable Authentication (Email/Password)
3. Enable Firestore Database
4. Enable Realtime Database
5. Get your configuration
```

### 2. Configure Flutter Project
```bash
# Get dependencies
flutter pub get

# Configure Firebase (requires Firebase CLI)
flutterfire configure

# This will automatically update firebase_options.dart
```

### 3. Update firebase_options.dart
If `flutterfire configure` doesn't work, manually update credentials:
- Get from Firebase Console → Project Settings
- Copy your credentials to `firebase_options.dart`

### 4. Run Application
```bash
flutter run
```

## Usage

### User Registration
1. Tap "Register" on login screen
2. Enter display name, email, and password
3. Account is created and saved to:
   - Firebase Authentication
   - Firestore (user profile)
   - Realtime Database (user directory)

### Sending Messages
1. Navigate to home screen
2. Select a chat or start a new one
3. Type message and tap send
4. Message appears instantly for all users

### User Presence
1. Check "Users" tab to see all users
2. Green indicator = online, Gray = offline
3. Tap user to start direct message

## Key Implementation Details

### Authentication Flow
```
Registration → Firebase Auth → Firestore + Realtime DB → Home
Login → Firebase Auth → Set Online → Home
```

### Message Flow
```
User sends → MessageModel created → Firestore saved → 
Update chat lastMessage → Stream notifies → UI updates
```

### Real-time Updates
- All components use StreamBuilders
- Real-time synchronization across devices
- Offline support through Firestore persistence

## Database Schema

### Firestore
```
chats/
├── {chatId}
│   ├── name, description, members
│   ├── createdBy, createdAt
│   └── lastMessage, lastMessageTime

messages/{chatId}/messages/
├── {messageId}
│   ├── senderUid, senderName, content
│   ├── timestamp, readBy
│   └── imageUrl (optional)

users/
├── {userId}
│   ├── email, displayName, photoUrl
│   └── createdAt, updatedAt
```

### Realtime Database
```
users/{userId}/
├── email, displayName, photoUrl, createdAt

presence/{userId}/
├── online, lastSeen, displayName
```

## Security Rules

### Firestore Security
```javascript
- Users can only read/write their own profile
- Chat messages only accessible to members
- Message deletion only by sender
```

### Realtime Database Security
```json
- Presence/user data readable by all
- Writable only by that user
```

## Testing

1. **Create 2-3 test accounts**
2. **Test real-time messaging**
3. **Verify online/offline status**
4. **Test message delivery**
5. **Test chat creation**
6. **Test direct messaging**

## Troubleshooting

### Firebase Not Initializing
- Check Firebase Console project is active
- Verify credentials in firebase_options.dart
- Run: `flutter clean && flutter pub get`

### Messages Not Saving
- Check Firestore security rules
- Verify user is authenticated
- Check network connection

### Presence Not Updating
- Verify Realtime Database is enabled
- Check connection status
- Clear app cache

## Performance Tips

1. **Enable Firestore persistence** for offline support
2. **Use pagination** for large message lists
3. **Implement image compression** before upload
4. **Use Firestore indexes** for complex queries

## Future Enhancements

- [ ] Image sharing
- [ ] Group chats
- [ ] Typing indicators
- [ ] Voice messages
- [ ] Push notifications
- [ ] User profiles with pictures
- [ ] Message search
- [ ] Dark mode

## Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Flutter Firebase Plugins](https://github.com/FirebaseExtended/flutterfire)
- [Flutter Provider](https://pub.dev/packages/provider)

## License

This project is created for educational purposes.

## Support

For issues or questions, refer to:
- DOCUMENTATION_REPORT.md (detailed technical docs)
- Firebase Console (debugging)
- Flutter documentation

---

**Created for Mobile Computing Course Final Project**
