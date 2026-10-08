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
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Marca(textos: textos),
                  const SizedBox(height: 40),
                  Text(
                    _isSignUp ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
                    style: textos.headlineMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 30,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp
                        ? 'Registra tu taller y empieza a gestionar todo en minutos.'
                        : 'Accede para sincronizar órdenes, inventario y facturación.',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  // Todos los talleres entran con Google: va primero y es el
                  // botón que más destaca.
                  _GoogleButton(
                    onPressed:
                        auth.isLoading ? null : () => auth.signInWithGoogle(),
                  ),
                  const SizedBox(height: 24),
                  const _Separador(texto: 'o con tu correo'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon:
                          const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textTertiary,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.errorSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppTheme.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(auth.error!,
                                  style: const TextStyle(
                                      color: AppTheme.error, fontSize: 13))),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: -0.2),
                  ],
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 12),
                  // "Modo Demo" se quitó el 17/09/2026: sin sesión de
                  // Supabase, la RLS nunca encuentra un perfil de taller y la
                  // app se quedaba para siempre en "Cargando perfil del
                  // taller...". Reconstruirlo implicaría volver a sembrar
                  // datos de ejemplo, que se quitaron por causar fugas entre
                  // talleres (ver database_helper.dart).
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _isSignUp = !_isSignUp;
                        auth.clearError();
                      }),
                      child: Text(
                        _isSignUp
                            ? '¿Ya tienes cuenta? Ingresa'
                            : '¿Sin cuenta? Regístrate',
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
        ),
      ),
    );
  }
}

/// Marca: bandera a cuadros y el nombre en la condensada.
class _Marca extends StatelessWidget {
  final TextTheme textos;
  const _Marca({required this.textos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Cuadros(),
        const SizedBox(height: 14),
        Text(
          'MECANIX',
          style: textos.displaySmall?.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 46,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(width: 28, height: 3, color: AppTheme.primaryLight),
            const SizedBox(width: 10),
            Text(
              'GESTIÓN DE TALLER DE MOTOS',
              style: textos.titleSmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 13,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Franja de bandera a cuadros, dos filas.
class _Cuadros extends StatelessWidget {
  const _Cuadros();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 80,
      height: 16,
      child: CustomPaint(painter: _PintorCuadros()),
    );
  }
}

class _PintorCuadros extends CustomPainter {
  const _PintorCuadros();

  @override
  void paint(Canvas canvas, Size size) {
    const lado = 8.0;
    final claro = Paint()..color = AppTheme.textPrimary;
    for (var fila = 0; fila < size.height ~/ lado; fila++) {
      for (var col = 0; col < size.width ~/ lado; col++) {
        if ((fila + col).isEven) {
          canvas.drawRect(
              Rect.fromLTWH(col * lado, fila * lado, lado, lado), claro);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Separador extends StatelessWidget {
  final String texto;
  const _Separador({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(texto,
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _PrimaryButton(
      {required this.label, required this.isLoading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(letterSpacing: 1.4)),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GoogleButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.textPrimary,
          foregroundColor: AppTheme.textInverse,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [
                  Color(0xFF4285F4),
                  Color(0xFF34A853),
                  Color(0xFFFBBC04),
                  Color(0xFFEA4335)
                ],
              ).createShader(b),
              child: const Text('G',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            const SizedBox(width: 12),
            const Text('Continuar con Google',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
