class Line {
  String uid;
  String rm;
  String operation;
  Line({required this.uid, required this.rm, required this.operation});

  factory Line.fromJson(Map<String, dynamic> json) {
  return Line(
    uid: json['uid'],
    rm: json['rm'],
    operation: json['operation'],
  );
}
}