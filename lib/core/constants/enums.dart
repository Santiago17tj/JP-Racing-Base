/// Categorías de repuestos del inventario.
enum CategoriaRepuesto {
  frenos('FRENOS', 'Frenos', '🛑'),
  motor('MOTOR', 'Motor', '⚙️'),
  electrico('ELECTRICO', 'Eléctrico', '⚡'),
  transmision('TRANSMISION', 'Transmisión', '🔗'),
  suspension('SUSPENSION', 'Suspensión', '🔩'),
  carroceria('CARROCERIA', 'Carrocería', '🏍️'),
  llantas('LLANTAS', 'Llantas', '🛞'),
  lubricantes('LUBRICANTES', 'Lubricantes', '🛢️'),
  filtros('FILTROS', 'Filtros', '🌀'),
  accesorios('ACCESORIOS', 'Accesorios', '🎒'),
  otros('OTROS', 'Otros', '📦');

  const CategoriaRepuesto(this.value, this.label, this.icon);
  final String value;
  final String label;
  final String icon;

  static CategoriaRepuesto fromValue(String value) {
    return CategoriaRepuesto.values.firstWhere(
      (c) => c.value == value,
      orElse: () => CategoriaRepuesto.otros,
    );
  }
}

/// Tipos de movimiento en el historial de stock.
enum TipoMovimiento {
  entrada('ENTRADA', 'Entrada'),
  salida('SALIDA', 'Salida'),
  ajuste('AJUSTE', 'Ajuste'),
  devolucion('DEVOLUCION', 'Devolución');

  const TipoMovimiento(this.value, this.label);
  final String value;
  final String label;

  static TipoMovimiento fromValue(String value) {
    return TipoMovimiento.values.firstWhere(
      (t) => t.value == value,
      orElse: () => TipoMovimiento.ajuste,
    );
  }
}

/// Estados de la orden de mantenimiento (Flujo del taller).
enum EstadoOrden {
  ingresada('Ingresada', 'Ingresada', 0xFF3B82F6),
  enDiagnostico('En Diagnóstico', 'En Diagnóstico', 0xFFF59E0B),
  enReparacion('En Reparación', 'En Reparación', 0xFF8B5CF6),
  listaParaEntrega('Lista para Entrega', 'Lista para Entrega', 0xFF10B981),
  entregada('Entregada', 'Entregada', 0xFF64748B),
  cancelada('Cancelada', 'Cancelada', 0xFFEF4444);

  const EstadoOrden(this.value, this.label, this.colorValue);
  final String value;
  final String label;
  final int colorValue;

  static EstadoOrden fromValue(String value) {
    final valClean = value.trim().toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (valClean.contains('diag')) return EstadoOrden.enDiagnostico;
    if (valClean.contains('repara')) return EstadoOrden.enReparacion;
    if (valClean.contains('lista') || valClean.contains('entrega')) {
      if (valClean == 'entregada') return EstadoOrden.entregada;
      return EstadoOrden.listaParaEntrega;
    }
    if (valClean.contains('cancel')) return EstadoOrden.cancelada;
    
    return EstadoOrden.values.firstWhere(
      (e) {
        final eV = e.value.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
        final eL = e.label.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
        return eV == valClean || eL == valClean;
      },
      orElse: () => EstadoOrden.ingresada,
    );
  }
}

/// Tipos de servicio para la orden.
class TiposServicio {
  static const preventivo = 'Mantenimiento Preventivo';
  static const correctivo = 'Mantenimiento Correctivo';
  static const diagnostico = 'Diagnóstico Técnico';
  static const reparacionMayor = 'Reparación Mayor';
  static const personalizacion = 'Personalización';
  static const garantia = 'Garantía';
  static const otro = 'Otro (Escribir a mano)';

  static const List<String> valores = [
    preventivo,
    correctivo,
    diagnostico,
    reparacionMayor,
    personalizacion,
    garantia,
    otro,
  ];

  static String fromValue(String value) {
    if (value == 'MANTENIMIENTO_PREVENTIVO') return preventivo;
    if (value == 'MANTENIMIENTO_CORRECTIVO') return correctivo;
    if (value == 'DIAGNOSTICO') return diagnostico;
    if (value == 'REPARACION_MAYOR') return reparacionMayor;
    if (value == 'PERSONALIZACION') return personalizacion;
    if (value == 'GARANTIA') return garantia;
    
    // Si ya es un texto personalizado o coincide con alguno de la lista
    return value;
  }
}
