import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentUserEmail = '';
  String _currentUserName = '';
  bool _isGroup = false;

  late String _chatTitle;

  @override
  void initState() {
    super.initState();
    _chatTitle = widget.chatTitle;
    _isGroup = widget.isGroup;
    _loadCurrentUser();
    _checkIfGroup();
  }

  Future<void> _checkIfGroup() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null && data['isGroup'] == true) {
          setState(() {
            _isGroup = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _editChatNameDialog() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _SafeEditNameDialog(
        initialText: _chatTitle,
        title: 'Edit Chat Name',
        label: 'Chat Name',
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        final currentUid = authUser?.uid ?? _currentUserUid;

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'chatName': newName,
          if (currentUid.isNotEmpty) 'savedBy': FieldValue.arrayUnion([currentUid]),
        });

        if (currentUid.isNotEmpty && !_isGroup) {
          try {
            await FirebaseFirestore.instance.collection('users').doc(currentUid).set({
              'savedContacts': FieldValue.arrayUnion([
                newName.trim().toLowerCase(),
              ]),
            }, SetOptions(merge: true));

            final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
            if (chatDoc.exists) {
              final users = List<String>.from(chatDoc.data()?['users'] ?? []);
              for (final u in users) {
                if (u != currentUid && u.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUid)
                      .collection('saved_contacts')
                      .doc(u)
                      .set({
                    'uid': u,
                    'name': newName.trim(),
                    'savedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  await FirebaseFirestore.instance.collection('users').doc(currentUid).set({
                    'savedContacts': FieldValue.arrayUnion([u, newName.trim().toLowerCase()]),
                  }, SetOptions(merge: true));
                }
              }
            }
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _chatTitle = newName;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contact name saved: $newName'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update name: $e')),
          );
        }
      }
    }
  }

  Future<List<Map<String, String>>> _loadCandidates() async {
    final Map<String, Map<String, String>> candidates = {};
    final Set<String> alreadyAdded = {};

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      if (chatDoc.exists) {
        final data = chatDoc.data() ?? {};
        final added = List<String>.from(data['addedMembers'] ?? []);
        for (var a in added) {
          alreadyAdded.add(a.trim().toLowerCase());
        }
        final creator = (data['createdBy'] ?? '').toString().trim().toLowerCase();
        if (creator.isNotEmpty) {
          alreadyAdded.add(creator);
        }
        final users = List<String>.from(data['users'] ?? []);
        for (var u in users) {
          alreadyAdded.add(u.trim().toLowerCase());
        }
      }
    } catch (_) {}

    if (_currentUserName.isNotEmpty) {
      alreadyAdded.add(_currentUserName.trim().toLowerCase());
    }
    if (_currentUserUid.isNotEmpty) {
      alreadyAdded.add(_currentUserUid.trim().toLowerCase());
    }

    // 1. Load ONLY from the current user's 1-on-1 chats / contacts list
    try {
      final chatsSnap = await FirebaseFirestore.instance.collection('chats').get();
      for (var doc in chatsSnap.docs) {
        final data = doc.data();
        if ((data['isGroup'] ?? false) == true) continue;
        if (doc.id == widget.chatId) continue;
        if (data['isSelfChat'] == true) continue;

        final usersList = List<String>.from(data['users'] ?? []);
        final createdByUid = (data['createdByUid'] ?? '').toString();
        final createdBy = (data['createdBy'] ?? '').toString().trim();
        final savedByList = List<String>.from(data['savedBy'] ?? []);
        final rawChatName = (data['chatName'] ?? '').toString().trim();

        if (rawChatName.toLowerCase() == 'you') continue;

        // Current user MUST be part of this chat or have saved it
        final bool isParticipant = usersList.contains(_currentUserUid) ||
            (_currentUserUid.isNotEmpty && (createdByUid == _currentUserUid || savedByList.contains(_currentUserUid)));

        if (!isParticipant) continue;

        // Determine contact's name from current user's perspective
        final bool isCreator = _currentUserUid.isNotEmpty && createdByUid == _currentUserUid;
        final String displayName = isCreator ? rawChatName : (createdBy.isNotEmpty ? createdBy : rawChatName);

        if (displayName.isEmpty || displayName.toLowerCase() == 'you') continue;

        String otherUid = usersList.firstWhere(
          (u) => u != _currentUserUid,
          orElse: () => '',
        );

        if (alreadyAdded.contains(displayName.toLowerCase()) ||
            (otherUid.isNotEmpty && alreadyAdded.contains(otherUid.toLowerCase()))) {
          continue;
        }

        candidates[displayName.toLowerCase()] = {
          'name': displayName,
          'uid': otherUid,
        };
      }
    } catch (_) {}

    // 2. Also load from users/{currentUserUid}/saved_contacts
    if (_currentUserUid.isNotEmpty) {
      try {
        final savedSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserUid)
            .collection('saved_contacts')
            .get();
        for (var doc in savedSnap.docs) {
          final sData = doc.data();
          final sName = (sData['name'] ?? '').toString().trim();
          final sUid = (sData['uid'] ?? doc.id).toString().trim();
          if (sName.isEmpty || alreadyAdded.contains(sName.toLowerCase())) continue;
          if (sUid.isNotEmpty && alreadyAdded.contains(sUid.toLowerCase())) continue;

          if (!candidates.containsKey(sName.toLowerCase())) {
            candidates[sName.toLowerCase()] = {
              'name': sName,
              'uid': sUid,
            };
          }
        }
      } catch (_) {}
    }

    return candidates.values.toList();
  }

  Future<void> _addMemberToGroup(Map<String, String> user) async {
    final uid = user['uid'] ?? '';
    final name = (user['name'] ?? 'User').trim();

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'addedMembers': FieldValue.arrayUnion([name]),
        if (uid.isNotEmpty) 'users': FieldValue.arrayUnion([uid]),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name added to group!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add member: $e')),
        );
      }
    }
  }

  void _showAddMemberModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return FutureBuilder<List<Map<String, String>>>(
          future: _loadCandidates(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final list = snapshot.data ?? [];

            if (list.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 40, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'No contacts found.',
                          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'First add or start a chat with contacts in the Chats tab to invite them here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                      'Select from Chats to Add',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final u = list[index];
                        final name = u['name'] ?? 'User';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          trailing: const Icon(Icons.person_add, color: Colors.teal),
                          onTap: () => _addMemberToGroup(u),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, String>>> _loadGroupMembers() async {
    final List<Map<String, String>> memberList = [];
    final Set<String> seenNames = {};

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      if (!chatDoc.exists) return [];

      final chatData = chatDoc.data() ?? {};
      final createdBy = (chatData['createdBy'] ?? '').toString().trim();
      final addedMembers = List<String>.from(chatData['addedMembers'] ?? []);

      // Group Admin / Creator
      final adminName = createdBy.isNotEmpty ? createdBy : (_currentUserName.isNotEmpty ? _currentUserName : 'Admin');
      seenNames.add(adminName.toLowerCase());
      memberList.add({
        'name': adminName,
        'isMe': (adminName.toLowerCase() == _currentUserName.toLowerCase()) ? 'true' : 'false',
        'role': 'Admin',
      });

      // 1. If addedMembers exists, use only those explicitly added members!
      if (addedMembers.isNotEmpty) {
        for (final m in addedMembers) {
          final trimmed = m.trim();
          if (trimmed.isEmpty) continue;
          if (seenNames.contains(trimmed.toLowerCase())) continue;
          seenNames.add(trimmed.toLowerCase());

          final isMe = trimmed.toLowerCase() == _currentUserName.toLowerCase();
          memberList.add({
            'name': trimmed,
            'isMe': isMe ? 'true' : 'false',
            'role': 'Member',
          });
        }
        return memberList;
      }

      // 2. Fallback for older groups: resolve ONLY real names from users collection (never show raw UIDs)
      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      final Map<String, String> idToName = {};

      for (var u in usersSnap.docs) {
        final d = u.data();
        final uid = (d['uid'] ?? u.id).toString().trim();
        final email = (d['email'] ?? '').toString().trim().toLowerCase();
        final name = (d['name'] ?? '').toString().trim();
        if (name.isNotEmpty && name != 'User') {
          if (uid.isNotEmpty) idToName[uid] = name;
          if (email.isNotEmpty) idToName[email] = name;
        }
      }

      final groupUsers = List<String>.from(chatData['users'] ?? []);
      for (var identifier in groupUsers) {
        String? resolvedName;
        if (idToName.containsKey(identifier)) {
          resolvedName = idToName[identifier];
        } else if (idToName.containsKey(identifier.toLowerCase())) {
          resolvedName = idToName[identifier.toLowerCase()];
        }

        // Only add if it resolved to a real user name (never show raw UIDs!)
        if (resolvedName != null && resolvedName.isNotEmpty) {
          if (!seenNames.contains(resolvedName.toLowerCase())) {
            seenNames.add(resolvedName.toLowerCase());
            final isMe = resolvedName.toLowerCase() == _currentUserName.toLowerCase();
            memberList.add({
              'name': resolvedName,
              'isMe': isMe ? 'true' : 'false',
              'role': 'Member',
            });
          }
        }
      }
    } catch (_) {}

    return memberList;
  }

  void _showGroupInfoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return FutureBuilder<List<Map<String, String>>>(
          future: _loadGroupMembers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final members = snapshot.data ?? [];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.group, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _chatTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${members.length} members',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Members in this Group',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ),
                    ),
                    if (members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No members found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final m = members[index];
                            final name = m['name'] ?? 'User';
                            final isMe = m['isMe'] == 'true';
                            final role = m['role'] ?? 'Member';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade100,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    color: Colors.teal.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      isMe ? '$name (You)' : name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (role == 'Admin')
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.teal.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        'Admin',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal.shade800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _currentUserUid = '';

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final authUser = FirebaseAuth.instance.currentUser;
    String uid = authUser?.uid ?? '';
    String email = prefs.getString('user_email') ?? authUser?.email ?? '';
    String name = prefs.getString('user_name') ?? authUser?.displayName ?? '';

    if (name.isEmpty || name == 'User' || name == 'Guest User') {
      if (authUser != null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(authUser.uid).get();
          if (userDoc.exists) {
            final fetchedName = (userDoc.data()?['name'] as String?)?.trim();
            if (fetchedName != null && fetchedName.isNotEmpty) {
              name = fetchedName;
              await prefs.setString('user_name', name);
            }
          }
        } catch (_) {}
      }
    }

    if (name.isEmpty || name == 'User' || name == 'Guest User') {
      if (email.isNotEmpty) {
        name = email.split('@').first;
      } else {
        name = 'User';
      }
    }

    if (mounted) {
      setState(() {
        _currentUserUid = uid;
        _currentUserEmail = email;
        _currentUserName = name;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final now = FieldValue.serverTimestamp();
    final authUser = FirebaseAuth.instance.currentUser;
    final senderEmail = _currentUserEmail.isNotEmpty ? _currentUserEmail : (authUser?.email ?? '');
    String senderName = (_currentUserName.isNotEmpty && _currentUserName != 'User' && _currentUserName != 'Guest User')
        ? _currentUserName
        : (authUser?.displayName ?? '');
    if (senderName.isEmpty || senderName == 'User' || senderName == 'Guest User') {
      senderName = senderEmail.isNotEmpty ? senderEmail.split('@').first : 'User';
    }
    final senderUid = _currentUserUid.isNotEmpty ? _currentUserUid : (authUser?.uid ?? '');

    try {
      // 1. Add message to 'messages' subcollection in Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'text': text,
        'senderName': senderName,
        'senderEmail': senderEmail,
        'senderUid': senderUid,
        'timestamp': now,
      });

      // 2. Update last message in parent chat document
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': _isGroup ? '$senderName: $text' : text,
        'lastMessageTime': now,
      });

      // Auto scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _chatTitle,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isGroup ? Icons.edit : Icons.person_add_alt_1, color: Colors.white),
            tooltip: _isGroup ? 'Edit Group Name' : 'Save Contact / Edit Name',
            onPressed: _editChatNameDialog,
          ),
          if (_isGroup)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'Options',
              onSelected: (value) {
                if (value == 'add_member') {
                  _showAddMemberModal();
                } else if (value == 'group_info') {
                  _showGroupInfoModal();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'add_member',
                  child: Row(
                    children: [
                      Icon(Icons.person_add, color: Colors.teal),
                      SizedBox(width: 10),
                      Text('Add Member'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'group_info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.teal),
                      SizedBox(width: 10),
                      Text('Group Info'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Start chatting!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    final text = messageData['text'] ?? '';
                    final senderEmail = (messageData['senderEmail'] as String?)?.trim() ?? '';
                    final senderUid = (messageData['senderUid'] as String?)?.trim() ?? '';

                    final isMe = (_currentUserEmail.isNotEmpty && senderEmail == _currentUserEmail) ||
                        (_currentUserUid.isNotEmpty && senderUid == _currentUserUid);

                    String senderName = (messageData['senderName'] as String?)?.trim() ?? '';
                    if (senderName.isEmpty || senderName == 'User' || senderName == 'Guest User') {
                      if (senderEmail.isNotEmpty) {
                        senderName = senderEmail.split('@').first;
                      } else {
                        senderName = 'User';
                      }
                    }

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4.0, horizontal: 8.0),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 12.0),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.teal : Colors.grey.shade300,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe
                                ? const Radius.circular(12)
                                : const Radius.circular(0),
                            bottomRight: isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isGroup) ...[
                              Text(
                                isMe ? '$senderName (You)' : senderName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isMe
                                      ? Colors.white70
                                      : Colors.teal.shade800,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              text,
                              style: TextStyle(
                                fontSize: 16,
                                color: isMe ? Colors.white : Colors.black87,
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
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafeEditNameDialog extends StatefulWidget {
  final String initialText;
  final String title;
  final String label;

  const _SafeEditNameDialog({
    required this.initialText,
    required this.title,
    required this.label,
  });

  @override
  State<_SafeEditNameDialog> createState() => _SafeEditNameDialogState();
}

class _SafeEditNameDialogState extends State<_SafeEditNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      FocusScope.of(context).unfocus();
      Navigator.pop(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}