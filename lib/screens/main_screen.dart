import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      textStyle: const TextStyle(fontSize: 18),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Управление принтерами'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Сканировать QR'),
              style: buttonStyle,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/printers'),
              icon: const Icon(Icons.list),
              label: const Text('Список принтеров'),
              style: buttonStyle,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/manual-entry'),
              icon: const Icon(Icons.add),
              label: const Text('Добавить принтер'),
              style: buttonStyle,
            ),
          ],
        ),
      ),
    );
  }
}
