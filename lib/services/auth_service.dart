import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../models/user_model.dart';
import 'realtime_database_service.dart';

// Simple AppUser used throughout the app UI (keeps backward compatibility)
class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    DateTime created;
    try {
      final v = map['createdAt'];
      if (v is Timestamp) {
        created = v.toDate();
      } else if (v is String) {
        created = DateTime.parse(v);
      } else {
        created = DateTime.now();
      }
    } catch (_) {
      created = DateTime.now();
    }

    return AppUser(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RealtimeDatabaseService _realtime = RealtimeDatabaseService();

  AppUser? _currentUser;
  final _authStateController = StreamController<AppUser?>.broadcast();

  factory AuthService() => _instance;

  AuthService._internal() {
    // Listen to FirebaseAuth state changes and emit AppUser instances
    _auth.authStateChanges().listen((fbUser) async {
      if (fbUser == null) {
        _currentUser = null;
        _authStateController.add(null);
      } else {
        try {
          final doc = await _firestore.collection('users').doc(fbUser.uid).get();
          if (doc.exists) {
            _currentUser = AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } else {
            // Create minimal profile if missing
            final createdAt = DateTime.now();
            final profile = {
              'email': fbUser.email ?? '',
              'displayName': fbUser.displayName ?? '',
              'createdAt': createdAt.toIso8601String(),
            };
            await _firestore.collection('users').doc(fbUser.uid).set(profile);
            _currentUser = AppUser(uid: fbUser.uid, email: fbUser.email ?? '', displayName: fbUser.displayName, createdAt: createdAt);
          }

          // Set presence online in Realtime DB (non-blocking safety)
          if (_currentUser != null) {
            () async {
              try {
                await _realtime.setUserOnline(_currentUser!.uid, _currentUser!.displayName ?? '')
                    .timeout(const Duration(seconds: 3));
              } catch (e) {
                print('Set presence (auth change) timed out or failed: $e');
              }
            }();
          }

          _authStateController.add(_currentUser);
        } catch (e) {
          print('Auth state handling error: $e');
          _authStateController.add(null);
        }
      }
    });
  }

  AppUser? get currentUser => _currentUser;
  Stream<AppUser?> get authStateChanges => _authStateController.stream;
  bool get isAuthenticated => _currentUser != null;
  String? get userId => _currentUser?.uid;

  // Register using Firebase Authentication and persist profile to Firestore and Realtime DB
  Future<Map<String, dynamic>> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      if (password.length < 6) throw Exception('Password must be at least 6 characters');

      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final fbUser = userCredential.user;
      if (fbUser == null) throw Exception('Failed to create user');

      final createdAt = DateTime.now();
      final profile = {
        'email': email,
        'displayName': displayName,
        'createdAt': createdAt.toIso8601String(),
      };

      await _firestore.collection('users').doc(fbUser.uid).set(profile);
      // Fire-and-forget presence writes to avoid UI stalling if network is slow
      // Save profile to Realtime DB with a short timeout
      () async {
        try {
          await _realtime
              .saveUserProfile(userId: fbUser.uid, email: email, displayName: displayName)
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          print('Realtime save (register) timed out or failed: $e');
        }
      }();
      // Set online presence with a short timeout
      () async {
        try {
          await _realtime.setUserOnline(fbUser.uid, displayName).timeout(const Duration(seconds: 3));
        } catch (e) {
          print('Set presence (register) timed out or failed: $e');
        }
      }();

      final appUser = AppUser(uid: fbUser.uid, email: email, displayName: displayName, createdAt: createdAt);
      _currentUser = appUser;
      _authStateController.add(appUser);
      return {'user': appUser};
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  // Login using Firebase Authentication
  Future<Map<String, dynamic>> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final fbUser = userCredential.user;
      if (fbUser == null) throw Exception('Failed to sign in');

      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      AppUser appUser;
      if (doc.exists) {
        appUser = AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      } else {
        final createdAt = DateTime.now();
        final displayName = fbUser.displayName ?? '';
        final profile = {
          'email': email,
          'displayName': displayName,
          'createdAt': createdAt.toIso8601String(),
        };
        await _firestore.collection('users').doc(fbUser.uid).set(profile);
        appUser = AppUser(uid: fbUser.uid, email: email, displayName: displayName, createdAt: createdAt);
      }

      _currentUser = appUser;
      // Presence update should not block login completion
      () async {
        try {
          await _realtime.setUserOnline(appUser.uid, appUser.displayName ?? '')
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          print('Set presence (login) timed out or failed: $e');
        }
      }();
      _authStateController.add(appUser);
      return {'user': appUser};
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Logout and mark user offline
  Future<void> logout() async {
    try {
      final uid = _currentUser?.uid;
      await _auth.signOut();
      if (uid != null) {
        () async {
          try {
            await _realtime.setUserOffline(uid).timeout(const Duration(seconds: 3));
          } catch (e) {
            print('Set offline (logout) timed out or failed: $e');
          }
        }();
      }
      _currentUser = null;
      _authStateController.add(null);
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

  // Update display name and optionally photo
  Future<void> updateUserProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final uid = _currentUser?.uid;
      if (uid == null) throw Exception('No authenticated user');

      await _firestore.collection('users').doc(uid).update({
        'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _realtime.saveUserProfile(userId: uid, email: _currentUser!.email, displayName: displayName, photoUrl: photoUrl);

      _currentUser = AppUser(uid: uid, email: _currentUser!.email, displayName: displayName, createdAt: _currentUser!.createdAt);
      _authStateController.add(_currentUser);
    } catch (e) {
      print('Profile update error: $e');
      rethrow;
    }
  }

  void dispose() {
    _authStateController.close();
  }
}
