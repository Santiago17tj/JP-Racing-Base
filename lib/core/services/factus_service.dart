import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:moto_taller_app/core/config/app_config.dart';
import 'package:moto_taller_app/core/services/supabase_service.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/orden_item.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';
import 'package:moto_taller_app/core/dominio/reglas_orden.dart';

/// Servicio de integración con la API de Facturación Electrónica DIAN via Factus.
/// Sandbox: api-sandbox.factus.com.co
class FactusService {
  /// Mapea el tipo de documento del cliente al código de documento DIAN / Factus.
  /// 3 = Cédula de Ciudadanía, 6 = NIT, 1 = Cédula de Extranjería, 7 = Pasaporte
  static String _mapTipoDocumento(TipoDocumento tipo) {
    switch (tipo) {
      case TipoDocumento.cc:
      case TipoDocumento.dni:
        return '3';
      case TipoDocumento.nit:
      case TipoDocumento.ruc:
        return '6';
      case TipoDocumento.pasaporte:
        return '7';
    }
  }

  /// Construye el payload JSON requerido por la API de Factus (v1/bills/validate).
  static Map<String, dynamic> buildFactusPayload({
    required OrdenMantenimiento orden,
    required Cliente cliente,
    required Vehiculo vehiculo,
    required List<OrdenItem> items,
    PerfilTaller? taller,
  }) {
    final double porcentajeImpuesto = taller?.porcentajeImpuestoDefecto ?? 0.0;
    // El IVA solo grava la mano de obra: los repuestos se venden con el
    // impuesto ya incluido en el precio, por eso van como excluidos.
    final String taxRateManoObra = porcentajeImpuesto.toStringAsFixed(2);
    const String taxRateRepuesto = '0.00';
    final int tributeManoObra =
        porcentajeImpuesto > 0 ? 1 : 21; // 1 = IVA, 21 = No aplica / Exento
    const int tributeRepuesto = 21;

    final List<Map<String, dynamic>> factusItems = [];

    // 1. Convertir repuestos/conceptos de la orden
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final esManoObra = ReglasOrden.esManoObra(item);
      final gravado = esManoObra && porcentajeImpuesto > 0;
      factusItems.add({
        'code_reference':
            item.repuestoId.isNotEmpty ? item.repuestoId : 'ITEM-${i + 1}',
        'name': item.descripcion,
        'quantity': item.cantidad,
        'price': item.precioUnitario,
        'tax_rate': esManoObra ? taxRateManoObra : taxRateRepuesto,
        'unit_measure_id': 70, // 70 = Unidad (EA)
        'standard_code_id': 1,
        'is_excluded': gravado ? 0 : 1,
        'tribute_id': esManoObra ? tributeManoObra : tributeRepuesto,
        'discount_rate': item.descuento,
      });
    }

    // 2. Mano de obra restante: orden.costoManoObra acumula todos los
    //    conceptos, incluidos los que ya se enviaron como item, así que solo
    //    se factura la diferencia para no cobrar dos veces lo mismo.
    final double manoObraDetallada = ReglasOrden.manoObraDetallada(items);
    final double manoObraRestante = orden.costoManoObra - manoObraDetallada;

    if (manoObraRestante > 0) {
      factusItems.add({
        'code_reference': 'MO-GENERAL',
        'name': 'Servicio Técnico / Mano de Obra General',
        'quantity': 1,
        'price': manoObraRestante,
        'tax_rate': taxRateManoObra,
        'unit_measure_id': 70,
        'standard_code_id': 1,
        'is_excluded': porcentajeImpuesto > 0 ? 0 : 1,
        'tribute_id': tributeManoObra,
        'discount_rate': 0.0,
      });
    }

    // Estructura completa del cliente
    final Map<String, dynamic> customer = {
      'identification': cliente.numeroDocumento,
      'dv': '',
      'company': '',
      'trade_name': '',
      'names': cliente.nombreCompleto,
      'address': cliente.direccion ?? 'Dirección No Especificada',
      'email': cliente.email ?? '',
      'phone': cliente.telefono,
      'legal_organization_id': cliente.tipoDocumento == TipoDocumento.nit
          ? '1'
          : '2', // 1: Persona Jurídica, 2: Persona Natural
      'tribute_id': '21', // 21: No responsable de IVA
      'identification_document_id': _mapTipoDocumento(cliente.tipoDocumento),
    };

