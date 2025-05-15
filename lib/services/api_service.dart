class ApiService {
  Future<List<Printer>> getAllPrinters() async {
    final response = await http.get(Uri.parse('https://example.com/printers'));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return jsonData.map((printer) => Printer.fromJson(printer)).toList();
    } else {
      throw Exception('Failed to load printers');
    }
  }

  Future<void> bindPrinter(Printer printer) async {
    final response = await http.post(
      Uri.parse('https://example.com/bind-printer'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'number': printer.number,
        'model': printer.model.code,
        'uid': printer.uid,
        'rm': printer.rm,
        'ip': printer.ip,
        'port': printer.port,
        'status': printer.status.code,
      }),
    );

    if (response.statusCode == 200) {
      // принтер привязан
    } else {
      // ошибка
    }
  }
}