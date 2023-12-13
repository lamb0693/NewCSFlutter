import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hello/audio_upload.dart';
import 'package:flutter_hello/constants.dart';
import 'package:flutter_hello/login.dart';
import 'package:flutter_hello/paint_upload.dart';
import 'package:flutter_hello/uploader.dart';
import 'package:flutter_hello/webrct.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'board.dart';
import 'board_list_view.dart';
import 'package:path/path.dart' as path;

import 'custom_audio_dlg.dart';
import 'custom_image_dlg.dart';
import 'custom_paint_dlg.dart';

import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'CS Application'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  String? storedAccessToken;
  String? storedTel;
  bool isLoading = false;

  // 서버로 부터 다운 받은 게시글 리스트
  final List<Board> boards = [];

  //  sendMessage 의 text
  final TextEditingController _messageController = TextEditingController();

  // 사진 찍어 전송용
  final picker = ImagePicker();
  // List<XFile?> multiImage = [];
  // List<XFile?> images = [];

  // 서버로 부터 boardList를 받는다
  Future<void> loadDataFromServer() async {
    if(storedAccessToken == null || storedAccessToken == ''){
      return;
    }

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
      var response = await http.post(Uri.parse('${AppConstants.apiBaseUrl}/api/board/list'),
        headers: <String, String>{
          'Authorization': 'Bearer:$storedAccessToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'noOfDisplay': requestBody['noOfDisplay'].toString(),
          'tel': requestBody['tel'],
        },
      ).timeout(const Duration(seconds: 5));

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
    } on TimeoutException catch (e) {
      print('Request timed out: $e');
    } catch (e) {
      if (kDebugMode) {
        print('error loading data $e')  ;
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> loadUserInfoFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    storedAccessToken = prefs.getString('accessToken') ?? '';
    storedTel = prefs.getString('tel') ?? '';
    if (kDebugMode) {
      print("storedAccessToken : $storedAccessToken");
    }
  }

  void moveToLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage(title: "Login")),
    );

    if (kDebugMode) {
      print("result $result");
    }
    if (result == true) {
      await loadUserInfoFromSharedPreferences();
      if (storedAccessToken != null) {
        if (kDebugMode) {
          print("Reload data after login: $storedAccessToken");
        }
        loadDataFromServer();
      }
    }
  }

  void sendMessage() async {

    Map<String, dynamic> requestBody = {
      'customerTel': storedTel,
      'tel': storedTel,
      'content' : 'TEXT',
      'message' : _messageController.text,
    };

    try {
      var response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/board/create'),
        headers: <String, String>{
          'Authorization': 'Bearer:$storedAccessToken',
        },
        body: {
          'customerTel': requestBody['customerTel'].toString(),
          'tel': requestBody['tel'].toString(),
          'message': requestBody['message'].toString(),
          'content': requestBody['content'].toString()
        },
      );
      print(response.body);
      loadDataFromServer();
    }
    catch(e){
      if (kDebugMode) {
        print(e);
      }
    }
  }

  void returnFromOtherPage() {
    loadDataFromServer();
  }

  void _moveToWebrtc() async {
    if(storedAccessToken == null || storedAccessToken == ''){
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('로그인 필요'),
            content: const Text('로그인 후 이용하세요'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebrtcPage(title: "Webrtc"),
      ),
    );

    returnFromOtherPage();
  }

  Future _moveToPainterPage() async{
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaintUploadPage(title: "Painter"),
      ),
    );

    returnFromOtherPage();
  }

  Future _moveToAudioRecorderPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AudioUploadPage(title: "Audio Uploader"),
      ),
    );

    returnFromOtherPage();
  }

  Future _pickImage() async {
    if (kDebugMode) {
      print('>>>> pick Image called');
    }
    XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (kDebugMode) {
      print('image file path : ${image?.path}');
    }

    if(storedAccessToken == null || storedAccessToken == "" ) {
      if (kDebugMode) {
        print(">>>> not login state");
      }
      return;
    }

    if (image != null) {
      File imageFile = File(image.path);

      String modifiedPath = path.join(path.dirname(imageFile.path), 'saveImg.jpg');
      await imageFile.rename(modifiedPath);
      if (kDebugMode) {
        print('imageFile path : ${imageFile.path}');
      }

      var uploader = Uploader("사진파일", storedAccessToken!, storedTel!, "IMAGE", modifiedPath);
      try {
        await uploader.upload();
        if (kDebugMode) {
          print('Upload successful');
        }
        // Proceed to load data from the server after a successful upload
        loadDataFromServer();
      } catch (e) {
        if (kDebugMode) {
          print('Upload failed: $e');
        }
        // Handle the error, perhaps show a user-friendly message
      }
    }
  }

  void _showFloatingMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context)!.context.findRenderObject() as RenderBox;

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    if(storedAccessToken == null || storedAccessToken == ''){
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('로그인 필요'),
            content: const Text('로그인 후 이용하세요'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
      return;
    }

    await showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          child: const Text('사진 전송'),
          onTap: () async {
            await _pickImage();
            returnFromOtherPage();
          },
        ),
        PopupMenuItem(
          child: const Text('음성 전송'),
          onTap: () async {
            await _moveToAudioRecorderPage();
            returnFromOtherPage();
          },
        ),
        PopupMenuItem(
          child: const Text('그림 그려 전송'),
          onTap: () async {
            await _moveToPainterPage();
            returnFromOtherPage();
          },
        ),
      ],
    );
  }

  void _showImageDialog(BuildContext context, int boardId) {
    if (storedAccessToken == null || storedAccessToken == '') {
      if (kDebugMode) {
        print("Show Image Dialog : $storedAccessToken");
      }
      return;
    }

    if (kDebugMode) {
      print("executing download");
    }
    String apiUrl = '${AppConstants.apiBaseUrl}/api/board/download';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder(
          future: _getImageData(apiUrl, boardId),
          builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                // Handle error if the image download fails
                if (kDebugMode) {
                  print('Failed to download image: ${snapshot.error}');
                }
                return const AlertDialog(
                  title: Text('Error'),
                  content: Text('Failed to download image.'),
                );
              } else {
                return CustomImageDialog(imageData: snapshot.data!);
              }
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        );
      },
    );
  }

  Future<Uint8List> _getImageData(String apiUrl, int boardId) async {
    try {
      final http.Response response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $storedAccessToken'},
        body: {'id': boardId.toString()},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download image. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error during image download: $e');
    }
  }

  void _showPaintDialog(BuildContext context, int boardId) {
    if (storedAccessToken == null || storedAccessToken == '') {
      if (kDebugMode) {
        print("Show Image Dialog : $storedAccessToken");
      }
      return;
    }

    if (kDebugMode) {
      print("executing download paint");
    }
    String apiUrl = '${AppConstants.apiBaseUrl}/api/board/download';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<List<List<Map<String, double>>>>(
          future: _getPaintData(apiUrl, boardId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text('Failed to fetch paint data'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty){
              return AlertDialog(
                title: const Text('No Paint Data'),
                content: const Text('There is no paint data available.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            } else {
              return CustomPaintDialog(lines: snapshot.data!);
            }
          }
        );
      },
    );
  }

  Future< List<List<Map<String, double>>> > _getPaintData(String apiUrl, int boardId) async {
    List<List<Map<String, double>>> lines = [];

    try {
      final http.Response response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $storedAccessToken'},
        body: {'id': boardId.toString()},
      );

      if (response.statusCode == 200) {
        String jsonString = response.body;
        List<dynamic> decodedList = json.decode( jsonString );

        lines = decodedList.map<List<Map<String, double>>>((line) {
          return (line as List<dynamic>).map<Map<String, double>>((point) {
            return {
              'x': (point['x'] as num).toDouble(),
              'y': (point['y'] as num).toDouble(),
            };
          }).toList();
        }).toList();

      } else {
        throw Exception('Failed to download paint file. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error during image download: $e');
    }

    return lines;
  }

  void _showAudioDialog(BuildContext context, int boardId) {
    if (storedAccessToken == null || storedAccessToken == '') {
      if (kDebugMode) {
        print("Show Image Dialog : $storedAccessToken");
      }
      return;
    }

    if (kDebugMode) {
      print("executing download");
    }
    String apiUrl = '${AppConstants.apiBaseUrl}/api/board/download';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder(
          future: _getAudioData(apiUrl, boardId),
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                if (kDebugMode) {
                  print('Failed to download audio: ${snapshot.error}');
                }
                return AlertDialog(
                  title: const Text('Error'),
                  content: const Text('Failed to download audio.'),
                  actions: <Widget>[
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close the dialog
                      },
                      child: const Text('OK'),
                    ),
                  ],
                );
              } else {
                return Dialog(
                  child: SizedBox(
                    height: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AudioPlayerWidget(audioData: snapshot.data!),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the dialog
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ),
                );
              }
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        );
      },
    );
  }

  Future<String> _getAudioData(String apiUrl, int boardId) async {
    try {
      final http.Response response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $storedAccessToken'},
        body: {'id': boardId.toString()},
      );

      if (response.statusCode == 200) {
        final String filePath = await _saveAudioToFile(response.bodyBytes);
        return filePath;
      } else {
        throw Exception('Failed to download audio. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error during audio download: $e');
    }
  }

  Future<String> _saveAudioToFile(Uint8List audioData) async {
    try {
      final String fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      final Directory? appDocDir = await getExternalStorageDirectory();
      final String? appDocPath = appDocDir?.path;
      final String filePath = '$appDocPath/$fileName';

      File file = File(filePath);
      await file.writeAsBytes(audioData);

      return filePath;
    } catch (e) {
      throw Exception('Error saving audio to file: $e');
    }
  }

  void logout() async{
    storedAccessToken = null;
    storedTel = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("accessToken");
    await prefs.remove("tel");
    await prefs.remove("role");
    setState(() {
      boards.clear();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home : Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: isLoading
                    ? const CircularProgressIndicator()
                    : storedAccessToken == null
                    ? Image.asset(
                        'assets/backImage.jpg',
                        fit: BoxFit.cover, // Use BoxFit.cover to fill the area
                    )
                    : BoardListView(boards: boards, onBoardTap: (int index) {
                    if (kDebugMode) {
                      print('Tapped board index: ${boards[index].boardId}');
                    }
                    if(boards[index].content == 'IMAGE') {
                      _showImageDialog(context, boards[index].boardId);
                    } else if(boards[index].content == 'PAINT'){
                      _showPaintDialog(context, boards[index].boardId);
                    } else if(boards[index].content == 'AUDIO'){
                      _showAudioDialog(context, boards[index].boardId);
                    }
                },),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _showFloatingMenu(context);
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0.0), // Set the border radius to 0 for a rectangular shape
                      ),
                    ),
                    child: const Icon(Icons.more_vert_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: sendMessage,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          child : Row (
            children: [
              Visibility(
                visible: storedAccessToken == null,
                child: ElevatedButton(
                  onPressed: moveToLogin,
                  child: const Text('로그인'),
                ),
              ),
              Visibility(
                visible: storedAccessToken != null && storedAccessToken != '',
                child: ElevatedButton(
                  onPressed: logout,
                  child: const Text('로그아웃'),
                ),
              ),
              ElevatedButton(
                  onPressed: _moveToWebrtc,
                  child: const Text('상담원연결')
              ),
            ],
          )
        ),
      ),
    );
  }
}



