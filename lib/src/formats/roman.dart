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

const romanDigits = <String, int>{
  'i': 1,
  'v': 5,
  'x': 10,
  'l': 50,
  'c': 100,
  'd': 500,
  'm': 1000,
  'I': 1,
  'V': 5,
  'X': 10,
  'L': 50,
  'C': 100,
  'D': 500,
  'M': 1000,
};

/// Represents a basic Roman numeral-based number
///
/// This is a simplistic rendition of handling Roman numerals.
///
/// The apostrophus and the vinculum are not supported. Fractions are not
/// supported.
///
/// See also: [Wikipedia: Roman numerals](https://en.wikipedia.org/wiki/Roman_numerals)
class RomanNumerals {
  final String value;

  RomanNumerals._(this.value);

  /// Creates a new instance
  ///
  /// Only a basic check of [input] is performed - namely that it is
  /// not empty and contains only valid Roman numerals (as defined in
  /// [romanDigits]).
  static RomanNumerals? tryParse(String input) {
    // Check for empty string
    if (input.isEmpty) {
      return null;
    }

    for (final c in input.characters) {
      if (!romanDigits.containsKey(c)) {
        return null;
      }
    }
    return RomanNumerals._(input);
  }

  /// Attempts to evaluate a Roman numeral as an integer
  ///
  /// This function does allow for some variation in valid Roman numerals
  /// (i.e. it will parse "IIII" as the number 4, even though the standard
  /// Roman numeral for 4 is "IV").
  ///
  /// If the input string is empty, it will return a `Failure` with a
  /// [RomanNumeralParseException].
  ///
  /// If the input string contains any characters that are not valid Roman
  /// numerals, it will return a `Failure` with a [RomanNumeralParseException].
  ///
  /// If the input string is a valid Roman numeral, it will return a `Success`
  /// containing a [RomanNumerals] object.
  ///
  /// Example:
  ///
  int? toInt() {
    // go backwards through the digits
    var total = 0;
    var prevDigit = 0;
    final reversed = value.characters.toList().reversed;

    for (final c in reversed) {
      var n = romanDigits[c];

      if (n == null) {
        return null;
      }

      if (n < prevDigit) {
        // e.g. ix
        total -= n;
      } else {
        total += n;
      }
      prevDigit = n;
    }
    return total;
  }

  static bool isValid(String value) => tryParse(value) != null;
}
