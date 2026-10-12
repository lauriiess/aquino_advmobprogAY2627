import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../constants.dart';
import '../models/user.dart';


ValueNotifier<UserService> userService = ValueNotifier(UserService());

/// tells us which login the session came from
enum LoginType { none, dummyJson, firebase }

/// an error that already has a message we can show as is
class AppException implements Exception {
  final String message;
  AppException(this.message);

  @override
  String toString() => message;
}

/// turns any error into a short message the user can understand
String friendlyError(Object error) {
  if (error is AppException) return error.message;

  if (error is fb.FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'weak-password':
        return 'That password is too weak.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'requires-recent-login':
        return 'Please log in again and retry.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException) {
    return 'No connection. Check your internet and try again.';
  }

  return 'Something went wrong. Please try again.';
}

class UserService {
  /// dummyjson occasionally resets the connection (errno 104). Use a fresh
  /// client per attempt (no stale keep-alive socket) and retry with backoff.
  Future<http.Response> _send(
    Future<http.Response> Function(http.Client client) request, {
    int maxAttempts = 4,
  }) async {
    for (var attempt = 1;; attempt++) {
      final client = http.Client();
      try {
        return await request(client).timeout(const Duration(seconds: 15));
      } catch (e) {
        final retryable = e is http.ClientException ||
            e is SocketException ||
            e is TimeoutException;
        if (!retryable || attempt >= maxAttempts) rethrow;
      } finally {
        client.close();
      }
      await Future.delayed(Duration(milliseconds: 400 * attempt));
    }
  }

  Map<String, dynamic> data = {};

  // ---------------------------------------------------------------------
  // Firebase Auth
  // ---------------------------------------------------------------------
  final fb.FirebaseAuth firebaseAuth = fb.FirebaseAuth.instance;

  fb.User? get currentUser => firebaseAuth.currentUser;

