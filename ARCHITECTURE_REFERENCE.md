// Model Index - Reference guide for all data models

/*
USER MODEL - lib/models/user_model.dart
Properties:
  - uid: String (unique user ID from Firebase Auth)
  - email: String (user's email)
  - displayName: String (user's display name)
  - photoUrl: String? (profile picture URL)
  - createdAt: DateTime (account creation time)
  - isOnline: bool (online status from Realtime DB)
  - lastSeen: DateTime (last activity time)

Used in:
  - Firestore collection: users/{userId}
  - Realtime DB path: users/{userId}
  - Home screen users tab
  - Chat member displays
*/

/*
MESSAGE MODEL - lib/models/message_model.dart
Properties:
  - id: String (unique message ID)
  - senderUid: String (who sent the message)
  - senderName: String (sender's display name)
  - content: String (message text)
  - timestamp: DateTime (when sent)
  - imageUrl: String? (attached image)
  - readBy: List<String> (users who read it)

Used in:
  - Firestore collection: messages/{chatId}/messages/{messageId}
  - Chat screen display
  - Read receipts
*/

/*
CHAT MODEL - lib/models/chat_model.dart
Properties:
  - id: String (unique chat ID)
  - name: String (chat name/title)
  - description: String? (chat description)
  - photoUrl: String? (chat picture)
  - members: List<String> (list of member UIDs)
  - createdBy: String (who created the chat)
  - createdAt: DateTime (creation time)
  - lastMessage: String (preview text)
  - lastMessageTime: DateTime (time of last message)
  - isPrivate: bool (1-on-1 or group)

Used in:
  - Firestore collection: chats/{chatId}
  - Home screen chats tab
  - Chat list display
*/

// SERVICE INDEX - Reference guide for all services

/*
AUTH SERVICE - lib/services/auth_service.dart

Methods:
  registerWithEmailPassword()
    - Creates new user account
    - Sets display name
    - Returns UserCredential
    
  loginWithEmailPassword()
    - Authenticates existing user
    - Manages session
    - Returns UserCredential
    
  logout()
    - Ends current session
    - Clears auth state
    
  resetPassword(email)
    - Sends password reset email
    - Email-based recovery
    
  updateUserProfile(displayName, photoUrl)
    - Updates display name
    - Updates profile picture
    - Syncs with Firebase Auth
    
  Properties:
    - currentUser: Current Firebase user
    - isAuthenticated: Check if logged in
    - userId: Get current user's UID
    - authStateChanges: Stream of auth changes

Used in:
  - All screens for authentication
  - Session management
  - User profile updates
*/

/*
REALTIME DATABASE SERVICE - lib/services/realtime_database_service.dart

Methods:
  setUserOnline(userId, displayName)
    - Mark user as online
    - Set in presence node
    - Called on login
    
  setUserOffline(userId)
    - Mark user as offline
    - Called on logout
    
  getUserPresenceStream(userId)
    - Get presence updates for one user
    - Returns DatabaseEvent stream
    
  getAllUsersPresenceStream()
    - Get all users' presence
    - Used in users tab
    - Real-time sync
    
  saveUserProfile(userId, email, displayName, photoUrl)
    - Save user info in Realtime DB
    - Called during registration
    
  getUserData(userId)
    - Fetch user info
    - Returns DataSnapshot
    
  getUserDataStream(userId)
    - Stream user data changes
    - Real-time updates
    
  updateLastSeen(userId)
    - Update last activity time
    - Periodic updates
    
  getAllUsersStream()
    - Get all users
    - Used in user directory

Database Structure:
  users/{userId}/
    - email, displayName, photoUrl, createdAt
    
  presence/{userId}/
    - online (bool), lastSeen (timestamp), displayName

Used in:
  - Home screen (users tab, online status)
  - User presence indicators
  - Online/offline visibility
  - User directory
*/

