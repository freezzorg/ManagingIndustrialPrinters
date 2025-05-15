enum PrinterStatus {
  connected,
  inWork,
  notWorking,
}

extension PrinterStatusExtension on PrinterStatus {
  int get code {
    switch (this) {
      case PrinterStatus.connected:
        return 1;
      case PrinterStatus.inWork:
        return 2;
      case PrinterStatus.notWorking:
        return 9;
    }
  }

  String get name {
    switch (this) {
      case PrinterStatus.connected:
        return 'Подключен';
      case PrinterStatus.inWork:
        return 'В работе';
      case PrinterStatus.notWorking:
        return 'Не в работе';
    }
  }

  static PrinterStatus fromCode(int code) {
    switch (code) {
      case 1:
        return PrinterStatus.connected;
      case 2:
        return PrinterStatus.inWork;
      case 9:
        return PrinterStatus.notWorking;
      default:
        return PrinterStatus.notWorking;
    }
  }
}

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
  final int number;
  final int modelCode;
  final String ip;
  final String port;
  final String uid;
  final String rm;
  final int statusCode;

  Printer({
    required this.number,
    required this.modelCode,
    required this.ip,
    required this.port,
    required this.uid,
    required this.rm,
    required this.statusCode,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      number: json['number'],
      modelCode: json['model'],
      ip: json['ip'],
      port: json['port'],
      uid: json['uid'],
      rm: json['rm'] ?? '',
      statusCode: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'model': modelCode,
      'ip': ip,
      'port': port,
      'uid': uid,
      'rm': rm,
      'status': statusCode,
    };
  }

  PrinterStatus get status => PrinterStatusExtension.fromCode(statusCode);
  PrinterModel get model => PrinterModelExtension.fromCode(modelCode);
}
