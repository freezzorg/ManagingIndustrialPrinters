import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:mip/services/api_service.dart';
import 'package:mip/models/printer.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  String? lineData;
  String? printerData;
  bool processing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканирование'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                if (processing) return;
                for (final barcode in capture.barcodes) {
                  final code = barcode.rawValue;
                  if (code == null) continue;

                  setState(() {
                    if (lineData == null) {
                      lineData = code;
                    } else if (printerData == null) {
                      printerData = code;
                      cameraController.stop();
                    }
                  });
                  break;
                }
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('Линия: ${lineData ?? "не отсканировано"}'),
                  Text('Принтер: ${printerData ?? "не отсканировано"}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed:
                        (lineData != null && printerData != null && !processing)
                            ? _bindPrinter
                            : null,
                    child: processing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Привязать'),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Сброс'),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      lineData = null;
      printerData = null;
      processing = false;
    });
    cameraController.start();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _bindPrinter() async {
    setState(() => processing = true);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final lineUid = _parseLineUid(lineData!);
      final lineRm = _parseLineRm(lineData!);
      final printerInfo = _parsePrinterInfo(printerData!);

      final printerFromServer =
          await api.getPrinterByIdOrUid(id: printerInfo.number);

      if (printerFromServer != null &&
          (printerFromServer.statusCode == 1 ||
              printerFromServer.statusCode == 2)) {
        final action = await _showRebindDialog(printerFromServer.rm);
        if (action == RebindAction.cancel) {
          _reset();
          return;
        }
      }

      await api.updatePrinter({
        'id': printerInfo.id,
        'number': printerInfo.number,
        'modelCode': printerInfo.modelCode,
        'ip': printerInfo.ip,
        'port': printerInfo.port,
        'uid': lineUid,
        'rm': lineRm,
        'statusCode': printerInfo.statusCode,
      });

      _showMessage('Принтер успешно привязан');
      _reset();
    } catch (e) {
      _showMessage('Ошибка: $e');
      _reset();
    } finally {
      setState(() => processing = false);
    }
  }

  Future<RebindAction> _showRebindDialog(String currentRm) async {
    return showDialog<RebindAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Принтер уже привязан'),
          content:
              Text('Принтер уже привязан к линии $currentRm. Перепривязать?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(RebindAction.cancel),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(RebindAction.rebind),
              child: const Text('Перепривязать'),
            ),
          ],
        );
      },
    ).then((value) => value ?? RebindAction.cancel);
  }

  String _parseLineUid(String qr) {
    return qr.split(',').first.trim();
  }

  String _parseLineRm(String qr) {
    final parts = qr.split(',');
    return parts.length > 1 ? parts[1].trim() : '';
  }

  Printer _parsePrinterInfo(String qr) {
    final parts = qr.split(',');
    return Printer(
      id: 0,
      number: int.parse(parts[0].trim()),
      modelCode: int.parse(parts[1].trim()),
      ip: parts[2].trim(),
      port: parts[3].trim(),
      statusCode: int.parse(parts[4].trim()),
      uid: '',
      rm: '',
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

enum RebindAction { cancel, rebind }
