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
