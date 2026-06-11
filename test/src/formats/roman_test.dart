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

import 'package:betto_schema/betto_schema.dart'
    show StringFormatValidator, RomanNumerals;
import 'package:test/test.dart';

// Refer to https://en.wikipedia.org/wiki/Roman_numerals
void main() {
  group('RomanNumerals validator  tests', () {
    final validator = StringFormatValidator()
        .getValidator("roman-numeral")
        ?.function;
    if (validator == null) {
      throw Exception('Could not find validator');
    }
    group('Invalid parameters', () {
      test('Empty string', () async {
        expect(validator(''), isFalse);
      });

      test('Invalid type', () async {
        expect(validator('1'), isFalse);
      });

      test('Invalid string', () async {
        expect(validator('Z'), isFalse);
      });
    });

    group('Single numerals', () {
      test('I', () async {
        expect(validator('I'), isTrue);
      });

      test('V', () async {
        expect(validator('V'), isTrue);
      });

      test('X', () async {
        expect(validator('X'), isTrue);
      });

      test('L', () async {
        expect(validator('L'), isTrue);
      });

      test('C', () async {
        expect(validator('C'), isTrue);
      });

      test('D', () async {
        expect(validator('D'), isTrue);
      });

      test('M', () async {
        expect(validator('M'), isTrue);
      });
    });

    group('Standard form', () {
      test('ii', () async {
        expect(validator('ii'), isTrue);
      });

      test('iii', () async {
        expect(validator('iii'), isTrue);
      });

      test('iv', () async {
        expect(validator('iv'), isTrue);
      });

      test('XXXIX', () async {
        expect(validator('XXXIX'), isTrue);
      });

      test('CCXLVI', () async {
        expect(validator('CCXLVI'), isTrue);
      });

      test('DCCLXXXIX', () async {
        expect(validator('DCCLXXXIX'), isTrue);
      });

      test('MMCDXXI', () async {
        expect(validator('MMCDXXI'), isTrue);
      });

      test('CLX', () async {
        expect(validator('CLX'), isTrue);
      });

      test('MMMCMXCIX', () async {
        expect(validator('MMMCMXCIX'), isTrue);
      });
    });

    group('Additive form', () {
      test('iiii', () async {
        expect(validator('iiii'), isTrue);
      });

      test('viiii', () async {
        expect(validator('viiii'), isTrue);
      });

      test('XXIIII', () async {
        expect(validator('XXIIII'), isTrue);
      });
    });

    group(
      'Other forms that are not supported but pass because the validator is simplistic',
      () {
        test('XIIX', () async {
          expect(validator('XIIX'), isTrue);
        });
      },
    );
  });

  group('RomanNumerals class tests', () {
    group('Invalid parameters', () {
      test('Empty string', () async {
        final n = RomanNumerals.tryParse('');
        expect(n, isNull);
      });

      test('Invalid type', () async {
        final n = RomanNumerals.tryParse('1');
        expect(n, isNull);
      });

      test('Invalid string', () async {
        final n = RomanNumerals.tryParse('Z');
        expect(n, isNull);
      });
    });

    group('Single numerals', () {
      test('I', () async {
        final n = RomanNumerals.tryParse('I');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(1));
      });

      test('V', () async {
        final n = RomanNumerals.tryParse('V');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(5));
      });

      test('X', () async {
        final n = RomanNumerals.tryParse('X');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(10));
      });

      test('L', () async {
        final n = RomanNumerals.tryParse('L');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(50));
      });

      test('C', () async {
        final n = RomanNumerals.tryParse('C');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(100));
      });

      test('D', () async {
        final n = RomanNumerals.tryParse('D');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(500));
      });

      test('M', () async {
        final n = RomanNumerals.tryParse('M');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(1000));
      });
    });

    group('Standard form', () {
      test('ii', () async {
        final n = RomanNumerals.tryParse('ii');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(2));
      });

      test('iii', () async {
        final n = RomanNumerals.tryParse('iii');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(3));
      });

      test('iv', () async {
        final n = RomanNumerals.tryParse('iv');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(4));
      });

      test('XXXIX', () async {
        final n = RomanNumerals.tryParse('XXXIX');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(39));
      });

      test('CCXLVI', () async {
        final n = RomanNumerals.tryParse('CCXLVI');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(246));
      });

      test('DCCLXXXIX', () async {
        final n = RomanNumerals.tryParse('DCCLXXXIX');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(789));
      });

      test('MMCDXXI', () async {
        final n = RomanNumerals.tryParse('MMCDXXI');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(2421));
      });

      test('CLX', () async {
        final n = RomanNumerals.tryParse('CLX');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(160));
      });

      test('MMMCMXCIX', () async {
        final n = RomanNumerals.tryParse('MMMCMXCIX');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(3999));
      });
    });

    group('Additive form', () {
      test('iiii', () async {
        final n = RomanNumerals.tryParse('iiii');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(4));
      });

      test('viiii', () async {
        final n = RomanNumerals.tryParse('viiii');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(9));
      });

      test('XXIIII', () async {
        final n = RomanNumerals.tryParse('XXIIII');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(24));
      });
    });

    group('Other forms that are not supported', () {
      test('XIIX', () async {
        final n = RomanNumerals.tryParse('XIIX');
        expect(n, isNotNull);
        expect(n!.toInt(), equals(20));
      });
    });
  });
}
