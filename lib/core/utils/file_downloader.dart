import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart'
    as downloader;

/// Descarga un archivo desde una URL.
/// En web usa AnchorElement del navegador. En móvil usa dio + share_plus.
Future<void> downloadFileFromUrl(String url, String fileName) =>
    downloader.downloadFileFromUrl(url, fileName);
