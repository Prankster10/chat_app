import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Reference to users node
  DatabaseReference get usersRef => _database.ref('users');

  // Reference to presence node
  DatabaseReference get presenceRef => _database.ref('presence');

  // Set user online status (with onDisconnect to mark offline)
  Future<void> setUserOnline(String userId, String displayName) async {
    try {
      final ref = presenceRef.child(userId);
      // Ensure onDisconnect marks user offline and updates lastSeen
      try {
        await ref.onDisconnect().update({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });
      } catch (_) {}

      await ref.update({
        'online': true,
        'lastSeen': ServerValue.timestamp,
        'displayName': displayName,
      });
    } catch (e) {
      print('Error setting user online: $e');
      rethrow;
    }
  }

  // Set user offline status
  Future<void> setUserOffline(String userId) async {
    try {
      await presenceRef.child(userId).update({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error setting user offline: $e');
      rethrow;
    }
  }

  // Get user presence stream
  Stream<DatabaseEvent> getUserPresenceStream(String userId) {
    return presenceRef.child(userId).onValue;
  }

  // Get all users presence
  Stream<DatabaseEvent> getAllUsersPresenceStream() {
    return presenceRef.onValue;
  }

  // Save user profile in Realtime Database
  Future<void> saveUserProfile({
    required String userId,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      await usersRef.child(userId).set({
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving user profile: $e');
      rethrow;
    }
  }

  // Get user data
  Future<DataSnapshot> getUserData(String userId) async {
    try {
      return await usersRef.child(userId).get();
    } catch (e) {
      print('Error getting user data: $e');
      rethrow;
    }
  }

  // Listen to user data changes
  Stream<DatabaseEvent> getUserDataStream(String userId) {
    return usersRef.child(userId).onValue;
  }

  // Update user last seen
  Future<void> updateLastSeen(String userId) async {
    try {
      await presenceRef.child(userId).update({
        'lastSeen': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error updating last seen: $e');
      rethrow;
    }
  }

  // Get all users
  Stream<DatabaseEvent> getAllUsersStream() {
    // Prefer presence for live online/offline states with displayName
    return presenceRef.onValue;
  }
}
