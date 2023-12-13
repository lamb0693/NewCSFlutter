import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioData;
  const AudioPlayerWidget({super.key, required this.audioData});


  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  bool isPlaying = false;

  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    init();

    super.initState();

  }

  init() async {
    _audioPlayer = AudioPlayer(playerId: widget.audioData.hashCode.toString());
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if(mounted){
          setState(() {
            isPlaying = false;
          });
        }
      }
    });
  }

  Future<bool> initPlayer() async {

    return true;
  }

  Future<void> _startPlaying() async {
    var urlSource = DeviceFileSource(widget.audioData);
    await _audioPlayer.play(urlSource);
    if(mounted){
      setState(() {
        isPlaying = true;
      });
    }
  }

  Future<void> _stopPlaying() async {
    await _audioPlayer.stop();
    if(mounted){
      setState(() {
        isPlaying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Visibility(
          visible: !isPlaying,
          child: ElevatedButton(
            onPressed: _startPlaying,
            child: const Icon(Icons.play_arrow_rounded),
          ),
        ),
        Visibility(
          visible: isPlaying,
          child: ElevatedButton(
            onPressed: _stopPlaying,
            child: const Icon(Icons.stop),
          ),
        ),
      ],
    );
  }
}