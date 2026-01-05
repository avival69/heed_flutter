import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class Profile extends StatefulWidget {
  final String? userId;
  const Profile({super.key, this.userId});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final currentUid = FirebaseAuth.instance.currentUser!.uid;
  late final profileUid = widget.userId ?? currentUid;

  bool isFollowing = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _checkFollow();
  }

  Future<void> _checkFollow() async {
    if (profileUid == currentUid) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(profileUid)
        .collection('followers')
        .doc(currentUid)
        .get();

    setState(() {
      isFollowing = doc.exists;
      loading = false;
    });
  }

  Future<void> _toggleFollow() async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(profileUid);
    final meRef =
        FirebaseFirestore.instance.collection('users').doc(currentUid);

    if (isFollowing) {
      await userRef.collection('followers').doc(currentUid).delete();
      await meRef.collection('following').doc(profileUid).delete();
    } else {
      await userRef.collection('followers').doc(currentUid).set({});
      await meRef.collection('following').doc(profileUid).set({});
    }

    setState(() => isFollowing = !isFollowing);
  }

  void _showImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = profileUid == currentUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "heed",
          style: TextStyle(
            fontFamily: 'InstagramSans',
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(profileUid)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snap.data!.data() as Map<String, dynamic>;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _header(user, isMe),
              ),

              /// POSTS GRID
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('uid', isEqualTo: profileUid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final posts = snap.data!.docs;

                    return SliverMasonryGrid.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childCount: posts.length,
                      itemBuilder: (_, i) {
                        final images =
                            List<Map<String, dynamic>>.from(posts[i]['images']);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            images.first['preview'],
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(Map<String, dynamic> user, bool isMe) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showImage(user['profileImage']),
            child: CircleAvatar(
              radius: 45,
              backgroundImage: NetworkImage(user['profileImage']),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            "@${user['username']}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 6),
          Text(user['bio'] ?? ""),

          const SizedBox(height: 12),

          if (!isMe)
            ElevatedButton(
              onPressed: loading ? null : _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isFollowing ? Colors.grey[300] : Colors.blue,
              ),
              child: Text(
                isFollowing ? "Following" : "Follow",
                style: TextStyle(
                  color: isFollowing ? Colors.black : Colors.white,
                ),
              ),
            ),

          if (isMe)
            OutlinedButton(
              onPressed: () {
                // TODO: edit bio modal
              },
              child: const Text("Edit Profile"),
            ),
        ],
      ),
    );
  }
}
