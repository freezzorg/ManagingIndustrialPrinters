import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart' as datawedge;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:mip/services/api_service.dart';
import 'package:mip/models/printer.dart';
import 'package:device_info_plus/device_info_plus.dart';

enum DeviceType { zebra, urovo, unknown }
enum RebindAction { cancel, rebind }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // For camera scanning (unknown devices)
  final MobileScannerController cameraController = MobileScannerController(autoStart: false);

  // For hardware scanning (Zebra/Urovo)
  late StreamSubscription<dynamic> _scanSubscription;
  datawedge.FlutterDataWedge? _dataWedge;
  static const scanChannel = EventChannel('com.symbol.datawedge/scan'); // For Urovo

  String scannedData = 'Готов к сканированию';
  bool isScannerEnabled = false; // For hardware scanner status
  DeviceType _deviceType = DeviceType.unknown;
  dynamic _deviceInfo;
  String deviceInfoText = 'Определение устройства...';

  String? lineData;
  String? printerData;
  bool? isPrinterBound;
  bool processing = false;

  @override
  void initState() {
    super.initState();
    _initDevice();
  }

  Future<void> _initDevice() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      _deviceInfo = await deviceInfoPlugin.androidInfo;

      // Определение типа устройства
      if (_isZebraDevice(_deviceInfo)) {
        _deviceType = DeviceType.zebra;
      } else if (_isUrovoDevice(_deviceInfo)) {
        _deviceType = DeviceType.urovo;
      } else {
        _deviceType = DeviceType.unknown;
      }

      // Формируем текст информации об устройстве
      deviceInfoText = '${_getManufacturerName(_deviceInfo.manufacturer)}: ${_deviceInfo.model ?? "Неизвестно"}';

      await _initScanner();
    } catch (e) {
      setState(() => scannedData = 'Ошибка определения устройства: $e');
    }
  }

  String _getManufacturerName(String? manufacturer) {
    if (manufacturer == null) return "Неизвестно";
    if (manufacturer.toLowerCase().contains('zebra')) return "Zebra";
    if (manufacturer.toLowerCase().contains('urovo')) return "Urovo";
    return manufacturer;
  }

  bool _isZebraDevice(dynamic info) {
    final manufacturer = info.manufacturer?.toString().toLowerCase() ?? '';
    final brand = info.brand?.toString().toLowerCase() ?? '';
    final model = info.model?.toString().toLowerCase() ?? '';
    final product = info.product?.toString().toLowerCase() ?? '';
    final fingerprint = info.fingerprint?.toString().toLowerCase() ?? '';

    return manufacturer.contains('zebra') ||
        brand.contains('zebra') ||
        model.contains('zebra') ||
        model.contains('mc33') ||
        model.contains('tc20') ||
        model.contains('tc25') ||
        product.contains('zebra') ||
        fingerprint.contains('zebra');
  }

  bool _isUrovoDevice(dynamic info) {
    final manufacturer = info.manufacturer?.toString().toLowerCase() ?? '';
    final brand = info.brand?.toString().toLowerCase() ?? '';
    final model = info.model?.toString().toLowerCase() ?? '';
    final product = info.product?.toString().toLowerCase() ?? '';
    final fingerprint = info.fingerprint?.toString().toLowerCase() ?? '';

    return manufacturer.contains('urovo') ||
        brand.contains('urovo') ||
        model.contains('urovo') ||
        model.contains('rt40s') ||
        model.contains('i6310') ||
        model.contains('i9000s') ||
        product.contains('urovo') ||
        fingerprint.contains('urovo');
  }

  Future<void> _initScanner() async {
    try {
      if (_deviceType == DeviceType.zebra) {
        await _initZebraScanner();
      } else if (_deviceType == DeviceType.urovo) {
        await _initUrovoScanner();
      } else {
        // For unknown devices, use camera scanner
        setState(() => scannedData = 'Используется камера для сканирования');
        // No explicit init needed for mobile_scanner beyond controller creation
      }
    } catch (e) {
      setState(() => scannedData = 'Ошибка инициализации сканера: $e');
    }
  }

  Future<void> _initZebraScanner() async {
    _dataWedge = datawedge.FlutterDataWedge();
    await _dataWedge!.initialize();
    await _dataWedge!.createDefaultProfile(profileName: 'UniversalScannerProfile');
    await _dataWedge!.enableScanner(true);
    setState(() => isScannerEnabled = true);

    _scanSubscription = _dataWedge!.onScanResult.listen((datawedge.ScanResult result) {
      _handleScannedData(result.data);
    }, onError: (error) {
      setState(() => scannedData = 'Ошибка Zebra: $error');
    });

    setState(() => scannedData = 'Zebra сканер готов к работе');
  }

  Future<void> _initUrovoScanner() async {
    _scanSubscription = scanChannel.receiveBroadcastStream().listen((event) {
      _handleScannedData(event.toString());
    }, onError: (error) {
      setState(() => scannedData = 'Ошибка Urovo: ${error.toString()}');
    });

    setState(() => isScannerEnabled = true);
    setState(() => scannedData = 'Urovo сканер готов к работе');
  }

  Future<void> _disableScanner() async {
    try {
      if (_deviceType == DeviceType.zebra && _dataWedge != null) {
        await _dataWedge!.enableScanner(false);
      }
      setState(() => isScannerEnabled = false);
    } catch (e) {
      debugPrint('Ошибка отключения сканера: $e');
    }
  }

  void _handleScannedData(String code) {
    if (code.isEmpty || processing) return;

    setState(() {
      if (printerData == null || (printerData != null && isPrinterBound == false)) {
        // Scanning for printer
        try {
          final printerInfo = _parsePrinterInfo(code);
          printerData = code;
          isPrinterBound = printerInfo.status;
          lineData = null;
          scannedData = 'Принтер отсканирован: ${printerInfo.number}';
        } catch (e) {
          _showMessage("Неверный QR-код принтера");
          scannedData = 'Ошибка сканирования принтера';
        }
      } else if (printerData != null && isPrinterBound == true && lineData == null) {
        // Scanning for line
        lineData = code;
        scannedData = 'Линия отсканирована: ${_parseLineName(code)}';
      }
    });
    // For camera scanner, stop after a scan
    if (_deviceType == DeviceType.unknown) {
      cameraController.stop();
    }
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    _disableScanner();
    cameraController.dispose();
    super.dispose();
  }

  void _startCameraScan() {
    if (_deviceType != DeviceType.unknown) return; // Only for camera devices
    setState(() {
      scannedData = 'Сканирование камерой...';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cameraController.start();
    });
  }

  void _onCameraDetect(BarcodeCapture capture) {
    if (processing) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null) continue;
      _handleScannedData(code);
      break;
    }
  }

  Widget _getScanButtonChild() {
    if (printerData == null) {
      return const Text('Сканировать принтер');
    } else if (printerData != null && isPrinterBound == true && lineData == null) {
      return const Text('Сканировать линию');
    }
    return const Text('Сканировать');
  }

  String _parseLineName(String qr) {
    final parts = qr.split(',');
    return parts.isNotEmpty ? parts[0].trim() : '';
  }

  String _parseLineUid(String qr) {
    final parts = qr.length > 1 ? qr.split(',') : ['', ''];
    return parts.length > 1 ? parts[1].trim() : '';
  }

  String _parseLineOpType(String qr) {
    final parts = qr.length > 2 ? qr.split(',') : ['', '', ''];
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
      processing = false;
      scannedData = 'Готов к сканированию';
    });
    if (_deviceType == DeviceType.unknown) {
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
        // title: Text('Сканер ${_deviceType.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          // No toggle button for scanner mode, as it's determined by device type
          if (_deviceType == DeviceType.unknown)
            IconButton(
              icon: const Icon(Icons.flash_on, color: Colors.white),
              onPressed: () => cameraController.toggleTorch(),
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
        child: Stack(
          children: [
            Column(
              children: [
                if (_deviceType == DeviceType.unknown)
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: (scannedData == 'Сканирование камерой...')
                            ? MobileScanner(
                                controller: cameraController,
                                onDetect: _onCameraDetect,
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
                                      style: TextStyle(color: Colors.white70, fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                Expanded(
                  flex: _deviceType == DeviceType.unknown ? 2 : 1,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: const Icon(Icons.print, color: Colors.blueAccent),
                              title: Text(
                                'Принтер: ${_getDisplayPrinterNumber(printerData)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: const Icon(Icons.linear_scale, color: Colors.blueAccent),
                              title: Text(
                                'Линия: ${_getDisplayLineName(lineData)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_deviceType == DeviceType.unknown)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: _getScanButtonChild(),
                                    onPressed: _startCameraScan,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (_deviceType == DeviceType.unknown) const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _getActionButtonOnPressed(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _getActionButtonColor(),
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _getActionButtonChild(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _reset(),
                            child: const Text(
                              'Сброс',
                              style: TextStyle(color: Colors.blueAccent, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
