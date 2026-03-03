import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Implementación móvil: descarga con dio → archivo temporal → share
Future<void> downloadFileFromUrl(String url, String fileName) async {
  final dir = await getTemporaryDirectory();
  final savePath = '${dir.path}/$fileName';
  final dio = Dio();
  await dio.download(url, savePath);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(savePath)],
      subject: 'Foto de visita - Disbattery',
    ),
  );
}
