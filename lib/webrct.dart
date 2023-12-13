import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_webrtc/flutter_webrtc.dart' ;
import 'package:http/http.dart' as http;

import 'board.dart';
import 'board_list_view.dart';
import 'constants.dart';
import 'mypainter.dart';

class WebrtcPage extends StatefulWidget {
  WebrtcPage({super.key, required this.title});

  final String title;

  late IO.Socket socket;

  @override
  State<WebrtcPage> createState() => _WebrtcPage();
}

class _WebrtcPage extends State<WebrtcPage> {
  late final IO.Socket socket;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? pc;

  late String storedAccessToken;
  late String storedTel;
  bool isLoading = false;
  final TextEditingController _messageController = TextEditingController();
  final List<Board> boards = [];

  List<List<Map<String, double>>> linesCSR = [];
  List<List<Map<String, double>>> linesCustomer = [];
  List<Map<String, double>> currentLine = [];
  late MyPainter painter;
  bool isDrawing =false;
  bool isSocketInitialized = false;


  @override
  void initState() {

    painter = MyPainter(linesCSR, linesCustomer, currentLine);

    init();

    super.initState();
  }

  Future init() async{
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    await connectSocket();

    showList();
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

  Future<void> loadUserInfoFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    storedAccessToken = prefs.getString('accessToken') ?? '';
    storedTel = prefs.getString('tel') ?? '';
    if (kDebugMode) {
      print("storedAccessToken : $storedAccessToken");
    }
  }

  void showList() async {
      await loadUserInfoFromSharedPreferences();
      if (storedAccessToken.isNotEmpty) {
        if (kDebugMode) {
          print("Reload data after login: $storedAccessToken");
        }
        loadDataFromServer();
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
      print(e);
    }

  }

  Future connectSocket() async{
    socket = IO.io(AppConstants.signalSERVER, IO.OptionBuilder().setTransports(['websocket']).build() );
    socket.onConnect((data) => print("connected") );

    socket.on('offer', (offer) async {

      if (kDebugMode) {
        print(' >>>> offer event arrived');
        print(' offer.sdp ${offer['sdp']}');
        print(' offer.type ${offer['type']}');
      }
      await _gotOffer(RTCSessionDescription(offer['sdp'], offer['type']));
      await _sendAnswer();
    });

    // socket.on('answer', (answer) async{
    //   print('answer event arrived');
    //   answer = jsonDecode(answer);
    //   await _gotAnswer(RTCSessionDescription(answer['sdp'], answer['type']));
    // });

    socket.on('ice', (ice) {
      if (kDebugMode) {
        print('>>>> ice event arrived, $ice');
      }
      _gotIce(RTCIceCandidate(
        ice['candidate'],
        ice['sdpMid'],
        ice['sdpMLineIndex'],
      ));
    });

    // socket.on('create_room_result', (data) {
    //   print(' >>>> create_room_result event arrived');
    //   _sendOffer();
    // });

    // socket.on('all_users', (data) {
    //   print('csr_joined event arrived');
    //   _sendOffer();
    // });

    socket.on('linesCSR', (lines) {
      if (kDebugMode) {
        print(" >>>> on linesCSR $lines");
      }

      List<dynamic> decodedList = json.decode(lines);

      // Convert the List<dynamic> to the desired List<List<Map<String, double>>> structure
      List<List<Map<String, double>>> tempLinesCSR =
      decodedList.map<List<Map<String, double>>>((line) {
        return (line as List<dynamic>).map<Map<String, double>>((point) {
          return {
            'x': (point['x'] as num).toDouble(),
            'y': (point['y'] as num).toDouble(),
          };
        }).toList();
      }).toList();

      if (kDebugMode) {
        print('tempLinesCSR : $tempLinesCSR' );
      }

      painter.setLinesCSR([...tempLinesCSR]);
      setState(() {
        linesCSR = [...tempLinesCSR];
      });
    });
  }

  void _removePrev() {
    linesCustomer.removeLast();
    painter.setLinesCustomer([...linesCustomer]);
    setState(() { });
    if (kDebugMode) {
      print('lineCustomer $linesCustomer');
    }
    socket.emit('linesCustomer', {'lines' : linesCustomer});
    //socket.emit('remove_prev_customer_line');
  }

  void _removeAll() {
    linesCustomer.clear();
    painter.setLinesCustomer([...linesCustomer]);
    setState(() { });
    if (kDebugMode) {
      print('lineCustomer $linesCustomer');
    }
    socket.emit('linesCustomer', {'lines' : linesCustomer});
    //socket.emit('remove_all_customer_line');
  }

