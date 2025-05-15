class PrinterListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Список принтеров', style: TextStyle(fontSize: 24)),
      ),
      body: FutureBuilder<List<Printer>>(
        future: Provider.of<ApiService>(context, listen: false).getAllPrinters(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Нет данных'));
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text('№', style: TextStyle(fontSize: 18))),
                DataColumn(label: Text('Модель', style: TextStyle(fontSize: 18))),
                DataColumn(label: Text('IP', style: TextStyle(fontSize: 18))),
                DataColumn(label: Text('Порт', style: TextStyle(fontSize: 18))),
                DataColumn(label: Text('Статус', style: TextStyle(fontSize: 18))),
                DataColumn(label: Text('UID', style: TextStyle(fontSize: 18))),
                DataColumn(label: Text('RM', style: TextStyle(fontSize: 18))),
              ],
              rows: snapshot.data!.map((printer) => DataRow(cells: [
                DataCell(Text(printer.number.toString(), style: TextStyle(fontSize: 16))),
                DataCell(Text(printer.model.name, style: TextStyle(fontSize: 16))),
                DataCell(Text(printer.ip, style: TextStyle(fontSize: 16))),
                DataCell(Text(printer.port, style: TextStyle(fontSize: 16))),
                DataCell(Text(printer.status.name, style: TextStyle(fontSize: 16))),
                DataCell(Text(printer.uid, style: TextStyle(fontSize: 16))),
                DataCell(Text(printer.rm, style: TextStyle(fontSize: 16))),
              ])).toList(),
            ),
          );
        },
      ),
    );
  }

  // ...
  void _bindPrinter() async {
    try {
      await Provider.of<ApiService>(context, listen: false).bindPrinter(
        Printer(
          number: 1,
          modelCode: PrinterModel.markemImaje9040.code,
          uid: lineData,
          rm: printerData,
          ip: 'ip-адрес принтера',
          port: 'порт принтера',
          statusCode: PrinterStatus.connected.code,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Принтер привязан')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }
}