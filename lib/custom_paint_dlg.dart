import 'dart:typed_data';

import 'package:flutter/material.dart';

class PainterInDlg extends CustomPainter {
  List<List<Map<String, double>>> lines;

  PainterInDlg(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke;

    // Draw lines based on the linesCSR data
    for (var line in lines) {
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}


class CustomPaintDialog extends StatelessWidget {
  final List<List<Map<String, double>>> lines;

  const CustomPaintDialog({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(350, 300),
            painter: PainterInDlg(lines),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}