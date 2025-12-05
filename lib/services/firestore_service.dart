import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get chatsCollection => _firestore.collection('chats');
  CollectionReference get messagesCollection => _firestore.collection('messages');
  CollectionReference get usersCollection => _firestore.collection('users');

  // ====================== CHAT OPERATIONS ======================

  // Create a new chat
  Future<String> createChat({
    required ChatModel chat,
  }) async {
    try {
      DocumentReference docRef = await chatsCollection.add(chat.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating chat: $e');
      rethrow;
    }
  }

  // Get all chats for a user
  Stream<QuerySnapshot> getUserChatsStream(String userId) {
    // Avoid requiring a composite index by omitting orderBy for now.
    // You can re-add orderBy('lastMessageTime', descending: true) after creating the index.
    return chatsCollection
      .where('members', arrayContains: userId)
      .snapshots();
  }

  // Get chat by ID
  Future<ChatModel?> getChatById(String chatId) async {
    try {
      DocumentSnapshot doc = await chatsCollection.doc(chatId).get();
      if (doc.exists) {
        return ChatModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting chat: $e');
      rethrow;
    }
  }

  // Update chat
  Future<void> updateChat(String chatId, Map<String, dynamic> data) async {
    try {
      await chatsCollection.doc(chatId).update(data);
    } catch (e) {
      print('Error updating chat: $e');
      rethrow;
    }
  }

  // Delete chat
  Future<void> deleteChat(String chatId) async {
    try {
      await chatsCollection.doc(chatId).delete();
    } catch (e) {
      print('Error deleting chat: $e');
      rethrow;
    }
  }

  // ====================== MESSAGE OPERATIONS ======================

  // Send message to a chat
  Future<String> sendMessage({
    required String chatId,
    required MessageModel message,
  }) async {
    try {
      // Add message to messages collection
      DocumentReference docRef = await messagesCollection
          .doc(chatId)
          .collection('messages')
          .add({
            ...message.toMap(),
            // Ensure Firestore Timestamp type for rules and ordering
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Update chat's last message
      await updateChat(chatId, {
        'lastMessage': message.content,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages stream for a chat
  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return messagesCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get messages with pagination
  Future<QuerySnapshot> getMessagesWithPagination(
    String chatId, {
    DocumentSnapshot? startAfter,
    int pageSize = 20,
  }) async {
    try {
      Query query = messagesCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      return await query.get();
    } catch (e) {
      print('Error getting messages with pagination: $e');
      rethrow;
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead(
    String chatId,
    String messageId,
    String userId,
  ) async {
    try {
      await messagesCollection
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readBy': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      print('Error marking message as read: $e');
      rethrow;
    }
  }

  // Delete message
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await messagesCollection
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  // ====================== USER OPERATIONS ======================

  // Save user in Firestore
  Future<void> saveUser({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    try {
      await usersCollection.doc(userId).set(userData, SetOptions(merge: true));
    } catch (e) {
      print('Error saving user: $e');
      rethrow;
    }
  }

  // Get user data
  Future<DocumentSnapshot> getUserData(String userId) async {
    try {
      return await usersCollection.doc(userId).get();
    } catch (e) {
      print('Error getting user data: $e');
      rethrow;
    }
  }

  // Get user stream
  Stream<DocumentSnapshot> getUserStream(String userId) {
    return usersCollection.doc(userId).snapshots();
  }

  // Search users by display name
  Future<QuerySnapshot> searchUsers(String query) async {
    try {
      return await usersCollection
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: query + 'z')
          .get();
    } catch (e) {
      print('Error searching users: $e');
      rethrow;
    }
  }

  // Get all users
  Future<QuerySnapshot> getAllUsers() async {
    try {
      return await usersCollection.get();
    } catch (e) {
      print('Error getting all users: $e');
      rethrow;
    }
  }

  // Stream all users
  Stream<QuerySnapshot> getAllUsersStream() {
    return usersCollection.snapshots();
  }

  // ====================== TRANSACTION OPERATIONS ======================

  // Create private chat (transaction)
  Future<String> createPrivateChatTransaction({
    required String user1Id,
    required String user2Id,
    required String user1Name,
    required String user2Name,
  }) async {
    try {
      String chatId = '';
      await _firestore.runTransaction((transaction) async {
        // Check if chat already exists
        QuerySnapshot existing = await _firestore
            .collection('chats')
            .where('members', arrayContains: user1Id)
            .where('isPrivate', isEqualTo: true)
            .get();

        for (var doc in existing.docs) {
          ChatModel chat = ChatModel.fromMap(doc.data() as Map<String, dynamic>);
          if (chat.members.contains(user2Id)) {
            chatId = doc.id;
            return;
          }
        }

        // Create new chat if it doesn't exist
        // For private chats, store a per-member display name so each user sees the other user's name.
        ChatModel newChat = ChatModel(
          id: '',
          name: '', // derived per viewer
          members: [user1Id, user2Id],
          createdBy: user1Id,
          createdAt: DateTime.now(),
          lastMessage: 'Chat started',
          lastMessageTime: DateTime.now(),
          isPrivate: true,
        );

        DocumentReference newDocRef = chatsCollection.doc();
        final data = newChat.copyWith(id: '').toMap();
        data['memberDisplayNames'] = {
          user1Id: user2Name,
          user2Id: user1Name,
        };
        transaction.set(newDocRef, data);

        chatId = newDocRef.id;
      });

      return chatId;
    } catch (e) {
      print('Error creating private chat: $e');
      rethrow;
    }
  }
}
