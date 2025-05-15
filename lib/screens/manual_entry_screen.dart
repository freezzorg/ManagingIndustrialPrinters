import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mip/services/api_service.dart';

class ManualEntryScreen extends StatefulWidget {
  @override
  _ManualEntryScreenState createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _numberController = TextEditingController();
  final _modelController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _uidController = TextEditingController();
  final _rmController = TextEditingController();
  int _status = 1; // Подключен по умолчанию

  @override
  void dispose() {
    _numberController.dispose();
    _modelController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _uidController.dispose();
    _rmController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final api = Provider.of<ApiService>(context, listen: false);

    try {
      await api.updatePrinter(
        number: int.parse(_numberController.text),
        model: int.parse(_modelController.text),
        ip: _ipController.text,
        port: _portController.text,
        uid: _uidController.text,
        rm: _rmController.text,
        status: _status,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Принтер обновлён')), 
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ручной ввод принтера')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _numberController,
                decoration: InputDecoration(labelText: 'Номер принтера'),
                keyboardType: TextInputType.number,
                validator: (value) => value == null || value.isEmpty ? 'Введите номер' : null,
              ),
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(labelText: 'Код модели'),
                keyboardType: TextInputType.number,
                validator: (value) => value == null || value.isEmpty ? 'Введите код модели' : null,
              ),
              TextFormField(
                controller: _ipController,
                decoration: InputDecoration(labelText: 'IP-адрес'),
                validator: (value) => value == null || value.isEmpty ? 'Введите IP' : null,
              ),
              TextFormField(
                controller: _portController,
                decoration: InputDecoration(labelText: 'Порт'),
                validator: (value) => value == null || value.isEmpty ? 'Введите порт' : null,
              ),
              TextFormField(
                controller: _uidController,
                decoration: InputDecoration(labelText: 'UID линии'),
              ),
              TextFormField(
                controller: _rmController,
                decoration: InputDecoration(labelText: 'Код RM линии'),
              ),
              DropdownButtonFormField<int>(
                value: _status,
                items: [
                  DropdownMenuItem(value: 1, child: Text('Подключен')),
                  DropdownMenuItem(value: 2, child: Text('В работе')),
                  DropdownMenuItem(value: 9, child: Text('Не в работе')),
                ],
                onChanged: (val) => setState(() => _status = val ?? 1),
                decoration: InputDecoration(labelText: 'Статус'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submit,
                child: Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}