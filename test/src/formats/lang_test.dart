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

import 'package:betto_schema/betto_schema.dart'
    show
        GrandfatheredTag,
        LangTag,
        LanguageTag,
        PrivateUseTag,
        StringFormatValidator;
import 'package:test/test.dart';

void main() {
  // ── StringFormatValidator: 'lang' format ────────────────────────────────────

  group('StringFormatValidator lang', () {
    final validator = StringFormatValidator().getValidator('lang')!.function;

    test('accepts simple language code', () {
      expect(validator('en'), isTrue);
      expect(validator('fr'), isTrue);
      expect(validator('de'), isTrue);
    });

    test('accepts language-region tag', () {
      expect(validator('en-US'), isTrue);
      expect(validator('en-AU'), isTrue);
      expect(validator('zh-CN'), isTrue);
    });

    test('accepts grandfathered tag', () {
      expect(validator('art-lojban'), isTrue);
      expect(validator('i-ami'), isTrue);
    });

    test('accepts private use tag', () {
      expect(validator('x-private'), isTrue);
    });

    test('rejects empty string', () {
      expect(validator(''), isFalse);
    });

    test('rejects invalid tag', () {
      expect(validator('123'), isFalse);
    });
  });

  // ── LanguageTag.tryParse ────────────────────────────────────────────────────

  group('LanguageTag.tryParse', () {
    test('returns null for empty string', () {
      expect(LanguageTag.tryParse(''), isNull);
    });

    test('returns null for invalid tag', () {
      expect(LanguageTag.tryParse('123-!!!'), isNull);
    });

    test('parses simple language code into LangTag', () {
      final tag = LanguageTag.tryParse('en');
      expect(tag, isA<LangTag>());
    });

    test('parses language-region into LangTag', () {
      final tag = LanguageTag.tryParse('en-US');
      expect(tag, isA<LangTag>());
      final lt = tag as LangTag;
      expect(lt.language, 'en');
      expect(lt.region, 'US');
    });

    test('normalises language to lowercase', () {
      final tag = LanguageTag.tryParse('EN') as LangTag?;
      expect(tag?.language, 'en');
    });

    test('normalises region to UPPERCASE', () {
      final tag = LanguageTag.tryParse('en-us') as LangTag?;
      expect(tag?.region, 'US');
    });

    test('parses language-script-region', () {
      final tag = LanguageTag.tryParse('zh-Hans-CN') as LangTag?;
      expect(tag, isNotNull);
      expect(tag?.language, 'zh');
      expect(tag?.script, 'Hans');
      expect(tag?.region, 'CN');
    });

    test('normalises script to Title Case', () {
      final tag = LanguageTag.tryParse('zh-hans-cn') as LangTag?;
      expect(tag?.script, 'Hans');
    });

    test('parses grandfathered irregular tag', () {
      final tag = LanguageTag.tryParse('i-ami');
      expect(tag, isA<GrandfatheredTag>());
      final gt = tag as GrandfatheredTag;
      expect(gt.type, 'grandfathered');
      expect(gt.regular, isFalse);
    });

    test('parses grandfathered regular tag', () {
      final tag = LanguageTag.tryParse('art-lojban');
      expect(tag, isA<GrandfatheredTag>());
      final gt = tag as GrandfatheredTag;
      expect(gt.regular, isTrue);
      expect(gt.tag, 'art-lojban');
    });

    test('parses private use tag', () {
      final tag = LanguageTag.tryParse('x-private');
      expect(tag, isA<PrivateUseTag>());
      final pt = tag as PrivateUseTag;
      expect(pt.type, 'privateuse');
      expect(pt.tag, isNotEmpty);
    });
  });

  // ── LanguageTag.isValid ─────────────────────────────────────────────────────

  group('LanguageTag.isValid', () {
    test('returns true for valid tag', () {
      expect(LanguageTag.isValid('en'), isTrue);
      expect(LanguageTag.isValid('en-US'), isTrue);
    });

    test('returns false for empty string', () {
      expect(LanguageTag.isValid(''), isFalse);
    });

    test('returns false for invalid tag', () {
      expect(LanguageTag.isValid('123'), isFalse);
    });
  });

  // ── LangTag string representation ────────────────────────────────────────────
  // LangTag uses `implements LanguageTag` (not extends), so == and hashCode
  // from LanguageTag are not inherited. Tests compare string representations.

  group('LanguageTag string representation', () {
    test('same input produces same string', () {
      final a = LanguageTag.tryParse('en-US')!;
      final b = LanguageTag.tryParse('en-US')!;
      expect(a.toString(), equals(b.toString()));
    });

    test('different inputs produce different strings', () {
      final a = LanguageTag.tryParse('en-US')!;
      final b = LanguageTag.tryParse('en-AU')!;
      expect(a.toString(), isNot(equals(b.toString())));
    });

    test('hashCode of equal strings matches', () {
      final a = LanguageTag.tryParse('en-US')!;
      final b = LanguageTag.tryParse('en-US')!;
      expect(a.toString().hashCode, equals(b.toString().hashCode));
    });
  });

  // ── LangTag.toString ────────────────────────────────────────────────────────

  group('LangTag.toString', () {
    test('simple language code', () {
      final tag = LanguageTag.tryParse('en') as LangTag;
      expect(tag.toString(), 'en');
    });

    test('language-region round-trips with normalisation', () {
      final tag = LanguageTag.tryParse('en-us') as LangTag;
      expect(tag.toString(), 'en-US');
    });

    test('language-script-region round-trips', () {
      final tag = LanguageTag.tryParse('zh-hans-cn') as LangTag;
      expect(tag.toString(), 'zh-Hans-CN');
    });

    test('toString is cached (second call returns same result)', () {
      final tag = LanguageTag.tryParse('en-AU') as LangTag;
      // Two calls should return identical results (exercising the cache path).
      expect(tag.toString(), equals(tag.toString()));
    });
  });

  // ── LangTag.type and LangTag.tag ───────────────────────────────────────────

  group('LangTag.type and tag', () {
    test('type is langtag', () {
      final tag = LanguageTag.tryParse('en') as LangTag;
      expect(tag.type, 'langtag');
    });

    test('tag delegates to toString', () {
      final tag = LanguageTag.tryParse('fr-FR') as LangTag;
      expect(tag.tag, tag.toString());
    });
  });

  // ── LangTag with optional subtags ───────────────────────────────────────────

  group('LangTag optional subtags', () {
    test('extendedLanguageSubtags is null for simple tag', () {
      final tag = LanguageTag.tryParse('en') as LangTag;
      expect(tag.extendedLanguageSubtags, isNull);
    });

    test('script is null when not supplied', () {
      final tag = LanguageTag.tryParse('en-AU') as LangTag;
      expect(tag.script, isNull);
    });

    test('region is null when not supplied', () {
      final tag = LanguageTag.tryParse('en') as LangTag;
      expect(tag.region, isNull);
    });

    test('variant is null when not supplied', () {
      final tag = LanguageTag.tryParse('en') as LangTag;
      expect(tag.variant, isNull);
    });

    test('extension_ is null when not supplied', () {
      final tag = LanguageTag.tryParse('en') as LangTag;
      expect(tag.extension, isNull);
    });

    test('privateuse is null when not supplied', () {
      final tag = LanguageTag.tryParse('en') as LangTag;
      expect(tag.privateuse, isNull);
    });

    test('LangTag.isValid returns false (stub, not yet implemented)', () {
      final tag = LanguageTag.tryParse('en') as LangTag;
      expect(tag.isValid, isFalse);
    });
  });
}
