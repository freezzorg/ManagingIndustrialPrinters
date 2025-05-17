import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mip/models/printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService extends ChangeNotifier {
  static const _prefsBaseUrlKey = 'baseUrl';

  String _baseUrl = 'http://10.10.8.21:21010';

  String get baseUrl => _baseUrl;

  ApiService() {
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_prefsBaseUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
      notifyListeners();
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    _baseUrl = newUrl;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBaseUrlKey, newUrl);
  }

  Future<Printer?> getPrinterByIdOrUid({int? id, String? uid}) async {
    if (id == null && uid == null) {
      throw ArgumentError('Необходимо передать либо id, либо uid принтера');
    }

    final printerQuery = <String, dynamic>{};
    if (id != null) printerQuery['id'] = id;
    if (uid != null) printerQuery['uid'] = uid;

    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'GetPrinter',
      'cmdbody': jsonEncode(printerQuery),
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded['response'];

      if (data == null) return null;
      return Printer.fromJson(data);
    } else {
      throw Exception('Ошибка получения принтера по id/uid');
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

  Future<void> addPrinter(Map<String, dynamic> printerData) async {
    final printer = {
      'id': 0,
      'number': printerData['number'],
      'model': printerData[
          'modelCode'], // или просто 'model' если ключ уже переименован
      'ip': printerData['ip'],
      'port': printerData['port'],
      'uid': printerData['uid'],
      'rm': printerData['rm'],
      'status': printerData['statusCode'], // или 'status'
    };

    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'PutPrinter',
      'cmdbody': jsonEncode(printer),
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка добавления принтера');
    }
  }

  Future<void> updatePrinter(Map<String, dynamic> printerData) async {
    final printer = {
      'id': printerData['id'],
      'number': printerData['number'],
      'model': printerData['modelCode'], // или просто 'model'
      'ip': printerData['ip'],
      'port': printerData['port'],
      'uid': printerData['uid'],
      'rm': printerData['rm'],
      'status': printerData['statusCode'], // или 'status'
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

  Future<void> deletePrinter(int id) async {
    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'DelPrinter',
      'cmdbody': jsonEncode({'id': id}),
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка удаления принтера');
    }
  }
}