    return {
      'numbering_range_id': 1,
      'reference_code': orden.numeroOrden,
      'observation':
          'Orden #${orden.numeroOrden} - Vehículo ${vehiculo.marca} ${vehiculo.modelo} (${vehiculo.placaPatente})',
      'payment_form': '1', // 1: Contado
      'payment_method_code': '10', // 10: Efectivo
      'customer': customer,
      'items': factusItems,
    };
  }

  /// Envía la factura a la API de Factus y registra el CUFE y QR en Supabase.
  /// Retorna un mapa con el resultado de la operación.
  static Future<Map<String, dynamic>> emitirFacturaElectronica({
    required OrdenMantenimiento orden,
    required Cliente cliente,
    required Vehiculo vehiculo,
    required List<OrdenItem> items,
    PerfilTaller? taller,
  }) async {
    // Si la facturación electrónica está desactivada en AppConfig, omitir
    if (!AppConfig.facturacionElectronicaActiva) {
      debugPrint(
          '[FactusService] Facturación electrónica desactivada en AppConfig.');
      return {
        'success': false,
        'disabled': true,
        'message': 'Facturación electrónica desactivada en AppConfig.',
      };
    }

    try {
      final payload = buildFactusPayload(
        orden: orden,
        cliente: cliente,
        vehiculo: vehiculo,
        items: items,
        taller: taller,
      );

      final url = Uri.parse('${AppConfig.factusApiUrl}/v1/bills/validate');
      final headers = {
        'Authorization': 'Bearer ${AppConfig.factusAccessToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      debugPrint(
          '[FactusService] Enviando factura electrónica para orden #${orden.numeroOrden}...');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      debugPrint('[FactusService] Response status: ${response.statusCode}');
      debugPrint('[FactusService] Response body: ${response.body}');

      final Map<String, dynamic> responseData =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Extraer datos de facturación (CUFE, QR, Estado)
        final billData = responseData['data']?['bill'] ??
            responseData['data'] ??
            responseData;
        final String cufe = billData['cufe']?.toString() ?? '';
        final String qr =
            billData['qr']?.toString() ?? billData['qr_code']?.toString() ?? '';
        final String estado = billData['status']?.toString() ?? 'APROBADA';

        // Guardar resultado en Supabase si está disponible
        await _guardarFacturaEnSupabase(
          ordenId: orden.id,
          numeroOrden: orden.numeroOrden,
          cufe: cufe,
          qr: qr,
          estado: estado,
          rawResponse: responseData,
        );

        return {
          'success': true,
          'cufe': cufe,
          'qr': qr,
          'status': estado,
          'data': responseData,
          'message': 'Factura electrónica emitida exitosamente.',
        };
      } else {
        final String errorMsg = responseData['message']?.toString() ??
            responseData['error']?.toString() ??
            'Error al validar factura en Factus (Código ${response.statusCode})';

        await _guardarFacturaEnSupabase(
          ordenId: orden.id,
          numeroOrden: orden.numeroOrden,
          cufe: '',
          qr: '',
          estado: 'RECHAZADA',
          rawResponse: responseData,
        );

        return {
          'success': false,
          'status': 'RECHAZADA',
          'message': errorMsg,
          'data': responseData,
        };
      }
    } catch (e, stack) {
      debugPrint('[FactusService] Error durante la emisión: $e\n$stack');
      return {
        'success': false,
        'status': 'ERROR',
        'message': 'Excepción al conectar con Factus: $e',
      };
    }
  }

  /// Registra el CUFE, QR y estado de la factura electrónica en Supabase.
  static Future<void> _guardarFacturaEnSupabase({
    required String ordenId,
    required String numeroOrden,
    required String cufe,
    required String qr,
    required String estado,
    required Map<String, dynamic> rawResponse,
  }) async {
    if (!SupabaseService.isConfigured) return;

    try {
      // 1. Actualizar orden en la tabla `ordenes` o `ordenes_mantenimiento`
      await SupabaseService.client.from('ordenes_mantenimiento').update({
        'cufe': cufe,
        'qr_factura': qr,
        'estado_factura_electronica': estado,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', ordenId);

      // 2. Insertar historial en la tabla `facturas_electronicas`
      await SupabaseService.client.from('facturas_electronicas').upsert({
        'orden_id': ordenId,
        'numero_orden': numeroOrden,
        'cufe': cufe,
        'qr_code': qr,
        'estado': estado,
        'respuesta_api': rawResponse,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'orden_id');
    } catch (e) {
      debugPrint(
          '[FactusService] Error actualizando Supabase con datos de Factus: $e');
    }
  }
}
