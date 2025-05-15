import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mip/screens/main_screen.dart';
import 'package:mip/screens/printer_list_screen.dart';
import 'package:mip/screens/manual_entry_screen.dart';
import 'package:mip/screens/scanner_screen.dart';
import 'package:mip/services/api_service.dart';


void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Управление принтерами',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => MainScreen(),
        '/scan': (context) => ScannerScreen(),
        '/manual-entry': (context) => ManualEntryScreen(),
        '/printers': (context) => PrinterListScreen(),
      },
    );
  }
}
