import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:mip/services/api_service.dart';
import 'package:mip/models/printer.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  bool? isPrinterBound;
  bool isScanningLine = false;
  bool isScanningPrinter = false;
  bool processing = false;
  bool hasHardwareScanner = false;
  bool isHardwareScannerMode = false;

  final FocusNode _scanFocusNode = FocusNode();
  final TextEditingController _scanController = TextEditingController();
  String _lastScannedData = '';

  @override
  void initState() {
    super.initState();
    _detectDeviceType();
    _scanController.addListener(_handleHardwareScan);
  }

  Future<void> _detectDeviceType() async {
    if (!Platform.isAndroid) return;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final manufacturer = deviceInfo.manufacturer.toLowerCase();
    final model = deviceInfo.model.toLowerCase();

    // Список производителей ТСД
    final tsdManufacturers = [
      'zebra technologies',
      'motorola solutions',
      'honeywell',
      'datalogic',
      'cipherlab',
      'keyence',
      'unitech'
    ];
    bool isTsd = tsdManufacturers.contains(manufacturer);

    if (manufacturer == 'motorola solutions') {
      isTsd = model.startsWith('mc');
    }

    setState(() {
      hasHardwareScanner = isTsd;
      isHardwareScannerMode = isTsd;
      if (isHardwareScannerMode) {
        Future.microtask(() => _scanFocusNode.requestFocus());
      }
    });
  }

  void _toggleScannerMode() {
    setState(() {
      isHardwareScannerMode = !isHardwareScannerMode;
    });
    _reset();
    if (isHardwareScannerMode) {
      Future.microtask(() => _scanFocusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    _scanController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  void _handleHardwareScan() {
    if (!isHardwareScannerMode) return;
    final scannedData = _scanController.text;
    if (scannedData.isEmpty || scannedData == _lastScannedData) return;
    _lastScannedData = scannedData;
    print("Отсканировано: $scannedData");
    if (scannedData.contains(',')) {
      try {
        if (_isPrinterQrCode(scannedData)) {
          final printerInfo = _parsePrinterInfo(scannedData);
          setState(() {
            printerData = scannedData;
            isPrinterBound = printerInfo.status;
            lineData = null;
          });
        } else if (printerData != null && isPrinterBound == true) {
          setState(() {
            lineData = scannedData;
          });
        }
        Future.delayed(const Duration(milliseconds: 500), () {
          _scanController.clear();
          _scanFocusNode.requestFocus();
        });
      } catch (e) {
        _showMessage("Ошибка при обработке данных: $e");
        _scanController.clear();
      }
    }
  }

  bool _isPrinterQrCode(String qrData) {
    final parts = qrData.split(',');
    if (parts.length < 5) return false;
    try {
      int.parse(parts[0].trim());
      return parts[2].trim().contains('.');
    } catch (e) {
      return false;
    }
  }

  void _startScanLine() {
    if (isHardwareScannerMode || printerData == null || isPrinterBound == false) {
      return;
    }
    setState(() {
      isScanningLine = true;
      isScanningPrinter = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cameraController.start();
    });
  }

  void _startScanPrinter() {
    if (isHardwareScannerMode) return;
    setState(() {
      isScanningLine = false;
      isScanningPrinter = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cameraController.start();
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (!(isScanningLine || isScanningPrinter) || processing) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null) continue;
      setState(() {
        if (isScanningLine && printerData != null && isPrinterBound == true) {
          lineData = code;
          isScanningLine = false;
        } else if (isScanningPrinter) {
          try {
            final printerInfo = _parsePrinterInfo(code);
            printerData = code;
            isPrinterBound = printerInfo.status;
            lineData = null;
          } catch (e) {
            _showMessage("Неверный QR-код принтера");
          }
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

  String _buildRm(String qr) {
    final name = _parseLineName(qr);
    final opType = _parseLineOpType(qr);
    return '$name. $opType';
  }

  String _getDisplayLineName(String? data) {
    if (data == null) return "не отсканировано";
    final name = _parseLineName(data);
    return name;
  }

  String _getDisplayPrinterNumber(String? data) {
    if (data == null) return "не отсканировано";
    try {
      final parts = data.split(',');
      if (parts.isEmpty) return "неверный формат";
      final number = int.parse(parts[0].trim());
      return "№${number.toString().padLeft(2, '0')}";
    } catch (e) {
      return "ошибка формата";
    }
  }

  Printer _parsePrinterInfo(String qr) {
    final parts = qr.split(',');
    final isWorking = int.parse(parts[4].trim()) == 1;
    return Printer(
      id: 0,
      number: int.parse(parts[0].trim()),
      model: int.parse(parts[1].trim()),
      ip: parts[2].trim(),
      port: parts[3].trim(),
      status: isWorking,
      uid: '',
      rm: '',
    );
  }

  Future<RebindAction> _showRebindDialog(String currentRm) async {
    return showDialog<RebindAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Принтер уже привязан'),
        content: Text('Принтер уже привязан к линии $currentRm. Перепривязать?'),
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
      final serverPrinter = await api.getPrinterByIdOrUid(id: printerInfo.number);
      if (serverPrinter == null) {
        throw Exception('Принтер не найден на сервере');
      }
      if (serverPrinter.status && serverPrinter.rm.isNotEmpty) {
        final action = await _showRebindDialog(serverPrinter.rm);
        if (action == RebindAction.cancel) {
          _reset();
          return;
        }
      }
      final payload = {
        'id': serverPrinter.id,
        'number': printerInfo.number,
        'model': printerInfo.model,
        'ip': printerInfo.ip,
        'port': printerInfo.port,
        'uid': lineUid,
        'rm': lineRm,
        'status': true,
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
      final serverPrinter = await api.getPrinterByIdOrUid(id: printerInfo.number);
      if (serverPrinter == null) {
        throw Exception('Принтер не найден на сервере');
      }
      final payload = {
        'id': serverPrinter.id,
        'number': printerInfo.number,
        'model': printerInfo.model,
        'ip': printerInfo.ip,
        'port': printerInfo.port,
        'uid': '00000000-0000-0000-0000-000000000000',
        'rm': '',
        'status': false,
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
      isPrinterBound = null;
      isScanningLine = false;
      isScanningPrinter = false;
      processing = false;
      _scanController.clear();
      _lastScannedData = '';
      if (isHardwareScannerMode) {
        Future.microtask(() => _scanFocusNode.requestFocus());
      }
    });
    if (!isHardwareScannerMode) {
      cameraController.stop();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void Function()? _getActionButtonOnPressed() {
    if (processing) return null;
    if (printerData != null && isPrinterBound == false) {
      return _unbindPrinter;
    } else if (printerData != null && isPrinterBound == true && lineData != null) {
      return _bindPrinter;
    }
    return null;
  }

  Widget _getActionButtonChild() {
    if (processing) {
      return const CircularProgressIndicator(color: Colors.white);
    } else if (printerData != null && isPrinterBound == false) {
      return const Text('Отвязать');
    } else if (printerData != null && isPrinterBound == true && lineData != null) {
      return const Text('Привязать');
    }
    return const Text('Действие недоступно');
  }

  Color? _getActionButtonColor() {
    if (processing) {
      return Colors.grey;
    } else if (printerData != null && isPrinterBound == false) {
      return Colors.red; // Для "Отвязать"
    } else if (printerData != null && isPrinterBound == true && lineData != null) {
      return Colors.green; // Для "Привязать"
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканирование'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          IconButton(
            icon: Icon(isHardwareScannerMode ? Icons.qr_code_scanner
                : Icons.camera_alt),
            onPressed: _toggleScannerMode,
            tooltip: isHardwareScannerMode ? 'Переключиться на камеру'
                : 'Переключиться на аппаратный сканер',
          ),
          if (!isHardwareScannerMode)
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
            child: Container(
              color: Colors.black54,
              child: isHardwareScannerMode
                  ? Stack(
                      children: [
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.qr_code_scanner,
                                size: 80,
                                color: Colors.white70,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Используйте аппаратный сканер для считывания QR-кодов',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: -1000,
                          child: TextField(
                            controller: _scanController,
                            focusNode: _scanFocusNode,
                            autofocus: true,
                            keyboardType: TextInputType.none,
                            decoration: const InputDecoration(
                              hintText: 'Сканирование',
                            ),
                          ),
                        ),
                      ],
                    )
                  : (isScanningLine || isScanningPrinter)
                      ? MobileScanner(
                          controller: cameraController,
                          onDetect: _onDetect,
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 80,
                                color: Colors.white70,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Нажмите кнопку ниже, чтобы начать сканирование',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 30,
                    alignment: Alignment.center,
                    child: Text(
                      'Принтер: ${_getDisplayPrinterNumber(printerData)}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  Container(
                    height: 30,
                    alignment: Alignment.center,
                    child: Text(
                      'Линия: ${_getDisplayLineName(lineData)}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isHardwareScannerMode) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.print),
                            label: const Text('Сканировать принтер'),
                            onPressed: _startScanPrinter,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.linear_scale),
                            label: const Text('Сканировать линию'),
                            onPressed: _startScanLine,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _getActionButtonOnPressed(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getActionButtonColor(),
                          ),
                          child: _getActionButtonChild(),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _reset(),
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
}
