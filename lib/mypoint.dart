class MyPoint {
  double x = 0;
  double y = 0;

  MyPoint(this.x, this.y);

  Map<String, dynamic> toMap() {
    return {'x': x, 'y': y};
  }
}