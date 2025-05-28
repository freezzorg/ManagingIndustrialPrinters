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

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  void _loadPrinters() {
    final api = Provider.of<ApiService>(context, listen: false);
    print("Loading printers..."); // Для отладки
    _futurePrinters = api.getPrinters().catchError((e) {
      print("Error in getPrinters: $e"); // Для отладки
      throw e;
    });
  }

  Future<void> _refreshPrinters() async {
    setState(() {
      _loadPrinters();
    });
  }

  Future<void> _navigateToAddPrinter(List<Printer> currentPrinters) async {
    final nextNumber = _getNextPrinterNumber(currentPrinters);
    final result = await Navigator.pushNamed(
      context,
      '/manual-entry',
      arguments: nextNumber,
    );
    if (result == true) {
      _refreshPrinters();
    }
  }

  Future<void> _navigateToEditPrinter(Printer printer) async {
    final result = await Navigator.pushNamed(
      context,
      '/manual-entry',
      arguments: printer,
    );
    if (result == true) {
      _refreshPrinters();
    }
  }

  Future<void> _confirmDelete(Printer printer) async {
    // Сохраняем мессенджер и прокси ApiService до await
    final messenger = ScaffoldMessenger.of(context);
    final api = Provider.of<ApiService>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить принтер'),
        content:
            Text('Вы уверены, что хотите удалить принтер №${printer.number}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );

    if (!mounted) return; // ← проверка, что State всё ещё в дереве
    if (confirmed == true) {
      try {
        await api.deletePrinter(printer.id);
        _refreshPrinters();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Ошибка удаления: ${e.toString()}')),
        );
      }
    }
  }

  void _onPrinterLongPress(Printer printer) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(context);
                _navigateToEditPrinter(printer);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(printer);
              },
            ),
          ],
        ),
      ),
    );
  }

  int _getNextPrinterNumber(List<Printer> printers) {
    if (printers.isEmpty) return 1;
    final numbers = printers.map((p) => p.number);
    return numbers.reduce((a, b) => a > b ? a : b) + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список принтеров'),
        actions: [
          FutureBuilder<List<Printer>>(
            future: _futurePrinters,
            builder: (context, snapshot) {
              return IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Добавить принтер',
                onPressed: snapshot.hasData
                    ? () => _navigateToAddPrinter(snapshot.data!)
                    : null,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Printer>>(
        future: _futurePrinters,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print("FutureBuilder error: ${snapshot.error}"); // Для отладки
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Ошибка загрузки принтеров: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshPrinters,
                    child: const Text('Попробовать снова'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет данных о принтерах'));
          }

          final printers = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refreshPrinters,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: printers.length,
              itemBuilder: (context, index) {
                final p = printers[index];
                return GestureDetector(
                  onLongPress: () => _onPrinterLongPress(p),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row('№', p.number.toString()),
                          _row('Модель', p.modelEnum.name),
                          _row('Статус', p.statusText),
                          _row('Адрес', '${p.ip}:${p.port}'),
                          if (p.rm.trim().isNotEmpty) _row('', p.rm),
                        ],
                      ),
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
