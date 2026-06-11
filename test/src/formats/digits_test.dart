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

import 'package:betto_schema/betto_schema.dart';
import 'package:characters/characters.dart' show StringCharacters;
import 'package:test/test.dart';

void main() {
  final validator = StringFormatValidator()
      .getValidator("digit-string")
      ?.function;
  if (validator == null) {
    throw Exception('Could not find validator');
  }
  group('DigitString', () {
    for (var str in ['9789295055124', '9789295055123']) {
      test('DigitString is valid: $str', () async {
        expect(validator(str), isTrue);
      });
    }

    for (var str in ['9789X295055124', '97892950😀55123']) {
      test('DigitString is not valid: $str', () async {
        expect(validator(str), isFalse);
      });
    }
  });
  group('DigitString', () {
    for (var str in ['9789295055124', '9789295055123']) {
      test('DigitString is valid: $str', () async {
        expect(DigitString.isValid(str), isTrue);
      });
    }

    for (var str in ['9789X295055124', '97892950😀55123']) {
      test('DigitString is not valid: $str', () async {
        expect(DigitString.isValid(str), false);
      });
    }

    test('concat', () async {
      final s1 = DigitString.tryParse('10')!;
      final s2 = DigitString.tryParse('85')!;

      expect(DigitString.concat([s1]), equals(DigitString.tryParse('10')));
      expect(
        DigitString.concat([s1, s2]),
        equals(DigitString.tryParse('1085')),
      );
    });

    test('characters', () async {
      final s1 = DigitString.tryParse('10')!;
      final s2 = DigitString.tryParse('85')!;

      expect(s1.characters, equals('10'.characters));
      expect(s2.characters, equals('85'.characters));
    });

    test('equals and hash', () async {
      final s1 = DigitString.tryParse('10');
      final s2 = DigitString.tryParse('85');
      final s3 = DigitString.tryParse('85');

      expect(s1.hashCode != s2.hashCode, isTrue);
      expect(s2.hashCode == s3.hashCode, isTrue);

      expect(s1 != s2, isTrue);
      expect(s2 == s3, isTrue);
    });
  });
}
