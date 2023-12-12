import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hello/uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'board.dart';
import 'board_list_view.dart';
import 'constants.dart';

import 'package:another_audio_recorder/another_audio_recorder.dart';
import 'package:path_provider/path_provider.dart';


class AudioRecorderWidget extends StatefulWidget {
  const AudioRecorderWidget({super.key});

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  AnotherAudioRecorder? recorder;
  String fileName = '';
  String filePath = '';
  Directory? externalDir;
  bool isRecording = false;

  @override
  void initState() {
    init();

    super.initState();
  }

  init() async {
    bool hasPermission = await AnotherAudioRecorder.hasPermissions;
    if(hasPermission){
      externalDir = await getExternalStorageDirectory();
    }
  }

  String getFilePath() {
    return filePath;
  }

  Future<bool> initPlayer() async {
    bool hasPermission = await AnotherAudioRecorder.hasPermissions;
    if(hasPermission) {
      externalDir = await getExternalStorageDirectory();

      String timestamp = DateTime
          .now()
          .millisecondsSinceEpoch
          .toString();
      setState(() {
        fileName = 'audio$timestamp.wav';
      });
      String filePath = '${externalDir?.path}/$fileName';
      recorder = AnotherAudioRecorder(filePath, audioFormat: AudioFormat.WAV);
      if (recorder == null) {
        print('>>>>error!! cannot acquire recorder');
        return false;
      } else {
        await recorder?.initialized;
        print('>>>>recorder $recorder');
        return true;
      }
    } else {
      return false;
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      isRecording = true;
    });
    bool initResult = await initPlayer();
    if(initResult){
      await recorder?.start();
      // 필요하면 log 찍자
      //Recording? recording = await recorder?.current(channel: 0);
      // Timer.periodic(Durations.extralong4, (Timer t) async {
      //   var current = await recording?.status;
      //     print('>>>> current $current');
      // });
    }
  }

  Future<void> _stopRecording() async {
    setState(() {
      isRecording = false;
    });
    var result = await recorder?.stop();
    print( 'path saved audio ${result?.path}');
  }

  Future<void> _playRecording() async {

  }

  @override
  void dispose() {
    // Be careful : you must `close` the audio session when you have finished with it.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Visibility(
          visible: !isRecording,
          child: ElevatedButton(
            onPressed: _startRecording,
            child: const Icon(Icons.fiber_manual_record),
          ),
        ),
        Visibility(
          visible: isRecording,
          child: ElevatedButton(
            onPressed: _stopRecording,
            child: const Icon(Icons.stop),
          ),
        ),
        Visibility(
          visible: !isRecording && fileName!='',
          child: ElevatedButton(
            onPressed: _playRecording,
            child: const Icon(Icons.play_arrow),
          ),
        ),
        Text(
          '녹음파일 : $fileName',
        ),
      ],
    );
  }
}

class AudioUploadPage extends StatefulWidget {
  final String title;

  const AudioUploadPage({super.key, required this.title});

  @override
  State<AudioUploadPage> createState() => _AudioUploadPage();
}

class _AudioUploadPage extends State<AudioUploadPage>{
  final List<Board> boards = [];

  final TextEditingController _messageController = TextEditingController();

  String? storedAccessToken;
  String? storedTel;

  bool isLoading = false;

  AudioRecorderWidget recorder = const AudioRecorderWidget();

  _AudioRecorderWidgetState? recorderState; // Declare the recorder variable

  @override
  void initState(){
    super.initState();
    init();
  }

  void init() async {
    await loadUserInfoFromSharedPreferences();
    if(storedAccessToken!= null && storedAccessToken != '') loadDataFromServer();
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
      var response = await http.post(Uri.parse('${AppConstants.apiBaseUrl}/api/board/list'),
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

  // Audio 와 message  함께 전송
  void _sendAudio() async {
    if(storedAccessToken == null || storedAccessToken == '') {
      print(">>>> not login state");
      return;
    }

    String? filePath =  recorderState?.getFilePath();
    print('uploading audio file,  filepath:$filePath');
    if(filePath == null){
      print('uploading audio, filePath null');
      return;
    }

    String strMessage= "Audio 파일";
    if(_messageController.text.isNotEmpty) {
      strMessage = _messageController.text;
      _messageController.text = '';
    }

    var uploader = Uploader(strMessage, storedAccessToken!, storedTel!, "AUDIO", filePath);
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
                  minHeight:50,
                  maxHeight: 50,
                ),
                child: Container(
                  color: Colors.grey,
                  child: recorder,
                ),
              ),
              Expanded(
                child: Center(
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : BoardListView(boards: boards, onBoardTap: (int index) {
                    // Handle the tapped board index here
                    if (kDebugMode) {
                      print('Tapped board index: ${boards[index].boardId}');
                    }
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
                      onPressed: _sendAudio,
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
                child: const Icon(Icons.arrow_back),
              ),
            ],
          ),
        ),
      ),
    );
  }
}