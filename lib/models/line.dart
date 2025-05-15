class Line {
  int number;
  String name;

  Line({
    required this.number,
    required this.name,
  });

  factory Line.fromJson(Map<String, dynamic> json) {
    return Line(
      number: json['number'],
      name: json['name'],
    );
  }
}