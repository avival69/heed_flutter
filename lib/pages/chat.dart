import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final currentUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: 'Messages'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMessagesTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }

  // ==================== MESSAGES TAB ====================
  Widget _buildMessagesTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: currentUid)
                .orderBy('lastMessageTime', descending: true)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (snap.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No messages yet', style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                itemCount: snap.data!.docs.length,
                itemBuilder: (_, i) {
                  final chat = snap.data!.docs[i].data() as Map<String, dynamic>;
                  final otherUid = (chat['participants'] as List<dynamic>)
                      .firstWhere((uid) => uid != currentUid);

                  return _buildChatTile(otherUid, chat);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== REQUESTS TAB ====================
  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chatRequests')
          .where('recipientUid', isEqualTo: currentUid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty) {
          return const Center(
            child: Text('No requests yet', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            final req = snap.data!.docs[i].data() as Map<String, dynamic>;
            final reqId = snap.data!.docs[i].id;
            return _buildRequestTile(req, reqId);
          },
        );
      },
    );
  }

  // ==================== WIDGETS ====================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search users...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(String otherUid, Map<String, dynamic> chat) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final user = snap.data!.data() as Map<String, dynamic>;

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(user['profileImage'] ?? ''),
          ),
          title: Text(user['name'] ?? 'Unknown'),
          subtitle: Text(
            chat['lastMessage'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          onTap: () {
            // TODO: Open chat conversation
          },
        );
      },
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> req, String reqId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(req['senderUid']).get(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final user = snap.data!.data() as Map<String, dynamic>;

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(user['profileImage'] ?? ''),
          ),
          title: Text(user['name'] ?? 'Unknown'),
          subtitle: const Text('Sent you a message request'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _acceptRequest(reqId, req['senderUid']),
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _declineRequest(reqId),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== LOGIC ====================
  Future<void> _acceptRequest(String reqId, String senderUid) async {
    // Update request status
    await FirebaseFirestore.instance
        .collection('chatRequests')
        .doc(reqId)
        .update({'status': 'accepted'});

    // Create chat document
    final chatId = _getChatId(currentUid!, senderUid);
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': [currentUid, senderUid],
      'lastMessage': '',
      'lastMessageTime': DateTime.now(),
    });
  }

  Future<void> _declineRequest(String reqId) async {
    await FirebaseFirestore.instance
        .collection('chatRequests')
        .doc(reqId)
        .update({'status': 'declined'});
  }

  Future<void> _sendChatRequest(String recipientUid) async {
    // Check if request already exists
    final existing = await FirebaseFirestore.instance
        .collection('chatRequests')
        .where('senderUid', isEqualTo: currentUid)
        .where('recipientUid', isEqualTo: recipientUid)
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request already sent')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('chatRequests').add({
      'senderUid': currentUid,
      'recipientUid': recipientUid,
      'status': 'pending',
      'timestamp': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat request sent!')),
    );
  }

  String _getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '$uid1-$uid2' : '$uid2-$uid1';
  }
}
