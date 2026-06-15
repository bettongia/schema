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

import 'package:betto_abnf/betto_abnf.dart';

/// The separator used in language tags (`-`).
const defaultSeparator = '-';

/// A language tag as defined in [RFC 5646](https://www.rfc-editor.org/info/rfc5646).
///
/// A language tag ("Tag") is a sequence of one or more subtags ("Subtag"),
/// separated by a hyphen (`-`).
///
/// Some example language tags:
///
/// - `en`: The ISO 639-1 code for English
/// - `en-AU`: adds the ISO 3166-1 alpha-2 region code for Australia
///
/// Language tags are not case sensitive but the following guidance
/// is recommended:
///
/// - language tags are lowercase
/// - region subtags are UPPERCASE
/// - script subtags are Title Case
/// - all other subtags are lowercase
///
/// This class will convert values to meet that guidance.
sealed class LanguageTag {
  String get type;

  String get tag;

  @override
  bool operator ==(Object other) {
    if (other is LanguageTag) {
      return other.toString() == toString();
    }
    return false;
  }

  @override
  int get hashCode => toString().hashCode;

  /// Parses a language tag string into a [LanguageTag] variant.
  ///
  /// Returns the parsed [LanguageTag] — one of [LangTag], [GrandfatheredTag],
  /// or [PrivateUseTag] — or `null` if [tag] is empty or syntactically invalid.
  static LanguageTag? tryParse(
    String tag, {
    String separator = defaultSeparator,
  }) {
    if (tag.isEmpty) {
      return null;
    }

    // Attempt to parse the tag using the RFC 5646 grammar.
    final result = rfc5646LanguageTag.parse(tag);

    if (!result.success) {
      return null;
    }

    // RFC 5646 defines specific rules for grandfathered and private use tags.
    // Grandfathered tags are explicitly listed and may map to a standard tag.
    if (result.getRuleLexemes('grandfathered').isNotEmpty) {
      final regular = result.getRuleLexemes('regular').isNotEmpty;
      return GrandfatheredTag._(tag, regular);
    } else if (result.getRuleLexemes('privateuse').isNotEmpty) {
      // Private use tags start with 'x-' and are for experimental or personal use.
      return PrivateUseTag._(tag);
    }

    // Standard RFC 5646 tags must have at least a primary language subtag.
    final language = result.getRuleLexemes('language').firstOrNull;

    if (language == null) {
      return null;
    }

    // Construct the LangTag from the parsed subtag lexemes.
    final langtag = LangTag._(
      language,
      extendedLanguageSubtags: result.getRuleLexemes('extlang').firstOrNull,
      script: result.getRuleLexemes('script').firstOrNull,
      region: result.getRuleLexemes('region').firstOrNull,
      variant: result.getRuleLexemes('variant').firstOrNull,
      extension: result.getRuleLexemes('extension').firstOrNull,
      privateuse: result.getRuleLexemes('privateuse').firstOrNull,
    );

    return langtag;
  }

  static bool isValid(String value) => tryParse(value) != null;

  // TODO: Canonicalization as per https://www.rfc-editor.org/rfc/rfc5646.html#section-4.5

  // Returns a new [LanguageTag] with the last subtag removed.
  // https://www.rfc-editor.org/rfc/rfc5646.html#section-4.4.2
  // TODO LanguageTag truncate() {}
}

/// A normal language tag as per RFC 5646
class LangTag implements LanguageTag {
  @override
  final type = 'langtag';

  /// ISO 639-\[1|2|3|5\] language code
  final String language;

  /// ISO 639 code
  final String? extendedLanguageSubtags;

  /// ISO 15924 code
  final String? script;

  /// ISO 3166-1 or UN M.49 code
  final String? region;
  final String? variant;
  final String? extension;
  final String? privateuse;

  //final bool _validRfc5646;

  String? _rendered;

  @override
  String get tag => toString();

  LangTag._(
    String language, {
    this.extendedLanguageSubtags,
    String? script,
    String? region,
    this.variant,
    this.extension,
    this.privateuse,
  }) : language = language.toLowerCase(),
       region = region?.toUpperCase(),
       script = script != null
           ? '${script[0].toUpperCase()}${script.substring(1).toLowerCase()}'
           : null;

  bool get isValid {
    return false;
  }

  @override
  String toString() {
    var result = _rendered;
    if (result == null) {
      result = [
        language,
        if (extendedLanguageSubtags != null) extendedLanguageSubtags,
        if (script != null) script,
        if (region != null) region,
        if (variant != null) variant,
        if (extension != null) extension,
        if (privateuse != null) privateuse,
      ].join(defaultSeparator);
      _rendered = result;
    }
    return result;
  }
}

/// A Grandfathered language tag as per RFC 5646
class GrandfatheredTag implements LanguageTag {
  @override
  final type = 'grandfathered';