  Future joinWebrtc() async {
    final config = {
      'iceservers' : [
        {"url" : AppConstants.stunServer},
      ]
    };

    final sdpConstraints = {
      'mandatory' : {
        'OfferToReceiveAudio' : true,
        'OfferToReceiveVideo' : true
      },
      'optional' : [],
    };

    pc = await createPeerConnection(config, sdpConstraints);
    print(' >>>>  createPeerConnection');

    final mediaConstraints = {
      'audio' : true,
      'video' : {
        'facingMode' : 'user',
      }
    };

    _localStream = await Helper.openCamera(mediaConstraints);
    if (kDebugMode) {
      print('$_localStream');
    }

    _localStream?.getTracks().forEach((track) {
      pc?.addTrack(track, _localStream!);
    });
    if (kDebugMode) {
      print('>>>>  localStream $_localStream');
    }

    setState( () {
      _localRenderer.srcObject = _localStream;
    });

    if (kDebugMode) {
      print('>>>>  _localRenderer  $_localRenderer');
    }

    pc!.onIceCandidate = (ice){
      // _sendIce(ice);

      var iceObject = {
        'candidate': ice.candidate,
        'sdpMid': ice.sdpMid,
        'sdpMLineIndex': ice.sdpMLineIndex,
      };

      socket.emit('ice', iceObject);

      if (kDebugMode) {
        print('sending Ice, $iceObject');
      }
    };


    pc!.onTrack = (event) {
      if (kDebugMode) {
        print('pc on Add remote stream, $event');
      }
      setState(() {
        _remoteRenderer.srcObject = event.streams[0];
      });
    };

  }

  // Future _sendOffer() async {
  //   var offer = await pc?.createOffer();
  //   pc!.setLocalDescription(offer!);
  //   print('>>>>  sendOffer executed $offer');
  //   socket.emit('offer', jsonEncode(offer!.toMap()));
  // }

  Future _gotOffer(RTCSessionDescription rtcSessionDescription) async {
    if (kDebugMode) {
      print('>>>>  gotOffer executed setting remoteDescripton, $rtcSessionDescription');
    }
    pc!.setRemoteDescription(rtcSessionDescription);
  }

  Future _sendAnswer() async {
    var answer = await pc!.createAnswer();
    pc!.setLocalDescription(answer);
    if (kDebugMode) {
      print('>>>>  sendAnwser executed $answer');
    }

    var answerObject = {
      'sdp': answer.sdp,
      'type': answer.type,
    };

    socket.emit('answer', answerObject);
  }

  // Future _gotAnswer(RTCSessionDescription rtcSessionDescription) async {
  //   print('>>>>  gotAnwser executed, $rtcSessionDescription');
  //   pc!.setRemoteDescription(rtcSessionDescription);
  // }

  Future _sendIce(RTCIceCandidate ice) async {
    if (kDebugMode) {
      print('>>>>  sendIce executed $ice');
    }
    socket.emit('ice', jsonEncode(ice.toMap()));
  }

  Future _gotIce(RTCIceCandidate rtcIceCandidate) async {
    if (kDebugMode) {
      print('>>>>  gotIce executed $rtcIceCandidate');
    }
    pc!.addCandidate(rtcIceCandidate);
  }

  void _toPrevious() async {
    //await disconnectSocket();
    if (mounted) Navigator.pop(context);
  }

  // void _enter() async {
  //   socket.emit('create_room', '01031795981');
  //   await joinWebrtc();
  // }

  void  _join() async {
    socket.emit('join_room', storedTel);
    await joinWebrtc();
  }


  Future disconnectSocket() async{
    socket.disconnect();
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
                  maxHeight: 150,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          color: Colors.blue,
                          child: RTCVideoView(_localRenderer),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          color: Colors.green,
                          child: RTCVideoView(_remoteRenderer),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 400,
                  minHeight: 150,
                  maxHeight: 150,
                ),
                child: Container(
                  color: Colors.grey,
                  child: GestureDetector(
                    onPanDown: (details) {
                      if (painter != null)  {
                        print('on Mouse Down ${details.localPosition}');
                        isDrawing = true;
                        setState(() {
                          currentLine.add({'x': details.localPosition.dx, 'y': details.localPosition.dy});
                        });
                      }
                    },
                    onPanUpdate: (details) {
                      if (painter != null){
                        print('on Mouse Down ${details.localPosition}');
                        setState(() {
                          currentLine.add({'x': details.localPosition.dx, 'y': details.localPosition.dy});
                        });
                      }
                    },
                    onPanEnd: (details) {
                      if (painter != null) {
                        linesCustomer.add([...currentLine]);
                        currentLine.clear();
                        painter.setLinesCustomer([...linesCustomer]);
                        setState(() { });
                        socket.emit('linesCustomer', {'lines' : linesCustomer});
                      }
                    },
                    child: CustomPaint(
                      size: const Size(400, 150),
                      painter: painter ,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: isLoading
                      ? const CircularProgressIndicator()
                      :BoardListView(boards: boards, onBoardTap: (int index) {
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
                      onPressed: sendMessage,
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
              ElevatedButton(
                onPressed: _join,
                child: const Text('상담원'),
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