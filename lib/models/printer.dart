enum PrinterModel {
  markemImaje9040,
  markemImaje9410,
  markemImaje9450,
  unknown,
}

extension PrinterModelExtension on PrinterModel {
  int get code {
    switch (this) {
      case PrinterModel.markemImaje9040:
        return 1;
      case PrinterModel.markemImaje9410:
        return 2;
      case PrinterModel.markemImaje9450:
        return 3;
      case PrinterModel.unknown:
        return 9;
    }
  }

  String get name {
    switch (this) {
      case PrinterModel.markemImaje9040:
        return 'Markem Imaje 9040';
      case PrinterModel.markemImaje9410:
        return 'Markem Imaje 9410';
      case PrinterModel.markemImaje9450:
        return 'Markem Imaje 9450';
      case PrinterModel.unknown:
        return 'Неизвестна';
    }
  }

  static PrinterModel fromCode(int code) {
    switch (code) {
      case 1:
        return PrinterModel.markemImaje9040;
      case 2:
        return PrinterModel.markemImaje9410;
      case 3:
        return PrinterModel.markemImaje9450;
      default:
        return PrinterModel.unknown;
    }
  }
}

class Printer {
  final int id;
  final int number;
  final int modelCode;
  final String ip;
  final String port;
  final String uid;
  final String rm;
  final bool isWorking; // Булево значение для статуса

  Printer({
    required this.id,
    required this.number,
    required this.modelCode,
    required this.ip,
    required this.port,
    required this.uid,
    required this.rm,
    required this.isWorking,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    // Преобразуем числовой код в булево значение
    // 1 = true (в работе), 0 = false (не в работе)
    final bool isWorking = json['status'] == 1;
    
    return Printer(
      id: json['id'] ?? 0,
      number: json['number'],
      modelCode: json['model'],
      ip: json['ip'],
      port: json['port'],
      uid: json['uid'],
      rm: json['rm'] ?? '',
      isWorking: isWorking,
    );
  }

  Map<String, dynamic> toJson() {
    // Преобразуем булево значение в числовой код
    // true (в работе) = 1, false (не в работе) = 0
    final int statusCode = isWorking ? 1 : 0;
    
    return {
      'id': id,
      'number': number,
      'model': modelCode,
      'ip': ip,
      'port': port,
      'uid': uid,
      'rm': rm,
      'status': statusCode,
    };
  }

  PrinterModel get model => PrinterModelExtension.fromCode(modelCode);
  
  // Геттер для получения текстового представления статуса
  String get status => isWorking ? 'В работе' : 'Не в работе';
}
