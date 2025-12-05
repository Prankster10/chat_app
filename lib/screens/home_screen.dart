import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/realtime_database_service.dart';
import '../models/chat_model.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AuthService _authService;
  late FirestoreService _firestoreService;
  late RealtimeDatabaseService _realtimeService;
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = context.read<AuthService>();
    _firestoreService = context.read<FirestoreService>();
    _realtimeService = context.read<RealtimeDatabaseService>();

    // Set user online
    if (_authService.userId != null) {
      _realtimeService.setUserOnline(
        _authService.userId!,
        _authService.currentUser?.displayName ?? 'Anonymous',
      );
    }
  }

  @override
  void dispose() {
    // Set user offline
    if (_authService.userId != null) {
      _realtimeService.setUserOffline(_authService.userId!);
    }
    super.dispose();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_authService.userId != null) {
                await _realtimeService.setUserOffline(_authService.userId!);
              }
              await _authService.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => const _NewChatDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildChatsTab() : _buildUsersTab(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    return StreamBuilder(
      stream: _firestoreService.getUserChatsStream(_authService.userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No chats yet. Start a conversation!'),
          );
        }

        final chats = snapshot.data!.docs
            .map((doc) => ChatModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return ListTile(
              title: Text(chat.name),
              subtitle: Text(
                chat.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _formatTime(chat.lastMessageTime),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatId: snapshot.data!.docs[index].id,
                      chatName: chat.name,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder(
      stream: _realtimeService.getAllUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('No users found'));
        }

        final usersMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final users = usersMap.entries
            .where((entry) => entry.key != _authService.userId)
            .toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final userData =
                (user.value as Map<dynamic, dynamic>?) ?? {};
            final isOnline = userData['online'] ?? false;

            return ListTile(
              title: Text(userData['displayName'] ?? 'Unknown'),
              subtitle: Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: isOnline ? Colors.green : Colors.grey,
                ),
              ),
              leading: CircleAvatar(
                backgroundColor: isOnline ? Colors.green : Colors.grey,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              onTap: () async {
                // Create private chat
                try {
                  final chatId =
                      await _firestoreService.createPrivateChatTransaction(
                    user1Id: _authService.userId!,
                    user2Id: user.key,
                    user1Name:
                        _authService.currentUser?.displayName ?? 'Anonymous',
                    user2Name: userData['displayName'] ?? 'Unknown',
                  );

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          chatId: chatId,
                          chatName: userData['displayName'] ?? 'Unknown',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class _NewChatDialog extends StatefulWidget {
  const _NewChatDialog({Key? key}) : super(key: key);

  @override
  State<_NewChatDialog> createState() => __NewChatDialogState();
}

class __NewChatDialogState extends State<_NewChatDialog> {
  final _chatNameController = TextEditingController();

  @override
  void dispose() {
    _chatNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Chat'),
      content: TextField(
        controller: _chatNameController,
        decoration: const InputDecoration(
          hintText: 'Chat name',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (_chatNameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a chat name')),
              );
              return;
            }

            final authService = context.read<AuthService>();
            final firestoreService = context.read<FirestoreService>();

            try {
              final chatModel = ChatModel(
                id: '',
                name: _chatNameController.text,
                members: [authService.userId!],
                createdBy: authService.userId!,
                createdAt: DateTime.now(),
                lastMessage: 'Chat created',
                lastMessageTime: DateTime.now(),
                isPrivate: false,
              );

              await firestoreService.createChat(chat: chatModel);

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat created successfully')),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
