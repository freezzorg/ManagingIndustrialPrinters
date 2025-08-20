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
  bool _isWorking = false;
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
        _selectedModel = PrinterModelExtension.fromCode(args.model);
        _isWorking = args.status;
      } else if (args is int) {
        numberController.text = args.toString();
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
    final isEmpty = text.isEmpty || text == _zeroUuid;
    final isValid = _isValidUid(text);
    setState(() {
      if (isEmpty) {
        rmController.clear();
        _isWorking = false;
      } else if (isValid) {
        if (rmController.text.trim().isEmpty) {
          rmController.text = 'PM';
        }
        if (!_isWorking) {
          _isWorking = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Редактировать принтер' : 'Добавить принтер',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueGrey, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.print, color: Colors.blueAccent),
                    title: TextFormField(
                      controller: numberController,
                      enabled: !_isEditMode,
                      decoration: const InputDecoration(
                        labelText: 'Номер принтера',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
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
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.devices, color: Colors.blueAccent),
                    title: DropdownButtonFormField<PrinterModel>(
                      initialValue: _selectedModel,
                      decoration: const InputDecoration(
                        labelText: 'Модель принтера',
                        border: InputBorder.none,
                      ),
                      style: TextStyle(color: textColor),
                      items: PrinterModel.values
                          .where((m) => m != PrinterModel.unknown)
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m.name, style: TextStyle(color: textColor)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedModel = v),
                      validator: (v) => v == null ? 'Выберите модель' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.settings_ethernet, color: Colors.blueAccent),
                    title: TextFormField(
                      controller: ipController,
                      decoration: const InputDecoration(
                        labelText: 'IP адрес принтера',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
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
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.settings_ethernet, color: Colors.blueAccent),
                    title: TextFormField(
                      controller: portController,
                      decoration: const InputDecoration(
                        labelText: 'Порт принтера',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      validator: (value) => (value == null || value.isEmpty) ? 'Введите порт' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.linear_scale, color: Colors.blueAccent),
                    title: TextFormField(
                      controller: uidController,
                      decoration: InputDecoration(
                        labelText: 'UID линии',
                        border: InputBorder.none,
                        suffixIcon: uidController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.blueAccent),
                                onPressed: () {
                                  uidController.clear();
                                  _validateUidAndUpdateFields();
                                },
                              )
                            : null,
                      ),
                      style: TextStyle(color: textColor),
                      onChanged: (_) => _validateUidAndUpdateFields(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.label, color: Colors.blueAccent),
                    title: TextFormField(
                      controller: rmController,
                      decoration: const InputDecoration(
                        labelText: 'PM линии',
                        border: InputBorder.none,
                      ),
                      style: TextStyle(color: textColor),
                      validator: (value) {
                        if (_isValidUid(uidController.text) && (value == null || value.trim().isEmpty)) {
                          return 'Введите PM линии';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.power_settings_new, color: Colors.blueAccent),
                    title: DropdownButtonFormField<bool>(
                      initialValue: _isWorking,
                      decoration: const InputDecoration(
                        labelText: 'Статус принтера',
                        border: InputBorder.none,
                      ),
                      style: TextStyle(color: textColor),
                      items: [
                        DropdownMenuItem(
                          value: true,
                          child: Text('В работе', style: TextStyle(color: textColor)),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('Не в работе', style: TextStyle(color: textColor)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _isWorking = v ?? false),
                      validator: (value) {
                        final text = uidController.text.trim();
                        final isEmpty = text.isEmpty || text == _zeroUuid;
                        final isValid = _isValidUid(text);
                        if (isEmpty && value == true) {
                          return 'Если UID пуст, статус должен быть "Не в работе"';
                        }
                        if (isValid && value == false) {
                          return 'Для указанного UID статус должен быть "В работе"';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final rawUid = uidController.text.trim();
                    final uid = rawUid.isEmpty ? _zeroUuid : rawUid;

                    final data = {
                      'number': int.parse(numberController.text),
                      'model': _selectedModel!.code,
                      'ip': ipController.text.trim(),
                      'port': portController.text.trim(),
                      'uid': uid,
                      'rm': rmController.text.trim(),
                      'status': _isWorking,
                    };

                    try {
                      if (_isEditMode) {
                        data['id'] = _existingPrinter!.id;
                        await apiService.updatePrinter(data);
                      } else {
                        await apiService.addPrinter(data);
                      }
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ошибка: $e', style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Сохранить', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
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