/*
FIRESTORE SERVICE - lib/services/firestore_service.dart

CHAT OPERATIONS:
  createChat(ChatModel)
    - Create new chat room
    - Add to chats collection
    - Returns chat ID
    
  getUserChatsStream(userId)
    - Get user's chats
    - Real-time stream
    - Ordered by lastMessageTime
    
  getChatById(chatId)
    - Retrieve specific chat
    - Returns ChatModel
    
  updateChat(chatId, data)
    - Modify chat properties
    - Update lastMessage, etc.
    
  deleteChat(chatId)
    - Remove chat room
    - Delete all messages

MESSAGE OPERATIONS:
  sendMessage(chatId, MessageModel)
    - Save message to Firestore
    - Update chat's lastMessage
    - Returns message ID
    
  getMessagesStream(chatId)
    - Stream chat messages
    - Ordered by timestamp (descending)
    - Real-time updates
    
  getMessagesWithPagination(chatId, startAfter, pageSize)
    - Load messages in chunks
    - Performance optimization
    - Load older messages
    
  markMessageAsRead(chatId, messageId, userId)
    - Add user to readBy array
    - Track read receipts
    
  deleteMessage(chatId, messageId)
    - Remove message
    - Only by sender

USER OPERATIONS:
  saveUser(userId, userData)
    - Create/update user profile
    - Called during registration
    
  getUserData(userId)
    - Fetch user profile
    - Returns DocumentSnapshot
    
  getUserStream(userId)
    - Stream user profile changes
    - Real-time updates
    
  searchUsers(query)
    - Find users by displayName
    - Used in search
    
  getAllUsers()
    - Get all users
    - Used for directory

TRANSACTION OPERATIONS:
  createPrivateChatTransaction(user1Id, user2Id, user1Name, user2Name)
    - Atomic operation
    - Check existing chat
    - Create if not exists
    - Prevents duplicates
    - Returns chat ID

Database Structure:
  chats/{chatId}/
    - name, description, members, createdBy, createdAt, lastMessage, lastMessageTime, isPrivate
    
  messages/{chatId}/messages/{messageId}/
    - senderUid, senderName, content, timestamp, readBy, imageUrl
    
  users/{userId}/
    - email, displayName, photoUrl, createdAt, updatedAt

Used in:
  - All chat operations
  - Message send/receive
  - User profile management
  - Chat creation and deletion
*/

// SCREEN INDEX - Reference guide for all screens

/*
SPLASH SCREEN - lib/screens/splash_screen.dart
Purpose: Initial loading screen, auth check

Flow:
  1. Shows splash animation
  2. Checks if user is authenticated
  3. Routes to appropriate screen:
     - Authenticated → Home Screen
     - Not authenticated → Login Screen
  4. 2 second delay for UX

Dependencies:
  - AuthService (check auth state)
*/

/*
LOGIN SCREEN - lib/screens/login_screen.dart
Purpose: User login

UI Elements:
  - Email input field
  - Password input field
  - Login button
  - Registration link
  - Error message display
  - Loading indicator

Flow:
  1. User enters email and password
  2. Validates input
  3. Calls AuthService.loginWithEmailPassword()
  4. Sets user online in Realtime DB
  5. Routes to Home Screen
  6. Shows errors if login fails

Dependencies:
  - AuthService
  - RealtimeDatabaseService
*/

/*
REGISTRATION SCREEN - lib/screens/registration_screen.dart
Purpose: New user account creation

UI Elements:
  - Display name input
  - Email input
  - Password input
  - Confirm password input
  - Register button
  - Login link
  - Error message display

Validation:
  - All fields required
  - Passwords must match
  - Password minimum 6 characters
  - Valid email format

Flow:
  1. User fills registration form
  2. Validates all inputs
  3. Calls AuthService.registerWithEmailPassword()
  4. Saves user to Firestore (profile)
  5. Saves user to Realtime DB (directory)
  6. Auto-logs in
  7. Routes to Home Screen

Dependencies:
  - AuthService
  - FirestoreService
  - RealtimeDatabaseService
*/

/*
HOME SCREEN - lib/screens/home_screen.dart
Purpose: Main app hub with chats and users

Tabs:
  1. Chats Tab
     - List of all user's chats
     - Last message preview
     - Chat timestamp
     - Tap to enter chat
     - Create new chat button
     
  2. Users Tab
     - List of all users
     - Online/offline indicators (green/gray)
     - Last seen status
     - Tap to start private chat

UI Elements:
  - Bottom navigation bar (Chats/Users)
  - Floating action button (create chat)
  - Logout button in app bar
  - Real-time streams for updates

Flow:
  1. On load, set user online
  2. Stream chats from Firestore
  3. Stream users from Realtime DB
  4. Show online/offline status
  5. On tap chat: Navigate to ChatScreen
  6. On tap user: Create private chat → Navigate to ChatScreen
  7. On logout: Set offline → Navigate to LoginScreen

Dependencies:
  - AuthService
  - FirestoreService
  - RealtimeDatabaseService
*/

/*
CHAT SCREEN - lib/screens/chat_screen.dart
Purpose: Individual chat messaging

UI Elements:
  - Message list (scrollable)
  - Message input field
  - Send button
  - Chat name in app bar

Message Display:
  - Current user messages: Blue, right-aligned
  - Other user messages: Gray, left-aligned
  - Sender name display
  - Timestamp for each message
  - Auto-scroll to latest

Message Input:
  - Text field
  - Send button
  - Multi-line support
  - Clear on send

Flow:
  1. Stream messages from Firestore
  2. Display in reverse order (newest first)
  3. User types message
  4. Tap send
  5. Create MessageModel
  6. Save to Firestore
  7. Update chat's lastMessage
  8. UI updates automatically
  9. Auto-scroll to bottom

Dependencies:
  - AuthService
  - FirestoreService
  - uuid (generate message IDs)
*/

// DATA FLOW DIAGRAMS

