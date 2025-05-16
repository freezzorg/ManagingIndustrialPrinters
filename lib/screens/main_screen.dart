import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mip/providers/theme_provider.dart';
import 'package:mip/services/api_service.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final apiService = Provider.of<ApiService>(context);

    final baseUrlController = TextEditingController(text: apiService.baseUrl);

    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      textStyle: const TextStyle(fontSize: 18),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Управление принтерами'),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.indigo,
                ),
                child: Text(
                  'Настройки',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Тёмная тема'),
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme(value);
                },
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL API',
                    border: OutlineInputBorder(),
                    hintText: 'http://10.10.8.21:21010',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: () {
                    final newUrl = baseUrlController.text.trim();
                    if (newUrl.isNotEmpty) {
                      apiService.updateBaseUrl(newUrl);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Base URL сохранён')),
                      );
                      Navigator.of(context).pop(); // Закрыть Drawer
                    }
                  },
                  child: const Text('Сохранить Base URL'),
                ),
              ),
            ],
          ),
        ),
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
