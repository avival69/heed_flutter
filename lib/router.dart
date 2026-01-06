import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

// auth pages
import 'auth/login.dart';


// onboarding
import 'pages/onboarding.dart';
import 'pages/pending_verification.dart';

// shell + pages
import 'layout/main_shell.dart';
import 'pages/home.dart';
import 'pages/search.dart';
import 'pages/create.dart';
import 'pages/chat.dart';
import 'pages/profile.dart';

import 'services/db.dart';

/// --------------------
/// AUTH STATE NOTIFIER
/// --------------------
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }
}

final authNotifier = AuthStateNotifier();

/// --------------------
/// GO ROUTER
/// --------------------
final GoRouter router = GoRouter(
  initialLocation: '/',
  refreshListenable: authNotifier,

  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final loggedIn = user != null;
    final location = state.matchedLocation;

    final authRoutes = ['/login', '/signup', '/onboarding'];

    // 🚫 Not logged in
    if (!loggedIn && !authRoutes.contains(location)) {
      return '/login';
    }

    // 🚫 Logged in → no auth pages, EXCEPT allow /login if coming from onboarding
    if (loggedIn && authRoutes.contains(location)) {
      // Only redirect to onboarding if coming from signup or onboarding completion
      if (location == '/login' && state.uri.queryParameters['from'] == 'onboarding') {
        return null;
      }
      // If user is on /login after hot restart or manual navigation, stay on /login
      if (location == '/login') {
        return null;
      }
      return '/onboarding';
    }

    // 🚫 If logged in and trying to access protected routes, check if onboarding completed
    if (loggedIn && !authRoutes.contains(location)) {
      final userData = await DatabaseService().getUser(user!.uid);
      if (userData == null) {
        return '/onboarding';
      }
    }

    // 🚫 Never redirect away from onboarding if on onboarding
    if (loggedIn && location == '/onboarding') {
      return null;
    }

    return null;
  },

  routes: [
    /// ---------- AUTH ----------
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: '/pending',
      builder: (context, state) => const PendingVerificationPage(),
    ),

    /// ---------- APP SHELL ----------
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          redirect: (_, __) => '/home',
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Home(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/create',
          builder: (context, state) => const CreatePage(),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const ChatPage(),
        ),

        /// 👤 MY PROFILE
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Profile(),
        ),

        /// 👤 OTHER USER PROFILE
        GoRoute(
          path: '/u/:uid',
          builder: (context, state) {
            final uid = state.pathParameters['uid']!;
            return Profile(userId: uid);
          },
        ),
      ],
    ),
  ],
);
