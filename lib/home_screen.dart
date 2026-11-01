import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _currentUserName =>
      FirebaseAuth.instance.currentUser?.displayName ??
      FirebaseAuth.instance.currentUser?.email?.split('@').first ??
      'User';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 1. Naya Chat ya Group Banane Ka Function
  Future<void> addNewChat({required bool isGroup}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => NewChatDialog(initialIsGroup: isGroup),
    );

    if (result != null) {
      final name = (result['name'] as String).trim();
      final isGrp = result['isGroup'] as bool? ?? isGroup;
      if (name.isEmpty) return;

      try {
        final doc = await FirebaseFirestore.instance.collection('chats').add({
          'chatName': name,
          'isGroup': isGrp,
          'users': [_currentUid],
          'createdBy': _currentUserName,
          'createdByUid': _currentUid,
          'lastMessage': 'No messages yet',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: doc.id,
                chatTitle: name,
                isGroup: isGrp,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  // 2. Naya Status Post Karne Ka Function
  Future<void> addNewStatus() async {
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => const NewStatusDialog(),
    );

    if (text != null && text.trim().isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('statuses').add({
          'statusText': text.trim(),
          'userName': _currentUserName,
          'userUid': _currentUid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status posted!'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat App'),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Groups'),
            Tab(text: 'Status'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ================= TAB 1: CHATS LIST =================
          StreamBuilder<QuerySnapshot>(
            stream: _currentUid.isEmpty
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('chats')
                    .where('users', arrayContains: _currentUid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filter: Only 1-on-1 chats (isGroup is false or not set)
              final docs = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['isGroup'] != true;
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text('No chats yet. Tap + to start.'));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final chatName = data['chatName'] ?? 'Chat';
                  final lastMessage = data['lastMessage'] ?? 'No messages yet';

                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(chatName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(lastMessage),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: docs[index].id,
                            chatTitle: chatName,
                            isGroup: false,
                          ),
                        ),
                      );
                    },
                    onLongPress: () => docs[index].reference.delete(),
                  );
                },
              );
            },
          ),

          // ================= TAB 2: GROUPS LIST =================
          StreamBuilder<QuerySnapshot>(
            stream: _currentUid.isEmpty
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('chats')
                    .where('users', arrayContains: _currentUid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // WHERE: Sirf Groups filter karo (isGroup == true)
              final docs = snapshot.data!.docs
                  .where((d) => (d.data() as Map<String, dynamic>)['isGroup'] == true)
                  .toList();

              if (docs.isEmpty) {
                return const Center(child: Text('No groups yet. Tap + to create.'));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final groupName = data['chatName'] ?? 'Group';
                  final lastMessage = data['lastMessage'] ?? 'No messages yet';

                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(lastMessage),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: docs[index].id,
                            chatTitle: groupName,
                            isGroup: true,
                          ),
                        ),
                      );
                    },
                    onLongPress: () => docs[index].reference.delete(),
                  );
                },
              );
            },
          ),

          // ================= TAB 3: STATUS LIST =================
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('statuses')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text('No status updates yet. Tap + to add.'));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final userName = data['userName'] ?? 'User';
                  final statusText = data['statusText'] ?? '';

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.teal, width: 2),
                      ),
                      child: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                    title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(statusText),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(userName),
                          content: Text(statusText, style: const TextStyle(fontSize: 18)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () {
          if (_tabController.index == 0) {
            addNewChat(isGroup: false);
          } else if (_tabController.index == 1) {
            addNewChat(isGroup: true);
          } else {
            addNewStatus();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Dialog for creating a new chat or group
class NewChatDialog extends StatefulWidget {
  final bool initialIsGroup;
  const NewChatDialog({super.key, this.initialIsGroup = false});

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final _controller = TextEditingController();
  late bool _isGroup;

  @override
  void initState() {
    super.initState();
    _isGroup = widget.initialIsGroup;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isGroup ? 'New Group' : 'New Chat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: _isGroup ? 'Group Name' : 'Chat Name',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Group Chat'),
            value: _isGroup,
            onChanged: (v) => setState(() => _isGroup = v ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, {'name': text, 'isGroup': _isGroup});
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Dialog for adding a text status
class NewStatusDialog extends StatefulWidget {
  const NewStatusDialog({super.key});

  @override
  State<NewStatusDialog> createState() => _NewStatusDialogState();
}

class _NewStatusDialogState extends State<NewStatusDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Text Status'),
      content: TextField(
        controller: _controller,
        maxLength: 60,
        decoration: const InputDecoration(
          hintText: 'Type your status here...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}
