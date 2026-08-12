import 'dart:html' as html;

Future<void> openPdfInNewTab(List<int> bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  try {
    html.window.location.assign(url);
  } catch (_) {
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..rel = 'noopener'
      ..download = fileName;
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
  }

  await Future.delayed(const Duration(seconds: 1));
  html.Url.revokeObjectUrl(url);
}

/// Descarga un archivo en el navegador con el nombre indicado.
Future<void> descargarArchivoWeb(
    List<int> bytes, String nombre, String tipoMime) async {
  final blob = html.Blob([bytes], tipoMime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = nombre
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  await Future.delayed(const Duration(seconds: 1));
  html.Url.revokeObjectUrl(url);
}
