import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mip/services/api_service.dart';
import 'package:mip/models/printer.dart';

class PrinterListScreen extends StatefulWidget {
  @override
  _PrinterListScreenState createState() => _PrinterListScreenState();
}

class _PrinterListScreenState extends State<PrinterListScreen> {
  late Future<List<Printer>> _futurePrinters;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  void _loadPrinters() {
    final api = Provider.of<ApiService>(context, listen: false);
    _futurePrinters = api.getAllPrinters();
  }

  void _editPrinter(Printer printer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditPrinterDialog(printer: printer),
      ),
    ).then((_) => setState(() => _loadPrinters()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Список принтеров')),
      body: FutureBuilder<List<Printer>>(
        future: _futurePrinters,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Принтеры не найдены'));
          }

          return ListView(
            children: snapshot.data!
                .map((printer) => ListTile(
                      title: Text('№${printer.number} — ${printer.model.name}'),
                      subtitle: Text(
                          '${printer.ip}:${printer.port}  [${printer.status.name}]'),
                      trailing: IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _editPrinter(printer),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _EditPrinterDialog extends StatefulWidget {
  final Printer printer;

  const _EditPrinterDialog({required this.printer});

  @override
  __EditPrinterDialogState createState() => __EditPrinterDialogState();
}

class __EditPrinterDialogState extends State<_EditPrinterDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _numberController;
  late TextEditingController _modelController;
  late TextEditingController _ipController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _numberController =
        TextEditingController(text: widget.printer.number.toString());
    _modelController =
        TextEditingController(text: widget.printer.modelCode.toString());
    _ipController = TextEditingController(text: widget.printer.ip);
    _portController = TextEditingController(text: widget.printer.port);
  }

  @override
  void dispose() {
    _numberController.dispose();
    _modelController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState?.validate() != true) return;

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.updatePrinter(
        number: int.parse(_numberController.text),
        model: int.parse(_modelController.text),
        ip: _ipController.text,
        port: _portController.text,
        uid: widget.printer.uid,
        rm: widget.printer.rm,
        status: widget.printer.statusCode,
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Редактировать принтер'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _numberController,
                decoration: InputDecoration(labelText: 'Номер'),
                keyboardType: TextInputType.number,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Введите номер' : null,
              ),
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(labelText: 'Модель'),
                keyboardType: TextInputType.number,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Введите модель' : null,
              ),
              TextFormField(
                controller: _ipController,
                decoration: InputDecoration(labelText: 'IP'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Введите IP' : null,
              ),
              TextFormField(
                controller: _portController,
                decoration: InputDecoration(labelText: 'Порт'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Введите порт' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text('Сохранить'),
        ),
      ],
    );
  }
}
