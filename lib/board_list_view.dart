import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'board.dart';

typedef OnBoardTapCallback = void Function(int index);

class BoardListView extends StatefulWidget {
  final List<Board> boards;
  final OnBoardTapCallback onBoardTap;

  const BoardListView({required this.boards, required this.onBoardTap, super.key});

  @override
  State<BoardListView> createState() => _BoardListViewState();
}

class _BoardListViewState extends State<BoardListView> {
  late List<Board> boards;

  @override
  void initState() {
    super.initState();
    boards = widget.boards;
  }

  void _onTapListView(int index) {
    print('Tapped board: ${boards[index].boardId}');
    widget.onBoardTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: boards.length,
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () => _onTapListView(index) ,
          child : Container(
              height: 50,
              color: Colors.limeAccent,
              child: Column(
                  children : [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: Text(
                              boards[index].name,
                              style: const TextStyle(
                                // Set text styles as needed
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 8,
                          child: Text(
                            boards[index].strUpdatedAt,
                            style: const TextStyle(
                              // Set text styles as needed
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: Text(
                                boards[index].content,
                                style: const TextStyle(
                                  // Set text styles as needed
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 8,
                            child: Text(
                              boards[index].message,
                              style: const TextStyle(
                                // Set text styles as needed
                              ),
                            ),
                          ),
                        ]
                    )
                  ]
              )
          ),
        );

      },
      separatorBuilder: (BuildContext context, int index) => const Divider(),
    );
  }
  
  
}