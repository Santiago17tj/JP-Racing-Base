Future<void> openPdfInNewTab(List<int> bytes, String fileName) async {
  throw UnsupportedError(
      'PDF web helper no está disponible en esta plataforma');
}

/// Descarga un archivo en el navegador. Fuera de la web no aplica: allí se
/// guarda en disco y se comparte con el menú del sistema.
Future<void> descargarArchivoWeb(
    List<int> bytes, String nombre, String tipoMime) async {
  throw UnsupportedError('La descarga por navegador solo existe en web');
}
