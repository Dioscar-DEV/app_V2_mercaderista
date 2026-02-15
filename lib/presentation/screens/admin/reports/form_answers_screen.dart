import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/reports_provider.dart';
import '../../../../core/models/report_models.dart';

/// Pantalla de respuestas de formularios con exportación CSV
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
                              ],
                            ),
                          ],
                        ),
                        children: items.map((answer) {
                          return ListTile(
                            dense: true,
                            title: Text(
                              answer.pregunta,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              answer.respuesta.isEmpty ? '(sin respuesta)' : answer.respuesta,
                              style: const TextStyle(fontSize: 13),
                            ),
                            leading: Icon(
                              _getQuestionIcon(answer.tipoPregunta),
                              size: 20,
                              color: Colors.grey[500],
                            ),
                          );
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

  Future<void> _exportCsv(
      BuildContext context, List<FormAnswerRow> answers, ReportsFilter filter) async {
    try {
      // Build CSV
      final buffer = StringBuffer();
      buffer.writeln('Mercaderista,Cliente,Tipo Ruta,Sede,Fecha,Hora,Pregunta,Tipo Pregunta,Respuesta');

      for (final a in answers) {
        final date =
            '${a.visitedAt.day.toString().padLeft(2, '0')}/${a.visitedAt.month.toString().padLeft(2, '0')}/${a.visitedAt.year}';
        final time =
            '${a.visitedAt.hour.toString().padLeft(2, '0')}:${a.visitedAt.minute.toString().padLeft(2, '0')}';

        // Escapar comillas en campos CSV
        String esc(String s) => '"${s.replaceAll('"', '""')}"';

        buffer.writeln(
          '${esc(a.mercaderista)},${esc(a.cliente)},${esc(a.tipoRuta)},${esc(a.sede)},$date,$time,${esc(a.pregunta)},${esc(a.tipoPregunta)},${esc(a.respuesta)}',
        );
      }

      // Save to temp file
      final dir = await getTemporaryDirectory();
      final dateRange = '${filter.from.day}-${filter.from.month}_${filter.to.day}-${filter.to.month}';
      final fileName = 'respuestas_formularios_$dateRange.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buffer.toString());

      // Share
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