  Stream<fb.User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<fb.UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _startFirebaseSession(credential.user);
    return credential;
  }

  Future<fb.UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _startFirebaseSession(credential.user);
    return credential;
  }

  Future<void> signOut() => logout();

  // changes the display name and saves it locally too
  Future<void> updateUsername({required String username}) async {
    final user = currentUser!;
    await user.updateDisplayName(username);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setString(_profileKey(user.uid, 'username'), username);
  }

  Future<void> deleteAccount({
  required String email,
  required String password,
}) async {
  // re-login is required before deleting
  final user = currentUser!;
  final uid = user.uid;
  final credential = fb.EmailAuthProvider.credential(
    email: email,
    password: password,
  );
  await user.reauthenticateWithCredential(credential);

  // delete the Firestore data while still signed in
  final userRef = FirebaseFirestore.instance.collection('Users').doc(uid);
  for (final sub in ['cart', 'orders']) {
    final snap = await userRef.collection(sub).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
  await userRef.delete();

  // delete the login itself, so the email and password stop working
  await user.delete();

  // remove the saved details of the deleted account
  final prefs = await SharedPreferences.getInstance();
  for (final field in _profileFields) {
    await prefs.remove(_profileKey(uid, field));
  }
  await logout();
}

  // needs the current password first, then sets the new one
  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    final user = currentUser!;
    final credential = fb.EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// gets a fresh Firebase token (they expire after about an hour)
  Future<String?> refreshFirebaseToken() async {
    final token = await currentUser?.getIdToken(true);
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('accessToken', token);
    }
    return token;
  }

  // Firebase doesn't store age or contact no., so we keep them here
  // per user. Logout doesn't clear these.
  static const _profileFields = ['firstName', 'lastName', 'age', 'contactNo', 'username'];

  String _profileKey(String uid, String field) => 'profile_${uid}_$field';

  Future<void> saveSignupDetails({
    required String firstName,
    required String lastName,
    required int age,
    required String contactNo,
    required String username,
  }) async {
    final user = currentUser!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(user.uid, 'firstName'), firstName);
    await prefs.setString(_profileKey(user.uid, 'lastName'), lastName);
    await prefs.setInt(_profileKey(user.uid, 'age'), age);
    await prefs.setString(_profileKey(user.uid, 'contactNo'), contactNo);
    await updateUsername(username: username);
    await _startFirebaseSession(user);
  }

  /// saves the Firebase user in the same keys DummyJSON uses
  Future<void> _startFirebaseSession(fb.User? user) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = await user.getIdToken() ?? '';

    await prefs.remove('id');
    await prefs.setString('email', user.email ?? '');
    await prefs.setString(
      'username',
      user.displayName ??
          prefs.getString(_profileKey(user.uid, 'username')) ??
          (user.email ?? '').split('@').first,
    );
    await prefs.setString(
      'firstName',
      prefs.getString(_profileKey(user.uid, 'firstName')) ?? '',
    );
    await prefs.setString(
      'lastName',
      prefs.getString(_profileKey(user.uid, 'lastName')) ?? '',
    );
    await prefs.setString('token', token);
    await prefs.setString('accessToken', token);
    await saveLoginType(LoginType.firebase);
    await _saveUserToFirestore(user, prefs);
  }

    /// saves the Firebase user to the Firestore "Users" collection (used by chat)
  Future<void> _saveUserToFirestore(fb.User user, SharedPreferences prefs) async {
    final firstName = prefs.getString('firstName') ?? '';
    final username = prefs.getString('username') ?? '';
    await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email ?? '',
      'username': username,
      'firstName': firstName.isNotEmpty ? firstName : username,
      'lastName': prefs.getString('lastName') ?? '',
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------
  // Login type (which backend this session belongs to)
  // ---------------------------------------------------------------------
  Future<void> saveLoginType(LoginType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loginType', type.name);
  }

  Future<LoginType> getLoginType() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('loginType');
    return LoginType.values.firstWhere(
      (t) => t.name == saved,
      orElse: () => LoginType.none,
    );
  }

  // ---------------------------------------------------------------------
  // DummyJSON (previous code)
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> loginUser(String username, String password) async {
    final response = await _send(
      (c) => c.post(
        Uri.parse('$host/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'expiresInMins': 60,
        }),
      ),
    );

    if (response.statusCode == 200) {
      data = jsonDecode(response.body);
      await saveUserData(data);
      await saveLoginType(LoginType.dummyJson);
      return data;
    } else {
      // 400 means the username or password was wrong
      throw AppException(
        response.statusCode == 400
            ? 'Incorrect username or password.'
            : 'Login failed. Please try again.',
      );
    }
  }

  /// Save User Data to SharedPreferences
  /// Save user data from API response based on User model
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final user = User.fromJson(userData);

    await prefs.setInt('id', user.id);
    await prefs.setString('username', user.username);
    await prefs.setString('email', user.email);
    await prefs.setString('firstName', user.firstName);
    await prefs.setString('lastName', user.lastName);
    await prefs.setString('gender', user.gender);
    await prefs.setString('image', user.image);
    await prefs.setString('accessToken', user.accessToken);
    await prefs.setString('refreshToken', user.refreshToken);

    // Support generic token key if present in API response
    if (userData.containsKey('token')) {
      await prefs.setString('token', userData['token'] ?? '');
    } else if (user.accessToken.isNotEmpty) {
      await prefs.setString('token', user.accessToken);
    }
  }

  /// Retrieve user data from SharedPreferences
  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = currentUser?.uid;
    return {
      'uid': uid ?? '',
      'id': prefs.getInt('id') ?? 0,
      'age': uid == null ? 0 : prefs.getInt(_profileKey(uid, 'age')) ?? 0,
      'contactNo':
          uid == null ? '' : prefs.getString(_profileKey(uid, 'contactNo')) ?? '',
      'loginType': (await getLoginType()).name,
      'username': prefs.getString('username') ?? '',
      'email': prefs.getString('email') ?? '',
      'firstName': prefs.getString('firstName') ?? '',
      'lastName': prefs.getString('lastName') ?? '',
      'gender': prefs.getString('gender') ?? '',
      'image': prefs.getString('image') ?? '',
      'accessToken': prefs.getString('accessToken') ?? '',
      'refreshToken': prefs.getString('refreshToken') ?? '',
      'token': prefs.getString('token') ?? prefs.getString('accessToken') ?? '',
    };
  }

  /// Retrieve User model from SharedPreferences
  Future<User> getUser() async {
    final userData = await getUserData();
    return User.fromJson(userData);
  }

  /// Check if User is Logged In
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? prefs.getString('token');
    return (token != null && token.isNotEmpty) || currentUser != null;
  }

  /// signs out of Firebase and clears the saved session
  Future<void> logout() async {
    try {
      if (currentUser != null) {
        await firebaseAuth.signOut();
      }
      final prefs = await SharedPreferences.getInstance();
      // remove everything except the saved profile details
      for (final key in prefs.getKeys().toList()) {
        if (!key.startsWith('profile_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      throw AppException('Could not log out. Please try again.');
    }
  }
}