import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:mip/services/api_service.dart';
import 'package:mip/models/printer.dart';

enum RebindAction { cancel, rebind }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  String? lineData;
  String? printerData;
  bool isScanningLine = false;
  bool isScanningPrinter = false;
  bool processing = false;

  @override
  void initState() {
    super.initState();
    // Отключаем автоматический старт камеры — сканирование по кнопке
    cameraController.stop();
  }

  void _startScanLine() {
    setState(() {
      lineData = null;
      printerData = null;
      isScanningLine = true;
      isScanningPrinter = false;
    });
    cameraController.start();
  }

  void _startScanPrinter() {
    setState(() {
      isScanningLine = false;
      isScanningPrinter = true;
    });
    cameraController.start();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!(isScanningLine || isScanningPrinter) || processing) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null) continue;

      setState(() {
        if (isScanningLine) {
          lineData = code;
          isScanningLine = false;
        } else if (isScanningPrinter) {
          printerData = code;
          isScanningPrinter = false;
        }
      });
      cameraController.stop();
      break;
    }
  }

  String _parseLineName(String qr) {
    final parts = qr.split(',');
    return parts.isNotEmpty ? parts[0].trim() : '';
  }

  String _parseLineUid(String qr) {
    final parts = qr.split(',');
    return parts.length > 1 ? parts[1].trim() : '';
  }

  String _parseLineOpType(String qr) {
    final parts = qr.split(',');
    return parts.length > 2 ? parts[2].trim() : '';
  }

  /// Формирует RM как "название линии. вид операции" (обратите внимание на пробел после точки)
  String _buildRm(String qr) {
    final name = _parseLineName(qr);
    final opType = _parseLineOpType(qr);
    return '$name. $opType';
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

  Future<RebindAction> _showRebindDialog(String currentRm) async {
    return showDialog<RebindAction>(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
    ).then((value) => value ?? RebindAction.cancel);
  }

  Future<void> _bindPrinter() async {
    setState(() => processing = true);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final lineUid = _parseLineUid(lineData!);
      final lineRm = _buildRm(lineData!);
      final printerInfo = _parsePrinterInfo(printerData!);

      final serverPrinter =
          await api.getPrinterByIdOrUid(id: printerInfo.number);
      if (serverPrinter == null) {
        throw Exception('Принтер не найден на сервере');
      }

      if (serverPrinter.statusCode == PrinterStatus.connected.code ||
          serverPrinter.statusCode == PrinterStatus.inWork.code) {
        final action = await _showRebindDialog(serverPrinter.rm);
        if (action == RebindAction.cancel) {
          _reset();
          return;
        }
      }

      final payload = {
        'id': serverPrinter.id,
        'number': serverPrinter.number,
        'model': serverPrinter.model.code,
        'ip': serverPrinter.ip,
        'port': serverPrinter.port,
        'uid': lineUid,
        'rm': lineRm,
        'status': printerInfo.statusCode,
      };

      await api.updatePrinter(payload);
      _showMessage('Принтер успешно привязан');
      _reset();
    } catch (e) {
      _showMessage('Ошибка: $e');
      _reset();
    } finally {
      setState(() => processing = false);
    }
  }

  Future<void> _unbindPrinter() async {
    setState(() => processing = true);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final printerInfo = _parsePrinterInfo(printerData!);
      final serverPrinter =
          await api.getPrinterByIdOrUid(id: printerInfo.number);
      if (serverPrinter == null) {
        throw Exception('Принтер не найден на сервере');
      }

      final payload = {
        'id': serverPrinter.id,
        'number': serverPrinter.number,
        'model': serverPrinter.model.code,
        'ip': serverPrinter.ip,
        'port': serverPrinter.port,
        'uid': '00000000-0000-0000-0000-000000000000',
        'rm': '',
        'status': PrinterStatus.notWorking.code,
      };

      await api.updatePrinter(payload);
      _showMessage('Принтер успешно отвязан');
      _reset();
    } catch (e) {
      _showMessage('Ошибка: $e');
      _reset();
    } finally {
      setState(() => processing = false);
    }
  }

  void _reset() {
    setState(() {
      lineData = null;
      printerData = null;
      isScanningLine = false;
      isScanningPrinter = false;
      processing = false;
    });
    cameraController.stop();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

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
              onDetect: _onDetect,
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
                    onPressed: _startScanLine,
                    child: const Text('Сканировать линию'),
                  ),
                  ElevatedButton(
                    onPressed: _startScanPrinter,
                    child: const Text('Сканировать принтер'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed:
                        (lineData != null && printerData != null && !processing)
                            ? _bindPrinter
                            : null,
                    child: processing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Привязать'),
                  ),
                  ElevatedButton(
                    onPressed: (printerData != null && !processing)
                        ? _unbindPrinter
                        : null,
                    child: processing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Отвязать'),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Сброс'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
