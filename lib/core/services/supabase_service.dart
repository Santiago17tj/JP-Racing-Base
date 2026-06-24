import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool _initialized = false;
  static bool get isConfigured => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase no está inicializado. Configura URL y anon key.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize({required String url, required String anonKey}) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
    _initialized = true;
  }

  static bool get isAuthenticated => !_initialized || client.auth.currentUser != null;

  static Future<void> signInWithEmail({required String email, required String password}) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signUpWithEmail({required String email, required String password}) async {
    await client.auth.signUp(email: email, password: password);
  }

  static Future<void> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(scopes: ['email']);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;
    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<List<Map<String, dynamic>>> fetchRepuestos() async {
    if (!_initialized) return [];
    final response = await client.from('repuestos').select().eq('activo', true).order('nombre');
    return List<Map<String, dynamic>>.from(response as List);
  }

  // Supabase Flutter v2+ — no .execute() needed, query builders are directly awaitable
  static Future<void> upsertRepuesto(Map<String, dynamic> data) async {
    if (!_initialized) return;
    await client.from('repuestos').upsert(data, onConflict: 'id');
  }

  static Future<void> deleteRepuesto(String id) async {
    if (!_initialized) return;
    await client.from('repuestos').update({'activo': false}).eq('id', id);
  }
}
