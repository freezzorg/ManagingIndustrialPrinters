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
    _futurePrinters = api.getPrinters().catchError((e) {
      throw e;
    });
  }

  Future<void> _refreshPrinters() async {
    setState(() {
      _loadPrinters();
    });
  }

  Future<void> _navigateToAddPrinter() async {
    final result = await Navigator.pushNamed(
      context,
      '/manual-entry',
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
    final messenger = ScaffoldMessenger.of(context);
    final api = Provider.of<ApiService>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить принтер'),
        content: Text('Вы уверены, что хотите удалить принтер с ID ${printer.id}?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.blueAccent)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await api.deletePrinter(printer.id);
      _refreshPrinters();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка удаления: ${e.toString()}')),
      );
    }
  }

  void _onPrinterLongPress(Printer printer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blueAccent),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(context);
                _navigateToEditPrinter(printer);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список принтеров', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        actions: [
          FutureBuilder<List<Printer>>(
            future: _futurePrinters,
            builder: (context, snapshot) {
              return IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'Добавить принтер',
                onPressed: () => _navigateToAddPrinter(),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueGrey, Colors.white],
          ),
        ),
        child: FutureBuilder<List<Printer>>(
          future: _futurePrinters,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
            } else if (snapshot.hasError) {
              return SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          'Ошибка загрузки принтеров: ${snapshot.error}',
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshPrinters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Попробовать снова'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'Нет данных о принтерах',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
              );
            }

            final printers = snapshot.data!;

            return RefreshIndicator(
              onRefresh: _refreshPrinters,
              color: Colors.blueAccent,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: printers.length,
                itemBuilder: (context, index) {
                  final p = printers[index];
                  return GestureDetector(
                    onLongPress: () => _onPrinterLongPress(p),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.print, color: Colors.blueAccent), // Иконка для модели
                                const SizedBox(width: 8),
                                Text(
                                  p.modelEnum.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.blueAccent), // Иконка для адреса
                                const SizedBox(width: 8),
                                Text(
                                  '${p.ip}:${p.port}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (p.rm.trim().isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.linear_scale, size: 16, color: Colors.blueAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p.rm,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            if (p.rm.trim().isNotEmpty) const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  p.status ? Icons.check_circle_outline : Icons.cancel_outlined, // Иконка для статуса
                                  size: 16,
                                  color: p.status ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  p.statusText,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