/*
AUTHENTICATION FLOW:
                    ┌─────────────────────┐
                    │  Splash Screen      │
                    │  (Check Auth)       │
                    └────────┬────────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
              Logged In?          Not Logged In?
                    │                 │
              ┌─────▼─────┐      ┌────▼──────────┐
              │Home Screen│      │ Login Screen  │
              └───────────┘      │               │
                                 │ Register Link │
                                 └────┬──────────┘
                                      │
                                 ┌────▼─────────────┐
                                 │Registration Scr. │
                                 │                  │
                                 │ Firebase Auth    │
                                 │ + Firestore      │
                                 │ + Realtime DB    │
                                 └────┬─────────────┘
                                      │
                                 ┌────▼──────┐
                                 │Home Screen │
                                 └────────────┘
*/

/*
MESSAGE FLOW:
User Types Message
    │
    ├─ Validate not empty
    │
    ├─ Create MessageModel
    │  ├─ Generate UUID
    │  ├─ Set sender info
    │  ├─ Add timestamp
    │  └─ Initialize readBy array
    │
    ├─ FirestoreService.sendMessage()
    │  ├─ Save to messages/{chatId}/messages/
    │  └─ Update chats/{chatId} lastMessage
    │
    ├─ Firestore Stream Triggered
    │  ├─ getMessagesStream() notifies
    │  └─ StreamBuilder rebuilds
    │
    ├─ UI Updates
    │  ├─ Message appears in list
    │  ├─ Auto-scroll to bottom
    │  └─ Timestamp displayed
    │
    └─ Other Users' Devices
       ├─ Receive stream update
       ├─ Message appears instantly
       └─ Their UI updates
*/

/*
PRESENCE TRACKING FLOW:
User Opens App
    │
    ├─ InitState
    │
    ├─ RealtimeDatabaseService.setUserOnline()
    │  ├─ Set presence/{userId}/online = true
    │  └─ Set lastSeen timestamp
    │
    ├─ getAllUsersPresenceStream()
    │  ├─ Listens to entire presence node
    │  └─ Real-time updates
    │
    ├─ Home Screen Users Tab
    │  ├─ Displays all users
    │  ├─ Green for online
    │  └─ Gray for offline
    │
    └─ On App Close
       ├─ Dispose
       ├─ RealtimeDatabaseService.setUserOffline()
       ├─ Set presence/{userId}/online = false
       └─ Other users see status change instantly
*/

/*
CHAT CREATION FLOW:
User Taps + Button
    │
    ├─ Dialog Opens
    │  └─ Enter chat name
    │
    ├─ FirestoreService.createChat()
    │  ├─ Create ChatModel
    │  ├─ Add to chats collection
    │  └─ Return chat ID
    │
    ├─ HomeScreen Stream Updated
    │  ├─ getUserChatsStream() notified
    │  └─ Chat list updates
    │
    ├─ New chat appears in list
    │
    └─ User can start messaging
*/

/*
PRIVATE CHAT CREATION FLOW:
User Taps on User (Users Tab)
    │
    ├─ FirestoreService.createPrivateChatTransaction()
    │  ├─ Query existing chats
    │  ├─ Check if already exists
    │  ├─ If exists: Return existing ID
    │  └─ If not: Create new, return ID
    │
    ├─ Prevent Duplicates
    │  └─ Transaction ensures atomicity
    │
    ├─ Navigate to ChatScreen
    │  └─ Use returned chat ID
    │
    └─ Ready to message
*/

// INTEGRATION SUMMARY

/*
HOW FIREBASE SERVICES WORK TOGETHER:

Firebase Auth
    ↓
    └─→ Authenticates user
        │
        ├─→ Save user to Firestore
        │   └─→ User profile + metadata
        │
        └─→ Save user to Realtime DB
            └─→ User directory + presence


Firestore DB
    ├─→ Stores chats
    ├─→ Stores messages
    ├─→ Stores user profiles
    └─→ Enables complex queries


Realtime DB
    ├─→ Tracks user presence
    ├─→ Tracks online/offline
    ├─→ Instant sync
    └─→ Lightweight updates


Together:
    ├─→ Authentication: Firebase Auth
    ├─→ Permanent data: Firestore
    ├─→ Real-time status: Realtime DB
    ├─→ Optimal performance
    └─→ Complete chat system
*/

// Quick Reference for Development

/*
TO ADD NEW FEATURE:

1. Model Layer
   - Create model class in lib/models/

2. Service Layer
   - Add methods to appropriate service
   - Handle Firestore/Realtime DB operations
   - Add error handling

3. UI Layer
   - Add screen in lib/screens/
   - Use StreamBuilder for real-time data
   - Use Provider for dependency injection

4. Route
   - Add route in main.dart
   - Update navigation logic

5. Test
   - Test on emulator/device
   - Check Firestore/Realtime DB
   - Verify real-time updates
*/
