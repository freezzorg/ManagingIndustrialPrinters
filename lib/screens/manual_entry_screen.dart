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

  final _formKey = GlobalKey<FormState>();

  PrinterModel? _selectedModel;
  PrinterStatus? _selectedStatus;

  bool _isEditMode = false;
  Printer? _existingPrinter;
  bool _isInitialized =
      false; // Флаг для предотвращения повторной инициализации

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Инициализируем только один раз
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Printer) {
        _isEditMode = true;
        _existingPrinter = args;

        numberController.text = args.number.toString();
        ipController.text = args.ip;
        portController.text = args.port;
        uidController.text = args.uid;
        rmController.text = args.rm;
        _selectedModel = args.model;
        _selectedStatus = args.status;
      } else if (!_isEditMode) {
        final nextNumber = ModalRoute.of(context)!.settings.arguments as int?;
        if (nextNumber != null) {
          numberController.text = nextNumber.toString();
        }
      }
      _isInitialized = true;
    }
  }

  bool _isValidIp(String ip) {
    final regex = RegExp(
      r'^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$',
    );
    return regex.hasMatch(ip);
  }

  bool _isValidUid(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(uid) && uid.length == 36;
  }

  void _validateUidAndUpdateFields() {
    final uid = uidController.text.trim();
    final isEmptyUid =
        uid.isEmpty || uid == '00000000-0000-0000-0000-000000000000';
    final isValid = _isValidUid(uid);

    setState(() {
      if (isEmptyUid) {
        rmController.clear();
        _selectedStatus = PrinterStatus.notWorking;
      } else if (isValid) {
        if (rmController.text.trim().isEmpty) {
          rmController.text = 'PM';
        }
        if (_selectedStatus != PrinterStatus.connected &&
            _selectedStatus != PrinterStatus.inWork) {
          _selectedStatus = PrinterStatus.connected;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редактировать принтер' : 'Добавить принтер'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: numberController,
                enabled: !_isEditMode,
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
              Builder(
                builder: (context) {
                  return DropdownButtonFormField<PrinterModel>(
                    value: _selectedModel,
                    decoration:
                        const InputDecoration(labelText: 'Модель принтера'),
                    items: PrinterModel.values
                        .where((model) => model != PrinterModel.unknown)
                        .map((model) => DropdownMenuItem(
                              value: model,
                              child: Text(model.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedModel = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Выберите модель' : null,
                  );
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: ipController,
                decoration:
                    const InputDecoration(labelText: 'IP адрес принтера'),
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
                decoration: const InputDecoration(labelText: 'Порт принтера'),
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
                decoration: const InputDecoration(labelText: 'UID линии'),
                onChanged: (_) => _validateUidAndUpdateFields(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: rmController,
                decoration: const InputDecoration(labelText: 'PM линии'),
                validator: (value) {
                  final uid = uidController.text.trim();
                  final isValid = _isValidUid(uid);
                  if (isValid && (value == null || value.trim().isEmpty)) {
                    return 'Введите PM линии';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PrinterStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Статус принтера'),
                items: PrinterStatus.values
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value;
                  });
                },
                validator: (value) {
                  final uid = uidController.text.trim();
                  final isValid = _isValidUid(uid);
                  if (value == null) return 'Выберите статус';
                  if (!isValid && value != PrinterStatus.notWorking) {
                    return 'Если UID пуст, статус должен быть "Не в работе"';
                  }
                  if (isValid &&
                      value != PrinterStatus.connected &&
                      value != PrinterStatus.inWork) {
                    return 'Для указанного UID статус должен быть "Подключен" или "В работе"';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final uid = uidController.text.trim().isEmpty
                        ? '00000000-0000-0000-0000-000000000000'
                        : uidController.text.trim();

                    final data = {
                      'number': int.parse(numberController.text),
                      'model': _selectedModel!.code,
                      'ip': ipController.text.trim(),
                      'port': portController.text.trim(),
                      'uid': uid,
                      'rm': rmController.text.trim(),
                      'status': _selectedStatus!.code,
                    };

                    try {
                      if (_isEditMode) {
                        data['id'] = _existingPrinter!.id;
                        await apiService.updatePrinter(data);
                        await apiService.getPrinters();
                      } else {
                        await apiService.addPrinter(data);
                      }
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка: $e')),
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
