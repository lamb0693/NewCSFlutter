class Line {
  List<Map<String, double>> points;

  Line(this.points);

  Map<String, dynamic> toJson() {
    return {'points': points};
  }

  factory Line.fromJson(Map<String, dynamic> json) {
    return Line((json['points'] as List).cast<Map<String, double>>());
  }
}