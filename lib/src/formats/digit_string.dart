// Copyright 2026 The Authors. See the AUTHORS file for details.
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

/// A string that only contains decimal (0-9)digits.
///
/// Does not handle fingers, thumbs or toes.
class DigitString {
  final String value;

  DigitString._(this.value);

  static DigitString? tryParse(String input) {
    var builder = StringBuffer();

    for (var c in input.characters) {
      var val = int.tryParse(c);
      if (val == null) {
        return null;
      }
      builder.write(c);
    }
    return DigitString._(builder.toString());
  }

  /// Extracts decimal digits from a string.
  factory DigitString.extract(String input) {
    var builder = StringBuffer();

    for (var c in input.characters) {
      var val = int.tryParse(c);
      if (val != null) {
        builder.write(c);
      }
    }
    return DigitString._(builder.toString());
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      (other is String && value == other) ||
      (other is DigitString && value == other.value);

  @override
  int get hashCode => value.hashCode;

  int get length => value.length;

  Characters get characters => value.characters;

  DigitString substring(int start, [int? end]) {
    return DigitString._(value.substring(start, end));
  }

  List<int> get intList =>
      value.split('').map((e) => int.parse(e)).toList(growable: false);

  DigitString valueAt(int index) {
    return DigitString._(value[index]);
  }

  int get intValue {
    return int.parse(value);
  }

  static DigitString concat(List<DigitString> values) {
    return DigitString._(values.map((e) => e.value).join(''));
  }

  static bool isValid(String value) => tryParse(value) != null;

  /*
  static bool inRange(DigitString value, DigitString start, DigitString end) {
    var v = value.intValue;
    return v >= start.intValue && v <= end.intValue;
  }
  */
}
