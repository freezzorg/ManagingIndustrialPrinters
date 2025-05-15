class Printer {
  int number;
  int modelCode;
  String uid;
  String rm;
  String ip;
  String port;
  int statusCode;

  Printer({
    required this.number,
    required this.modelCode,
    required this.uid,
    required this.rm,
    required this.ip,
    required this.port,
    required this.statusCode,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      number: json['number'],
      modelCode: json['model'],
      uid: json['uid'],
      rm: json['rm'],
      ip: json['ip'],
      port: json['port'],
      statusCode: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'model': modelCode,
      'uid': uid,
      'rm': rm,
      'ip': ip,
      'port': port,
      'status': statusCode,
    };
  }

  PrinterStatus get status {
    return PrinterStatus.values[statusCode - 1];
  }

  PrinterModel get model {
    return PrinterModel.values[modelCode - 1];
  }
}

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
}