import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // USER
  // ============================================================

  Future<void> createGeneralUser({
    required String uid,
    required String? email,
    required String name,
    required int age,
    required String gender,
    required String location,
    required String username,
    required String bio,
    required String profileImageUrl,
    required List<String> interests,
  }) async {
    await _db.collection('users').doc(uid).set({
      "uid": uid,
      "email": email,
      "name": name,
      "username": username.toLowerCase(),
      "profileImage": profileImageUrl,
      "bio": bio,
      "gender": gender,
      "age": age,
      "location": location,
      "interests": interests,

      "role": "general",
      "status": "approved",
      "isBanned": false,

      "followersCount": 0,
      "followingCount": 0,
      "savedItemsCount": 0,
      "repostsCount": 0,

      // 🔥 USER BEHAVIOR TRACKING
      "likedPosts": [],          // [{postId, tags, createdAt}]
      "repostedPosts": [],       // [{postId, originalUid, createdAt}]
      "notInterestedPosts": [],  // [postId]

      "createdAt": FieldValue.serverTimestamp(),
      "lastActive": FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // POSTS
  // ============================================================

  Future<void> createPost({
    required String uid,
    required List<Map<String, dynamic>> images,
    required int width,
    required int height,
    required String title,
    required String caption,
    String? price,
    required List<String> tags,
    required bool allowComments,
    required bool allowChat,
    required bool showLikes,
  }) async {
    await _db.collection('posts').add({
      "uid": uid,
      "images": images, // [{id, preview, original, width, height}]
      "width": width,   // cover image
      "height": height,

      "title": title,
      "caption": caption,
      "price": price,
      "tags": tags,

      "allowComments": allowComments,
      "allowChat": allowChat,
      "showLikes": showLikes,

      "likesCount": 0,
      "commentsCount": 0,
      "repostsCount": 0,

      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // LIKE / UNLIKE
  // ============================================================

  Future<void> likePost({
    required String postId,
    required List<String> tags,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final batch = _db.batch();

    batch.update(_db.collection('posts').doc(postId), {
      "likesCount": FieldValue.increment(1),
    });

    batch.update(_db.collection('users').doc(uid), {
      "likedPosts": FieldValue.arrayUnion([
        {
          "postId": postId,
          "tags": tags,
          "createdAt": FieldValue.serverTimestamp(),
        }
      ]),
    });

    await batch.commit();
  }

  Future<void> unlikePost({
    required String postId,
    required Map<String, dynamic> likedEntry,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final batch = _db.batch();

    batch.update(_db.collection('posts').doc(postId), {
      "likesCount": FieldValue.increment(-1),
    });

    batch.update(_db.collection('users').doc(uid), {
      "likedPosts": FieldValue.arrayRemove([likedEntry]),
    });

    await batch.commit();
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  Future<void> addComment({
    required String postId,
    required String text,
    required String name,
    required String photoUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final batch = _db.batch();

    batch.set(
      _db
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(),
      {
        "uid": uid,
        "name": name,
        "photoUrl": photoUrl,
        "text": text,
        "createdAt": FieldValue.serverTimestamp(),
      },
    );

    batch.update(_db.collection('posts').doc(postId), {
      "commentsCount": FieldValue.increment(1),
    });

    await batch.commit();
  }

  // ============================================================
  // REPOST
  // ============================================================

  Future<void> repostPost({
    required String postId,
    required String originalUid,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final batch = _db.batch();

    batch.update(_db.collection('users').doc(uid), {
      "repostedPosts": FieldValue.arrayUnion([
        {
          "postId": postId,
          "originalUid": originalUid,
          "createdAt": FieldValue.serverTimestamp(),
        }
      ]),
      "repostsCount": FieldValue.increment(1),
    });

    batch.update(_db.collection('posts').doc(postId), {
      "repostsCount": FieldValue.increment(1),
    });

    await batch.commit();
  }

  // ============================================================
  // SAVE / UNSAVE
  // ============================================================

  Future<void> savePost(String postId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _db.collection('users').doc(uid).update({
      "savedItemsCount": FieldValue.increment(1),
      "savedPosts": FieldValue.arrayUnion([postId]),
    });
  }

  Future<void> unsavePost(String postId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _db.collection('users').doc(uid).update({
      "savedItemsCount": FieldValue.increment(-1),
      "savedPosts": FieldValue.arrayRemove([postId]),
    });
  }

  // ============================================================
  // NOT INTERESTED
  // ============================================================

  Future<void> markNotInterested(String postId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _db.collection('users').doc(uid).update({
      "notInterestedPosts": FieldValue.arrayUnion([postId]),
    });
  }
  // ---------- BUSINESS USER ----------
  Future<void> createBusinessUser({
    required String uid,
    required String? email,
    required String companyName,
    required String phone,
    required String gst,
    required String address,
    required String website,
    required String category,
    required String publicEmail,
    required String profileImageUrl, // Logo
  }) async {
    await _db.collection('users').doc(uid).set({
      // --- Identity ---
      "uid": uid,
      "email": email, // Login Email
      "role": "business",
      "status": "pending",
    
      // --- Visuals ---
      "profileImage": profileImageUrl, 
      "bio": "Welcome to $companyName", // Default bio

      // --- Business Essentials ---
      "businessDetails": {
        "companyName": companyName,
        "gst": gst,
        "phone": phone,
        "address": address,
      },
    
      "category": category,
      "website": website,
      "publicEmail": publicEmail,

      // --- Trust Signals ---
      "isVerified": false,
      "rating": 0.0,
      "reviewCount": 0,

      // --- Technical ---
      "fcmToken": "",
      "createdAt": FieldValue.serverTimestamp(),
      "lastActive": FieldValue.serverTimestamp(),
      "isBanned": false,
    });
  }



  
}