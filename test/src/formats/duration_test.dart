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
import 'package:test/test.dart';

const validDurationStrings = [
  'PT1S',
  'PT1M',
  'PT1H',
  'P1D',
  'P1DT',
  'PT5H4M3S',
  'P0Y0M0DT5H4M3S',
  'P0Y0M6DT5H4M3S',
  'P6DT5H4M3S',
  'P6DT4M',
  'PT120S',
];

void main() {
  final validator = StringFormatValidator().getValidator("duration")?.function;
  if (validator == null) {
    throw Exception('Could not find validator');
  }
  group('duration validator — valid', () {
    for (final str in validDurationStrings) {
      test('Duration: $str', () async {
        expect(validator(str), isTrue);
      });
    }
  });

  group('duration validator — invalid', () {
    test('rejects string without P prefix', () {
      expect(validator('T1H'), isFalse);
      expect(validator('1H'), isFalse);
    });

    test('rejects string with random garbage', () {
      expect(validator('not-a-duration'), isFalse);
      expect(validator('PXXX'), isFalse);
    });
  });

  group('Iso8601Duration', () {
    test('tryParse returns null for non-P prefix', () {
      expect(Iso8601Duration.tryParse('T1H'), isNull);
    });

    test('tryParse returns null for input exceeding maxInputLength', () {
      const long = 'P11111111111111111111111111'; // 27 chars > default max 24
      expect(Iso8601Duration.tryParse(long), isNull);
    });

    test('tryParse returns null for regex mismatch', () {
      expect(Iso8601Duration.tryParse('PXXX'), isNull);
    });

    test('isValid returns true for valid string', () {
      expect(Iso8601Duration.isValid('PT1S'), isTrue);
    });

    test('isValid returns false for invalid string', () {
      expect(Iso8601Duration.isValid('not-a-duration'), isFalse);
    });

    test('equality: same components are equal', () {
      final a = Iso8601Duration.tryParse('PT5S')!;
      final b = Iso8601Duration.tryParse('PT5S')!;
      expect(a, equals(b));
    });

    test('equality: different components are not equal', () {
      final a = Iso8601Duration.tryParse('PT5S')!;
      final b = Iso8601Duration.tryParse('PT6S')!;
      expect(a, isNot(equals(b)));
    });

    test('equality: not equal to non-Iso8601Duration', () {
      final a = Iso8601Duration.tryParse('PT5S')!;
      expect(a == ('PT5S' as Object), isFalse);
    });

    test('hashCode: equal durations have same hashCode', () {
      final a = Iso8601Duration.tryParse('PT5S')!;
      final b = Iso8601Duration.tryParse('PT5S')!;
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString formats all components', () {
      final d = Iso8601Duration.tryParse('P1Y2M3DT4H5M6S')!;
      expect(d.toString(), 'P1Y2M3DT4H5M6S');
    });

    test('duration returns null when both years and months are set', () {
      final d = Iso8601Duration.tryParse('P1Y2M')!;
      expect(d.duration, isNull);
    });

    test('duration returns a Duration when no years/months', () {
      final d = Iso8601Duration.tryParse('P1DT2H3M4S')!;
      expect(d.duration, isNotNull);
      expect(d.duration, Duration(days: 1, hours: 2, minutes: 3, seconds: 4));
    });
  });
}
