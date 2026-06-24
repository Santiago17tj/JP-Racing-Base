import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isAuthenticated = SupabaseService.isAuthenticated;
  bool get isAuthenticated => _isAuthenticated;

  String? _error;
  String? get error => _error;

  Future<void> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await SupabaseService.signInWithEmail(email: email, password: password);
      _isAuthenticated = SupabaseService.isAuthenticated;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await SupabaseService.signUpWithEmail(email: email, password: password);
      _isAuthenticated = SupabaseService.isAuthenticated;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await SupabaseService.signInWithGoogle();
      _isAuthenticated = SupabaseService.isAuthenticated;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    _isAuthenticated = false;
    notifyListeners();
  }
}
