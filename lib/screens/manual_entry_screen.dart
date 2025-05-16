import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mip/services/api_service.dart';
import 'package:mip/models/printer.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _numberController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _uidController = TextEditingController();
  final _rmController = TextEditingController();

  PrinterModel? _selectedModel;
  PrinterStatus? _selectedStatus;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _numberController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _uidController.dispose();
    _rmController.dispose();
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
              _buildModelDropdown(),
              _buildTextField(_ipController, 'IP-адрес', TextInputType.text),
              _buildTextField(_portController, 'Порт', TextInputType.number),
              _buildTextField(_uidController, 'UID линии', TextInputType.text),
              _buildTextField(_rmController, 'PM линии', TextInputType.text),
              _buildStatusDropdown(),
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

  Widget _buildModelDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<PrinterModel>(
        value: _selectedModel,
        items: PrinterModel.values
            .where((m) => m != PrinterModel.unknown)
            .map((model) => DropdownMenuItem(
                  value: model,
                  child: Text(model.name),
                ))
            .toList(),
        onChanged: (model) => setState(() => _selectedModel = model),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Модель',
        ),
        validator: (value) => value == null ? 'Выберите модель принтера' : null,
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<PrinterStatus>(
        value: _selectedStatus,
        items: PrinterStatus.values
            .map((status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.name),
                ))
            .toList(),
        onChanged: (status) => setState(() => _selectedStatus = status),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Статус',
        ),
        validator: (value) => value == null ? 'Выберите статус принтера' : null,
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
        model: _selectedModel!.code,
        ip: _ipController.text.trim(),
        port: _portController.text.trim(),
        uid: _uidController.text.trim(),
        rm: _rmController.text.trim(),
        status: _selectedStatus!.code,
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
