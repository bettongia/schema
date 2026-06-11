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

import 'package:betto_schema/betto_schema.dart';
import 'package:test/test.dart';

void main() {
  group('DOI', () {
    test('constructor', () {
      final doi = DOI(
        directoryIndicator: DigitString.tryParse('10')!,
        registrantCodes: [DigitString.tryParse('1000')!],
        suffix: '292',
      );
      expect(doi.suffix, '292');
      expect(doi.directoryIndicator.intValue, 10);
      expect(doi.registrantCodes.length, 1);
      expect(doi.registrantCodes[0].intValue, 1000);
      expect(doi.toUri().toString(), 'https://doi.org/10.1000/292');
    });
    test('validate returns a DOI for valid DOI', () {
      final doi = DOI.tryParse('10.1000/292')!;
      expect(doi, isNotNull);
      expect(doi.suffix, '292');
      expect(doi.directoryIndicator.intValue, 10);
      expect(doi.registrantCodes.length, 1);
      expect(doi.registrantCodes[0].intValue, 1000);
      expect(doi.toUri().toString(), 'https://doi.org/10.1000/292');
    });

    test('equality', () {
      final doi1 = DOI.tryParse('10.1000/292')!;
      final doi2 = DOI.tryParse('10.1000/292')!;
      final doi3 = DOI.tryParse('10.1000/291')!;
      expect(doi1 == doi2, isTrue);
      expect(doi1.hashCode == doi2.hashCode, isTrue);
      expect(doi1 == doi3, isFalse);
      expect(doi1.hashCode == doi3.hashCode, isFalse);
    });

    test('syntax errors', () {
      expect(DOI.tryParse('10_1000/292'), isNull);
      expect(DOI.isValid('10_1000/292'), isFalse);

      expect(DOI.isValid('10.1000_292'), isFalse);

      expect(DOI.isValid('10.wrong/292'), isFalse);

      expect(DOI.tryParse('.1000/292'), isNull);

      expect(DOI.tryParse('10.1000/'), isNull);
    });
  });
}
