import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:mip/services/api_service.dart';
import 'package:mip/models/printer.dart';

class ScannerScreen extends StatefulWidget {
  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  String? lineData;
  String? printerData;
  bool isProcessing = false;

  @override
  void reassemble() {
    super.reassemble();
    controller?.pauseCamera();
    controller?.resumeCamera();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;
    controller!.scannedDataStream.listen((scanData) async {
      if (isProcessing) return;

      setState(() => isProcessing = true);

      try {
        final code = scanData.code ?? '';

        if (lineData == null) {
          // Сканировали линию
          setState(() => lineData = code);
        } else if (printerData == null) {
          // Сканировали принтер
          setState(() => printerData = code);

          await _handleBinding();
        }
      } finally {
        setState(() => isProcessing = false);
      }
    });
  }

  Future<void> _handleBinding() async {
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      // декодировать printerData (номер, модель, IP, порт, статус)
      // пример: "1, 1, 192.168.1.1, 9100, 1"
      final parts = printerData!.split(',').map((e) => e.trim()).toList();
      final number = int.parse(parts[0]);
      final model = int.parse(parts[1]);
      final ip = parts[2];
      final port = parts[3];
      final status = int.parse(parts[4]);

      // Получить текущий принтер из базы через API
      final currentPrinter = await api.getPrinterByNumber(number);

      if (currentPrinter.statusCode == 9) {
        // Принтер был "не в работе" — просто обновляем
        await api.updatePrinter(
          number: number,
          model: model,
          ip: ip,
          port: port,
          uid: lineData!,
          rm: _extractRM(lineData!),
          status: status,
        );
        _showMessage('Принтер привязан');
      } else {
        // Принтер уже привязан — спрашиваем пользователя
        _askRebind(currentPrinter, number, model, ip, port, status);
      }
    } catch (e) {
      _showMessage('Ошибка: $e');
    } finally {
      setState(() {
        lineData = null;
        printerData = null;
      });
    }
  }

  String _extractRM(String data) {
    // извлечение RM из QR кода линии
    // Пример: "59809bc5..., PM01, Линия ..." → PM01
    final parts = data.split(',');
    return parts.length >= 2 ? parts[1].trim() : '';
  }

  void _askRebind(Printer current, int number, int model, String ip, String port, int status) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Принтер уже привязан'),
        content: Text('Текущая линия: ${current.rm}. Перепривязать?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final api = Provider.of<ApiService>(context, listen: false);
              await api.updatePrinter(
                number: number,
                model: model,
                ip: ip,
                port: port,
                uid: lineData!,
                rm: _extractRM(lineData!),
                status: status,
              );
              _showMessage('Принтер перепривязан');
            },
            child: Text('Перепривязать'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Сканирование')),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(lineData == null ? 'Ожидание линии...' : 'Линия: $lineData'),
                Text(printerData == null ? 'Ожидание принтера...' : 'Принтер: $printerData'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
