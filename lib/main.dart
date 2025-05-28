import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/scanner_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/manual_entry_screen.dart';
import 'screens/printer_list_screen.dart';
import 'services/api_service.dart';
import 'providers/theme_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Принтеры',
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.light,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ScannerScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/manual-entry': (context) => const ManualEntryScreen(),
        '/printers': (context) => const PrinterListScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
