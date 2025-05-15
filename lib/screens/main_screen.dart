import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:mip/services/api_service.dart';
import 'package:mip/models/printer.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String? lineData;
  String? printerData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ТСД Принтеры')),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Text(lineData ?? 'Сканируйте линию', style: TextStyle(fontSize: 18)),
          Text(printerData ?? 'Сканируйте принтер', style: TextStyle(fontSize: 18)),
          ElevatedButton(
            onPressed: lineData != null && printerData != null ? _bindPrinter : null,
            child: Text('Привязать'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/printers'),
            child: Text('Список принтеров'),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        if (lineData == null) {
          lineData = scanData.code;
        } else {
          printerData = scanData.code;
        }
      });
    });
  }

  void _bindPrinter() async {
    try {
      await Provider.of<ApiService>(context, listen: false).bindPrinter(
        Printer(
          number: 1,
          model: 'Модель принтера',
          uid: lineData,
          rm: printerData,
          ip: 'ip-адрес принтера',
          port: 'порт принтера',
          status: 'Статус принтера', // добавьте значение для параметра status
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Принтер привязан')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }
}