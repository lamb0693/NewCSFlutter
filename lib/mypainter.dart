import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MyPainter extends CustomPainter {
  final List<List<Map<String, double>>> linesCSR;
  final List<List<Map<String, double>>> linesCustomer;
  final List<Map<String, double>> currentLine;

  MyPainter(this.linesCSR, this.linesCustomer, this.currentLine);

  @override
  void paint(Canvas canvas, Size size) {


    var paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke;

    if (kDebugMode) {
      print(' >>>> paint is called');
      print(' >>>>linesCSR : $linesCSR');
      print(' >>>>linesCustomer : $linesCustomer');
      print(' >>>>currentLine : $currentLine');
    }

    // Draw lines based on the linesCSR data
    for (var line in linesCSR) {
      if (line.length > 1) {
        final path = Path();
        path.moveTo(line[0]['x']!, line[0]['y']!);
        for (var i = 1; i < line.length; i++) {
          path.lineTo(line[i]['x']!, line[i]['y']!);
        }

        var paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke;

        canvas.drawPath(path, paint);
      }
    }

    for (var line in linesCustomer) {
      if (line.length > 1) {
        final path = Path();
        path.moveTo(line[0]['x']!, line[0]['y']!);
        for (var i = 1; i < line.length; i++) {
          path.lineTo(line[i]['x']!, line[i]['y']!);
        }

        var paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke;

        canvas.drawPath(path, paint);
      }
    }

    // Draw the current line being drawn
    if (currentLine.isNotEmpty) {
      final path = Path();
      path.moveTo(currentLine[0]['x']!, currentLine[0]['y']!);
      for (var i = 1; i < currentLine.length; i++) {
        path.lineTo(currentLine[i]['x']!, currentLine[i]['y']!);
      }
      canvas.drawPath(path, Paint()..color = Colors.red);
    }

  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
