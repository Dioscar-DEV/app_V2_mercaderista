// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Implementación web: dispara la descarga nativa del navegador
Future<void> downloadFileFromUrl(String url, String fileName) async {
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..target = '_blank';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
