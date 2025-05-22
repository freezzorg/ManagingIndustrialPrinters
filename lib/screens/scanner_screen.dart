import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mip/services/api_service.dart';
import 'package:mip/models/printer.dart';
import 'package:flutter/services.dart';

enum RebindAction { cancel, rebind }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController cameraController =
      MobileScannerController(autoStart: false);

  String? lineData;
  String? printerData;
  bool isScanningLine = false;
  bool isScanningPrinter = false;
  bool processing = false;
  bool useCameraScan = false;
  bool hasHardwareScanner = false;

  final TextEditingController _keyboardScanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _detectScanner();
    _keyboardScanController.addListener(_handleKeyboardScan);
  }

  Future<void> _detectScanner() async {
    final deviceModel = await _getDeviceModel();
    setState(() {
      hasHardwareScanner = deviceModel.toLowerCase().contains("zebra") ||
          deviceModel.toLowerCase().contains("urovo") ||
          deviceModel.toLowerCase().contains("rt40");
      useCameraScan = !hasHardwareScanner;
    });
  }

  Future<String> _getDeviceModel() async {
    const MethodChannel deviceInfoChannel = MethodChannel('device_info');
    try {
      final result = await deviceInfoChannel.invokeMethod<String>('getModel');
      return result ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    _keyboardScanController.removeListener(_handleKeyboardScan);
    _keyboardScanController.dispose();
    super.dispose();
  }

  void _startScanLine() {
    setState(() {
      lineData = null;
      isScanningLine = true;
      isScanningPrinter = false;
    });

    if (useCameraScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        cameraController.start();
      });
    }
  }

  void _startScanPrinter() {
    setState(() {
      isScanningPrinter = true;
      isScanningLine = false;
    });

    if (useCameraScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        cameraController.start();
      });
    }
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

  void _handleKeyboardScan() {
    final scanned = _keyboardScanController.text.trim();
    if (scanned.isEmpty || !(isScanningLine || isScanningPrinter)) return;

    setState(() {
      if (isScanningLine) {
        lineData = scanned;
        isScanningLine = false;
      } else if (isScanningPrinter) {
        printerData = scanned;
        isScanningPrinter = false;
      }
    });

    _keyboardScanController.clear();
  }

  String _parseLineUid(String qr) =>
      qr.split(',').length > 1 ? qr.split(',')[1].trim() : '';

  String _buildRm(String qr) {
    final parts = qr.split(',');
    final name = parts.isNotEmpty ? parts[0].trim() : '';
    final op = parts.length > 2 ? parts[2].trim() : '';
    return '$name. $op';
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
        if (action == RebindAction.cancel) return _reset();
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
    } catch (e) {
      _showMessage('Ошибка: $e');
    } finally {
      _reset();
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
    } catch (e) {
      _showMessage('Ошибка: $e');
    } finally {
      _reset();
    }
  }

  Future<RebindAction> _showRebindDialog(String currentRm) async {
    return (await showDialog<RebindAction>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Принтер уже привязан'),
            content:
                Text('Принтер уже привязан к линии $currentRm. Перепривязать?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, RebindAction.cancel),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, RebindAction.rebind),
                child: const Text('Перепривязать'),
              ),
            ],
          ),
        )) ??
        RebindAction.cancel;
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
    _keyboardScanController.clear();
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
          if (useCameraScan)
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => cameraController.toggleTorch(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: useCameraScan
                  ? (isScanningLine || isScanningPrinter
                      ? MobileScanner(
                          controller: cameraController,
                          onDetect: _onDetect,
                        )
                      : const Center(
                          child: Text(
                            'Нажмите кнопку, чтобы начать сканирование',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ))
                  : TextField(
                      controller: _keyboardScanController,
                      autofocus: true,
                      readOnly: true,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      decoration: const InputDecoration(
                        hintText: 'Ожидание сканирования...',
                        contentPadding: EdgeInsets.all(16),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 0),
                    ),
            ),
            Expanded(
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
                      onPressed: (lineData != null &&
                              printerData != null &&
                              !processing)
                          ? _bindPrinter
                          : null,
                      child: processing
                          ? const CircularProgressIndicator()
                          : const Text('Привязать'),
                    ),
                    ElevatedButton(
                      onPressed: (printerData != null && !processing)
                          ? _unbindPrinter
                          : null,
                      child: processing
                          ? const CircularProgressIndicator()
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
      ),
    );
  }
}
