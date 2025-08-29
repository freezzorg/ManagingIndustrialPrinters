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
  StreamSubscription<dynamic>? _scanSubscription;
  datawedge.FlutterDataWedge? _dataWedge;
  static const scanChannel = EventChannel('com.symbol.datawedge/scan'); // For Urovo

  String scannedData = 'Готов к сканированию';
  bool isScannerEnabled = false; // For hardware scanner status
  DeviceType _deviceType = DeviceType.unknown;
  dynamic _deviceInfo;
  String deviceInfoText = 'Определение устройства...';
  bool _useCameraScanner = false; // New state variable for camera/hardware scanner toggle

  String? lineData;
  String? printerData;
  bool? isPrinterBound;
  bool processing = false;
  int? _lineNumber; // Для хранения номера линии

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
        _useCameraScanner = false;
        await _initZebraScanner();
      } else if (_deviceType == DeviceType.urovo) {
        _useCameraScanner = false; // Default to hardware scanner for Urovo
        await _initUrovoScanner();
      } else {
        _useCameraScanner = true; // Default to camera for unknown devices
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
      } else if (_deviceType == DeviceType.urovo) {
        // For Urovo, we just cancel the subscription to stop listening
        // There's no explicit 'disable' method like Zebra's DataWedge
        _scanSubscription?.cancel();
      }
      setState(() => isScannerEnabled = false);
    } catch (e) {
      debugPrint('Ошибка отключения сканера: $e');
    }
  }

  void _handleScannedData(String code) {
    if (code.isEmpty || processing) return;

    setState(() {
      if (printerData == null) {
        // Scanning for printer (initial state)
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
      } else if (printerData != null && isPrinterBound == false) {
        // Printer scanned for unbinding, no further scan expected here.
        // This state should lead to unbind action, not another scan.
        _showMessage("Принтер готов к отвязке. Нажмите кнопку 'Отвязать'.");
      } else if (printerData != null && isPrinterBound == true && lineData == null) {
        // Printer scanned for binding, now expecting line QR code
        try {
          // Attempt to parse as a printer QR code to detect incorrect scan
          _parsePrinterInfo(code);
          _showMessage("Неверный QR-код линии. Отсканируйте QR-код линии.");
          // Do not update state, remain in "waiting for line" state
        } catch (e) {
          // If it's not a printer QR code, assume it's a line QR code
          if (_isValidLineQr(code)) {
            lineData = code;
            _lineNumber = _parseLineNumber(code); // Сохраняем номер линии
            scannedData = 'Линия отсканирована: ${_parseLineName(code)}';
          } else {
            _showMessage("Неверный QR-код линии. Отсканируйте QR-код линии.");
            // Do not update state, remain in "waiting for line" state
          }
        }
      }
    });
    // For camera scanner, stop after a scan
    if (_useCameraScanner) {
      cameraController.stop();
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _disableScanner();
    cameraController.dispose();
    super.dispose();
  }

  void _startCameraScan() {
    if (!_useCameraScanner) return; // Only if camera is selected
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

  int _parseLineNumber(String qr) {
    final parts = qr.split(',');
    if (parts.isEmpty) throw const FormatException('Неверный формат QR-кода линии');
    final pmPart = parts[0].trim();
    if (!pmPart.startsWith('PM') || pmPart.length != 4) {
      throw const FormatException('Неверный формат номера линии в QR-коде');
    }
    return int.parse(pmPart.substring(2));
  }

  bool _isValidLineQr(String qr) {
    final parts = qr.split(',');
    if (parts.length < 3) return false; // Должно быть как минимум 3 части

    final pmPart = parts[0].trim();
    if (!pmPart.startsWith('PM') || pmPart.length != 4 || !RegExp(r'PM\d{2}').hasMatch(pmPart)) {
      return false; // Не соответствует формату PMXX
    }

    final uidPart = parts[1].trim();
    // Простая проверка на UID (можно улучшить с помощью RegExp для UUID)
    if (uidPart.length != 36 || !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(uidPart)) {
      return false; // Не соответствует формату UID
    }

    return true;
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
    if (parts.length < 3) {
      throw const FormatException('Неверный формат QR-кода принтера. Ожидается 3 части.');
    }
    final number = int.parse(parts[0].trim());
    final modelCode = int.parse(parts[1].trim());
    final status = int.parse(parts[2].trim()) == 1;

    // IP и порт будут определены позже, после сканирования линии
    return Printer(
      id: 0,
      number: number,
      model: modelCode,
      ip: '', // Будет заполнено после сканирования линии
      port: '', // Будет заполнено после сканирования линии
      status: status,
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
      final ipAddress = '10.1.${_lineNumber!}.7';
      final port = PrinterModelExtension.fromCode(printerInfo.model).port;

      final payload = {
        'id': serverPrinter.id,
        'number': printerInfo.number,
        'model': printerInfo.model,
        'ip': ipAddress,
        'port': port,
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
        'ip': '', // Сбрасываем IP при отвязке
        'port': '', // Сбрасываем порт при отвязке
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

  Widget _getMainButtonChild() {
    if (processing) {
      return const CircularProgressIndicator(color: Colors.white);
    } else if (printerData == null) {
      return const Text('Сканировать принтер');
    } else if (printerData != null && isPrinterBound == false) {
      return const Text('Отвязать');
    } else if (printerData != null && isPrinterBound == true && lineData == null) {
      return const Text('Сканировать линию');
    } else if (printerData != null && isPrinterBound == true && lineData != null) {
      return const Text('Привязать');
    }
    return const Text('Действие'); // Fallback, should not be reached
  }

  void Function()? _getMainButtonOnPressed() {
    if (processing) return null;
    if (printerData == null) {
      return _useCameraScanner ? _startCameraScan : null; // Hardware scanner auto-scans
    } else if (printerData != null && isPrinterBound == false) {
      return _unbindPrinter;
    } else if (printerData != null && isPrinterBound == true && lineData == null) {
      return _useCameraScanner ? _startCameraScan : null; // Hardware scanner auto-scans
    } else if (printerData != null && isPrinterBound == true && lineData != null) {
      return _bindPrinter;
    }
    return null;
  }

  Color? _getMainButtonColor() {
    if (processing) {
      return Colors.grey;
    } else if (printerData != null && isPrinterBound == false) {
      return Colors.red; // Для "Отвязать"
    } else if (printerData != null && isPrinterBound == true && lineData != null) {
      return Colors.green; // Для "Привязать"
    }
    return Colors.blueAccent; // Для "Сканировать принтер" и "Сканировать линию"
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Привязка/Отвязка принтера', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          if (_deviceType == DeviceType.urovo)
            IconButton(
              icon: Icon(
                _useCameraScanner ? Icons.qr_code_scanner : Icons.camera_alt,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _useCameraScanner = !_useCameraScanner;
                  if (_useCameraScanner) {
                    _disableScanner(); // Disable hardware scanner
                    scannedData = 'Используется камера для сканирования';
                  } else {
                    _initUrovoScanner(); // Re-initialize Urovo hardware scanner
                    scannedData = 'Urovo сканер готов к работе';
                  }
                });
              },
            ),
          if (_useCameraScanner) // Show torch button only if camera is active
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
                if (_useCameraScanner) // Show camera preview only if camera is active
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
                  flex: _useCameraScanner ? 2 : 1,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          Card(
                            elevation: 4,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
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
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                            child: ListTile(
                              leading: const Icon(Icons.linear_scale, color: Colors.blueAccent),
                              title: Text(
                                'Линия: ${_getDisplayLineName(lineData)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: _getMainButtonChild(),
                                  onPressed: _getMainButtonOnPressed(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _getMainButtonColor(),
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
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
