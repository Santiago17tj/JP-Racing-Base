import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quién está usando la app en este teléfono.
enum RolUsuario {
  /// El dueño: ve el dinero, los costos y la contabilidad.
  administrador('Administrador'),

  /// El mecánico: trabaja las órdenes, pero no ve márgenes ni caja.
  mecanico('Mecánico');

  const RolUsuario(this.label);
  final String label;
}

/// Modo de trabajo del dispositivo.
///
/// IMPORTANTE — esto NO es seguridad de servidor. Es un control de la
/// interfaz para que el celular del taller pueda quedar en manos del mecánico
/// sin que vea los precios de costo, las ganancias ni la caja. Alguien con
/// conocimientos técnicos y acceso físico al teléfono podría saltárselo; para
/// separar de verdad los datos harían falta cuentas distintas en Supabase con
/// permisos propios.
class SesionLocalProvider extends ChangeNotifier {
  static const _claveRol = 'mecanix_rol_actual';
  static const _clavePin = 'mecanix_pin_administrador';

  RolUsuario _rol = RolUsuario.administrador;
  RolUsuario get rol => _rol;

  bool get esAdministrador => _rol == RolUsuario.administrador;

  /// ¿Puede ver dinero sensible: costos, márgenes, caja y contabilidad?
  bool get puedeVerFinanzas => esAdministrador;

  /// ¿Puede cambiar los ajustes del taller y la facturación?
  bool get puedeConfigurarTaller => esAdministrador;

  bool _cargado = false;
  bool get cargado => _cargado;

  bool _tienePin = false;
  bool get tienePin => _tienePin;

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_claveRol);
      _rol = RolUsuario.values.firstWhere(
        (r) => r.name == guardado,
        orElse: () => RolUsuario.administrador,
      );
      _tienePin = (prefs.getString(_clavePin) ?? '').isNotEmpty;
    } catch (e) {
      debugPrint('No se pudo leer el modo de trabajo: $e');
    }
    _cargado = true;
    notifyListeners();
  }

  /// Pasa el teléfono a modo mecánico. No pide PIN: entregar el equipo es una
  /// acción deliberada del dueño; el PIN se exige para volver.
  Future<void> activarModoMecanico() async {
    _rol = RolUsuario.mecanico;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveRol, _rol.name);
  }

  /// Vuelve a modo administrador. Si hay PIN configurado, debe coincidir.
  /// Devuelve false si el PIN es incorrecto.
  Future<bool> volverAModoAdministrador({String? pin}) async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clavePin) ?? '';

    if (guardado.isNotEmpty && guardado != (pin ?? '')) return false;

    _rol = RolUsuario.administrador;
    notifyListeners();
    await prefs.setString(_claveRol, _rol.name);
    return true;
  }

  /// Define o cambia el PIN que protege el modo administrador.
  /// Solo tiene sentido hacerlo estando en modo administrador.
  Future<void> definirPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final limpio = pin.trim();
    if (limpio.isEmpty) {
      await prefs.remove(_clavePin);
      _tienePin = false;
    } else {
      await prefs.setString(_clavePin, limpio);
      _tienePin = true;
    }
    notifyListeners();
  }
}
