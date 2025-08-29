enum PrinterModel {
  markemImaje9040,
  markemImaje94X0,
  lmeLaserLmeUf,
  unknown,
}

extension PrinterModelExtension on PrinterModel {
  int get code {
    switch (this) {
      case PrinterModel.markemImaje9040:
        return 1;
      case PrinterModel.markemImaje94X0:
        return 2;
      case PrinterModel.lmeLaserLmeUf:
        return 3;
      case PrinterModel.unknown:
        return 9;
    }
  }

  String get name {
    switch (this) {
      case PrinterModel.markemImaje9040:
        return 'Markem Imaje 9040';
      case PrinterModel.markemImaje94X0:
        return 'Markem Imaje 94X0';
      case PrinterModel.lmeLaserLmeUf:
        return 'LME laser LME-UF';
      case PrinterModel.unknown:
        return 'Неизвестна';
    }
  }

  String get port {
    switch (this) {
      case PrinterModel.markemImaje9040:
        return '2101';
      case PrinterModel.markemImaje94X0:
        return '2000';
      case PrinterModel.lmeLaserLmeUf:
        return '8888';
      case PrinterModel.unknown:
        return '0'; // Или другое значение по умолчанию
    }
  }

  static PrinterModel fromCode(int code) {
    switch (code) {
      case 1:
        return PrinterModel.markemImaje9040;
      case 2:
        return PrinterModel.markemImaje94X0;
      case 3:
        return PrinterModel.lmeLaserLmeUf;
      default:
        return PrinterModel.unknown;
    }
  }
}

class Printer {
  final int id;
  final int number;
  final int model;
  final String ip;
  final String port;
  final String uid;
  final String rm;
  final bool status;

  Printer({
    required this.id,
    required this.number,
    required this.model,
    required this.ip,
    required this.port,
    required this.uid,
    required this.rm,
    required this.status,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['id'] ?? 0,
      number: json['number'] ?? 0, // Добавлено значение по умолчанию
      model: json['model'] ?? 9, // Добавлено значение по умолчанию (unknown)
      ip: json['ip'] ?? '',
      port: json['port'] ?? '',
      uid: json['uid'] ?? '00000000-0000-0000-0000-000000000000', // Добавлено значение по умолчанию
      rm: json['rm'] ?? '',
      status: json['status'] ?? false, // Добавлено значение по умолчанию
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'model': model,
      'ip': ip,
      'port': port,
      'uid': uid,
      'rm': rm,
      'status': status,
    };
  }

  PrinterModel get modelEnum => PrinterModelExtension.fromCode(model);

  String get statusText => status ? 'В работе' : 'Не в работе';
}
