import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.title});

  final String title;

  @override
  State<LoginPage> createState() => _LoginPage();
}

class _LoginPage extends State<LoginPage> {

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _toPrevious() {
    Navigator.pop(context);
  }

  void _login() async{
    BuildContext localContext = context;
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String id = _idController.text;
    String password = _passwordController.text;
    if (kDebugMode) {
      print('ID: $id, Password: $password');
    }

    Map<String, String> requestBody = {
      'tel': id,
      'password': password,
    };

    var response = await http.post(Uri.parse('http://10.100.203.62:8080/getToken'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if(response.statusCode == 200){
      if (kDebugMode) {
        print('login success');
        Map<String, dynamic> responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        await prefs.setString("accessToken", responseBody["accessToken"]);
        await prefs.setString("tel", responseBody["tel"]);
        await prefs.setString("role", responseBody["role"]);
        if (mounted) Navigator.pop(localContext, true);
      }
    } else {
      if (kDebugMode) {
        print('login fail');
        print('Response body: ${response.body}');
        if (mounted) {
          showDialog(
            context: localContext,
            builder: (BuildContext localContext) {
              return AlertDialog(
                title: const Text('Login Failed'),
                content: const Text('Invalid credentials. Please try again.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(localContext).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home : Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(widget.title),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'ID',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('Login'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            child: Row(
              children:[
                const Icon(Icons.access_time_filled),
                const Icon(Icons.star),
                ElevatedButton(
                  onPressed: _toPrevious,
                  child: const Text('돌아가기')
                ),
              ],
            ),
          ),
        )
    );
  }
}