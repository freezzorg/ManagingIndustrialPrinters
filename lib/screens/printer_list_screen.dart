import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mip/services/api_service.dart';
import 'package:mip/models/printer.dart';

class PrinterListScreen extends StatefulWidget {
  const PrinterListScreen({super.key});

  @override
  State<PrinterListScreen> createState() => _PrinterListScreenState();
}

class _PrinterListScreenState extends State<PrinterListScreen> {
  late Future<List<Printer>> _futurePrinters;
  List<Printer> _printers = [];

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  void _loadPrinters() {
    final api = Provider.of<ApiService>(context, listen: false);
    _futurePrinters = api.getPrinters();
    _futurePrinters.then((data) {
      setState(() {
        _printers = data;
      });
    });
  }

  Future<void> _refreshPrinters() async {
    _loadPrinters();
  }

  Future<void> _navigateToAddPrinter() async {
    final maxNumber = _printers.isEmpty
        ? 1
        : _printers.map((p) => p.number).reduce((a, b) => a > b ? a : b) + 1;

    final result = await Navigator.pushNamed(
      context,
      '/manual-entry',
      arguments: maxNumber,
    );

    if (result == true) {
      _refreshPrinters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список принтеров'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Добавить принтер',
            onPressed: _navigateToAddPrinter,
          ),
        ],
      ),
      body: FutureBuilder<List<Printer>>(
        future: _futurePrinters,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет данных о принтерах'));
          }

          final printers = snapshot.data!;
          _printers = printers; // сохранить актуальный список

          return RefreshIndicator(
            onRefresh: _refreshPrinters,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: printers.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final p = printers[index];
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row('№', p.number.toString()),
                        _row('Модель', p.model.name),
                        _row('Статус', p.status.name),
                        _row('Адрес', '${p.ip}:${p.port}'),
                        if (p.rm.trim().isNotEmpty) _row('', p.rm),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
