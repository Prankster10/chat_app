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
              // Close the dialog first to avoid overlay issues
              Navigator.of(context, rootNavigator: true).pop();

              // AuthService handles presence update non-blocking
              await _authService.logout();

              if (mounted) {
                // Clear navigation stack and go to login
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
    final uid = _authService.userId;
    if (uid == null) {
      return const Center(child: Text('Not authenticated'));
    }
    return StreamBuilder(
      stream: _firestoreService.getUserChatsStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading chats: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No chats yet. Start a conversation!'),
          );
        }

        final docs = snapshot.data!.docs;
        final chats = docs
            .map((doc) => ChatModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return ListTile(
              title: Text(chat.name),
              // If private, show other participant's name using memberDisplayNames
              subtitle: Text(
                chat.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: CircleAvatar(child: Text(_chatTitleForViewer(chat).substring(0,1).toUpperCase())),
              trailing: Text(
                _formatTime(chat.lastMessageTime),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatId: docs[index].id,
                      chatName: _chatTitleForViewer(chat),
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
    // Outer stream: Firestore users
    return StreamBuilder(
      stream: _firestoreService.getAllUsersStream(),
      builder: (context, usersSnap) {
        if (usersSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (usersSnap.hasError) {
          return Center(child: Text('Error loading users: ${usersSnap.error}'));
        }
        if (!usersSnap.hasData || usersSnap.data!.docs.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        final userDocs = usersSnap.data!.docs.where((d) => d.id != _authService.userId).toList();

        // Inner stream: Realtime Database presence
        return StreamBuilder(
          stream: _realtimeService.getAllUsersPresenceStream(),
          builder: (context, presenceSnap) {
            Map<dynamic, dynamic> presenceMap = {};
            if (presenceSnap.hasData && presenceSnap.data!.snapshot.value is Map) {
              presenceMap = presenceSnap.data!.snapshot.value as Map<dynamic, dynamic>;
            }

            return ListView.builder(
              itemCount: userDocs.length,
              itemBuilder: (context, index) {
                final userDoc = userDocs[index];
                final userData = userDoc.data() as Map<String, dynamic>? ?? {};
                final presenceData = presenceMap[userDoc.id] as Map<dynamic, dynamic>?;
                final isOnline = (presenceData != null && (presenceData['online'] == true));
                final displayName = userData['displayName'] ?? presenceData?['displayName'] ?? 'Unknown';

                return ListTile(
                  title: Text(displayName),
                  subtitle: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(color: isOnline ? Colors.green : Colors.grey),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isOnline ? Colors.green : Colors.grey,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  onTap: () async {
                    try {
                      final chatId = await _firestoreService.createPrivateChatTransaction(
                        user1Id: _authService.userId!,
                        user2Id: userDoc.id,
                        user1Name: _authService.currentUser?.displayName ?? 'Anonymous',
                        user2Name: displayName,
                      );

                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatId: chatId,
                              chatName: displayName,
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

  String _chatTitleForViewer(ChatModel chat) {
    if (!chat.isPrivate) return chat.name.isNotEmpty ? chat.name : 'Group Chat';
    final uid = _authService.userId;
    if (uid == null) return chat.name;
    final map = chat.memberDisplayNames ?? {};
    return map[uid] ?? chat.name;
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
