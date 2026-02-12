import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barber_sync/models/models.dart';

final userProvider = StateNotifierProvider<UserNotifier, User?>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<User?> {
  UserNotifier() : super(null) {
    _loadUser();
  }

  static const String _userKey = 'auth_user';

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        final user = User.fromJson(jsonDecode(userJson));
        // If user is just a Customer (incomplete reg), do not auto-login
        if (user.role == AppRole.customer) {
           prefs.remove(_userKey);
           state = null;
        } else {
           state = user;
        }
      } catch (e) {
        print("DEBUG: Error loading user: $e. Clearing storage.");
        await prefs.remove(_userKey);
        state = null;
      }
    } else {
      print("DEBUG: No user found in storage.");
    }
  }

  Future<void> setUser(User user) async {
    state = user;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(user.toJson());
    print("DEBUG: UserNotifier.setUser saving to $_userKey: $jsonStr");
    await prefs.setString(_userKey, jsonStr);
  }

  void setTemporaryUser(User user) {
    state = user;
  }

  Future<void> logout() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
