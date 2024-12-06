import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wordgame/flame/camera.dart';
import 'package:wordgame/flame/game.dart';

import 'state.dart';
import 'flame/world.dart';
import 'flutter/connect_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://fyrmyugxmmimjdcitwjo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5cm15dWd4bW1pbWpkY2l0d2pvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzM0NjUyMzQsImV4cCI6MjA0OTA0MTIzNH0.vPDmJnFivLEWZSBYjWZv-tsipMPp2ADqS43XcS7lVrk',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final game = WordGame();

    if (!appState.isConnected()) {
      return ConnectScreen();
    }
    return GameWidget(game: game);
  }
}