  @override
  final String tag;

  final bool regular;

  GrandfatheredTag._(this.tag, this.regular);
}

/// A Private Use Tag language tag as per RFC 5646
class PrivateUseTag implements LanguageTag {
  @override
  final type = 'privateuse';

  @override
  final String tag;

  PrivateUseTag._(this.tag);
}

/// The Language Tag syntax as defined in RFC 5646.
///
/// Language tags can match one of the following rules:
///
/// - `langtag`
/// - `privateuse`
/// - `grandfathered`
final rfc5646LanguageTag = grammar(
  'RFC5646 Language Tag',
  rule(
    'Language-Tag',
    alternatives([
      // grandfathered tags are explicitly listed and can map to a `langtag`
      // so we check them before `langtag`
      rfc5646grandfathered,
      // private use tags start with 'x' so check this next
      rfc5646privateuse,
      rfc5646langtag,
    ]),
  ),
);

final rfc5646langtag = rule(
  'langtag',
  concatenation([
    rfc5646language,
    optionalSequence([literal('-'), rfc5646script]),
    optionalSequence([literal('-'), rfc5646region]),
    variableRepetition(concatenation([literal('-'), rfc5646variant])),
    variableRepetition(concatenation([literal('-'), rfc5646extension])),
    optionalSequence([literal('-'), rfc5646privateuse]),
  ]),
);

final rfc5646language = rule(
  'language',
  alternatives([
    concatenation([
      variableRepetition(alpha, min: 2, max: 3),
      negativeLookahead(alphanum),
      optionalSequence([
        concatenation([literal('-'), rfc5646extlang]),
      ]),
    ]),
    concatenation([repetition(alpha, 4), negativeLookahead(alphanum)]),
    concatenation([
      variableRepetition(alpha, min: 5, max: 8),
      negativeLookahead(alphanum),
    ]),
  ]),
);

/// As defined in RFC5646, Section 2.2.2. Extended language subtags
///
///
final rfc5646extlang = rule(
  'extlang',
  concatenation([
    repetition(alpha, 3),
    negativeLookahead(alphanum),
    variableRepetition(
      concatenation([
        literal('-'),
        repetition(alpha, 3),
        negativeLookahead(alphanum),
      ]),
      max: 2,
    ),
  ]),
);

final rfc5646script = rule(
  'script',
  concatenation([repetition(alpha, 4), negativeLookahead(alphanum)]),
);

final rfc5646region = rule(
  'region',
  concatenation([
    alternatives([repetition(alpha, 2), repetition(digit, 3)]),
    negativeLookahead(alphanum),
  ]),
);

final rfc5646variant = rule(
  'variant',
  concatenation([
    alternatives([
      variableRepetition(alphanum, min: 5, max: 8),
      concatenation([digit, repetition(alphanum, 3)]),
    ]),
    negativeLookahead(alphanum),
  ]),
);

final rfc5646singleton = rule(
  'singleton',
  alternatives([
    digit,
    valueRange(0x41, 0x57),
    valueRange(0x59, 0x5A),
    valueRange(0x61, 0x77),
    valueRange(0x79, 0x7A),
  ]),
);

final rfc5646extension = rule(
  'extension',
  concatenation([
    rfc5646singleton,
    variableRepetition(
      concatenation([
        literal('-'),
        variableRepetition(alphanum, min: 2, max: 8),
        negativeLookahead(alphanum),
      ]),
      min: 1,
    ),
  ]),
);

/// As defined in RFC5646, grandfathered tags are still allowed
/// but have generally been deprecated in favour of new subtags
final rfc5646grandfathered = rule(
  'grandfathered',
  alternatives([
    rule('irregular', alternatives(irregular.map((e) => literal(e)))),
    rule('regular', alternatives(regular.map((e) => literal(e)))),
  ]),
);

/// As defined in RFC5646
const irregular = [
  'en-GB-oed',
  'i-ami',
  'i-bnn',
  'i-default',
  'i-enochian',
  'i-hak',
  'i-klingon',
  'i-lux',
  'i-mingo',
  'i-navajo',
  'i-pwn',
  'i-tao',
  'i-tay',
  'i-tsu',
  'sgn-BE-FR',
  'sgn-BE-NL',
  'sgn-CH-DE',
];

/// As defined in RFC5646
const regular = [
  'art-lojban',
  'cel-gaulish',
  'no-bok',
  'no-nyn',
  'zh-guoyu',
  'zh-hakka',
  'zh-min-nan',
  'zh-min',
  'zh-xiang',
];

final rfc5646privateuse = rule(
  'privateuse',
  concatenation([
    literal('x'),
    variableRepetition(
      concatenation([
        literal('-'),
        variableRepetition(alphanum, min: 1, max: 8),
      ]),
      min: 1,
    ),
  ]),
);
