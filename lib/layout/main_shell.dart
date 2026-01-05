import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'nav_visibility_controller.dart';

final navController = NavVisibilityController();

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});


  @override
Widget build(BuildContext context) {
  final location = GoRouterState.of(context).matchedLocation;

  final hideBottomNav =
      location.startsWith('/create') ||
      location.startsWith('/caption');

  // 🔥 THIS IS THE FIX
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (hideBottomNav) {
      navController.hide();
    } else {
      navController.show();
    }
  });

  final index = switch (location) {
    '/home' => 0,
    '/search' => 1,
    '/create' => 2,
    '/chat' => 3,
    '/profile' => 4,
    _ => 0,
  };

  return Scaffold(
    body: Stack(
      children: [
        Positioned.fill(child: child),

        AnimatedBuilder(
          animation: navController,
          builder: (_, __) {
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              bottom: navController.visible ? 0 : -90,
              left: 0,
              right: 0,
              child: _navBar(context, index),
            );
          },
        ),
      ],
    ),
  );
}


  // ---------------- NAV BAR ----------------

  Widget _navBar(BuildContext context, int index) {
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) {
            switch (i) {
              case 0:
                context.go('/home');
                break;
              case 1:
                context.go('/search');
                break;
              case 2:
                context.go('/create');
                break;
              case 3:
                context.go('/chat');
                break;
              case 4:
                context.go('/profile');
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: _items(index), // ✅ NOW DEFINED
        ),
      ),
    );
  }

  // ---------------- NAV ITEMS ----------------

  List<BottomNavigationBarItem> _items(int activeIndex) {
    BottomNavigationBarItem buildItem(
      IconData icon,
      int index,
    ) {
      final isActive = index == activeIndex;

      return BottomNavigationBarItem(
        label: '',
        icon: AnimatedScale(
          scale: isActive ? 1.25 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Icon(
            icon,
            color: isActive ? Colors.black : Colors.grey,
          ),
        ),
      );
    }

    return [
      buildItem(Icons.home_filled, 0),
      buildItem(Icons.search, 1),
      buildItem(Icons.add_box_outlined, 2),
      buildItem(Icons.chat_bubble_outline, 3),
      buildItem(Icons.person_outline, 4),
    ];
  }
}
