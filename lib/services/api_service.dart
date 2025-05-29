import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mip/models/printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService extends ChangeNotifier {
  static const _prefsBaseUrlKey = 'baseUrl';
  static const _zeroUuid = '00000000-0000-0000-0000-000000000000';

  String _baseUrl = 'http://10.10.8.21:21010';

  String get baseUrl => _baseUrl;

  ApiService() {
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_prefsBaseUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl.startsWith('http://') ? savedUrl : 'http://$savedUrl';
      notifyListeners();
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    final trimmedUrl = newUrl.trim();
    _baseUrl = trimmedUrl.startsWith('http://') ? trimmedUrl : 'http://$trimmedUrl';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBaseUrlKey, _baseUrl);
    notifyListeners();
  }

  Map<String, dynamic> _normalizePrinterData(Map<String, dynamic> data) {
    final rawUid = data['uid']?.toString().trim().toLowerCase() ?? '';
    final isUidEmpty = rawUid.isEmpty || rawUid == _zeroUuid;
    return {
      'id': data['id'] ?? 0,
      'number': data['number'],
      'model': data['model'],
      'ip': data['ip'],
      'port': data['port'],
      'uid': isUidEmpty ? _zeroUuid : rawUid,
      'rm': isUidEmpty ? '' : data['rm'],
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

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

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
      throw Exception('Ошибка получения принтера: $e');
    }
  }

  Future<List<Printer>> getPrinters() async {
    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'GetAllPrinters',
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

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
      throw Exception('Ошибка получения принтеров: $e');
    }
  }

  Future<void> addPrinter(Map<String, dynamic> printerData) async {
    final printer = _normalizePrinterData(printerData);

    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'PutPrinter',
      'cmdbody': jsonEncode(printer),
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка добавления принтера: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Ошибка добавления принтера: $e');
    }
  }

  Future<void> updatePrinter(Map<String, dynamic> printerData) async {
    final printer = _normalizePrinterData(printerData);

    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'UpdPrinter',
      'cmdbody': jsonEncode(printer),
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка обновления принтера: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Ошибка обновления принтера: $e');
    }
  }

  Future<void> deletePrinter(int id) async {
    final body = jsonEncode({
      'cmdtype': 'requesttodb',
      'cmdname': 'DelPrinter',
      'cmdbody': jsonEncode({'id': id}),
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка удаления принтера: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Ошибка удаления принтера: $e');
    }
  }
}
