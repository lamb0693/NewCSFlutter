import 'dart:core';
import 'dart:ffi';

class Board {
  int boardId;
  String content;
  String message;
  String name;
  String strUpdatedAt;
  String tel;
  bool breplied;


  Board(this.boardId, this.content, this.message, this.name, this.strUpdatedAt,
      this.tel, this.breplied);

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      json['board_id'],
      json['content'],
      json['message'],
      json['name'],
      json['strUpdatedAt'],
      json['tel'],
      json['breplied'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'board_id': boardId,
      'content': content,
      'message': message,
      'name': name,
      'strUpdatedAt': strUpdatedAt,
      'tel': tel,
      'breplied': breplied,
    };
  }
}