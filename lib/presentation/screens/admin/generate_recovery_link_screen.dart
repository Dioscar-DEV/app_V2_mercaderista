import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/password_recovery_provider.dart';

/// Pantalla para generar enlaces de recuperación de contraseña manualmente
class GenerateRecoveryLinkScreen extends ConsumerStatefulWidget {
  const GenerateRecoveryLinkScreen({super.key});

  @override
  ConsumerState<GenerateRecoveryLinkScreen> createState() =>
      _GenerateRecoveryLinkScreenState();
}

class _GenerateRecoveryLinkScreenState
    extends ConsumerState<GenerateRecoveryLinkScreen> {
  final _emailController = TextEditingController();
  String? _generatedLink;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _generateLink() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Por favor ingresa un email');
      return;
    }

    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Email inválido');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedLink = null;
    });

    try {
      final link = await ref.read(
        generatePasswordLinkProvider(email).future,
      );

      setState(() {
        _generatedLink = link;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_generatedLink != null) {
      Clipboard.setData(ClipboardData(text: _generatedLink!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace copiado al portapapeles')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar Enlace de Recuperación'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card con instrucciones
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instrucciones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Ingresa el email del usuario\n'
                    '2. Haz clic en "Generar Enlace"\n'
                    '3. Copia el enlace y comparte con el usuario\n'
                    '4. El usuario podrá usar el enlace para cambiar su contraseña',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Input de email
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email del usuario',
              hintText: 'ejemplo@correo.com',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              errorText: _errorMessage,
            ),
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // Botón generar
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateLink,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link),
            label: Text(_isLoading ? 'Generando...' : 'Generar Enlace'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 24),

          // Link generado
          if (_generatedLink != null) ...[
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✓ Enlace generado exitosamente',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          _generatedLink!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar Enlace'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Este enlace expira en 1 hora. Comparte el enlace anterior con el usuario ${_emailController.text}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],

          // Error
          if (_errorMessage != null && _generatedLink == null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
