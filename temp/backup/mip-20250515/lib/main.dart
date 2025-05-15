import 'package:flutter/material.dart';
import 'package:mip/screens/main_screen.dart';
import 'package:mip/screens/printer_list_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/': (context) => MainScreen(),
        '/printers': (context) => PrinterListScreen(),
      },
    );
  }
}