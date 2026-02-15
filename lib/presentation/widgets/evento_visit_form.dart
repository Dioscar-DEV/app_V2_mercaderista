import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/models/route_form_question.dart';
import '../../core/models/route_visit.dart';
import '../../config/supabase_config.dart';

/// Formulario de Evento - Página única scrollable
/// Sin señalización, con lógica condicional de ventas
/// Fotos desde GALERÍA
class EventoVisitForm extends ConsumerStatefulWidget {
  final List<RouteFormQuestion> questions;
  final Function(List<RouteVisitAnswer> answers, List<String> photoUrls,
      String? observations) onComplete;

  const EventoVisitForm({
    super.key,
    required this.questions,
    required this.onComplete,
  });

  @override
  ConsumerState<EventoVisitForm> createState() => _EventoVisitFormState();
}

class _EventoVisitFormState extends ConsumerState<EventoVisitForm> {
  bool _isSubmitting = false;
  final _imagePicker = ImagePicker();

  final Map<String, dynamic> _answers = {};
  final Map<String, List<File>> _questionPhotos = {};
  final Map<String, List<String>> _uploadedPhotoUrls = {};
  final Map<String, List<Map<String, dynamic>>> _dynamicListItems = {};

  @override
  void initState() {
    super.initState();
    for (final q in widget.questions) {
      switch (q.questionType) {
        case QuestionType.boolean:
        case QuestionType.booleanPhoto:
          _answers[q.id] = false;
          break;
        case QuestionType.number:
        case QuestionType.numberPhoto:
          _answers[q.id] = 0;
          break;
        case QuestionType.dynamicList:
          _dynamicListItems[q.id] = [];
          break;
        default:
          _answers[q.id] = null;
      }
    }
  }

  bool _shouldShowQuestion(RouteFormQuestion question) {
    if (question.dependsOn == null) return true;
    final parentAnswer = _answers[question.dependsOn];
    if (parentAnswer == null) return false;
    return parentAnswer.toString() == question.dependsValue;
  }

  List<RouteFormQuestion> get _sortedQuestions {
    final qs = List<RouteFormQuestion>.from(widget.questions);
    qs.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return qs;
  }

