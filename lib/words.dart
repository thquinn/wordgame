import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wordgame/state.dart';

class Words {
  static Set<String> wordSet = {};
  static List<double> letterDistribution = [];

  static initialize() async {
    final file = await rootBundle.loadString('assets/enable1.txt');
    LineSplitter ls = LineSplitter();
    wordSet = ls.convert(file).toSet();
    print('Initialized word list with ${wordSet.length} words.');
    // Calculate letter distribution.
    final counts = List.filled(26, 0);
    final codeUnitA = 'a'.codeUnitAt(0);
    double total = 0.0;
    for (final word in wordSet) {
      for (final codeUnit in word.codeUnits) {
        counts[codeUnit - codeUnitA]++;
        total++;
      }
    }
    letterDistribution = counts.map((c) => max(c / total, 0.01)).toList();
    debugPrint('Calculated letter distribution: ${jsonEncode(letterDistribution)}');
  }

  static bool isLegal(String word) {
    return wordSet.contains(word.toLowerCase()) == true;
  }

  static List<ProvisionalWord> getProvisionalWords(WordGameState wordGameState) {
    final List<ProvisionalWord> results = [];
    final game = wordGameState.game!;
    final presenceState = wordGameState.presenceState!;
    // Check horizontal and vertical words.
    for (final direction in [Point(1, 0), Point(0, 1)]) {
      final toCheck = presenceState.provisionalTiles.keys.toList();
      while (toCheck.isNotEmpty) {
        String word = '';
        final Set<String> usernames = { presenceState.username };
        // Find the leftmost tile of the word.
        Point<int> point = toCheck.first;
        while (game.state.placedTiles.containsKey(point) || presenceState.provisionalTiles.containsKey(point)) {
          point -= direction;
        }
        point += direction;
        // Put the letters and usernames together.
        while (game.state.placedTiles.containsKey(point) || presenceState.provisionalTiles.containsKey(point)) {
          word += game.state.placedTiles[point]?.letter ?? presenceState.provisionalTiles[point]!;
          if (game.state.placedTiles.containsKey(point)) {
            usernames.add(game.state.placedTiles[point]!.username);
          }
          toCheck.remove(point);
          point += direction;
        }
        if (word.length > 1) {
          results.add(ProvisionalWord(word, usernames.toList()));
        }
      }
    }
    return results;
  }
}

class ProvisionalWord {
  final String word;
  final List<String> usernames;

  ProvisionalWord(this.word, this.usernames);
}