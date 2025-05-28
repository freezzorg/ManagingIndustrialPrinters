import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import 'printer_list_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final apiService = Provider.of<ApiService>(context);
    final TextEditingController baseUrlController =
        TextEditingController(text: apiService.baseUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Переключатель тем
            SwitchListTile(
              title: const Text('Тёмная тема'),
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.toggleTheme(value),
            ),
            // Поле для редактирования baseUrl
            TextField(
              controller: baseUrlController,
              decoration: const InputDecoration(labelText: 'Base URL'),
              onSubmitted: (value) => apiService.updateBaseUrl(value),
            ),
            const SizedBox(height: 20),
            // Кнопка перехода к списку принтеров
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PrinterListScreen()),
                );
              },
              child: const Text('Управление принтерами'),
            ),
          ],
        ),
      ),
    );
  }
}