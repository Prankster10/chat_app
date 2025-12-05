import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  late AuthService _authService;
  late FirestoreService _firestoreService;
  final ScrollController _scrollController = ScrollController();
  bool _isMarkingAsRead = false;
  Set<String> _processedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _firestoreService = context.read<FirestoreService>();
    // Mark chat as read when opened
    _markChatAsRead();
  }

  Future<void> _markChatAsRead() async {
    if (_isMarkingAsRead) return;
    _isMarkingAsRead = true;
    try {
      final userId = _authService.userId;
      if (userId != null) {
        await _firestoreService.markChatAsRead(widget.chatId, userId);
      }
    } catch (e) {
      print('Error marking chat as read: $e');
    } finally {
      _isMarkingAsRead = false;
    }
  }

  // Mark new messages as read when they arrive while chat is open
  Future<void> _markNewMessagesAsRead(List<QueryDocumentSnapshot> messageDocs) async {
    final userId = _authService.userId;
    if (userId == null || _isMarkingAsRead) return;

    try {
      // First, always reset unread count since we're viewing the chat
      await _firestoreService.updateChat(widget.chatId, {
        'unreadCount.$userId': 0,
      });

      // Then mark only truly new unread messages as read
      final batch = _firestoreService.firestore.batch();
      bool hasUpdates = false;
      final newMessageIds = <String>{};

      for (var doc in messageDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final messageId = doc.id;
        final readBy = List<String>.from(data['readBy'] ?? []);
        final senderUid = data['senderUid'] as String?;
        
        newMessageIds.add(messageId);
        
        // If message is not from current user and not yet read by current user
        if (senderUid != null && senderUid != userId && !readBy.contains(userId)) {
          // Only process if we haven't processed this message before
          if (!_processedMessageIds.contains(messageId)) {
            batch.update(doc.reference, {
              'readBy': FieldValue.arrayUnion([userId])
            });
            hasUpdates = true;
            _processedMessageIds.add(messageId);
          }
        }
      }

      // Clean up old message IDs that are no longer in the chat
      _processedMessageIds.removeWhere((id) => !newMessageIds.contains(id));

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (e) {
      print('Error marking new messages as read: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final messageText = _messageController.text;
    _messageController.clear();

    try {
      final message = MessageModel(
        id: const Uuid().v4(),
        senderUid: _authService.userId!,
        senderName: _authService.currentUser?.displayName ?? 'Anonymous',
        content: messageText,
        timestamp: DateTime.now(),
        readBy: [_authService.userId!],
      );

      await _firestoreService.sendMessage(
        chatId: widget.chatId,
        message: message,
        senderId: _authService.userId!,
      );

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatName),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddUserDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _firestoreService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messageDocs = snapshot.data!.docs;
                final messages = messageDocs
                    .map((doc) => MessageModel.fromMap(
                          doc.data() as Map<String, dynamic>,
                        ))
                    .toList();

                // Mark new messages as read when chat is open
                if (messageDocs.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markNewMessagesAsRead(messageDocs);
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser =
                        message.senderUid == _authService.userId;

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.scale(
                            scale: 0.8 + (0.2 * value),
                            child: child,
                          ),
                        );
                      },
                      child: Align(
                        alignment: isCurrentUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Row(
                            mainAxisAlignment: isCurrentUser
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isCurrentUser) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    message.senderName.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrentUser
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                                      bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isCurrentUser
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      if (!isCurrentUser)
                                        Text(
                                          message.senderName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                                          ),
                                        ),
                                      if (!isCurrentUser) const SizedBox(height: 4),
                                      Text(
                                        message.content,
                                        style: TextStyle(
                                          color: isCurrentUser
                                              ? Colors.white
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatTime(message.timestamp),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isCurrentUser
                                                  ? Colors.white70
                                                  : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                                            ),
                                          ),
                                          if (isCurrentUser) ...[
                                            const SizedBox(width: 6),
                                            _buildSeenIndicator(message),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isCurrentUser) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    _authService.currentUser?.displayName?.substring(0, 1).toUpperCase() ?? 'A',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSeenIndicator(MessageModel message) {
    return FutureBuilder<ChatModel?>(
      future: _firestoreService.getChatById(widget.chatId),
      builder: (context, chatSnapshot) {
        if (chatSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (chatSnapshot.hasError || !chatSnapshot.hasData || chatSnapshot.data == null) {
          return const SizedBox.shrink();
        }
        
        final chat = chatSnapshot.data!;
        final userId = _authService.userId;
        if (userId == null) return const SizedBox.shrink();

        // A message is "seen" if all OTHER members in the chat have read it
        final otherMembers = chat.members.where((memberId) => memberId != userId).toList();
        final readBy = message.readBy ?? [];
        final allOtherMembersRead = otherMembers.isNotEmpty && 
            otherMembers.every((memberId) => readBy.contains(memberId));

        return Icon(
          allOtherMembersRead ? Icons.done_all : Icons.done,
          size: 14,
          color: allOtherMembersRead ? Colors.blue[300] : Colors.white54,
        );
      },
    );
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add user by email'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Email'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final email = controller.text.trim();
                if (email.isEmpty) {
                  return;
                }
                try {
                  // Find user by email in Firestore users collection
                  final qs = await _firestoreService.usersCollection
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();
                  if (qs.docs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User not found')),
                    );
                    return;
                  }
                  final userDoc = qs.docs.first;
                  final userId = userDoc.id;
                  final data = userDoc.data() as Map<String, dynamic>;
                  final displayName = data['displayName'] ?? 'User';

                  // Add to chat members
                  await _firestoreService.updateChat(widget.chatId, {
                    'members': FieldValue.arrayUnion([userId]),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added $displayName to chat')),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