  @override
  Widget build(BuildContext context) {
    final visibleQuestions =
        _sortedQuestions.where(_shouldShowQuestion).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Formulario de Evento',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // All questions in a single card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < visibleQuestions.length; i++) ...[
                  _buildQuestionWidget(visibleQuestions[i]),
                  if (i < visibleQuestions.length - 1) const Divider(height: 24),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitForm,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check),
            label:
                Text(_isSubmitting ? 'Guardando...' : 'Completar Visita'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionWidget(RouteFormQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                question.questionText,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            if (question.isRequired)
              const Text(' *',
                  style: TextStyle(color: Colors.red, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        _buildFieldForType(question),
      ],
    );
  }

  Widget _buildFieldForType(RouteFormQuestion question) {
    switch (question.questionType) {
      case QuestionType.boolean:
        return _buildBooleanField(question);
      case QuestionType.booleanPhoto:
        return _buildBooleanPhotoField(question);
      case QuestionType.number:
        return _buildNumberField(question);
      case QuestionType.photo:
        return _buildPhotoField(question);
      case QuestionType.textarea:
        return _buildTextareaField(question);
      case QuestionType.dynamicList:
        return _buildDynamicListField(question);
      case QuestionType.text:
        return _buildTextField(question);
      case QuestionType.select:
        return _buildSelectField(question);
      default:
        return _buildTextField(question);
    }
  }

  Widget _buildBooleanField(RouteFormQuestion question) {
    final value = _answers[question.id] == true;
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('No'), icon: Icon(Icons.close)),
        ButtonSegment(value: true, label: Text('Sí'), icon: Icon(Icons.check)),
      ],
      selected: {value},
      onSelectionChanged: (newSelection) {
        setState(() => _answers[question.id] = newSelection.first);
      },
    );
  }

  Widget _buildBooleanPhotoField(RouteFormQuestion question) {
    final value = _answers[question.id] == true;
    final photos = _questionPhotos[question.id] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: false, label: Text('No'), icon: Icon(Icons.close)),
            ButtonSegment(
                value: true, label: Text('Sí'), icon: Icon(Icons.check)),
          ],
          selected: {value},
          onSelectionChanged: (newSelection) {
            setState(() {
              _answers[question.id] = newSelection.first;
              if (!newSelection.first) _questionPhotos.remove(question.id);
            });
          },
        ),
        if (value) ...[
          const SizedBox(height: 12),
          _buildPhotoCapture(question.id, photos, maxPhotos: 1),
        ],
      ],
    );
  }

  Widget _buildNumberField(RouteFormQuestion question) {
    return TextFormField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: 'Ingresar cantidad',
        prefixIcon: const Icon(Icons.numbers),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      initialValue: (_answers[question.id] ?? 0).toString(),
      onChanged: (value) {
        if (value.isEmpty) {
          _answers[question.id] = 0;
        } else {
          _answers[question.id] =
              int.tryParse(value) ?? double.tryParse(value) ?? 0;
        }
      },
    );
  }

  Widget _buildPhotoField(RouteFormQuestion question) {
    final photos = _questionPhotos[question.id] ?? [];
    final maxPhotos = question.maxPhotos;
    return _buildPhotoCapture(question.id, photos, maxPhotos: maxPhotos);
  }

  Widget _buildTextareaField(RouteFormQuestion question) {
    return TextFormField(
      maxLines: 4,
      decoration: InputDecoration(
        hintText: question.placeholder ?? 'Escriba aquí...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        alignLabelWithHint: true,
      ),
      onChanged: (value) => _answers[question.id] = value,
    );
  }

  Widget _buildTextField(RouteFormQuestion question) {
    return TextFormField(
      decoration: InputDecoration(
        hintText: 'Escribe tu respuesta...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      onChanged: (value) => _answers[question.id] = value,
    );
  }

  Widget _buildSelectField(RouteFormQuestion question) {
    return DropdownButtonFormField<String>(
      value: _answers[question.id] as String?,
      decoration: InputDecoration(
        hintText: 'Selecciona una opción...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      items: question.options
              ?.map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList() ??
          [],
      onChanged: (value) => setState(() => _answers[question.id] = value),
    );
  }

  Widget _buildDynamicListField(RouteFormQuestion question) {
    final items = _dynamicListItems[question.id] ?? [];
    final types = question.options ?? [];
    final maxItems = question.maxItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty) ...[
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Card(
              color: Colors.grey[50],
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                ),
                title: Text(item['type'] as String,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text('Cantidad: ${item['quantity']}',
                    style: const TextStyle(fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () {
                    setState(
                        () => _dynamicListItems[question.id]!.removeAt(i));
                  },
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
        if (items.length < maxItems)
          _DynamicListAdder(
            types: types,
            onAdd: (type, quantity) {
              setState(() {
                _dynamicListItems[question.id] ??= [];
                _dynamicListItems[question.id]!
                    .add({'type': type, 'quantity': quantity});
              });
            },
          ),
        if (items.length >= maxItems)
          Text('Máximo $maxItems items alcanzado',
              style: TextStyle(color: Colors.orange[700], fontSize: 12)),
      ],
    );
  }

  // ==============================
  // CAPTURA DE FOTOS (galería + cámara)
  // ==============================

  Widget _buildPhotoCapture(String questionId, List<File> photos,
      {int maxPhotos = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: photos.asMap().entries.map((entry) {
              final i = entry.key;
              final photo = entry.value;
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(photo),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _questionPhotos[questionId]?.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        if (photos.length < maxPhotos)
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickPhoto(questionId, ImageSource.gallery),
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Galería'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                  side: BorderSide(color: Colors.blue[300]!),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickPhoto(questionId, ImageSource.camera),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Cámara'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!),
                ),
              ),
              if (photos.isNotEmpty) ...[
                const Spacer(),
                Text('${photos.length}/$maxPhotos',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ],
          )
        else
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700], size: 18),
              const SizedBox(width: 4),
              Text('${photos.length} foto(s)',
                  style: TextStyle(color: Colors.green[700], fontSize: 13)),
            ],
          ),
      ],
    );
  }

  Future<void> _pickPhoto(String questionId, ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (pickedFile == null) return;
      final compressedFile = await _compressImage(File(pickedFile.path));
      setState(() {
        _questionPhotos[questionId] ??= [];
        _questionPhotos[questionId]!.add(compressedFile);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = p.join(
          dir.path, 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
      );
      if (result != null) return File(result.path);
    } catch (_) {}
    return file;
  }

  // ==============================
  // VALIDACIÓN Y SUBMIT
  // ==============================

  bool _validate() {
    final questions =
        _sortedQuestions.where(_shouldShowQuestion).where((q) => q.isRequired);

    for (final q in questions) {
      final answer = _answers[q.id];
      switch (q.questionType) {
        case QuestionType.select:
          if (answer == null) {
            _showError('Selecciona: ${q.questionText}');
            return false;
          }
          break;
        case QuestionType.number:
          if (answer == null) {
            _showError('Ingresa: ${q.questionText}');
            return false;
          }
          break;
        case QuestionType.textarea:
        case QuestionType.text:
          if (answer == null || (answer is String && answer.trim().isEmpty)) {
            _showError('Completa: ${q.questionText}');
            return false;
          }
          break;
        default:
          break;
      }
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  Future<void> _submitForm() async {
    if (!_validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final allPhotoUrls = <String>[];
      final userId = SupabaseConfig.currentUser?.id;

      for (final entry in _questionPhotos.entries) {
        final qId = entry.key;
        final files = entry.value;
        final urls = <String>[];
        for (int i = 0; i < files.length; i++) {
          try {
            final bytes = await files[i].readAsBytes();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileName =
                '${userId ?? "unknown"}/evento_${timestamp}_${qId.substring(qId.length - 4)}_$i.jpg';
            final url = await SupabaseConfig.uploadFile(
              SupabaseConfig.visitPhotosBucket,
              fileName,
              bytes,
            );
            urls.add(url);
            allPhotoUrls.add(url);
          } catch (e) {
            urls.add('local:${files[i].path}');
            allPhotoUrls.add('local:${files[i].path}');
          }
        }
        _uploadedPhotoUrls[qId] = urls;
      }

      final answers = <RouteVisitAnswer>[];
      for (final q in widget.questions) {
        if (!_shouldShowQuestion(q)) continue;
        final answer = _answers[q.id];
        final photoUrls = _uploadedPhotoUrls[q.id];

        if (q.questionType == QuestionType.dynamicList) {
          final items = _dynamicListItems[q.id] ?? [];
          if (items.isNotEmpty) {
            final itemStrings =
                items.map((i) => '${i["type"]}:${i["quantity"]}').toList();
            answers.add(RouteVisitAnswer(
              id: '',
              routeVisitId: '',
              questionId: q.id,
              answerOptions: itemStrings,
              answerPhotoUrls: photoUrls,
              createdAt: DateTime.now(),
            ));
          } else {
            answers.add(RouteVisitAnswer(
              id: '',
              routeVisitId: '',
              questionId: q.id,
              answerPhotoUrls: photoUrls,
              createdAt: DateTime.now(),
            ));
          }
          continue;
        }

        answers.add(RouteVisitAnswer(
          id: '',
          routeVisitId: '',
          questionId: q.id,
          answerText: answer is String ? answer : null,
          answerNumber: answer is num ? answer.toDouble() : null,
          answerBoolean: answer is bool ? answer : null,
          answerPhotoUrls: photoUrls,
          createdAt: DateTime.now(),
        ));
      }

      widget.onComplete(answers, allPhotoUrls, null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ==============================
// Widget auxiliar: Agregar item a dynamic list
// ==============================

class _DynamicListAdder extends StatefulWidget {
  final List<String> types;
  final Function(String type, int quantity) onAdd;
  const _DynamicListAdder({required this.types, required this.onAdd});

  @override
  State<_DynamicListAdder> createState() => _DynamicListAdderState();
}

class _DynamicListAdderState extends State<_DynamicListAdder> {
  String? _selectedType;
  final _quantityController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: InputDecoration(
              labelText: 'Producto',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            isExpanded: true,
            items: widget.types
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              if (_selectedType == null) return;
              final qty = int.tryParse(_quantityController.text) ?? 0;
              if (qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ingresa una cantidad válida'),
                      backgroundColor: Colors.orange),
                );
                return;
              }
              widget.onAdd(_selectedType!, qty);
              setState(() {
                _selectedType = null;
                _quantityController.clear();
              });
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
