import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../layout/main_shell.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
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
    return CustomScrollView(
      controller: _controller,
      slivers: [
        /// 🔍 SEARCH BAR
        SliverAppBar(
          pinned: true,
          floating: true,
          elevation: 0,
          backgroundColor: Colors.white,
          toolbarHeight: 76,
          title: _searchBar(),
        ),

        /// 🟣 BIG HERO BANNER
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _heroBanner(),
          ),
        ),

        /// 🫧 CATEGORY BUBBLES
        SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _bubble("Shoes"),
                _bubble("Streetwear"),
                _bubble("Minimal"),
                _bubble("Watches"),
                _bubble("Tech"),
                _bubble("Travel"),
              ],
            ),
          ),
        ),

        /// 🔥 TRENDING
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              "Trending",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childCount: 6,
            itemBuilder: (context, i) => _trendCard(i),
          ),
        ),

        /// 💡 YOU MIGHT ALSO LIKE
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              "You might also like",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        /// 🧩 RECOMMENDATION GROUP
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _recommendationGroup(),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ---------------- UI COMPONENTS ----------------

  Widget _searchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: "Search ideas",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _heroBanner() {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to hero collection
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Text(
            "Minimal Fashion",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ActionChip(
        label: Text(text),
        onPressed: () {
          // TODO: Navigate to category search
        },
      ),
    );
  }

  Widget _trendCard(int i) {
    final height = (i % 2 == 0) ? 220.0 : 180.0;

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to trending results
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(child: Text("Trend $i")),
      ),
    );
  }

  Widget _recommendationGroup() {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to full recommendation page
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "New Shoes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (_, i) => Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
