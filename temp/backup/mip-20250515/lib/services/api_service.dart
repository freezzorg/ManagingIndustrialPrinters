import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/printer.dart';
import '../models/line.dart';

class ApiService {
  static const String baseUrl = 'http://10.10.8.21:21010'; // URL PrintComm
  static const String oneCUrl = 'http://your-1c-service'; // Замените на URL 1С

  Future<List<Line>> getLines() async {
    final response = await http.get(Uri.parse('$oneCUrl/1c/lines'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Line.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load lines');
    }
  }

  Future<Printer?> getPrinter(int number) async {
    final response = await http.get(Uri.parse('$baseUrl/printers/$number'));
    if (response.statusCode == 200) {
      return Printer.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  }

  Future<List<Printer>> getAllPrinters() async {
    final response = await http.get(Uri.parse('$baseUrl/printers'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Printer.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load printers');
    }
  }

  Future bindPrinter(Printer printer) async {
    final response = await http.post(
      Uri.parse('$baseUrl/printers'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(printer.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to bind printer');
    }
  }
}