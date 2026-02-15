import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/models/route_form_question.dart';
import '../../../core/models/route_visit.dart';
import '../../../config/theme_config.dart';
import '../../../config/supabase_config.dart';

/// Formulario dinámico para visitas
/// Genera campos basados en las preguntas configuradas para el tipo de ruta
class RouteVisitForm extends ConsumerStatefulWidget {
  final List<RouteFormQuestion> questions;
  final Function(List<RouteVisitAnswer> answers, List<String> photoUrls, String? observations) onComplete;

  const RouteVisitForm({
    super.key,
    required this.questions,
    required this.onComplete,
  });

  @override
  ConsumerState<RouteVisitForm> createState() => _RouteVisitFormState();
}

class _RouteVisitFormState extends ConsumerState<RouteVisitForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _answers = {};
  final _observationsController = TextEditingController();
  final List<String> _photoUrls = [];
  final List<File> _localPhotos = []; // Fotos locales antes de subir
  bool _isSubmitting = false;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    for (final question in widget.questions) {
      switch (question.questionType) {
        case QuestionType.boolean:
          _answers[question.id] = false;
          break;
        case QuestionType.rating:
          _answers[question.id] = 3.0;
          break;
        case QuestionType.multiselect:
          _answers[question.id] = <String>[];
          break;
        default:
          _answers[question.id] = null;
      }
    }
  }

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assignment, color: ThemeConfig.primaryColor),
                      SizedBox(width: 8),
                      Text(
                        'Formulario de Visita',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Preguntas dinámicas
                  ...widget.questions.map((question) => _buildQuestionField(question)),

                  // Campo de observaciones
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _observationsController,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones',
                      prefixIcon: Icon(Icons.notes),
                      hintText: 'Comentarios adicionales...',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sección de fotos
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.photo_camera, color: ThemeConfig.primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Fotos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _takePhoto(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Cámara'),
                          ),
                          TextButton.icon(
                            onPressed: () => _takePhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: const Text('Galería'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_localPhotos.isEmpty && _photoUrls.isEmpty)
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library, size: 32, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Toca Cámara o Galería para agregar fotos',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _localPhotos.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_localPhotos[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _localPhotos.removeAt(index);
                                        if (index < _photoUrls.length) {
                                          _photoUrls.removeAt(index);
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Botón de completar
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
              label: Text(_isSubmitting ? 'Guardando...' : 'Completar Visita'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionField(RouteFormQuestion question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question.questionText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (question.isRequired)
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInputField(question),
        ],
      ),
    );
  }

  Widget _buildInputField(RouteFormQuestion question) {
    switch (question.questionType) {
      case QuestionType.text:
        return TextFormField(
          decoration: const InputDecoration(
            hintText: 'Escribe tu respuesta...',
          ),
          onChanged: (value) => _answers[question.id] = value,
          validator: question.isRequired
              ? (value) => value?.isEmpty ?? true ? 'Campo requerido' : null
              : null,
        );

      case QuestionType.number:
        return TextFormField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Ingresa un número...',
          ),
          onChanged: (value) => _answers[question.id] = double.tryParse(value),
          validator: question.isRequired
              ? (value) => value?.isEmpty ?? true ? 'Campo requerido' : null
              : null,
        );

      case QuestionType.boolean:
        return SwitchListTile(
          value: _answers[question.id] ?? false,
          onChanged: (value) => setState(() => _answers[question.id] = value),
          title: Text(_answers[question.id] == true ? 'Sí' : 'No'),
          contentPadding: EdgeInsets.zero,
        );

      case QuestionType.select:
        return DropdownButtonFormField<String>(
          value: _answers[question.id] as String?,
          decoration: const InputDecoration(
            hintText: 'Selecciona una opción...',
          ),
          items: question.options?.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList() ?? [],
          onChanged: (value) => setState(() => _answers[question.id] = value),
          validator: question.isRequired
              ? (value) => value == null ? 'Selecciona una opción' : null
              : null,
        );

      case QuestionType.multiselect:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: question.options?.map((option) {
            final selected = (_answers[question.id] as List<String>? ?? []).contains(option);
            return FilterChip(
              label: Text(option),
              selected: selected,
              onSelected: (isSelected) {
                setState(() {
                  final list = List<String>.from(_answers[question.id] ?? []);
                  if (isSelected) {
                    list.add(option);
                  } else {
                    list.remove(option);
                  }
                  _answers[question.id] = list;
                });
              },
              selectedColor: ThemeConfig.primaryColor.withValues(alpha: 0.2),
              checkmarkColor: ThemeConfig.primaryColor,
            );
          }).toList() ?? [],
        );

      case QuestionType.rating:
        final rating = (_answers[question.id] as double?) ?? 3.0;
        return Row(
          children: [
            ...List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                icon: Icon(
                  starValue <= rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () => setState(() => _answers[question.id] = starValue.toDouble()),
              );
            }),
            const SizedBox(width: 8),
            Text(
              '${rating.toInt()}/5',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );

      case QuestionType.photo:
        return OutlinedButton.icon(
          onPressed: () => _takePhotoForQuestion(question.id),
          icon: const Icon(Icons.camera_alt),
          label: Text(
            _answers[question.id] != null ? 'Foto tomada ✓' : 'Tomar foto',
          ),
        );

      // Nuevos tipos se manejan en MerchandisingVisitForm
      default:
        return TextFormField(
          decoration: const InputDecoration(hintText: 'Escribe tu respuesta...'),
          onChanged: (value) => _answers[question.id] = value,
        );
    }
  }

  Future<void> _takePhoto(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      // Comprimir la imagen
      final compressedFile = await _compressImage(File(pickedFile.path));

      setState(() {
        _localPhotos.add(compressedFile);
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto agregada'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al capturar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhotoForQuestion(String questionId) async {
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
        _localPhotos.add(compressedFile);
        _answers[questionId] = compressedFile.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al capturar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Comprime imagen para reducir tamaño antes de subir
  Future<File> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = p.join(dir.path, 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
      );

      if (result != null) {
        return File(result.path);
      }
    } catch (_) {
      // Si falla la compresión, usar la original
    }
    return file;
  }

  /// Sube fotos a Supabase Storage y retorna las URLs
  Future<List<String>> _uploadPhotos() async {
    final uploadedUrls = <String>[];

    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return uploadedUrls;

    for (int i = 0; i < _localPhotos.length; i++) {
      try {
        final file = _localPhotos[i];
        final bytes = await file.readAsBytes();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '$userId/visit_${timestamp}_$i.jpg';

        final url = await SupabaseConfig.uploadFile(
          SupabaseConfig.visitPhotosBucket,
          fileName,
          bytes,
        );
        uploadedUrls.add(url);
      } catch (e) {
        // Si falla una foto, continuar con las demás
        // Guardar path local como fallback para sync posterior
        uploadedUrls.add('local:${_localPhotos[i].path}');
      }
    }

    return uploadedUrls;
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verificar campos requeridos
    for (final question in widget.questions) {
      if (question.isRequired) {
        final answer = _answers[question.id];
        if (answer == null ||
            (answer is String && answer.isEmpty) ||
            (answer is List && answer.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Complete el campo: ${question.questionText}')),
          );
          return;
        }
      }
    }

    setState(() => _isSubmitting = true);

    // Subir fotos a Supabase Storage
    List<String> uploadedPhotoUrls = [];
    if (_localPhotos.isNotEmpty) {
      uploadedPhotoUrls = await _uploadPhotos();
    }

    // Construir las respuestas
    final answers = widget.questions.map((question) {
      final answer = _answers[question.id];

      return RouteVisitAnswer(
        id: '',
        routeVisitId: '',
        questionId: question.id,
        answerText: answer is String ? answer : null,
        answerNumber: answer is double || answer is int ? answer.toDouble() : null,
        answerBoolean: answer is bool ? answer : null,
        answerOptions: answer is List<String> ? answer : null,
        answerPhotoUrls: question.questionType == QuestionType.photo && answer is String
            ? [answer]
            : null,
        createdAt: DateTime.now(),
      );
    }).toList();

    widget.onComplete(
      answers,
      uploadedPhotoUrls,
      _observationsController.text.trim().isEmpty
          ? null
          : _observationsController.text.trim(),
    );
  }
}
