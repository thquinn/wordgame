import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:wordgame/model.dart';
import 'package:wordgame/state.dart';
import 'package:wordgame/util.dart';

class Words {
  static Set<String> wordSet = {};
  static List<double> letterDistribution = [];
  static Map<String, int> letterValues = {
    'a': 1, 'b': 2, 'c': 2, 'd': 1, 'e': 1, 'f': 2, 'g': 1, 'h': 2,
    'i': 1, 'j': 3, 'k': 3, 'l': 1, 'm': 1, 'n': 1, 'o': 1, 'p': 2,
    'q': 4, 'r': 1, 's': 1, 't': 1, 'u': 1, 'v': 3, 'w': 2, 'x': 3,
    'y': 2, 'z': 3
  };

  static initialize() async {
    final file = await rootBundle.loadString('assets/words.txt');
    LineSplitter ls = LineSplitter();
    wordSet = ls.convert(file).toSet();
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
    letterDistribution = counts.map((c) => max(c / total, 0.005)).toList(); // all letters should be at least 0.5% of the distribution
  }

  static bool isLegal(String word) {
    return wordSet.contains(word.toLowerCase()) == true;
  }

  static ProvisionalResult getProvisionalResult(WordGameState wordGameState) {
    final List<ProvisionalWord> provisionalWords = [];
    final game = wordGameState.game!;
    final localState = wordGameState.localState!;
    final provisionalTiles = Map<Point<int>, String>.from(localState.provisionalTiles);
    // Check horizontal and vertical words.
    for (final direction in [Point(1, 0), Point(0, 1)]) {
      final toCheck = provisionalTiles.keys.toList();
      while (toCheck.isNotEmpty) {
        String word = '';
        final Set<String> usernames = { localState.username };
        // Find the leftmost tile of the word.
        Point<int> point = toCheck.first;
        while (game.state.placedTiles.containsKey(point) || provisionalTiles.containsKey(point)) {
          point -= direction;
        }
        point += direction;
        // Put the letters and usernames together.
        while (game.state.placedTiles.containsKey(point) || provisionalTiles.containsKey(point)) {
          word += game.state.placedTiles[point]?.letter ?? provisionalTiles[point]!;
          if (game.state.placedTiles.containsKey(point)) {
            usernames.add(game.state.placedTiles[point]!.username);
          }
          toCheck.remove(point);
          point += direction;
        }
        if (word.length > 1) {
          provisionalWords.add(ProvisionalWord(word, usernames.toList()));
        }
      }
    }
    final pickups = game.state.pickups.entries.where((kvp) => provisionalTiles.containsKey(kvp.key)).map((kvp) => kvp.value).toList();
    final coorsBefore = game.state.placedTiles.keys.toSet();
    final coorsAfter = game.state.placedTiles.keys.followedBy(localState.provisionalTiles.keys).toSet();
    final enclosedAreas = Util.findNewEnclosedEmptyAreas(coorsBefore, coorsAfter);
    final largestNewRect = Util.findLargestNewRectangle(coorsBefore, coorsAfter);
    return ProvisionalResult(provisionalTiles, provisionalWords, pickups, enclosedAreas, largestNewRect);
  }
}

class ProvisionalResult {
  final Map<Point<int>, String> provisionalTiles;
  final List<ProvisionalWord> words;
  final List<PickupType> pickups;
  final List<Set<Point<int>>> enclosedAreas;
  final RectInt? largestNewRect;

  ProvisionalResult(this.provisionalTiles, this.words, this.pickups, this.enclosedAreas, this.largestNewRect);

  ProvisionalScore score() {
    int total = 0;
    final List<ProvisionalScoreDisplayLine> displayLines = [];
    final sortedWords = List<ProvisionalWord>.from(words)..sort((a, b) => a.word.length != b.word.length ? b.word.length.compareTo(a.word.length) : a.word.compareTo(b.word));
    for (final word in sortedWords) {
      final line = word.score();
      total += line.score;
      displayLines.add(line);
    }
    for (final area in enclosedAreas) {
      final score = 10 + (pow(area.length, 1.5) / 2.0).floor();
      total += score;
      displayLines.add(ProvisionalScoreDisplayLine(true, score, '', '${area.length} surrounded', score.toString()));
    }
    if (largestNewRect != null) {
      final score = (pow(largestNewRect!.area, 2) / 2.0).floor();
      total += score;
      displayLines.add(ProvisionalScoreDisplayLine(true, score, '', '${largestNewRect!.width}×${largestNewRect!.height} block', score.toString()));
    }
    return ProvisionalScore(total, displayLines);
  }
}

class ProvisionalWord {
  static final List<String?> COLOR_QUALIFIERS = [null, null, 'bicolor', 'tricolor', 'tetracolor', 'quintacolor', 'hexacolor', 'heptacolor', 'octacolor', 'enneacolor', 'decacolor', 'hyperpolycolor'];

  final String word;
  final List<String> usernames;

  ProvisionalWord(this.word, this.usernames);

  ProvisionalScoreDisplayLine score() {
    int baseScore = word.split('').map((char) => Words.letterValues[char] ?? 0).reduce((sum, value) => sum + value);
    if (word.length > 5) {
      baseScore += pow(word.length - 4, 2).floor();
    }
    final valid = Words.isLegal(word);
    final multiplier = usernames.length;
    final score = baseScore * multiplier;
    final qualifierText = multiplier >= 2 ? '(${COLOR_QUALIFIERS[min(multiplier, COLOR_QUALIFIERS.length - 1)]})' : '';
    final scoreText = valid ? (multiplier > 1 ? '$baseScore×$multiplier' : baseScore.toString()) : '×';
    return ProvisionalScoreDisplayLine(valid, score, word, qualifierText, scoreText);
  }

  String? getNotificationQualifier() {
    String? lengthQualifier = word.length >= 8 ? '${word.length}-letter' : null;
    String? colorQualifier = COLOR_QUALIFIERS[min(usernames.length, COLOR_QUALIFIERS.length - 1)];
    if (lengthQualifier != null && colorQualifier != null) return '$lengthQualifier $colorQualifier';
    if (lengthQualifier != null) return lengthQualifier;
    if (colorQualifier != null) return colorQualifier;
    return null;
  }
}

class ProvisionalScore {
  final int total;
  List<ProvisionalScoreDisplayLine> displayLines;

  ProvisionalScore(this.total, this.displayLines);
}
class ProvisionalScoreDisplayLine {
  final bool valid;
  final int score;
  final String wordText, qualifierText, scoreText;

  ProvisionalScoreDisplayLine(this.valid, this.score, this.wordText, this.qualifierText, this.scoreText);
}