import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import '../services/cloudflare.dart';

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
  bool isFollowLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFollow();
  }

  // --- LOGIC (Follow/Unfollow) ---
  Future<void> _checkFollow() async {
    if (profileUid == currentUid) {
      if (mounted) setState(() => isFollowLoading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(profileUid)
        .collection('followers')
        .doc(currentUid)
        .get();

    if (mounted) {
      setState(() {
        isFollowing = doc.exists;
        isFollowLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => isFollowLoading = true);
    final batch = FirebaseFirestore.instance.batch();
    final userRef = FirebaseFirestore.instance.collection('users').doc(profileUid);
    final meRef = FirebaseFirestore.instance.collection('users').doc(currentUid);

    if (isFollowing) {
      batch.delete(userRef.collection('followers').doc(currentUid));
      batch.delete(meRef.collection('following').doc(profileUid));
      batch.update(userRef, {'followersCount': FieldValue.increment(-1)});
      batch.update(meRef, {'followingCount': FieldValue.increment(-1)});
    } else {
      batch.set(userRef.collection('followers').doc(currentUid), {});
      batch.set(meRef.collection('following').doc(profileUid), {});
      batch.update(userRef, {'followersCount': FieldValue.increment(1)});
      batch.update(meRef, {'followingCount': FieldValue.increment(1)});
    }
    await batch.commit();

    if (mounted) {
      setState(() {
        isFollowing = !isFollowing;
        isFollowLoading = false;
      });
    }
  }

  // --- UI CONSTRUCTION ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "heed", 
          style: TextStyle(
            color: Colors.black, 
            fontWeight: FontWeight.w900, 
            fontSize: 24, 
            letterSpacing: -1
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black),
            onPressed: () {},
          ),
          if (profileUid == currentUid)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.black),
              onPressed: () async {
                // Show settings menu with cache clear option
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  await CloudflareService.clearImageCache();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cache cleared!')),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.clear, size: 20),
                                      SizedBox(height: 8),
                                      Text(
                                        'Clear Image Cache',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(height: 1, color: Colors.grey[300]),
                            const SizedBox(height: 6),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  try {
                                    Navigator.pop(context);
                                    await FirebaseAuth.instance.signOut();
                                    await CloudflareService.clearImageCache();
                                    if (context.mounted) {
                                      context.go('/login');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Logout failed: $e')),
                                      );
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.logout, size: 20),
                                      SizedBox(height: 8),
                                      Text(
                                        'Logout',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(profileUid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          
          // If user doesn't exist, handle gracefully
          if (!snap.data!.exists) return const Center(child: Text("User not found"));

          final user = snap.data!.data() as Map<String, dynamic>;

          return DefaultTabController(
            length: 2,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(child: _buildPinterestHeader(user)),
                  SliverPersistentHeader(
                    delegate: _StickyTabBarDelegate(
                      const TabBar(
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.black,
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorWeight: 2,
                        tabs: [
                          Tab(text: "Created"),
                          Tab(text: "Saved"), // Pinterest calls "Reposts/Collections" Saved
                        ],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _MasonryContentGrid(uid: profileUid, isRepost: false),
                  _MasonryContentGrid(uid: profileUid, isRepost: true),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinterestHeader(Map<String, dynamic> user) {
    final isMe = profileUid == currentUid;
    final int followers = user['followersCount'] ?? 0;
    final int following = user['followingCount'] ?? 0;
    // Assuming you track 'postsCount' and 'repostsCount' in db. If not, remove them or query them.
    final int reposts = user['repostsCount'] ?? 0;

    return Column(
      children: [
        const SizedBox(height: 20),
        
        // 1. CENTERED AVATAR
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Gradient border effect for flair
            gradient: const LinearGradient(
              colors: [Color(0xFFE2336B), Color(0xFFFCAC46)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 47,
              backgroundImage: NetworkImage(user['profileImage'] ?? ''),
              onBackgroundImageError: (exception, stackTrace) {},
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 2. NAME & USERNAME
        Text(
          user['name'] ?? "User",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          "@${user['username']}",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 20),

        // 3. STATS ROW (Clean, airy, Pinterest-style text)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _statItem("$followers", "followers"),
            _divider(),
            _statItem("$following", "following"),
            _divider(),
            _statItem("$reposts", "reposts"),
          ],
        ),

        const SizedBox(height: 20),

        // 4. BIO
        if ((user['bio'] ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              user['bio'],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),

        const SizedBox(height: 24),

        // 5. ACTION BUTTONS (Pill Shaped)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isMe)
              _pillButton(text: "Edit Profile", onTap: () {})
            else ...[
              _pillButton(
                text: isFollowing ? "Following" : "Follow",
                isPrimary: !isFollowing,
                onTap: isFollowLoading ? () {} : _toggleFollow,
              ),
              const SizedBox(width: 12),
              _pillButton(text: "Message", onTap: () {}),
            ],
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _statItem(String count, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 20,
      width: 1,
      color: Colors.grey[300],
    );
  }

  Widget _pillButton({
    required String text, 
    required VoidCallback onTap, 
    bool isPrimary = false
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.black : Colors.grey[200],
          borderRadius: BorderRadius.circular(30), // Pill shape
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isPrimary ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// =================================================================
// THE MASONRY GRID (Pinterest Style)
// =================================================================

class _MasonryContentGrid extends StatelessWidget {
  final String uid;
  final bool isRepost;

  const _MasonryContentGrid({required this.uid, required this.isRepost});

  @override
  Widget build(BuildContext context) {
    // If it's "Created" (Posts), query posts collection
    // If it's "Saved/Reposts", you might query user's subcollection or array. 
    // For this snippet, I'll assume we query 'posts' for both but filter differently
    // or just show the same logic for demonstration.
    
    // NOTE: For 'reposts', typically you fetch the array of IDs from user doc, 
    // then query posts 'whereIn'. Firestore 'whereIn' is limited to 10.
    // A robust app usually duplicates repost data into a subcollection 'user_reposts'.
    
    Query query = FirebaseFirestore.instance.collection('posts');
    
    if (!isRepost) {
      query = query.where('uid', isEqualTo: uid).orderBy('createdAt', descending: true);
    } else {
      // Logic for Reposts (Assuming you have a way to filter them, e.g. a 'repostedBy' array field in posts 
      // OR querying a subcollection). 
      // For Demo: I will just show *all* posts to demonstrate the layout.
      // REPLACE THIS with your actual Repost query logic.
      query = query.limit(10); 
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              isRepost ? "No pins saved yet." : "No posts yet.",
              style: TextStyle(color: Colors.grey[400]),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: MasonryGridView.count(
            crossAxisCount: 2, // 2 Columns = Pinterest Style
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final images = List.from(data['images'] ?? []);
              final imgUrl = images.isNotEmpty ? images.first['preview'] : '';
              
              // Random aspect ratio for demo if height missing, 
              // or use actual dimensions if available in DB
              final double aspectRatio = (index % 3 == 0) ? 0.7 : 1.0; 

              return GestureDetector(
                onTap: () {
                   // Open Detail Page
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGE CARD
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16), // Rounded corners are key for Pinterest look
                      child: Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        cacheHeight: 600,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // TITLE / META (Optional, Pinterest usually shows title below)
                    if (data['title'] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          data['title'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    
                    // "Reposted" Badge if applicable
                    if (isRepost)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.repeat, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              "reposted",
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// =================================================================
// STICKY HEADER DELEGATE
// =================================================================
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _StickyTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}