import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'comment_sheet.dart'; 

class PostDetailPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> post;

  const PostDetailPage({
    super.key,
    required this.postId,
    required this.post,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final ScrollController _scrollController = ScrollController();
  int _currentImageIndex = 0; // To track active image for dots

  bool liked = false;
  bool saved = false;
  bool _isScrolling = false;
  late int likesCount;
  late int commentsCount;
  final uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    likesCount = widget.post['likesCount'] ?? 0;
    commentsCount = widget.post['commentsCount'] ?? 0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      setState(() => _isScrolling = true);
    } else if (notification is ScrollEndNotification) {
      setState(() => _isScrolling = false);
    }
    return false;
  }

  void _onTitleTap() {
    bool wasScrolling = _isScrolling;
    setState(() => _isScrolling = false);
    if (wasScrolling) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = List<Map<String, dynamic>>.from(widget.post['images'] ?? []);
    final cover = images.isNotEmpty ? images.first : null;
    
    // Calculate aspect ratio, defaulting to a taller portrait ratio if missing
    final double aspectRatio =
        cover != null && cover['width'] != null && cover['height'] != null
            ? cover['width'] / cover['height']
            : 0.8; 

    return Scaffold(
      backgroundColor: Colors.white,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          // 1. IMAGE SLIDER
          SliverToBoxAdapter(
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: aspectRatio,
                  child: PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() => _currentImageIndex = index);
                    },
                    itemBuilder: (_, i) {
                      return CachedNetworkImage(
                        imageUrl: images[i]['original'],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      );
                    },
                  ),
                ),
                
                // Back Button
                Visibility(
                  visible: _isScrolling,
                  child: Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 16,
                    child: _circleButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ),

                // Pagination Dots
                if (images.length > 1)
                  Positioned(
                    bottom: 40, // Lifted up so it doesn't get hidden by the sheet
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImageIndex == index ? 8 : 6,
                          height: _currentImageIndex == index ? 8 : 6,
                          decoration: BoxDecoration(
                            color: _currentImageIndex == index
                                ? Colors.black87
                                : Colors.black26,
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),

          // 2. CURVED WHITE SHEET
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -24, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Action Row (Likes, Comments, Share, Star)
                    _actionRow(),
                    const SizedBox(height: 20),

                    // B. Price
                    if (widget.post['price'] != null)
                      Text(
                        "\$${widget.post['price']}.00", // Formatting to match UI
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                    const SizedBox(height: 8),

                    // C. Seller Info (Small Row)
                    _sellerRow(),
                    const SizedBox(height: 16),

                    // D. Title
                    GestureDetector(
                      onTap: _onTitleTap,
                      child: Text(
                        (widget.post['title'] ?? 'Unknown Item').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // E. Caption / Description
                    if ((widget.post['caption'] ?? '').isNotEmpty)
                      Text(
                        widget.post['caption'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                    
                    const SizedBox(height: 24),

                    // F. Big Blue Button (Chat/Buy)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAACCFF), // Light blue from UI
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // Handle chat or buy action
                        },
                        child: const Text(
                          "Chat with seller", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // G. More Like This Header
                    const Text(
                      "More Like this",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // H. Grid
                    _moreLikeThis(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // ---------- WIDGET HELPERS ----------

  Widget _sellerRow() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.post['uid'])
          .get(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final u = snap.data!.data() as Map<String, dynamic>;

        return Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(u['profileImage']),
            ),
            const SizedBox(width: 8),
            Text(
              u['name'],
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _actionRow() {
    return Row(
      children: [
        _iconAction(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: _formatCount(likesCount),
          onTap: _toggleLike,
        ),
        const SizedBox(width: 20),
        _iconAction(
          icon: Icons.chat_bubble_outline,
          label: commentsCount.toString(),
          onTap: _openComments,
        ),
        const SizedBox(width: 20),
        _iconAction(
          icon: Icons.share_outlined, // Using share arrow
          onTap: () {},
        ),
        const Spacer(),
        // Star Icon for Save (per design)
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            saved ? Icons.star : Icons.star_border,
            size: 28,
            color: Colors.black87,
          ),
          onPressed: () => setState(() => saved = !saved),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count > 1000) {
      return "${(count / 1000).toStringAsFixed(1)}K";
    }
    return count.toString();
  }

  Widget _iconAction({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 26, color: Colors.black87),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600, 
                fontSize: 15
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _moreLikeThis() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .limit(6)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox(height: 100);
        final docs = snap.data!.docs;

        return MasonryGridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final img = data['images'][0];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailPage(
                      postId: docs[i].id,
                      post: data,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                     // Mimic different heights for staggered effect
                    aspectRatio: (i % 2 == 0) ? 0.7 : 0.85,
                    child: CachedNetworkImage(
                      imageUrl: img['preview'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8), // Slightly transparent
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12),
        ),
        child: Icon(icon, color: Colors.black, size: 20),
      ),
    );
  }

  // ---------- LOGIC ----------

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentSheet(
        postId: widget.postId,
        onNewComment: () {
          setState(() => commentsCount++);
        },
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (uid == null) return;
    setState(() {
      liked = !liked;
      likesCount += liked ? 1 : -1;
    });
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .update({
      'likesCount': FieldValue.increment(liked ? 1 : -1),
    });
  }
}