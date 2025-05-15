import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mip/services/api_service.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _numberController = TextEditingController();
  final _modelController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _uidController = TextEditingController();
  final _rmController = TextEditingController();
  final _statusController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _numberController.dispose();
    _modelController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _uidController.dispose();
    _rmController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      textStyle: const TextStyle(fontSize: 18),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ручной ввод'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(
                  _numberController, 'Номер принтера', TextInputType.number),
              _buildTextField(
                  _modelController, 'Код модели', TextInputType.number),
              _buildTextField(_ipController, 'IP-адрес', TextInputType.text),
              _buildTextField(_portController, 'Порт', TextInputType.number),
              _buildTextField(_uidController, 'UID линии', TextInputType.text),
              _buildTextField(
                  _rmController, 'RM (опционально)', TextInputType.text),
              _buildTextField(
                  _statusController, 'Статус', TextInputType.number),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: buttonStyle,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      TextInputType keyboardType) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
        validator: (value) => (value == null || value.trim().isEmpty)
            ? 'Обязательное поле'
            : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final api = Provider.of<ApiService>(context, listen: false);

    try {
      await api.updatePrinter(
        number: int.parse(_numberController.text.trim()),
        model: int.parse(_modelController.text.trim()),
        ip: _ipController.text.trim(),
        port: _portController.text.trim(),
        uid: _uidController.text.trim(),
        rm: _rmController.text.trim(),
        status: int.parse(_statusController.text.trim()),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Принтер обновлён')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
