import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/reports_provider.dart';
import '../../../../core/models/report_models.dart';
import '../../../../core/utils/file_downloader.dart' as downloader;

/// Pantalla de respuestas de formularios con exportación CSV y visor de fotos
class FormAnswersScreen extends ConsumerWidget {
  const FormAnswersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answersAsync = ref.watch(formAnswersProvider);
    final filter = ref.watch(reportsFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Respuestas de Formularios'),
        actions: [
          answersAsync.whenOrNull(
                data: (answers) {
                  if (answers.isEmpty) return null;
                  return IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Exportar CSV',
                    onPressed: () => _exportCsv(context, answers, filter),
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: Column(
        children: [
          // Filtros de fecha
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildFilterChips(context, ref, filter),
          ),

          // Resumen
          answersAsync.whenOrNull(
                data: (answers) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.description, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        '${answers.length} respuestas encontradas',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const Spacer(),
                      if (answers.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _exportCsv(context, answers, filter),
                          icon: const Icon(Icons.file_download, size: 18),
                          label: const Text('CSV'),
                        ),
                    ],
                  ),
                ),
              ) ??
              const SizedBox.shrink(),

          const Divider(height: 1),

          // Lista de respuestas
          Expanded(
            child: answersAsync.when(
              data: (answers) {
                if (answers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay respuestas en este periodo',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                // Agrupar por visita (mercaderista + cliente + fecha)
                final grouped = <String, List<FormAnswerRow>>{};
                for (final a in answers) {
                  final key = '${a.mercaderista}|${a.cliente}|${a.visitedAt.toIso8601String()}';
                  grouped.putIfAbsent(key, () => []).add(a);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final entry = grouped.entries.elementAt(index);
                    final items = entry.value;
                    final first = items.first;
                    final dateStr =
                        '${first.visitedAt.day.toString().padLeft(2, '0')}/${first.visitedAt.month.toString().padLeft(2, '0')}/${first.visitedAt.year}';
                    final timeStr =
                        '${first.visitedAt.hour.toString().padLeft(2, '0')}:${first.visitedAt.minute.toString().padLeft(2, '0')}';

                    // Contar fotos del grupo
                    final totalPhotos = items.fold<int>(
                        0, (sum, a) => sum + a.photoUrls.length);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: _getTypeColor(first.tipoRuta),
                          child: Text(
                            first.tipoRuta.isNotEmpty ? first.tipoRuta[0] : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          first.mercaderista,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              first.cliente,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _getTypeColor(first.tipoRuta).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    first.tipoRuta,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _getTypeColor(first.tipoRuta),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$dateStr $timeStr',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${items.length} resp.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                                if (totalPhotos > 0) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.photo_library, size: 13, color: Colors.blue[400]),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$totalPhotos foto${totalPhotos > 1 ? 's' : ''}',
                                    style: TextStyle(fontSize: 11, color: Colors.blue[400]),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        children: items.map((answer) {
                          return _AnswerTile(answer: answer);
                        }).toList(),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, WidgetRef ref, ReportsFilter current) {
    final currentSede = current.sede;
    final filters = <MapEntry<String, ReportsFilter>>[
      MapEntry('Hoy', ReportsFilter.today().copyWith(sede: currentSede)),
      MapEntry('7d', ReportsFilter.last7Days().copyWith(sede: currentSede)),
      MapEntry('30d', ReportsFilter.last30Days().copyWith(sede: currentSede)),
      MapEntry('Este mes', ReportsFilter.thisMonth().copyWith(sede: currentSede)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((entry) {
          final isSelected = current.label == entry.value.label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.key),
              selected: isSelected,
              onSelected: (_) {
                ref.read(reportsFilterProvider.notifier).state = entry.value;
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getTypeColor(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'merchandising':
        return Colors.green;
      case 'impulso':
        return Colors.orange;
      case 'evento':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _exportCsv(
      BuildContext context, List<FormAnswerRow> answers, ReportsFilter filter) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Mercaderista,Cliente,Tipo Ruta,Sede,Fecha,Hora,Pregunta,Tipo Pregunta,Respuesta');

      for (final a in answers) {
        final date =
            '${a.visitedAt.day.toString().padLeft(2, '0')}/${a.visitedAt.month.toString().padLeft(2, '0')}/${a.visitedAt.year}';
        final time =
            '${a.visitedAt.hour.toString().padLeft(2, '0')}:${a.visitedAt.minute.toString().padLeft(2, '0')}';
        String esc(String s) => '"${s.replaceAll('"', '""')}"';
        buffer.writeln(
          '${esc(a.mercaderista)},${esc(a.cliente)},${esc(a.tipoRuta)},${esc(a.sede)},$date,$time,${esc(a.pregunta)},${esc(a.tipoPregunta)},${esc(a.respuesta)}',
        );
      }

      final dir = await getTemporaryDirectory();
      final dateRange = '${filter.from.day}-${filter.from.month}_${filter.to.day}-${filter.to.month}';
      final fileName = 'respuestas_formularios_$dateRange.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buffer.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Respuestas de Formularios - Disbattery',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exportando: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────
// Tile de una respuesta individual
// ─────────────────────────────────────────────

class _AnswerTile extends StatelessWidget {
  final FormAnswerRow answer;

  const _AnswerTile({required this.answer});

  @override
  Widget build(BuildContext context) {
    final hasPhotos = answer.photoUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          leading: Icon(
            _getQuestionIcon(answer.tipoPregunta),
            size: 20,
            color: Colors.grey[500],
          ),
          title: Text(
            answer.pregunta,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: hasPhotos
              ? null
              : Text(
                  answer.respuesta.isEmpty ? '(sin respuesta)' : answer.respuesta,
                  style: const TextStyle(fontSize: 13),
                ),
        ),
        // Galería de thumbnails cuando hay fotos
        if (hasPhotos)
          Padding(
            padding: const EdgeInsets.only(left: 56, right: 16, bottom: 12),
            child: _PhotoStrip(photoUrls: answer.photoUrls),
          ),
      ],
    );
  }

  IconData _getQuestionIcon(String type) {
    switch (type) {
      case 'boolean':
      case 'boolean_photo':
        return Icons.check_circle_outline;
      case 'number':
      case 'number_photo':
        return Icons.numbers;
      case 'textarea':
      case 'text':
        return Icons.text_fields;
      case 'dynamic_list':
        return Icons.list;
      case 'select':
        return Icons.radio_button_checked;
      case 'photo':
        return Icons.camera_alt;
      default:
        return Icons.help_outline;
    }
  }
}

// ─────────────────────────────────────────────
// Fila de thumbnails clicables
// ─────────────────────────────────────────────

class _PhotoStrip extends StatelessWidget {
  final List<String> photoUrls;

  const _PhotoStrip({required this.photoUrls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photoUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () => _openViewer(context, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: photoUrls[i],
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 72,
                  height: 72,
                  color: Colors.grey[200],
                  child: const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 72,
                  height: 72,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewerScreen(
          photoUrls: photoUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pantalla fullscreen de visor + descarga
// ─────────────────────────────────────────────

class _PhotoViewerScreen extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const _PhotoViewerScreen({
    required this.photoUrls,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photoUrls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: total > 1
            ? Text('${_currentIndex + 1} / $total',
                style: const TextStyle(color: Colors.white))
            : null,
        actions: [
          _downloading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Descargar foto',
                  onPressed: _downloadCurrent,
                ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: total,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.photoUrls[i],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey, size: 48),
                      SizedBox(height: 8),
                      Text('No se pudo cargar la foto',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      // Indicador de puntos si hay más de 1 foto
      bottomNavigationBar: total > 1
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentIndex ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentIndex
                          ? Colors.white
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            )
          : null,
    );
  }

  Future<void> _downloadCurrent() async {
    setState(() => _downloading = true);
    try {
      final url = widget.photoUrls[_currentIndex];
      final fileName =
          'foto_visita_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await downloader.downloadFileFromUrl(url, fileName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}
