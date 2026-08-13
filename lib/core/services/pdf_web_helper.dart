import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Implementación web de la apertura y descarga de archivos.
///
/// Se llega aquí por importación condicional desde `pdf_web_helper_stub.dart`;
/// en Android e iOS este archivo no existe siquiera.
///
/// Usa `package:web` y no `dart:html`, que está deprecado y desaparecerá: el
/// día que Flutter lo quite, un proyecto que dependa de él deja de compilar
/// para web por completo.

/// Envuelve unos bytes en un Blob del navegador.
web.Blob _blob(List<int> bytes, String tipoMime) => web.Blob(
      [Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: tipoMime),
    );

/// Abre el PDF en la pestaña actual; si el navegador lo bloquea, cae a una
/// descarga con nombre.
Future<void> openPdfInNewTab(List<int> bytes, String fileName) async {
  final url = web.URL.createObjectURL(_blob(bytes, 'application/pdf'));

  try {
    web.window.location.assign(url);
  } catch (_) {
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..target = '_blank'
      ..rel = 'noopener'
      ..download = fileName;
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
  }

  // Se espera antes de liberar la URL: soltarla de inmediato cancelaría la
  // descarga que el navegador acaba de empezar.
  await Future<void>.delayed(const Duration(seconds: 1));
  web.URL.revokeObjectURL(url);
}

/// Descarga un archivo en el navegador con el nombre indicado.
Future<void> descargarArchivoWeb(
    List<int> bytes, String nombre, String tipoMime) async {
  final url = web.URL.createObjectURL(_blob(bytes, tipoMime));
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = nombre;
  anchor.style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  await Future<void>.delayed(const Duration(seconds: 1));
  web.URL.revokeObjectURL(url);
}
