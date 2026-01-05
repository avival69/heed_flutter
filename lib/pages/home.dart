import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../layout/main_shell.dart';
import 'post_detail.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      final dir = _controller.position.userScrollDirection;
      if (dir == ScrollDirection.reverse) {
        navController.hide();
      } else if (dir == ScrollDirection.forward) {
        navController.show();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      // ---------------- APP BAR ----------------
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

      // ---------------- FEED ----------------
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _skeletonFeed();
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No posts yet"));
          }

          return CustomScrollView(
            controller: _controller,
            slivers: [
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childCount: docs.length,
                  itemBuilder: (context, i) {
                    final data =
                        docs[i].data() as Map<String, dynamic>;

                    final images =
                        List<Map<String, dynamic>>.from(data['images'] ?? []);

                    if (images.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    // ✅ SAFE DIMENSION EXTRACTION
                    final cover = images.first;

                    final int w =
                        (cover['w'] ?? cover['width'] ?? 1);
                    final int h =
                        (cover['h'] ?? cover['height'] ?? 1);

                    double aspectRatio =
                        (w > 0 && h > 0) ? w / h : 1.0;

                    // Clamp to avoid extreme tall / wide images
                    aspectRatio = aspectRatio.clamp(0.5, 1.6);

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
                      child: _pin(images, aspectRatio),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  // ---------------- PIN TILE ----------------

  Widget _pin(
    List<Map<String, dynamic>> images,
    double aspectRatio,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: _imageCarousel(images),
      ),
    );
  }

  // ---------------- IMAGE CAROUSEL ----------------

  Widget _imageCarousel(List<Map<String, dynamic>> images) {
    final PageController controller = PageController();

    return StatefulBuilder(
      builder: (context, setState) {
        int index = 0;

        return Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                images[index]['preview'],
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(color: Colors.grey.shade300);
                },
              ),
            ),

            // Swipe layer
            if (images.length > 1)
              Positioned.fill(
                child: PageView.builder(
                  controller: controller,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => index = i),
                  itemBuilder: (_, __) => const SizedBox.shrink(),
                ),
              ),

            // Dots overlay
            if (images.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        images.length,
                        (i) => Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          width: i == index ? 6 : 5,
                          height: i == index ? 6 : 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == index
                                ? Colors.white
                                : Colors.white70,
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

  // ---------------- SKELETON ----------------

  Widget _imageSkeleton() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _skeletonFeed() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childCount: 8,
            itemBuilder: (_, __) => _imageSkeleton(),
          ),
        ),
      ],
    );
  }
}
