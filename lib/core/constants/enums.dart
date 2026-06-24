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
  ingresada('INGRESADA', 'Ingresada', 0xFF3B82F6),
  enDiagnostico('EN_DIAGNOSTICO', 'En Diagnóstico', 0xFFF59E0B),
  enReparacion('EN_REPARACION', 'En Reparación', 0xFF8B5CF6),
  listaParaEntrega('LISTA_PARA_ENTREGA', 'Lista para Entrega', 0xFF10B981),
  entregada('ENTREGADA', 'Entregada', 0xFF64748B),
  cancelada('CANCELADA', 'Cancelada', 0xFFEF4444);

  const EstadoOrden(this.value, this.label, this.colorValue);
  final String value;
  final String label;
  final int colorValue;

  static EstadoOrden fromValue(String value) {
    return EstadoOrden.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EstadoOrden.ingresada,
    );
  }
}

/// Tipos de servicio para la orden.
enum TipoServicio {
  preventivo('MANTENIMIENTO_PREVENTIVO', 'Mantenimiento Preventivo'),
  correctivo('MANTENIMIENTO_CORRECTIVO', 'Mantenimiento Correctivo'),
  diagnostico('DIAGNOSTICO', 'Diagnóstico'),
  reparacionMayor('REPARACION_MAYOR', 'Reparación Mayor'),
  personalizacion('PERSONALIZACION', 'Personalización'),
  garantia('GARANTIA', 'Garantía');

  const TipoServicio(this.value, this.label);
  final String value;
  final String label;

  static TipoServicio fromValue(String value) {
    return TipoServicio.values.firstWhere(
      (t) => t.value == value,
      orElse: () => TipoServicio.preventivo,
    );
  }
}
