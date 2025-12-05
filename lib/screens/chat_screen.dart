import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/message_model.dart';

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

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _firestoreService = context.read<FirestoreService>();
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
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                final messages = snapshot.data!.docs
                    .map((doc) => MessageModel.fromMap(
                          doc.data() as Map<String, dynamic>,
                        ))
                    .toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser =
                        message.senderUid == _authService.userId;

                    return Align(
                      alignment: isCurrentUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Column(
                          crossAxisAlignment: isCurrentUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.senderName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isCurrentUser
                                    ? Colors.white70
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message.content,
                              style: TextStyle(
                                color: isCurrentUser
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: isCurrentUser
                                    ? Colors.white54
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
