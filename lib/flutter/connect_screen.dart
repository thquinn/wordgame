import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wordgame/state.dart';

class ConnectScreen extends StatefulWidget {
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final TextEditingController roomController = TextEditingController();
  final usernameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<WordGameState>();
    final roomID = Uri.base.queryParameters['room'];
    if (roomID != null) {
      roomController.value = TextEditingValue(text: roomID);
    }
    SharedPreferences.getInstance().then((prefs) => usernameController.value = TextEditingValue(text: prefs.getString('username') ?? ''));

    join() async {
      if (roomController.text.isNotEmpty && usernameController.text.isNotEmpty) {
        SharedPreferences.getInstance().then((prefs) => prefs.setString('username', usernameController.text));
        await appState.connect(roomController.text, usernameController.text);
      }
    }

    return Scaffold(
      body: Column(
        children: [
          Text('Room ID:'),
          TextField(controller: roomController, autofocus: roomID == null),
          Text('Username:'),
          TextField(controller: usernameController, onSubmitted: (String _) async {await join();}, autofocus: roomID != null),
          ElevatedButton(onPressed: join, child: const Text('Join')),
        ],
      ),
    );
  }
}
