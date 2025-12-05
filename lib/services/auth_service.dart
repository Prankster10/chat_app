import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

// Simple User model
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
    return AppUser(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  AppUser? _currentUser;
  final _authStateController = StreamController<AppUser?>.broadcast();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  AppUser? get currentUser => _currentUser;
  Stream<AppUser?> get authStateChanges => _authStateController.stream;
  bool get isAuthenticated => _currentUser != null;
  String? get userId => _currentUser?.uid;

  // Register with email and password
  Future<dynamic> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Check if user already exists
      final existingQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('Email already registered');
      }

      // Validate password length
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      final uid = const Uuid().v4();
      final user = AppUser(
        uid: uid,
        email: email,
        displayName: displayName,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(user.toMap());

      _currentUser = user;
      _authStateController.add(user);
      
      return {'user': user};
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  // Login with email
  Future<dynamic> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Validate email and password
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }

      if (password.length < 6) {
        throw Exception('Invalid email or password');
      }

      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Invalid email or password');
      }

      final doc = querySnapshot.docs.first;
      final user = AppUser.fromMap(doc.data(), doc.id);

      _currentUser = user;
      _authStateController.add(user);
      
      return {'user': user};
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      _currentUser = null;
      _authStateController.add(null);
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      if (_currentUser != null) {
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'displayName': displayName,
        });

        _currentUser = AppUser(
          uid: _currentUser!.uid,
          email: _currentUser!.email,
          displayName: displayName,
          createdAt: _currentUser!.createdAt,
        );
        _authStateController.add(_currentUser);
      }
    } catch (e) {
      print('Profile update error: $e');
      rethrow;
    }
  }

  void dispose() {
    _authStateController.close();
  }
}
