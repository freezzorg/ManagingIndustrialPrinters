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
      number: json['number'],
      model: json['model'],
      ip: json['ip'],
      port: json['port'],
      uid: json['uid'],
      rm: json['rm'] ?? '',
      status: json['status'],
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
