import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mip/models/printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService extends ChangeNotifier {
  static const _prefsBaseUrlKey = 'baseUrl';
  static const _zeroUuid = '00000000-0000-0000-0000-000000000000';

  String _baseUrl = 'http://10.10.8.80:21010';

  String get baseUrl => _baseUrl;

  ApiService() {
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_prefsBaseUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
      print("Loaded baseUrl: $_baseUrl"); // Для отладки
      notifyListeners();
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    _baseUrl = newUrl;
    print("Updated baseUrl: $_baseUrl"); // Для отладки
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBaseUrlKey, newUrl);
  }

  /// Приводит данные принтера к корректному виду:
  /// - для пустого или all-zero UID устанавливает uid=all-zero, rm='' и isWorking=false
  /// - для любого другого UID оставляет rm и isWorking как есть (или isWorking=true по умолчанию)
  Map<String, dynamic> _normalizePrinterData(Map<String, dynamic> data) {
    final rawUid = data['uid']?.toString().trim().toLowerCase() ?? '';
    final isUidEmpty = rawUid.isEmpty || rawUid == _zeroUuid;

    return {
      'id': data['id'] ?? 0,
      'number': data['number'],
      'model': data['model'],
      'ip': data['ip'],
      'port': data['port'],
      // для пустого UID храним all-zero строку
      'uid': isUidEmpty ? _zeroUuid : rawUid,
      // RM линии — пустое для пустого UID, иначе переданное значение
      'rm': isUidEmpty ? '' : data['rm'],
      // Статус — 0 (не в работе) при пустом UID, иначе переданный или 1 (в работе) по умолчанию
      'status': isUidEmpty ? false : (data['status'] ?? true),
    };
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

    print("Sending GetPrinter request: $body"); // Для отладки
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      print(
          "GetPrinter response: ${response.statusCode} ${response.body}"); // Для отладки

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['response'];

        if (data == null) return null;
        return Printer.fromJson(data);
      } else {
        throw Exception(
            'Ошибка получения принтера: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print("Error in getPrinterByIdOrUid: $e"); // Для отладки
      throw Exception('Ошибка получения принтера: $e');
    }
  }

  Future<List<Printer>> getPrinters() async {
    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'GetAllPrinters',
    });

    print("Sending GetAllPrinters request: $body"); // Для отладки
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      print(
          "GetAllPrinters response: ${response.statusCode} ${response.body}"); // Для отладки

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['response'] == null) {
          throw Exception('Ответ сервера не содержит данных');
        }
        final printers = (decoded['response'] as List)
            .map((json) => Printer.fromJson(json))
            .toList();
        return printers;
      } else {
        throw Exception(
            'Ошибка получения принтеров: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print("Error in getPrinters: $e"); // Для отладки
      throw Exception('Ошибка получения принтеров: $e');
    }
  }

  Future<void> addPrinter(Map<String, dynamic> printerData) async {
    // Нормализуем данные перед отправкой
    final printer = _normalizePrinterData(printerData);

    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'PutPrinter',
      'cmdbody': jsonEncode(printer),
    });

    print("Sending PutPrinter request: $body"); // Для отладки
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      print(
          "PutPrinter response: ${response.statusCode} ${response.body}"); // Для отладки

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка добавления принтера: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print("Error in addPrinter: $e"); // Для отладки
      throw Exception('Ошибка добавления принтера: $e');
    }
  }

  Future<void> updatePrinter(Map<String, dynamic> printerData) async {
    // Нормализуем данные перед отправкой
    final printer = _normalizePrinterData(printerData);

    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'UpdPrinter',
      'cmdbody': jsonEncode(printer),
    });

    print("Sending UpdPrinter request: $body"); // Для отладки
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      print(
          "UpdPrinter response: ${response.statusCode} ${response.body}"); // Для отладки

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка обновления принтера: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print("Error in updatePrinter: $e"); // Для отладки
      throw Exception('Ошибка обновления принтера: $e');
    }
  }

  Future<void> deletePrinter(int id) async {
    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'DelPrinter',
      'cmdbody': jsonEncode({'id': id}),
    });

    print("Sending DelPrinter request: $body"); // Для отладки
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      print(
          "DelPrinter response: ${response.statusCode} ${response.body}"); // Для отладки

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка удаления принтера: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print("Error in deletePrinter: $e"); // Для отладки
      throw Exception('Ошибка удаления принтера: $e');
    }
  }
}
