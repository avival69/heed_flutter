import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- GENERAL USER ----------
  Future<void> createGeneralUser({
    required User user,
    required String name,
    required int age,
    required String gender,
    required String location,
    required String username,
    required String bio,
    required String profileImageUrl, // <--- R2 Link
    required List<String> interests,
  }) async {
    await _db.collection('users').doc(user.uid).set({
      // --- Identity ---
      "uid": user.uid,
      "email": user.email,
      "name": name,
      "gender": gender,
      "age": age,
      "location": location,
      "interests": interests,

      // --- Essentials ---
      "profileImage": profileImageUrl,
      "username": username.toLowerCase(),
      "bio": bio,

      // --- Role & Status ---
      "role": "general",
      "status": "approved",

      // --- Social Metrics ---
      "followersCount": 0,
      "followingCount": 0,
      "savedItemsCount": 0,

      // --- Technical ---
      "fcmToken": "", // Update this later via NotificationService
      "createdAt": FieldValue.serverTimestamp(),
      "lastActive": FieldValue.serverTimestamp(),
      "isBanned": false,
    });
  }

  // ---------- BUSINESS USER ----------
  Future<void> createBusinessUser({
    required User user,
    required String companyName,
    required String phone,
    required String gst,
    required String address,
    required String website,
    required String category,
    required String publicEmail,
    required String profileImageUrl, // Logo
  }) async {
    await _db.collection('users').doc(user.uid).set({
      // --- Identity ---
      "uid": user.uid,
      "email": user.email, // Login Email
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
  // ---------- CREATE POST ----------
 // ---------- CREATE POST ----------
Future<void> createPost({
  required String uid,
  required List<Map<String, dynamic>> images,
  required int width,
  required int height,
  required String title,
  required String caption,
  String? price,
  List<String>? tags,
  required bool allowComments,
  required bool allowChat,
  required bool showLikes,
}) async {
  await _db.collection('posts').add({
    "uid": uid,

    // 🔑 REQUIRED FOR MASONRY
    "width": width,
    "height": height,

    // Images
    "images": images,

    // Content
    "title": title,
    "caption": caption,
    "price": price,

    // Meta
    "tags": tags ?? [],
    "allowComments": allowComments,
    "allowChat": allowChat,
    "showLikes": showLikes,

    // Stats
    "likesCount": 0,
    "commentsCount": 0,

    // System
    "type": "general",
    "createdAt": FieldValue.serverTimestamp(),
  });
}







  
}