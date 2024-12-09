import 'dart:convert';

import 'package:flutter/services.dart';

class Words {
  static Set<String>? wordSet;

  static initialize() async {
    final file = await rootBundle.loadString('assets/enable1.txt');
    LineSplitter ls = LineSplitter();
    wordSet = ls.convert(file).toSet();
    print('Initialized word list with ${wordSet!.length} words.');
  }

  static bool isWord(String word) {
    return wordSet?.contains(word.toLowerCase()) == true;
  }
}