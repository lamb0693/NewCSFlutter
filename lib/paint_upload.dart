
import 'package:flutter/material.dart';

class Painter extends CustomPainter{
  List<List<Map<String, double>>> lines ;
  List<Map<String, double>> line;

  Painter(this.line, this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke;

    print('>>>> onPaint : $line, $lines');

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

    // Draw the current line being drawn
    if (line.isNotEmpty) {
      final path = Path();
      path.moveTo(line[0]['x']!, line[0]['y']!);
      for (var i = 1; i < line.length; i++) {
        path.lineTo(line[i]['x']!, line[i]['y']!);
      }
      canvas.drawPath(path, Paint()..color = Colors.red);
    }
  }

  void setLines(List<List<Map<String, double>>> lines){
    this.lines = [...lines];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class PaintUploadPage extends StatefulWidget {
  final String title;

  const PaintUploadPage({super.key, required this.title});

  @override
  State<PaintUploadPage> createState() => _PaintUploadPage();

}

class _PaintUploadPage extends State<PaintUploadPage>{
  List<List<Map<String, double>>> lines = [];
  List<Map<String, double>> line = [];
  bool isDrawing = false;

  final TextEditingController _messageController = TextEditingController();


  late Painter painter;

  @override
  void initState() {
    painter = Painter(line, lines);
    super.initState();
  }

  void _toPrevious(){
    if (mounted) Navigator.pop(context);
  }

  void _removePrev(){
    lines.removeLast();
    painter.setLines([...lines]);
    setState(() {    });
  }

  void _removeAll(){
    lines.clear();
    painter.setLines([...lines]);
    setState(() {    });
  }

  void _sendMessage() async {

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            children: [
               ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 400,
                  minHeight: 300,
                  maxHeight: 300,
                ),
                child: Container(
                  color: Colors.grey,
                  child: GestureDetector(
                    onPanDown: (details) {
                      if (painter != null)  {
                        print('on Mouse Down ${details.localPosition}');
                        isDrawing = true;
                        setState(() {
                          line.add({'x': details.localPosition.dx, 'y': details.localPosition.dy});
                        });
                      }
                    },
                    onPanUpdate: (details) {
                      if (painter != null){
                        print('on Mouse Down ${details.localPosition}');
                        setState(() {
                          line.add({'x': details.localPosition.dx, 'y': details.localPosition.dy});
                        });
                      }
                    },
                    onPanEnd: (details) {
                      if (painter != null) {
                        lines.add([...line]);
                        line.clear();
                        painter.setLines([...lines]);
                        setState(() { });
                      }
                    },
                    child: CustomPaint(
                      size: Size(400, 300),
                      painter: painter ,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _sendMessage,
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: _toPrevious,
                child: const Text('돌아가기'),
              ),
              ElevatedButton(
                onPressed: _removePrev,
                child: const Text('이전제거'),
              ),
              ElevatedButton(
                onPressed: _removeAll,
                child: const Text('모두제거'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}