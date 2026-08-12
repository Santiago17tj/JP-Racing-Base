import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isSignUp    = false;
  bool _obscure     = true;
  bool _emailFocused    = false;
  bool _passwordFocused = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordFocused = _passwordFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Stack(
        children: [
          // ── Fondo gradiente profundo ──────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF020611),
                  Color(0xFF060D22),
                  Color(0xFF0A1628),
                  Color(0xFF050A18),
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),
          // ── Orbes decorativos de fondo ───────────────────────
          const Positioned(
            top: -120, left: -80,
            child: _GlowOrb(color: Color(0xFF3B82F6), size: 350),
          ),
          const Positioned(
            bottom: -100, right: -60,
            child: _GlowOrb(color: Color(0xFF8B5CF6), size: 280),
          ),
          const Positioned(
            top: 200, right: -50,
            child: _GlowOrb(color: Color(0xFF06B6D4), size: 180),
          ),
          // ── Contenido centrado ───────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: AppTheme.glassDecoration(
                        opacity: 0.07,
                        borderOpacity: 0.18,
                        radius: 28,
                      ),
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Logo + Header ─────────────────────
                          _buildHeader(),
                          const SizedBox(height: 32),
                          // ── Campos ────────────────────────────
                          _buildAnimatedField(
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            isFocused: _emailFocused,
                            label: 'Correo electrónico',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _buildAnimatedField(
                            controller: _passwordCtrl,
                            focusNode: _passwordFocus,
                            isFocused: _passwordFocused,
                            label: 'Contraseña',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppTheme.textTertiary, size: 20,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          // ── Error ─────────────────────────────
                          if (auth.error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(auth.error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                                ],
                              ),
                            ).animate().fadeIn().slideY(begin: -0.2),
                          ],
                          const SizedBox(height: 24),
                          // ── Botón Google ─────────────────────
                          _GoogleButton(
                            onPressed: auth.isLoading ? null : () => auth.signInWithGoogle(),
                          ),
                          const SizedBox(height: 12),
                          // ── Botón principal ───────────────────
                          _PrimaryButton(
                            label: _isSignUp ? 'CREAR CUENTA' : 'INGRESAR',
                            isLoading: auth.isLoading,
                            onPressed: () async {
                              auth.clearError();
                              if (_isSignUp) {
                                await auth.signUp(
                                  email: _emailCtrl.text.trim(),
                                  password: _passwordCtrl.text,
                                );
                              } else {
                                await auth.signIn(
                                  email: _emailCtrl.text.trim(),
                                  password: _passwordCtrl.text,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          // ── Toggle + Modo Demo ─────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => setState(() {
                                  _isSignUp = !_isSignUp;
                                  auth.clearError();
                                }),
                                child: Text(
                                  _isSignUp ? '¿Ya tienes cuenta? Ingresa' : '¿Sin cuenta? Regístrate',
                                  style: const TextStyle(color: AppTheme.primaryLight, fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: () => auth.bypassAuthentication(),
                                child: const Text(
                                  'Modo Demo',
                                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.06, duration: 500.ms, curve: Curves.easeOut),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge premium
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.motorcycle_rounded, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text('MotoTaller SaaS', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
        const SizedBox(height: 16),
        Text(
          _isSignUp ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.2),
        ).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: 6),
        Text(
          _isSignUp
              ? 'Registra tu taller y empieza a gestionar todo en minutos.'
              : 'Accede para sincronizar órdenes, inventario y facturación.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.45),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildAnimatedField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isFocused
            ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 0)]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isFocused ? AppTheme.primaryLight : AppTheme.textTertiary,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, size: 20, color: isFocused ? AppTheme.primaryLight : AppTheme.textTertiary),
          suffixIcon: suffix,
          filled: true,
          fillColor: isFocused
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.6),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ── Botón Principal con gradiente ──────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.label, required this.isLoading, this.onPressed});
  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onPressed?.call(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _pressed
                  ? [const Color(0xFF2563EB), const Color(0xFF7C3AED)]
                  : [const Color(0xFF3B82F6), const Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: _pressed
                ? []
                : [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}

// ── Botón Google glassmorphic ──────────────────────────────────────────────────
class _GoogleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  const _GoogleButton({this.onPressed});
  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onPressed?.call(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _pressed ? 0.05 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // G colorida hecha con texto estilizado
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC04), Color(0xFFEA4335)],
                ).createShader(b),
                child: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              const Text('Continuar con Google', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Orbe de resplandor decorativo ─────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}
