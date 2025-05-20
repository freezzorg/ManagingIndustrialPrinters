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
  static const _zeroUuid = '00000000-0000-0000-0000-000000000000';

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
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

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
      } else {
        final nextNumber = args as int?;
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

  /// Считаем валидным только настоящий UUID, но не all-zero
  bool _isValidUid(String? uid) {
    if (uid == null) return false;
    final trimmed = uid.trim();
    if (trimmed.isEmpty || trimmed == _zeroUuid) return false;

    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(trimmed);
  }

  void _validateUidAndUpdateFields() {
    final text = uidController.text.trim();
    final isEmptyUid = text.isEmpty || text == _zeroUuid;
    final isValid = _isValidUid(text);

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
              // Номер принтера
              TextFormField(
                controller: numberController,
                enabled: !_isEditMode,
                decoration: const InputDecoration(labelText: 'Номер принтера'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите номер';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Неверный номер';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // Модель
              DropdownButtonFormField<PrinterModel>(
                value: _selectedModel,
                decoration: const InputDecoration(labelText: 'Модель принтера'),
                items: PrinterModel.values
                    .where((m) => m != PrinterModel.unknown)
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedModel = v),
                validator: (v) => v == null ? 'Выберите модель' : null,
              ),

              const SizedBox(height: 8),

              // IP
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

              // Порт
              TextFormField(
                controller: portController,
                decoration: const InputDecoration(labelText: 'Порт принтера'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Введите порт' : null,
              ),

              const SizedBox(height: 8),

              // UID линии
              TextFormField(
                controller: uidController,
                decoration: const InputDecoration(labelText: 'UID линии'),
                onChanged: (_) => _validateUidAndUpdateFields(),
              ),

              const SizedBox(height: 8),

              // PM линии
              TextFormField(
                controller: rmController,
                decoration: const InputDecoration(labelText: 'PM линии'),
                validator: (value) {
                  if (_isValidUid(uidController.text) &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Введите PM линии';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // Статус принтера
              DropdownButtonFormField<PrinterStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Статус принтера'),
                items: PrinterStatus.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStatus = v),
                validator: (value) {
                  final text = uidController.text.trim();
                  final isEmptyUid = text.isEmpty || text == _zeroUuid;
                  final isValid = _isValidUid(text);

                  if (value == null) return 'Выберите статус';

                  if (isEmptyUid && value != PrinterStatus.notWorking) {
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

              // Кнопка Сохранить
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final rawUid = uidController.text.trim();
                    final uid = rawUid.isEmpty ? _zeroUuid : rawUid;

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
