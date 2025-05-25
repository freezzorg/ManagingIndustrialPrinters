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
  bool isScanningLine = false;
  bool isScanningPrinter = false;
  bool processing = false;
  bool hasHardwareScanner = false; // результат автоопределения
  bool isHardwareScannerMode =
      false; // режим работы (может быть изменен пользователем)

  // Для обработки аппаратного сканера
  final FocusNode _scanFocusNode = FocusNode();
  final TextEditingController _scanController = TextEditingController();
  String _lastScannedData = '';

  @override
  void initState() {
    super.initState();
    _detectDeviceType();
    
    // Настраиваем слушателя для аппаратного сканера
    _scanController.addListener(_handleHardwareScan);
  }

  // Автоопределение типа устройства
  Future<void> _detectDeviceType() async {
    if (!Platform.isAndroid) return;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final model = deviceInfo.model.toLowerCase();

    final isHardware = model.contains('zebra') || model.contains('urovo');
    
    setState(() {
      hasHardwareScanner = isHardware;
      isHardwareScannerMode =
          isHardware; // Изначально используем результат автоопределения

      // Если определили аппаратный сканер, устанавливаем фокус
      if (isHardwareScannerMode) {
        Future.microtask(() => _scanFocusNode.requestFocus());
      }
    });
  }

  // Переключение режима сканера
  void _toggleScannerMode() {
    setState(() {
      isHardwareScannerMode = !isHardwareScannerMode;
    });

    // Сбрасываем состояние
    _reset();

    // Если переключились на аппаратный сканер, устанавливаем фокус
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

  // Обработчик для данных от аппаратного сканера
  void _handleHardwareScan() {
    if (!isHardwareScannerMode) return;

    final scannedData = _scanController.text;
    if (scannedData.isEmpty || scannedData == _lastScannedData) return;

    _lastScannedData = scannedData;
    print("Отсканировано: $scannedData");

    if (scannedData.contains(',')) {
      // Определяем тип отсканированных данных по формату
      try {
        if (_isPrinterQrCode(scannedData)) {
          setState(() {
            printerData = scannedData;
          });
          _showMessage("Принтер отсканирован");
        } else {
          setState(() {
            lineData = scannedData;
          });
          _showMessage("Линия отсканирована");
        }

        // Очищаем поле и возвращаем фокус для следующего сканирования
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

  // Определяет, является ли QR-код кодом принтера
  bool _isPrinterQrCode(String qrData) {
    final parts = qrData.split(',');
    if (parts.length < 5) return false;

    try {
      // Проверяем, можно ли первую часть преобразовать в число (номер принтера)
      int.parse(parts[0].trim());
      // Проверяем, есть ли IP-адрес в третьей части
      return parts[2].trim().contains('.');
    } catch (e) {
      return false;
    }
  }

  void _startScanLine() {
    if (isHardwareScannerMode) return;
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

  String _buildRm(String qr) {
    final name = _parseLineName(qr);
    final opType = _parseLineOpType(qr);
    return '$name. $opType';
  }

  // Функция для отображения имени линии в формате PM01
  String _getDisplayLineName(String? data) {
    if (data == null) return "не отсканировано";
    final name = _parseLineName(data);
    return name; // Уже в формате PM01
  }

  // Функция для отображения номера принтера в формате №01
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
      
      // Сброс поля ввода для аппаратного сканера
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканирование'),
        actions: [
          // Переключатель режима сканера
          IconButton(
            icon: Icon(isHardwareScannerMode
                ? Icons.qr_code_scanner
                : Icons.camera_alt),
            onPressed: _toggleScannerMode,
            tooltip: isHardwareScannerMode
                ? 'Переключиться на камеру'
                : 'Переключиться на аппаратный сканер',
          ),
          // Кнопка вспышки для камеры
          if (!isHardwareScannerMode)
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => cameraController.toggleTorch(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Верхняя часть экрана - камера или информация
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
                        // Скрытое поле для приема данных от аппаратного сканера
                        Positioned(
                          left: -1000, // Размещаем вне видимой области
                          child: TextField(
                            controller: _scanController,
                            focusNode: _scanFocusNode,
                            autofocus: true,
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

          // Нижняя часть экрана - информация и кнопки
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Статус сканирования
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

                  // Кнопки для камерного сканирования
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

                  // Кнопки действий
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (lineData != null &&
                                  printerData != null &&
                                  !processing)
                              ? _bindPrinter
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: processing &&
                                  lineData != null &&
                                  printerData != null
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Привязать'),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (printerData != null && !processing)
                              ? _unbindPrinter
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: processing &&
                                  printerData != null &&
                                  lineData == null
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Отвязать'),
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
