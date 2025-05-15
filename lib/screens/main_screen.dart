import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Управление принтерами')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/scan'),
            child: Text('Сканировать QR-коды'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/manual-entry'),
            child: Text('Ручной ввод'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/printers'),
            child: Text('Список принтеров'),
          ),
        ],
      ),
    );
  }
}
