import 'dart:typed_data';

import 'package:flutter/material.dart';

class CustomImageDialog extends StatelessWidget {
  final Uint8List imageData;

  const CustomImageDialog({super.key, required this.imageData});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.memory(
            imageData,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
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