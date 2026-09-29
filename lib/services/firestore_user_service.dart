import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:spotify_fy/models/user_profile.dart';

/// Client-side mirror for Google users. Email/password accounts have no
/// Firebase Auth session, so the backend `syncUserToFirestore` (admin SDK) is
/// the primary path. This is best-effort — failures are swallowed.
///
/// FirebaseFirestore.instance is resolved lazily inside [syncUser] so
/// constructing this service never throws (desktop, tests, or missing
/// google-services.json all degrade to a debug log instead of a crash).
class FirestoreUserService {
  Future<void> syncUser(UserProfile user) async {
    try {
      final db = FirebaseFirestore.instance;
      final fbUser = FirebaseAuth.instance.currentUser;
      // Email/password accounts have no Firebase Auth session, so security
      // rules deny the write (request.auth == null) — skip the guaranteed
      // failure. The backend admin-SDK mirror already covers those users;
      // only Google users (signInWithCredential) have a session to write with.
      if (fbUser == null) {
        debugPrint('Firestore client sync skipped (no Firebase session): ${user.id}');
        return;
      }
      await db.collection('users').doc(user.id).set(
        {
          'id': user.id,
          'email': user.email,
          'username': user.username,
          'firstName': user.firstName,
          'lastName': user.lastName,
          'avatarUrl': user.avatarUrl,
          'bio': user.bio,
          'preferences': user.preferences,
          'stats': user.stats,
          'updatedAt': FieldValue.serverTimestamp(),
          'provider': 'google',
          'firebaseUid': fbUser.uid,
          if (user.createdAt != null) 'createdAt': Timestamp.fromDate(user.createdAt!),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Firestore client sync skipped: $e');
    }
  }
}
