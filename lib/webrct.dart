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
import 'mypainter.dart';

class WebrtcPage extends StatefulWidget {
  WebrtcPage({super.key, required this.title});

  final String title;

  late IO.Socket socket;

  @override
  State<WebrtcPage> createState() => _WebrtcPage();
}

class _WebrtcPage extends State<WebrtcPage> {
  final SGINAL_SERVER = 'http://10.100.203.62:3002';
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
  late MyPainter painter;

  @override
  void initState() {

    setState(() {
      painter = MyPainter(linesCSR, linesCustomer);
    });

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

  }

  Future connectSocket() async{
    socket = IO.io(SGINAL_SERVER, IO.OptionBuilder().setTransports(['websocket']).build() );
    socket.onConnect((data) => print("connected") );

    socket.on('offer', (offer) async {
      print(' >>>> offer event arrived');
      print(' offer.sdp ${offer['sdp']}');
      print(' offer.type ${offer['type']}');
      // try{
      //   offer = jsonDecode(offer);
      // } catch(e) {
      //   print('>>>> offer : jsonDecode error $offer');
      // }

      await _gotOffer(RTCSessionDescription(offer['sdp'], offer['type']));
      await _sendAnswer();
    });

    // socket.on('answer', (answer) async{
    //   print('answer event arrived');
    //   answer = jsonDecode(answer);
    //   await _gotAnswer(RTCSessionDescription(answer['sdp'], answer['type']));
    // });

    socket.on('ice', (ice) {
      print('>>>> ice event arrived, $ice');
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

    socket.on('linesCSR', (dynamic lines) {
      print("on linesCSR $lines");
       setState(() {
          try {
            linesCSR = (lines as List<dynamic>).map<List<Map<String, double>>>((dynamic line) {
              return (line as List<dynamic>).map<Map<String, double>>((dynamic point) {
                return {
                  'x': (point['x'] as num).toDouble(),
                  'y': (point['y'] as num).toDouble(),
                };
              }).toList();
            }).toList();
            print('>>>> lineCSR in Setting lineCSR : $linesCSR');
          } catch (e) {
            print('Error converting linesCSR: $e');
          }
      });
    });

    socket.on('linesCustomer', (dynamic lines) {
      print(" >>>> on linesCustomer $lines");
      setState(() {
        linesCustomer = (lines as List<dynamic>).map<List<Map<String, double>>>((dynamic line) {
          return (line as List<dynamic>).map<Map<String, double>>((dynamic point) {
            return {
              'x': (point['x'] as num).toDouble(), // Convert 'x' to double
              'y': (point['y'] as num).toDouble(), // Convert 'y' to double
            };
          }).toList();
        }).toList();
        print('>>>> lineCSR in Setting lineCustomer : $linesCustomer');
      });
    });
  }

  void _removePrev() {
    socket.emit('remove_prev_customer_line');
  }

  void _removeAll() {
    socket.emit('remove_all_customer_line');
  }

  Future joinWebrtc() async {
    final config = {
      'iceservers' : [
        {"url" : "stun:stun.l.google.com:19302"},
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
    print('$_localStream');

    //await Future.delayed(const Duration(seconds: 1));

    // Refine video constraints based on desired values
    // final refinedConstraints = {
    //   'audio': true,
    //   'video': {
    //     'facingMode': 'user',
    //     'width': {'min': 256, 'ideal': 256},
    //     'height': {'min': 190, 'ideal': 144},
    //   },
    // };

    _localStream?.getTracks().forEach((track) {
      pc?.addTrack(track, _localStream!);
    });
    print('>>>>  localStream $_localStream');

    setState( () {
      _localRenderer.srcObject = _localStream;
    });

    print('>>>>  _localRenderer  $_localRenderer');

    pc!.onIceCandidate = (ice){
      // _sendIce(ice);

      var iceObject = {
        'candidate': ice.candidate,
        'sdpMid': ice.sdpMid,
        'sdpMLineIndex': ice.sdpMLineIndex,
      };

      socket.emit('ice', iceObject);

      print('sending Ice, $iceObject');
    };


    pc!.onTrack = (event) {
      print('pc on Add remote stream, $event');
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
    print('>>>>  gotOffer executed setting remoteDescripton, $rtcSessionDescription');
    pc!.setRemoteDescription(rtcSessionDescription);
  }

  Future _sendAnswer() async {
    var answer = await pc!.createAnswer();
    pc!.setLocalDescription(answer);
    print('>>>>  sendAnwser executed $answer');

    var answerObject = {
      'sdp': answer.sdp,
      'type': answer.type,
    };

    socket.emit('answer', answerObject);
    //socket.emit('answer', answer);
  }

  // Future _gotAnswer(RTCSessionDescription rtcSessionDescription) async {
  //   print('>>>>  gotAnwser executed, $rtcSessionDescription');
  //   pc!.setRemoteDescription(rtcSessionDescription);
  // }

  Future _sendIce(RTCIceCandidate ice) async {
    print('>>>>  sendIce executed $ice');
    socket.emit('ice', jsonEncode(ice.toMap()));
  }

  Future _gotIce(RTCIceCandidate rtcIceCandidate) async {
    print('>>>>  gotIce executed $rtcIceCandidate');
    pc!.addCandidate(rtcIceCandidate);
  }

  void _toPrevious() async {
    await disconnectSocket();
    if (mounted) Navigator.pop(context);
  }

  // void _enter() async {
  //   socket.emit('create_room', '01031795981');
  //   await joinWebrtc();
  // }

  void  _join() async {
    socket.emit('join_room', 'aaa');
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
                  maxHeight: 200,
                ),
                child: Row(
                  children: [
                    Expanded(child: RTCVideoView(_localRenderer)),
                    Expanded(child: RTCVideoView(_remoteRenderer)),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 400,
                  minHeight: 200,
                  maxHeight: 200,
                ),
                child: Container(
                  color: Colors.grey,
                  child: GestureDetector(
                    onPanDown: (details) {
                      if (painter != null)  {
                        print('on Mouse Down ${details.localPosition}');
                        painter.handleMouseDown(details.localPosition);
                      }
                    },
                    onPanUpdate: (details) {
                      if (painter != null){
                        print('on Mouse Down ${details.localPosition}');
                        painter.handleMouseMove(details.localPosition);
                      }
                      setState(() {});
                    },
                    onPanEnd: (details) {
                      if (painter != null) {
                        painter.handleMouseUp();
                        List<Map<String, dynamic>> currentLine = painter.getCurrentLine();
                        //print(' >>>> on mouse up :  $currentLine');
                        if(socket != null ) {
                          socket.emit('add_customer_line', {'line' : currentLine } );
                        };
                        painter.clearCurrentLine();
                      }
                    },
                    child: CustomPaint(
                      size: Size(400, 200),
                      painter: painter ?? MyPainter([], []),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : BoardListView(boards: boards),
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
                child: const Text('돌아가기'),
              ),
              // ElevatedButton(
              //   onPressed: _enter,
              //   child: const Text('입장'),
              // ),
              ElevatedButton(
                onPressed: _join,
                child: const Text('참가'),
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