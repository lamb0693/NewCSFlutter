import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';

class Uploader {
  final String filePath;
  final String storedAccessToken;
  final String storedTel;
  final String message;
  final String content;

  Uploader( this.message, this.storedAccessToken, this.storedTel,this.content, this.filePath );

  Future<void> upload() async {
    if(storedAccessToken == null ||  storedAccessToken.isEmpty) {
      print(">>>> not login state");
      return;
    } else {
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConstants.apiBaseUrl}/api/board/create'),
        );

        // Set headers
        request.headers['Authorization'] = 'Bearer $storedAccessToken';

        // Add fields to the request
        request.fields['customerTel'] = storedTel;
        request.fields['tel'] = storedTel;
        request.fields['content'] = content;
        request.fields['message'] = message;

        // Add file to the request
        if (filePath != null && filePath.isNotEmpty) {
          var file = await http.MultipartFile.fromPath('file', filePath);
          request.files.add(file);
        }

        var response = await http.Response.fromStream(await request.send());

        if (kDebugMode) {
          print(response.body);
        }
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    }
  }

}