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

import 'package:betto_schema/schema.dart';
import 'package:test/test.dart';

void main() {
  group('Isbn13', () {
    const validIsbn978 = '9789295055124';
    const invalidIsbn978 = '9789295055123';
    const validIsbn979 = '9791091275002'; // French ISBN

    test('validate returns true for valid ISBN 13', () {
      expect(
        Isbn13.validateChecksum(DigitString.extract(validIsbn978)),
        isTrue,
      );
      expect(
        Isbn13.validateChecksum(DigitString.extract(validIsbn979)),
        isTrue,
      );
    });

    test('validate returns false for invalid check digit', () {
      expect(
        Isbn13.validateChecksum(DigitString.extract(invalidIsbn978)),
        isFalse,
      );
    });

    test('validate returns false for incorrect length', () {
      expect(
        Isbn13.validateChecksum(DigitString.extract('978929505512')),
        isFalse,
      );
      expect(
        Isbn13.validateChecksum(DigitString.extract('97892950551244')),
        isFalse,
      );
    });

    test('isValid correctly identifies validity', () {
      expect(Isbn13.isValid(validIsbn978), isTrue);
      expect(Isbn13.isValid(validIsbn979), isTrue);
      expect(Isbn13.isValid(invalidIsbn978), isFalse);
      expect(Isbn13.isValid('not an isbn'), isFalse);
      expect(Isbn13.isValid('12345678901234567890123'), isFalse); // > 22 chars
    });

    test('tryParse handles various input formats', () {
      final inputs = [
        '978-92-95055-12-4',
        'ISBN 978-92-95055-12-4',
        '978 92 95055 12 4',
        'ISBN 978 92 95055 12 4',
        '9789295055124',
      ];
      for (final input in inputs) {
        final result = Isbn13.tryParse(input);
        expect(result, isNotNull);
      }
    });

    test('tryParse supports Prefix 979', () {
      final result = Isbn13.tryParse('979-10-91275-00-2');
      expect(result, isNotNull);
    });

    test('tryParse fails for invalid prefix', () {
      // 9779295055125 has a valid check digit (5) but invalid prefix (977)
      final result = Isbn13.tryParse('9779295055125');
      expect(result, isNull);
    });

    test('toString formats correctly', () {
      final result = Isbn13.tryParse(validIsbn978);

      expect(result.toString(), '9789295055124');
    });

    test('toDigitString returns full 13 digits', () {
      final result = Isbn13.tryParse(validIsbn978);
      expect(result.toString(), validIsbn978);
    });

    test('calculateIsbn13CheckDigit returns correct digit', () {
      final input = DigitString.extract('9789295055124');
      expect(Isbn13.calculateIsbn13CheckDigit(input), 4);

      final zeroCheckInput = DigitString.extract('9786110000000');
      expect(Isbn13.calculateIsbn13CheckDigit(zeroCheckInput), 0);

      final invalidLen = DigitString.extract('978929505512');
      expect(Isbn13.calculateIsbn13CheckDigit(invalidLen), isNull);
    });
  });
}
