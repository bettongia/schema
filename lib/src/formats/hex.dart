// Copyright 2026 The Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:characters/characters.dart';

/// Handle a string made up of hexidecimal characters (not witchcraft)
class HexString {
  static const hexValues = {
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
  };

  final String value;

  HexString._(this.value);

  static HexString? tryParse(String input) {
    String test;
    if (input.startsWith('0x')) {
      test = input.substring(2);
    } else {
      test = input;
    }
    for (var c in test.characters) {
      if (!hexValues.contains(c)) {
        return null;
      }
    }
    return HexString._(input);
  }

  static bool isValid(String value) => tryParse(value) != null;

  static int unHex(int c) {
    if ('0'.codeUnitAt(0) <= c && c <= '9'.codeUnitAt(0)) {
      return c - '0'.codeUnitAt(0);
    }
    if ('a'.codeUnitAt(0) <= c && c <= 'f'.codeUnitAt(0)) {
      return c - 'a'.codeUnitAt(0) + 10;
    }
    if ('A'.codeUnitAt(0) <= c && c <= 'F'.codeUnitAt(0)) {
      return c - 'A'.codeUnitAt(0) + 10;
    }
    return 0;
  }
}
