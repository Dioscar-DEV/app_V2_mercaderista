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

/// Formulario de Merchandising con Stepper de 4 secciones
/// Secciones: Señalización → Shell → Qualid → Reportes
class MerchandisingVisitForm extends ConsumerStatefulWidget {
  final List<RouteFormQuestion> questions;
  final Function(List<RouteVisitAnswer> answers, List<String> photoUrls,
      String? observations) onComplete;

  const MerchandisingVisitForm({
    super.key,
    required this.questions,
    required this.onComplete,
  });

  @override
  ConsumerState<MerchandisingVisitForm> createState() =>
      _MerchandisingVisitFormState();
}

class _MerchandisingVisitFormState
    extends ConsumerState<MerchandisingVisitForm> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  final _imagePicker = ImagePicker();

  // Respuestas: questionId → valor
  final Map<String, dynamic> _answers = {};
  // Fotos por pregunta: questionId → List<File>
  final Map<String, List<File>> _questionPhotos = {};
  // URLs subidas por pregunta: questionId → List<String>
  final Map<String, List<String>> _uploadedPhotoUrls = {};
  // Items de dynamic_list: questionId → List<{type, quantity}>
  final Map<String, List<Map<String, dynamic>>> _dynamicListItems = {};

  // Secciones ordenadas
  static const _sectionOrder = ['senalizacion', 'shell', 'qualid', 'reportes'];
  static const _sectionTitles = {
    'senalizacion': 'Señalización',
    'shell': 'Shell Merchandising',
    'qualid': 'Qualid Merchandising',
    'reportes': 'Reportes Finales',
  };
  static const _sectionIcons = {
    'senalizacion': Icons.signpost,
    'shell': Icons.local_gas_station,
    'qualid': Icons.directions_car,
    'reportes': Icons.description,
  };

  List<RouteFormQuestion> _getQuestionsForSection(String section) {
    return widget.questions
        .where((q) => q.section == section)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  @override
  void initState() {
    super.initState();
    // Inicializar respuestas con valores por defecto
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

  @override
  Widget build(BuildContext context) {
    final sections = _sectionOrder
        .where((s) => _getQuestionsForSection(s).isNotEmpty)
        .toList();

    return Column(
      children: [
        // Header con progreso
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(_sectionIcons[sections[_currentStep]] ?? Icons.assignment,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sectionTitles[sections[_currentStep]] ?? '',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Paso ${_currentStep + 1} de ${sections.length}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Indicador de progreso circular
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: (_currentStep + 1) / sections.length,
                    strokeWidth: 4,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Steps indicator (dots)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(sections.length, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _currentStep ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= _currentStep
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),

        // Contenido de la sección actual
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._getQuestionsForSection(sections[_currentStep])
                    .where(_shouldShowQuestion)
                    .map(_buildQuestionWidget),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Botones de navegación
        Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep--),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Anterior'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _currentStep < sections.length - 1
                  ? ElevatedButton.icon(
                      onPressed: () {
                        if (_validateCurrentStep(sections[_currentStep])) {
                          setState(() => _currentStep++);
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Siguiente'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    )
                  : ElevatedButton.icon(
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
                      label: Text(
                          _isSubmitting ? 'Guardando...' : 'Completar Visita'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  // ==============================
  // RENDERIZADO DE PREGUNTAS
  // ==============================

  Widget _buildQuestionWidget(RouteFormQuestion question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label de la pregunta
          Row(
            children: [
              Expanded(
                child: Text(
                  question.questionText,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              if (question.isRequired)
                const Text(' *', style: TextStyle(color: Colors.red, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          // Campo según tipo
          _buildFieldForType(question),
        ],
      ),
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
      case QuestionType.numberPhoto:
        return _buildNumberPhotoField(question);
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

  // --- Boolean (Sí/No) ---
  Widget _buildBooleanField(RouteFormQuestion question) {
    final value = _answers[question.id] == true;
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('No'), icon: Icon(Icons.close)),
        ButtonSegment(
            value: true,
            label: Text('Sí'),
            icon: Icon(Icons.check)),
      ],
      selected: {value},
      onSelectionChanged: (newSelection) {
        setState(() => _answers[question.id] = newSelection.first);
      },
    );
  }

  // --- Boolean + Photo (Sí/No, si Sí→foto) ---
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
                value: true,
                label: Text('Sí'),
                icon: Icon(Icons.check)),
          ],
          selected: {value},
          onSelectionChanged: (newSelection) {
            setState(() {
              _answers[question.id] = newSelection.first;
              if (!newSelection.first) {
                _questionPhotos.remove(question.id);
              }
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

  // --- Number ---
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
          _answers[question.id] = int.tryParse(value) ?? double.tryParse(value) ?? 0;
        }
      },
    );
  }

  // --- Number + Photo ---
  Widget _buildNumberPhotoField(RouteFormQuestion question) {
    final photos = _questionPhotos[question.id] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
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
              _answers[question.id] = int.tryParse(value) ?? double.tryParse(value) ?? 0;
            }
          },
        ),
        const SizedBox(height: 8),
        _buildPhotoCapture(question.id, photos, maxPhotos: 1),
      ],
    );
  }

  // --- Photo (solo cámara) ---
  Widget _buildPhotoField(RouteFormQuestion question) {
    final photos = _questionPhotos[question.id] ?? [];
    return _buildPhotoCapture(question.id, photos, maxPhotos: 1);
  }

  // --- Textarea ---
  Widget _buildTextareaField(RouteFormQuestion question) {
    return TextFormField(
      maxLines: 5,
      decoration: InputDecoration(
        hintText: question.placeholder ?? 'Escriba aquí...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        alignLabelWithHint: true,
      ),
      onChanged: (value) => _answers[question.id] = value,
    );
  }

  // --- Text ---
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

  // --- Select ---
  Widget _buildSelectField(RouteFormQuestion question) {
    return DropdownButtonFormField<String>(
      value: _answers[question.id] as String?,
      decoration: InputDecoration(
        hintText: 'Seleccionar',
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

  // --- Dynamic List (tipo + cantidad, agregar múltiples) ---
  Widget _buildDynamicListField(RouteFormQuestion question) {
    final items = _dynamicListItems[question.id] ?? [];
    final types = question.options ?? [];
    final maxItems = question.maxItems;
    final showPhoto = question.hasPhoto;
    final photos = _questionPhotos[question.id] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lista de items agregados
        if (items.isNotEmpty) ...[
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Card(
              color: Colors.grey[50],
              margin: const EdgeInsets.only(bottom: 8),
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
                    setState(() {
                      _dynamicListItems[question.id]!.removeAt(i);
                    });
                  },
                ),
              ),
            );
          }),
          const Divider(),
        ],

        // Agregar nuevo item
        if (items.length < maxItems) _DynamicListAdder(
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

        // Foto opcional para la lista
        if (showPhoto && items.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildPhotoCapture(question.id, photos, maxPhotos: 1),
        ],
      ],
    );
  }

  // ==============================
  // CAPTURA DE FOTOS (reutilizable)
  // ==============================

  Widget _buildPhotoCapture(String questionId, List<File> photos,
      {int maxPhotos = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isEmpty)
          OutlinedButton.icon(
            onPressed: () => _takePhoto(questionId),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Tomar foto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[700],
              side: BorderSide(color: Colors.blue[300]!),
            ),
          )
        else
          Row(
            children: [
              // Preview de la foto
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(photos.first),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _questionPhotos[questionId]?.clear();
                          });
                        },
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
              ),
              const SizedBox(width: 12),
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 4),
              const Text('Foto capturada',
                  style: TextStyle(color: Colors.green, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _takePhoto(questionId),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Cambiar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _takePhoto(String questionId) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      final compressedFile = await _compressImage(File(pickedFile.path));

      setState(() {
        _questionPhotos[questionId] = [compressedFile];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al capturar foto: $e'),
            backgroundColor: Colors.red),
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
  // VALIDACIÓN
  // ==============================

  bool _validateCurrentStep(String section) {
    final questions = _getQuestionsForSection(section)
        .where(_shouldShowQuestion)
        .where((q) => q.isRequired);

    for (final q in questions) {
      final answer = _answers[q.id];

      switch (q.questionType) {
        case QuestionType.booleanPhoto:
          if (answer == true && (_questionPhotos[q.id]?.isEmpty ?? true)) {
            _showValidationError('Toma una foto para: ${q.questionText}');
            return false;
          }
          break;
        case QuestionType.numberPhoto:
          if (answer == null) {
            _showValidationError('Ingresa la cantidad: ${q.questionText}');
            return false;
          }
          break;
        case QuestionType.number:
          if (answer == null) {
            _showValidationError('Ingresa la cantidad: ${q.questionText}');
            return false;
          }
          break;
        case QuestionType.photo:
          if (_questionPhotos[q.id]?.isEmpty ?? true) {
            _showValidationError('Toma una foto: ${q.questionText}');
            return false;
          }
          break;
        case QuestionType.textarea:
        case QuestionType.text:
          if (answer == null || (answer is String && answer.trim().isEmpty)) {
            _showValidationError('Completa: ${q.questionText}');
            return false;
          }
          break;
        default:
          break;
      }
    }
    return true;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  // ==============================
  // SUBMIT
  // ==============================

  Future<void> _submitForm() async {
    // Validar último paso
    final sections = _sectionOrder
        .where((s) => _getQuestionsForSection(s).isNotEmpty)
        .toList();
    if (!_validateCurrentStep(sections[_currentStep])) return;

    setState(() => _isSubmitting = true);

    try {
      // Subir todas las fotos
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
                '${userId ?? "unknown"}/merch_${timestamp}_${qId.substring(qId.length - 4)}_$i.jpg';

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

      // Construir answers
      final answers = <RouteVisitAnswer>[];

      for (final q in widget.questions) {
        if (!_shouldShowQuestion(q)) continue;

        final answer = _answers[q.id];
        final photoUrls = _uploadedPhotoUrls[q.id];

        Map<String, dynamic>? answerJson;

        // Construir answer_json según tipo
        if (q.questionType == QuestionType.dynamicList) {
          final items = _dynamicListItems[q.id] ?? [];
          if (items.isNotEmpty || (photoUrls != null && photoUrls.isNotEmpty)) {
            answerJson = {};
            if (items.isNotEmpty) answerJson['items'] = items;
            if (photoUrls != null && photoUrls.isNotEmpty) {
              answerJson['photo_urls'] = photoUrls;
            }
          }
        } else if (photoUrls != null && photoUrls.isNotEmpty) {
          answerJson = {'photo_urls': photoUrls};
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

        // Si hay answer_json, necesitamos actualizar el toInsertJson manualmente
        // El answer_json se construye en _buildAnswerJson() de RouteVisitAnswer
        // Pero dynamic_list necesita items, no solo photo_urls
        // Usaremos answerOptions para pasar datos extra como JSON string
        if (q.questionType == QuestionType.dynamicList) {
          final items = _dynamicListItems[q.id] ?? [];
          if (items.isNotEmpty) {
            // Reemplazar el último answer con uno que tenga los items codificados
            answers.removeLast();
            // Codificar items como lista de strings "type:quantity"
            final itemStrings =
                items.map((i) => '${i["type"]}:${i["quantity"]}').toList();
            answers.add(RouteVisitAnswer(
              id: '',
              routeVisitId: '',
              questionId: q.id,
              answerText: null,
              answerNumber: null,
              answerBoolean: null,
              answerOptions: itemStrings,
              answerPhotoUrls: photoUrls,
              createdAt: DateTime.now(),
            ));
          }
        }
      }

      widget.onComplete(answers, allPhotoUrls, null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red),
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
        // Tipo selector
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: InputDecoration(
              labelText: 'Tipo',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: widget.types
                .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v),
          ),
        ),
        const SizedBox(width: 8),
        // Cantidad
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
        // Botón agregar
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              if (_selectedType == null) return;
              final qty =
                  int.tryParse(_quantityController.text) ?? 0;
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
