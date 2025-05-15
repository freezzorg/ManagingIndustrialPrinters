class Printer {
  int? id;
  int number;
  int model;
  String ip;
  String port;
  String uid;
  String rm;
  int status;
  Printer(
    {
      this.id,
      required this.number,
      required this.model,
      required this.ip,
      required this.port,
      required this.uid,
      required this.rm,
      required this.status
    }
  );

Map<String, dynamic> toJson() {
    return {
      'number': number,
      'model': model,
      'ip': ip,
      'port': port,
      'status': status,
      'uid': uid,
      'rm': rm,
    };
  }

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      number: json['number'],
      model: json['model'],
      ip: json['ip'],
      port: json['port'],
      status: json['status'],
      uid: json['uid'],
      rm: json['rm'],
    );
  }
}