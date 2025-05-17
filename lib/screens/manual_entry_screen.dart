import 'package:flutter/material.dart';
import 'package:mip/models/printer.dart';
import 'package:mip/services/api_service.dart';
import 'package:provider/provider.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final numberController = TextEditingController();
  final ipController = TextEditingController();
  final portController = TextEditingController();
  final uidController = TextEditingController();
  final rmController = TextEditingController();

  PrinterModel? _selectedModel;
  PrinterStatus? _selectedStatus;

  final _formKey = GlobalKey<FormState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      numberController.text = args.toString();
    }
  }

  bool _isValidIp(String ip) {
    final regex = RegExp(
      r'^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$',
    );
    return regex.hasMatch(ip);
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить принтер'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: numberController,
                decoration: const InputDecoration(labelText: 'Номер принтера'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите номер';
                  }
                  final number = int.tryParse(value);
                  if (number == null) {
                    return 'Неверный номер';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PrinterModel>(
                value: _selectedModel,
                decoration: const InputDecoration(labelText: 'Модель'),
                items: PrinterModel.values
                    .where((model) => model != PrinterModel.unknown)
                    .map((model) => DropdownMenuItem(
                          value: model,
                          child: Text(model.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedModel = value);
                },
                validator: (value) => value == null ? 'Выберите модель' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: ipController,
                decoration: const InputDecoration(labelText: 'IP-адрес'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите IP';
                  }
                  if (!_isValidIp(value)) {
                    return 'Неверный формат IP';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: portController,
                decoration: const InputDecoration(labelText: 'Порт'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите порт';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: uidController,
                decoration: const InputDecoration(labelText: 'UID принтера'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: rmController,
                decoration: const InputDecoration(labelText: 'PM линии'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PrinterStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Статус'),
                items: PrinterStatus.values
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedStatus = value);
                },
                validator: (value) => value == null ? 'Выберите статус' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final newNumber = int.parse(numberController.text);
                    final uid = uidController.text.trim().isEmpty
                        ? '00000000-0000-0000-0000-000000000000'
                        : uidController.text.trim();

                    try {
                      await apiService.addPrinter(
                        number: newNumber,
                        model: _selectedModel!.code,
                        ip: ipController.text.trim(),
                        port: portController.text.trim(),
                        uid: uid,
                        rm: rmController.text.trim(),
                        status: _selectedStatus!.code,
                      );
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка: ${e.toString()}')),
                        );
                      }
                    }
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    numberController.dispose();
    ipController.dispose();
    portController.dispose();
    uidController.dispose();
    rmController.dispose();
    super.dispose();
  }
}
