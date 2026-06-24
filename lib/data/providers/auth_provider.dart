import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Si Supabase no está configurado, se muestra la HomeShell directamente
  // (modo offline — sin login requerido)
  bool _isAuthenticated = !SupabaseService.isConfigured;
  bool get isAuthenticated => _isAuthenticated;

  String? _error;
  String? get error => _error;

  Future<void> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await SupabaseService.signInWithEmail(email: email, password: password);
      _isAuthenticated = true;
    } catch (e) {
      _error = _parseError(e.toString());
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
      _isAuthenticated = true;
    } catch (e) {
      _error = _parseError(e.toString());
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
      _isAuthenticated = true;
    } catch (e) {
      _error = _parseError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Permite ingresar a la aplicación en modo demo sin cuenta de Supabase.
  void bypassAuthentication() {
    _isAuthenticated = true;
    notifyListeners();
  }

  /// Limpia el error manualmente (para UX)
  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _parseError(String raw) {
    if (raw.contains('Invalid login credentials')) return 'Correo o contraseña incorrectos';
    if (raw.contains('Email not confirmed')) return 'Confirma tu email antes de ingresar';
    if (raw.contains('User already registered')) return 'Este correo ya tiene una cuenta';
    if (raw.contains('network') || raw.contains('SocketException')) return 'Sin conexión a internet';
    return 'Error: ${raw.replaceAll('Exception: ', '')}';
  }
}
