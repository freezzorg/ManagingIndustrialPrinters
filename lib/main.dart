import 'package:flutter/material.dart';
import 'package:mip/screens/main_screen.dart';
import 'package:mip/screens/printer_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:mip/services/api_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiService()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Принтеры',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/': (context) => MainScreen(),
        '/printers': (context) => PrinterListScreen(),
      },
    );
  }
}