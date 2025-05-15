import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mip/screens/main_screen.dart';
import 'package:mip/screens/scanner_screen.dart';
import 'package:mip/screens/manual_entry_screen.dart';
import 'package:mip/screens/printer_list_screen.dart';
import 'package:mip/services/api_service.dart';

void main() {
  runApp(
    Provider<ApiService>(
      create: (_) => ApiService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Принтеры',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScreen(),
        '/scan': (context) => const ScannerScreen(),
        '/manual-entry': (context) => const ManualEntryScreen(),
        '/printers': (context) => const PrinterListScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
