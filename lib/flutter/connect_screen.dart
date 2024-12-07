import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wordgame/state.dart';

class ConnectScreen extends StatefulWidget {
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final roomController = TextEditingController();
  final usernameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    print('connect screen buildcontext');
    print(context);

    return Scaffold(
      body: Column(
        children: [
          Text('Room ID:'),
          TextField(controller: roomController),
          Text('Username:'),
          TextField(controller: usernameController),
          ElevatedButton(onPressed: () async => {
            if (roomController.text.isNotEmpty && usernameController.text.isNotEmpty) {
              await appState.connect(roomController.text, usernameController.text)
            }
          }, child: const Text('Join')),
        ],
      ),
    );
  }
}
