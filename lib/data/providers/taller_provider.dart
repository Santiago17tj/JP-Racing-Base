import 'package:flutter/material.dart';
import '../models/perfil_taller.dart';
import '../database/database_helper.dart';
import '../database/fuente_de_datos.dart';
import '../../core/services/supabase_service.dart';

/// Provider encargado de gestionar el estado del Perfil del Taller (Tenant)
/// y sincronizarlo con Supabase y localmente.
class TallerProvider extends ChangeNotifier {
  final FuenteDeDatos _db;

  /// Sin argumentos usa la base real, igual que siempre.
  TallerProvider({FuenteDeDatos? db}) : _db = db ?? DatabaseHelper.instance;

  PerfilTaller? _taller;
  PerfilTaller? get taller => _taller;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _hasWorkshop = true;
  bool get hasWorkshop => _hasWorkshop;

  void setTaller(PerfilTaller? taller) {
    _taller = taller;
    _hasWorkshop = taller != null;
    DatabaseHelper.activeTallerId = taller?.id;
    notifyListeners();
  }

  /// Carga el perfil del taller asociado al usuario administrador.
  ///
  /// v1.1.5 — Lógica síncrona estricta:
  /// 1. Usa siempre el ID de la sesión activa de Google/Supabase como fuente de verdad.
  /// 2. Consulta OBLIGATORIA a Supabase con await; bloquea hasta completar.
  /// 3. Guarda el nombre real y logo_url en SQLite antes de desbloquear el Dashboard.
  /// 4. Si la nube no responde, usa SQLite local como fallback (modo offline).
  Future<void> cargarTaller(String usuarioId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (usuarioId == 'demo-user') {
        _taller = PerfilTaller(
          id: 'taller-demo',
          usuarioAdministradorId: 'demo-user',
          nombreTaller: 'Taller Demo (Local)',
          moneda: 'COP',
          porcentajeImpuestoDefecto: 0.0,
        );
        _hasWorkshop = true;
        DatabaseHelper.activeTallerId = 'taller-demo';
      } else {
        // Obtener el UID directamente de la sesión activa.
        // En instalación limpia, este es el único identificador fiable.
        final String uid = SupabaseService.isConfigured
            ? (SupabaseService.client.auth.currentUser?.id ?? usuarioId)
            : usuarioId;

        // ── PASO 1: Consulta OBLIGATORIA a la nube (await estricto) ──────────
        // No se continúa hasta que esta consulta termine. Garantiza que el
        // nombre real del taller y la URL del logo se descarguen antes de
        // mostrar el Dashboard. Se filtra por usuario_administrador_id para
        // funcionar incluso en instalación limpia donde no hay taller_id local.
        Map<String, dynamic>? cloudData;
        if (SupabaseService.isConfigured) {
          try {
            final response = await SupabaseService.client
                .from('perfil_taller')
                .select()
                .eq('usuario_administrador_id', uid)
                .maybeSingle();
            if (response != null) {
              cloudData = Map<String, dynamic>.from(response as Map);
            }
          } catch (cloudErr) {
            debugPrint('⚠️ [v1.1.5] Consulta nube perfil_taller falló: $cloudErr');
          }
        }

        if (cloudData != null) {
          // Nube respondió: construir con nombre real del taller y logo_url
          _taller = PerfilTaller.fromMap(cloudData);
          _hasWorkshop = true;
          // Persistir en SQLite local de forma síncrona (await estricto)
          await _db.savePerfilTallerLocal(_taller!);
          debugPrint('✅ [v1.1.5] Perfil cargado desde la nube: ${_taller!.nombreTaller}');
        } else {
          // ── PASO 2: Fallback — SQLite local (sin internet) ────────────────
          final localTaller = await _db.getPerfilTallerLocal(uid);
          if (localTaller != null) {
            _taller = localTaller;
            _hasWorkshop = true;
            debugPrint('📱 [v1.1.5] Perfil cargado desde SQLite local (modo offline)');
          } else {
            // Taller no existe: crear perfil por defecto y subirlo
            final nuevoTaller = PerfilTaller(
              usuarioAdministradorId: uid,
              nombreTaller: 'Mi Taller',
              moneda: 'COP',
              porcentajeImpuestoDefecto: 0.0,
            );
            _taller = nuevoTaller;
            _hasWorkshop = false;
            try {
              await SupabaseService.client
                  .from('perfil_taller')
                  .upsert(nuevoTaller.toMap(), onConflict: 'usuario_administrador_id');
              _hasWorkshop = true;
              await _db.savePerfilTallerLocal(nuevoTaller);
            } catch (dbError) {
              debugPrint('⚠️ No se pudo guardar el taller inicial: $dbError');
            }
          }
        }

        DatabaseHelper.activeTallerId = _taller?.id;

        // ── PASO 3: Sincronizar clientes, órdenes e inventario ───────────────
        if (_taller != null && _hasWorkshop) {
          // Si el teléfono se usó antes con otra cuenta, se quitan sus datos
          // antes de bajar los propios. Sin esto se iban acumulando sesión
          // tras sesión.
          await _db.limpiarDatosDeOtrosTalleres(_taller!.id);
          await _db.sincronizarDesdeNube(_taller!.id);
        }
      }
    } catch (e) {
      debugPrint('Error cargando taller en TallerProvider: $e');
      _error = e.toString();

      // Fallback de emergencia: evita quedarse en pantalla de carga infinita
      if (_taller == null) {
        _taller = PerfilTaller(
          id: usuarioId,
          usuarioAdministradorId: usuarioId,
          nombreTaller: 'Mi Taller (Local)',
          moneda: 'COP',
          porcentajeImpuestoDefecto: 0.0,
        );
        _hasWorkshop = false;
        DatabaseHelper.activeTallerId = _taller?.id;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza los datos del taller en Supabase y localmente.
  Future<bool> actualizarTaller(PerfilTaller nuevoTaller) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final savedTaller = await _db.insertPerfilTaller(nuevoTaller);
      _taller = savedTaller;
      _hasWorkshop = true;
      DatabaseHelper.activeTallerId = savedTaller.id;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error actualizando taller: $e');
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restablece el estado a valores iniciales por defecto al cerrar sesión.
  void limpiarDatos() {
    _taller = null;
    _isLoading = false;
    _error = null;
    _hasWorkshop = false;
    DatabaseHelper.activeTallerId = null;
    notifyListeners();
  }
}
