import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

import 'custom_image_dlg.dart';

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

  late String storedAccessToken;
  late String storedTel;
  bool isLoading = false;

  final List<Board> boards = [];

  final TextEditingController _messageController = TextEditingController();

  final picker = ImagePicker();
  List<XFile?> multiImage = []; // 갤러리에서 여러 장의 사진을 선택해서 저장할 변수
  List<XFile?> images = []; // 가져온 사진들을 보여주기 위한 변수

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
      if (storedAccessToken.isNotEmpty) {
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
        Uri.parse('http://10.100.203.62:8080/api/board/create'),
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
      print(e);
    }
  }

  void returnFromOtherPage() {
    loadDataFromServer();
  }

  void _moveToWebrtc() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebrtcPage(title: "Webrtc"),
      ),
    );

    returnFromOtherPage();
  }

  _moveToPainterPage() async{
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaintUploadPage(title: "Painter"),
      ),
    );

    returnFromOtherPage();
  }

  void _pickImage() async {
    print('>>>> pick Image called');
    XFile? image = await picker.pickImage(source: ImageSource.camera);
    print('image file path : ${image?.path}');

    if(storedAccessToken == null || storedAccessToken.isEmpty) {
      print(">>>> not login state");
      return;
    }

    if (image != null) {
      File imageFile = File(image.path);

      String modifiedPath = path.join(path.dirname(imageFile.path), 'saveImg.jpg');
      await imageFile.rename(modifiedPath);
      print('imageFile path : ${imageFile.path}');

      var uploader = Uploader("사진파일", storedAccessToken, storedTel, "IMAGE", modifiedPath);
      try {
        await uploader.upload();
        print('Upload successful');
        // Proceed to load data from the server after a successful upload
        loadDataFromServer();
      } catch (e) {
        print('Upload failed: $e');
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

    await showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          child: const Text('사진 전송'),
          onTap: () {
            _pickImage();
          },
        ),
        PopupMenuItem(
          child: const Text('그림 그려 전송'),
          onTap: () {
            _moveToPainterPage();
          },
        ),
      ],
    );
  }

  void _showImageDialog(BuildContext context, int boardId) {
    if (storedAccessToken == null || storedAccessToken.isEmpty) {
      print("Show Image Dialog : $storedAccessToken");
      return;
    }

    print("executing download");
    String apiUrl = 'http://10.100.203.62:8080/api/board/download';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder(
          future: _getImageData(apiUrl, boardId),
          builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                // Handle error if the image download fails
                print('Failed to download image: ${snapshot.error}');
                return const AlertDialog(
                  title: Text('Error'),
                  content: Text('Failed to download image.'),
                );
              } else {
                // Image has been loaded successfully, show the custom image dialog
                return CustomImageDialog(imageData: snapshot.data!);
              }
            } else {
              // Show a loading indicator while waiting for the image to load
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


  // void _showImageDialog(BuildContext context, int boardId) async {
  //   if(storedAccessToken == null || storedAccessToken.isEmpty) {
  //     print("Show Image Dialog : $storedAccessToken");
  //     return;
  //   }
  //
  //   print("executing download");
  //   String apiUrl = 'http://10.100.203.62:8080/api/board/download';
  //
  //   try {
  //     final http.Response response = await http.post(
  //       Uri.parse(apiUrl),
  //       headers: {'Authorization': 'Bearer $storedAccessToken'},
  //       body: {'id': boardId.toString()},
  //     );
  //
  //     if (response.statusCode == 200) {
  //       Uint8List imageData = response.bodyBytes;
  //
  //       showDialog(
  //         context: context,
  //         builder: (context) {
  //           return CustomImageDialog(imageData: imageData);
  //         },
  //       );
  //     } else {
  //       // Handle error if the image download fails
  //       print('Failed to download image. Status code: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     // Handle error if the HTTP request fails
  //     print('Error during image download: $e');
  //   }
  // }


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
                    : BoardListView(boards: boards, onBoardTap: (int index) {
                    print('Tapped board index: ${boards[index].boardId}');
                    if(boards[index].content == 'IMAGE') {
                      _showImageDialog(context, boards[index].boardId);
                    } else {

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
              ElevatedButton(
                  onPressed: moveToLogin,
                  child: const Icon(Icons.login)),
              ElevatedButton(
                  onPressed: _moveToWebrtc,
                  child: const Text('webrtc')
              ),
            ],
          )
        ),
      ),
    );
  }
}



