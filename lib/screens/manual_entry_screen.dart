import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final _ipRegex = RegExp(
    r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$',
  );

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
        title: const Text('Добавить принтер'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(
                controller: _numberController,
                label: 'Номер принтера',
                keyboardType: TextInputType.number,
              ),
              _buildDropdown<PrinterModel>(
                label: 'Модель',
                value: _selectedModel,
                items: PrinterModel.values
                    .where((m) => m != PrinterModel.unknown)
                    .toList(),
                onChanged: (value) => setState(() => _selectedModel = value),
                getLabel: (model) => model.name,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _ipController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'IP-адрес',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Обязательное поле';
                    }
                    if (!_ipRegex.hasMatch(value.trim())) {
                      return 'Некорректный IP-адрес';
                    }
                    return null;
                  },
                ),
              ),
              _buildTextField(
                controller: _portController,
                label: 'Порт',
                keyboardType: TextInputType.number,
              ),
              _buildTextField(
                controller: _uidController,
                label: 'UID линии',
                keyboardType: TextInputType.text,
              ),
              _buildTextField(
                controller: _rmController,
                label: 'PM линии',
                keyboardType: TextInputType.text,
              ),
              _buildDropdown<PrinterStatus>(
                label: 'Статус',
                value: _selectedStatus,
                items: PrinterStatus.values,
                onChanged: (value) => setState(() => _selectedStatus = value),
                getLabel: (status) => status.name,
              ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
  }) {
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

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) getLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(getLabel(item)),
                ))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
        validator: (value) => value == null ? 'Обязательное поле' : null,
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
      Navigator.pop(context, true);
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
