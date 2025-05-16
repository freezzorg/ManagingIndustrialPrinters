import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mip/models/printer.dart';

class ApiService extends ChangeNotifier {
  String _baseUrl = 'http://10.10.8.21:21010';

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    notifyListeners();
  }

  Future<Printer?> getPrinterByNumber(int number) async {
    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'GetAllPrinters',
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final printers = (decoded['response'] as List)
          .map((json) => Printer.fromJson(json))
          .toList();
      return printers.firstWhere((p) => p.number == number);
    } else {
      throw Exception('Не удалось получить принтер');
    }
  }

  Future<List<Printer>> getPrinters() async {
    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'GetAllPrinters',
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final printers = (decoded['response'] as List)
          .map((json) => Printer.fromJson(json))
          .toList();
      return printers;
    } else {
      throw Exception('Ошибка получения принтеров');
    }
  }

  Future<void> updatePrinter({
    required int number,
    required int model,
    required String ip,
    required String port,
    required String uid,
    required String rm,
    required int status,
  }) async {
    final printer = {
      'number': number,
      'model': model,
      'ip': ip,
      'port': port,
      'uid': uid,
      'rm': rm,
      'status': status,
    };

    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'UpdPrinter',
      'cmdbody': jsonEncode(printer),
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка обновления принтера');
    }
  }
}
