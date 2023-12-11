
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hello/uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'board.dart';
import 'board_list_view.dart';
import 'package:http/http.dart' as http;

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

  final List<Board> boards = [];

  final TextEditingController _messageController = TextEditingController();
  late Painter painter;

  late String storedAccessToken;
  late String storedTel;

  bool isLoading = false;

  @override
  void initState(){
    painter = Painter(line, lines);
    init();
    super.initState();
  }

  void init() async {
    await loadUserInfoFromSharedPreferences();
    if(storedAccessToken!= null && storedAccessToken.isNotEmpty) loadDataFromServer();
  }

  Future<void> loadUserInfoFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    storedAccessToken = prefs.getString('accessToken') ?? '';
    storedTel = prefs.getString('tel') ?? '';
    if (kDebugMode) {
      print("storedAccessToken : $storedAccessToken");
    }
  }

  Future<void> loadDataFromServer() async {
    // Set loading state to true
    setState(() {
      isLoading = true;
    });

    Map<String, dynamic> requestBody = {
      'noOfDisplay': 30,
      'tel': storedTel,
    };

    if (kDebugMode) {
      print('executing async getlist');
    }

    try{
      var response = await http.post(Uri.parse('http://10.100.203.62:8080/api/board/list'),
        headers: <String, String>{
          'Authorization': 'Bearer:$storedAccessToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'noOfDisplay': requestBody['noOfDisplay'].toString(),
          'tel': requestBody['tel'],
        },
      );

      if(response.statusCode == 200){
        List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        boards.clear();
        for (var jsonBoard in jsonList) {
          // 밑에  setState()에서 UI가 새로 그려지니 여기는 없어도 될 듯합니다
          Board board = Board.fromJson(jsonBoard);
          boards.add(board);
        }
        if (kDebugMode) {
          print('Get list success : ${response.body}');
        }
      } else {
        if (kDebugMode) {
          print('Response body: ${response.body}, ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('error loading data $e')  ;

      }
    }

    setState(() {
      isLoading = false;
    });
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

  // Paint 와 message  함께 전송
  void _sendPaint() async {
    if(lines.isEmpty){
      print(">>>> no lines");
      return;
    }

    if(storedAccessToken == null || storedAccessToken.isEmpty) {
      print(">>>> not login state");
      return;
    }

    String jsonData = jsonEncode(lines);

    Directory appDocDir = await getApplicationDocumentsDirectory();
    // Create the 'paint.csr' file in the app's local directory
    File file = File('${appDocDir.path}/paint.csr');
    await file.writeAsString(jsonData);

    String strMessage= "Paint 파일";
    if(_messageController.text.isNotEmpty) {
      strMessage = _messageController.text;
      _messageController.text = '';
    }
    var uploader = Uploader(strMessage, storedAccessToken, storedTel, "PAINT", file.path);
    try {
      await uploader.upload();
      print('Upload successful');
      loadDataFromServer();
    } catch (e) {
      print('Upload failed: $e');
    }
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
              Expanded(
                child: Center(
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : BoardListView(boards: boards, onBoardTap: (int index) {
                    // Handle the tapped board index here
                    print('Tapped board index: ${boards[index].boardId}');
                  },),
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
                      onPressed: _sendPaint,
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