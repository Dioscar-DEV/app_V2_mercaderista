import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../config/theme_config.dart';
import '../../../data/services/location_service.dart';
import '../../providers/prospect_provider.dart';

class ProspectFormScreen extends ConsumerStatefulWidget {
  const ProspectFormScreen({super.key});

  @override
  ConsumerState<ProspectFormScreen> createState() => _ProspectFormScreenState();
}

class _ProspectFormScreenState extends ConsumerState<ProspectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rifController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();
  bool _inSitu = true;
  File? _photoFile;
  bool _loadingGps = true;

  @override
  void initState() {
    super.initState();
    _captureGps();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rifController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    if (kIsWeb) {
      setState(() => _loadingGps = false);
      return;
    }
    try {
      final coords = await LocationService.instance.getCoordinates();
      if (coords != null && mounted) {
        ref.read(prospectFormProvider.notifier).setLocation(coords.latitude, coords.longitude);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingGps = false);
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      // Comprimir
      final compressed = await _compressPhoto(File(pickedFile.path));
      setState(() => _photoFile = compressed);
      ref.read(prospectFormProvider.notifier).setPhoto(compressed.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar foto: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<File> _compressPhoto(File file) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${appDir.path}/prospect_photos');
      if (!await photoDir.exists()) await photoDir.create(recursive: true);
      final targetPath = p.join(
        photoDir.path,
        'prospect_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(prospectFormProvider.notifier).submitProspect(
      name: _nameController.text.trim(),
      rif: _rifController.text.trim().isEmpty ? null : _rifController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      contactPerson: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
      inSitu: _inSitu,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      // Check connectivity to show appropriate message
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity == ConnectivityResult.wifi ||
          connectivity == ConnectivityResult.mobile ||
          connectivity == ConnectivityResult.ethernet;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Prospecto registrado exitosamente'
                      : 'Prospecto guardado localmente. Se sincronizara al volver en linea.',
                ),
              ),
            ],
          ),
          backgroundColor: isOnline ? Colors.green : Colors.orange,
          duration: Duration(seconds: isOnline ? 3 : 4),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(prospectFormProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Prospecto'),
        backgroundColor: ThemeConfig.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // GPS Status
              _buildGpsCard(formState),
              const SizedBox(height: 16),

              // Foto del local
              _buildPhotoSection(),
              const SizedBox(height: 16),

              // Nombre *
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del negocio *',
                  hintText: 'Ej: Bodega Don Pedro',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 12),

              // RIF
              TextFormField(
                controller: _rifController,
                decoration: const InputDecoration(
                  labelText: 'RIF',
                  hintText: 'Ej: J-12345678-9',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),

              // Dirección *
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Direccion *',
                  hintText: 'Ej: Av. Principal, C.C. Plaza, Local 5',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 12),

              // Teléfono
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
                  hintText: 'Ej: 0412-1234567',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // Persona de contacto
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Persona de contacto',
                  hintText: 'Nombre del encargado/dueno',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // In Situ toggle
              Card(
                child: SwitchListTile(
                  title: const Text('Estoy en el sitio'),
                  subtitle: Text(
                    _inSitu
                        ? 'La ubicacion GPS corresponde al local'
                        : 'No estoy fisicamente en el local',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: _inSitu,
                  onChanged: (v) => setState(() => _inSitu = v),
                  secondary: Icon(
                    _inSitu ? Icons.location_on : Icons.location_off,
                    color: _inSitu ? Colors.green : Colors.grey,
                  ),
                  activeColor: ThemeConfig.primaryColor,
                ),
              ),
              const SizedBox(height: 12),

              // Notas
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas / Observaciones',
                  hintText: 'Cualquier detalle adicional...',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Error
              if (formState.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    formState.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Submit
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: formState.isLoading ? null : _submit,
                  icon: formState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(formState.isLoading ? 'Guardando...' : 'Guardar Prospecto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsCard(ProspectFormState formState) {
    final hasGps = formState.hasGps;
    return Card(
      color: hasGps ? Colors.green.shade50 : (_loadingGps ? Colors.blue.shade50 : Colors.orange.shade50),
      child: ListTile(
        leading: _loadingGps
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                hasGps ? Icons.gps_fixed : Icons.gps_off,
                color: hasGps ? Colors.green : Colors.orange,
              ),
        title: Text(
          _loadingGps
              ? 'Obteniendo ubicacion...'
              : hasGps
                  ? 'Ubicacion capturada'
                  : 'Sin GPS',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: hasGps ? Colors.green.shade700 : (_loadingGps ? Colors.blue.shade700 : Colors.orange.shade700),
          ),
        ),
        subtitle: hasGps
            ? Text(
                '${formState.latitude!.toStringAsFixed(6)}, ${formState.longitude!.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              )
            : _loadingGps
                ? null
                : const Text('El prospecto se guardara sin coordenadas', style: TextStyle(fontSize: 11)),
        trailing: !_loadingGps && !hasGps
            ? IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() => _loadingGps = true);
                  _captureGps();
                },
              )
            : null,
      ),
    );
  }

  Widget _buildPhotoSection() {
    return GestureDetector(
      onTap: _takePhoto,
      child: Container(
        height: _photoFile != null ? 200 : 120,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _photoFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_photoFile!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        onPressed: _takePhoto,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Tomar foto del local',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Text(
                    '(Opcional)',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
      ),
    );
  }
}
