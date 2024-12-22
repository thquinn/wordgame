import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wordgame/connect_screen.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';
import 'package:wordgame/words.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://fyrmyugxmmimjdcitwjo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5cm15dWd4bW1pbWpkY2l0d2pvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzM0NjUyMzQsImV4cCI6MjA0OTA0MTIzNH0.vPDmJnFivLEWZSBYjWZv-tsipMPp2ADqS43XcS7lVrk',
  );
  await Words.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WordGameState(),
      child: MaterialApp(
        title: 'Wordgame',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Color.fromRGBO(95, 95, 177, 1)),
          fontFamily: 'Solway',
          cardTheme: CardTheme(elevation: 2),
          inputDecorationTheme: InputDecorationTheme(contentPadding: EdgeInsets.all(10), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
          scrollbarTheme: ScrollbarThemeData(thickness: WidgetStatePropertyAll(0)),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final connectScreen = ConnectScreen();
  final gameWidget = GameWidget(game: WordGame());

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<WordGameState>();
    if (!appState.isConnected()) {
      return connectScreen;
    }
    return gameWidget;
  }
}
