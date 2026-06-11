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

import 'digit_string.dart' show DigitString;

/// An International Standard Book Number (ISBN).
///
/// See:
///
/// - [ISBN Users' Manual](https://www.isbn-international.org/content/isbn-users-manual/29)
/// - [OCLC International Standard Book Number](https://www.oclc.org/bibformats/en/0xx/020.html)
/// - [Administration of the ISBN System](https://isbn-information.com/administration-of-the-isbn-system.html)
class Isbn13 {
  static final gsiPrefixes = const ['978', '979'];

  final DigitString isbn;

  /// The GS1 (formerly EAN) Element (e.g., '978' or '979').
  DigitString get prefix => isbn.substring(0, 3);

  /// The ISBN 13 check digit.
  DigitString get checkDigit => isbn.valueAt(isbn.length - 1);

  Isbn13._(this.isbn);

  @override
  String toString() => isbn.toString();

  static DigitString? _extractISBNString(String input) {
    if (input.characters.length > 22) {
      return null;
    }

    var str = DigitString.extract(input);

    return str.length == 13 ? str : null;
  }

  static Isbn13? tryParse(String input) {
    var isbn = _extractISBNString(input);

    if (isbn == null) {
      return null;
    }

    if (!_validatePrefix(isbn)) {
      return null;
    }

    if (!validateChecksum(isbn)) {
      return null;
    }

    return Isbn13._(isbn);
  }

  static int? calculateIsbn13CheckDigit(DigitString input) {
    const weights = [1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3];

    var inputList = input.intList;

    if (input.length != 13) {
      return null;
    }

    var sumProd = 0;
    for (var i = 0; i < 12; i++) {
      sumProd += inputList[i] * weights[i];
    }
    return (10 - sumProd % 10) % 10;
  }

  static bool _validatePrefix(DigitString isbn) {
    final prefix = isbn.substring(0, 3).toString();

    if (!gsiPrefixes.contains(prefix)) {
      return false;
    }
    return true;
  }

  /// If [input] is a valid ISBN, returns `true`.
  ///
  /// Refer to
  /// [APPENDIX 1 Check digit calculation](https://www.isbn-international.org/content/isbn-users-manual/29)
  static bool validateChecksum(DigitString isbn) {
    if (isbn.length != 13) {
      return false;
    }

    var checkDigit = isbn.valueAt(12);

    return calculateIsbn13CheckDigit(isbn) == checkDigit.intValue;
  }

  static bool isValid(String value) => tryParse(value) != null;
}
