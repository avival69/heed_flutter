import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentSheet extends StatefulWidget {
  final String postId;
  final VoidCallback onNewComment;

  const CommentSheet({
    super.key,
    required this.postId,
    required this.onNewComment,
  });

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController controller = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // 👇 this is the KEY FIX
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ---------- DRAG HANDLE ----------
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                "Comments",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Divider(),

              // ---------- COMMENTS LIST ----------
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.postId)
                      .collection('comments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (_, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No comments yet",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final c =
                            docs[i].data() as Map<String, dynamic>;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                NetworkImage(c['photoUrl']),
                          ),
                          title: Text(
                            c['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(c['text']),
                          onTap: () {
                            // TODO: Navigate to profile
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              // ---------- INPUT BAR ----------
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: "Add a comment…",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.black,
                      onPressed: _sendComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- SEND COMMENT ----------
  Future<void> _sendComment() async {
    if (controller.text.trim().isEmpty || uid == null) return;

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final user = userSnap.data()!;
    final text = controller.text.trim();

    controller.clear();

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'uid': uid,
      'name': user['name'],
      'photoUrl': user['profileImage'],
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // increment comment count
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .update({
      'commentsCount': FieldValue.increment(1),
    });

    widget.onNewComment();
  }
}
