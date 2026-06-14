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

import 'package:betto_schema/betto_schema.dart' show HexString;
import 'package:characters/characters.dart';
import 'package:betto_schema/src/formats/formats_base.dart'
    show StringFormatValidator;
import 'package:test/test.dart';

void main() {
  final validator = StringFormatValidator()
      .getValidator("hex-string")
      ?.function;
  if (validator == null) {
    throw Exception('Could not find validator');
  }
  group('HexString validator', () {
    var s = '0123456789abcdefABCDEF';
    for (var ch in s.characters) {
      test('Is hex: $ch', () async {
        expect(validator(ch), isTrue);
      });

      var h = '0x$ch';
      test('Is hex: $h', () async {
        expect(validator(h), isTrue);
      });
    }

    var sNon = 'ghijklmnopqrstuvwxyz😀';
    for (var ch in sNon.characters) {
      test('Is not hex: $ch', () async {
        expect(validator(ch), isFalse);
      });

      var h = '0x$ch';
      test('Is not hex: $h', () async {
        expect(validator(h), isFalse);
      });
    }
  });
  group('HexString', () {
    var s = '0123456789abcdefABCDEF';
    for (var ch in s.characters) {
      test('Is hex: $ch', () async {
        expect(HexString.tryParse(ch), isNotNull);
      });

      var h = '0x$ch';
      test('Is hex: $h', () async {
        expect(HexString.tryParse(h), isNotNull);
      });
    }

    var sNon = 'ghijklmnopqrstuvwxyz😀';
    for (var ch in sNon.characters) {
      test('Is not hex: $ch', () async {
        expect(HexString.tryParse(ch), isNull);
      });

      var h = '0x$ch';
      test('Is not hex: $h', () async {
        expect(HexString.tryParse(h), isNull);
      });
    }

    group('isValid', () {
      test('returns true for hex string', () {
        expect(HexString.isValid('deadbeef'), isTrue);
      });

      test('returns false for non-hex string', () {
        expect(HexString.isValid('xyz'), isFalse);
      });
    });

    group('unHex', () {
      test('digit characters 0-9', () {
        expect(HexString.unHex('0'.codeUnitAt(0)), 0);
        expect(HexString.unHex('9'.codeUnitAt(0)), 9);
      });

      test('lowercase a-f', () {
        expect(HexString.unHex('a'.codeUnitAt(0)), 10);
        expect(HexString.unHex('f'.codeUnitAt(0)), 15);
      });

      test('uppercase A-F', () {
        expect(HexString.unHex('A'.codeUnitAt(0)), 10);
        expect(HexString.unHex('F'.codeUnitAt(0)), 15);
      });

      test('non-hex character returns 0', () {
        expect(HexString.unHex('z'.codeUnitAt(0)), 0);
      });
    });
  });
}
