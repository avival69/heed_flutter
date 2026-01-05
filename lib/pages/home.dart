import 'package:flutter/material.dart';// for ScrollController, Scaffold 
import 'package:flutter/rendering.dart';// for ScrollDirection
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';// for SliverMasonryGrid(masonry (Pinterest-like) grid)
import 'package:cloud_firestore/cloud_firestore.dart'; // for Firestore database

import '../layout/main_shell.dart';
import 'post_detail.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}
///aswin donr thidd
class _HomeState extends State<Home> {
  final ScrollController _controller = ScrollController();

  final List<QueryDocumentSnapshot> _posts = [];
  bool _loading = false;
  bool _hasMore = true;

  static const int _limit = 10;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();

    _loadPosts();

    _controller.addListener(() {
      /// navbar hide / show
      final dir = _controller.position.userScrollDirection;
      if (dir == ScrollDirection.reverse) {
        navController.hide();
      } else if (dir == ScrollDirection.forward) {
        navController.show();
      }

      /// load more trigger
      if (_controller.position.pixels >=
              _controller.position.maxScrollExtent - 300 &&
          !_loading &&
          _hasMore) {
        _loadPosts();
      }
    });
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_loading) return;
    _loading = true;
    setState(() {});

    try {
      Query query = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_limit);

      if (!refresh && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snap = await query.get();

      if (refresh) {
        _posts.clear();
        _lastDoc = null;
        _hasMore = true;
      }

      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        _posts.addAll(snap.docs);
      } else {
        _hasMore = false;
      }
    } finally {
      _loading = false;
      setState(() {});
    }
  }
  //nshuf hudgdxsfdvefcswcsesc
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "heed",
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: 0.5,
            color: Colors.black,
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: () async => _loadPosts(refresh: true),
        child: CustomScrollView(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childCount: _posts.length,
                itemBuilder: (context, i) {
                  final data = _posts[i].data() as Map<String, dynamic>;

                  final images =
                      List<Map<String, dynamic>>.from(data['images'] ?? []);

                  if (images.isEmpty) return const SizedBox.shrink();

                  final cover = images.first;

                  final int w = (cover['w'] ?? cover['width'] ?? 1);
                  final int h = (cover['h'] ?? cover['height'] ?? 1);

                  double aspectRatio = (w > 0 && h > 0) ? w / h : 1.0;
                  aspectRatio = aspectRatio.clamp(0.5, 1.6);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(
                            postId: _posts[i].id,
                            post: data,
                          ),
                        ),
                      );
                    },
                    child: _pin(images, aspectRatio),
                  );
                },
              ),
            ),

            /// Loader at bottom
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : !_hasMore
                          ? const Text("No more posts")
                          : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pin(List<Map<String, dynamic>> images, double aspectRatio) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: _imageCarousel(images),
      ),
    );
  }

  Widget _imageCarousel(List<Map<String, dynamic>> images) {
    final PageController controller = PageController();

    return StatefulBuilder(
      builder: (context, setState) {
        int index = 0;

        return Stack(
          children: [
            // Main image viewer with PageView
            PageView.builder(
              controller: controller,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => index = i),
              itemBuilder: (_, i) => Image.network(
                images[i]['preview'] ?? images[i]['original'] ?? '',
                fit: BoxFit.cover,
                cacheWidth: 400,
                cacheHeight: 600,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),

            // Pagination dots
            if (images.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        images.length,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == index ? 7 : 6,
                          height: i == index ? 7 : 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == index ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
