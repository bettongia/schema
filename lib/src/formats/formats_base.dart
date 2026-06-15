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
import 'dart:collection' show UnmodifiableMapView;

import 'package:intl/intl.dart';
import 'package:uuid/validation.dart';

import 'digit_string.dart';
import 'doi.dart';
import 'duration.dart';
import 'email.dart';
import 'hex.dart';
import 'idn_hostname.dart';
import 'isbn.dart';
import 'ipv6.dart';
import 'lang.dart';
import 'roman.dart';
import 'urn.dart';

export 'digit_string.dart';
export 'doi.dart';
export 'duration.dart';
export 'email.dart';
export 'hex.dart';
export 'idn_hostname.dart';
export 'isbn.dart';
export 'ipv6.dart';
export 'lang.dart';
export 'roman.dart';
export 'urn.dart';

/// An immutable descriptor for a single named string-format validator.
///
/// [name] identifies the format (e.g. `'email'`, `'uri'`, `'uuid'`).
/// [description] is a human-readable explanation of the format.
/// [function] returns `true` if a string value satisfies the format.
class StringValidator {
  final String name;
  final String description;
  final bool Function(String) function;

  StringValidator(this.name, this.description, this.function);
}

/// Provides a registry of named string-format validators.
///
/// Implementations must ensure [supportedValidators] returns an unmodifiable
/// view — callers may enumerate it but must not mutate it.
abstract class StringValidatorService {
  /// All validators indexed by format name.
  ///
  /// The returned map is unmodifiable; calling any mutating method throws
  /// [UnsupportedError].
  UnmodifiableMapView<String, StringValidator> get supportedValidators;

  /// Returns the [StringValidator] for [name], or `null` if unrecognised.
  StringValidator? getValidator(String name);
}

/// The built-in registry of JSON Schema and project-specific format validators.
class StringFormatValidator implements StringValidatorService {
  @override
  UnmodifiableMapView<String, StringValidator> get supportedValidators =>
      UnmodifiableMapView(_supportedValidators);

  @override
  StringValidator? getValidator(String name) => _supportedValidators[name];

  final _supportedValidators = {
    'uri': StringValidator(
      'uri',
      'A string instance is valid against this attribute if it is a valid URI,'
          ' according to RFC 3986. Note: a valid URN (urn: scheme) is also a'
          ' valid URI, so this validator accepts both http URLs and URNs.',
      // Uri.tryParse is intentionally lenient: it accepts all registered URI
      // schemes, including urn:. A URN is a valid URI per RFC 3986.
      (value) => Uri.tryParse(value) != null ? true : false,
    ),
    'urn': StringValidator(
      'urn',
      'A string instance is valid against this attribute if it is a valid URN,'
          ' according to RFC 8141',
      // Urn.tryParse strictly validates URN syntax (urn:<nid>:<nss>).
      // Plain http/https URLs are not URNs and are rejected.
      (value) => Urn.tryParse(value) != null ? true : false,
    ),
    'duration': StringValidator(
      'duration',
      'A string instance is valid against this attribute if it is a valid '
          'representation according to RFC3339',
      Iso8601Duration.isValid,
    ),
    'email': StringValidator(
      'email',
      'A string instance is valid against this attribute if it is a valid '
          'representation of a pragmatic subset of RFC 5322',
      Email.isValid,
    ),
    'lang': StringValidator(
      'lang',
      'A string instance is valid against this attribute if it is a valid '
          'language tag as defined in RFC 5646',
      LanguageTag.isValid,
    ),
    'date-time': StringValidator(
      'date-time',
      'A string instance is valid against this attribute if it is a valid '
          'representation according to the "date-time" ABNF rule in ISO8601',
      (value) => DateTime.tryParse(value) != null ? true : false,
    ),
    'date': StringValidator(
      'date',
      'A string instance is valid against this attribute if it is a valid '
          'representation according to the "date" ABNF rule in RFC3339',
      isValidDate,
    ),
    'time': StringValidator(
      'time',
      'A string instance is valid against this attribute if it is a valid '
          'representation according to the "time" ABNF rule in RFC3339',
      (value) => DateFormat('HH:mm:ss.SSS').tryParseStrict(value) != null,
    ),
    'uuid': StringValidator(
      'uuid',
      'A string instance is valid against this attribute if it is a valid '
          'string representation of a UUID, according to RFC9562',
      (value) => UuidValidation.isValidUUID(fromString: value, noDashes: false),
    ),
    'regex': StringValidator(
      'regex',
      'A regular expression, which SHOULD be valid '
          'according to the ECMA-262 [ecma262] regular expression dialect.',
      isValidRegex,
    ),
    'hex-string': StringValidator(
      'hex-string',
      'The string represents a valid '
          'series of characters for a hexadecimal number',
      HexString.isValid,
    ),
    'digit-string': StringValidator(
      'digit-string',
      'The string represents a valid '
          'series of characters for a decimal number',
      DigitString.isValid,
    ),
    'roman-numeral': StringValidator(
      'roman-numeral',
      'The string represents a valid '
          'series of characters for a Roman numeral',
      RomanNumerals.isValid,
    ),
    'isbn-13': StringValidator(
      'isbn-13',
      'The string represents a valid'
          ' International Standard Book Number (ISBN) if it meets the '
          'required check digit calculation',
      Isbn13.isValid,
    ),
    'doi': StringValidator(
      'doi',
      'The string represents a valid DOI',
      DOI.isValid,
    ),
    'ipv4': StringValidator(
      'ipv4',
      'A string instance is valid against this attribute if it is a valid '
          'IPv4 address according to RFC 2673 §3.2: four decimal octets '
          '0–255 separated by dots. Leading zeros in any octet are rejected '
          'to avoid ambiguous octal interpretation.',
      // Per-octet alternation rejects leading zeros and values > 255 in a
      // single pass without post-processing.
      (value) => RegExp(
        r'^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)'
        r'\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)'
        r'\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)'
        r'\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)$',
      ).hasMatch(value),
    ),
    'ipv6': StringValidator(
      'ipv6',
      'A string instance is valid against this attribute if it is a valid '
          'IPv6 address according to RFC 4291 §2.2. Both full eight-group '
          'and compressed (::) forms are accepted, including IPv4-mapped '
          'addresses. Validation uses a pure-Dart approach (no dart:io) '
          'so that the validator works in browser environments.',
      Ipv6.isValid,
    ),
    'hostname': StringValidator(
      'hostname',
      'A string instance is valid against this attribute if it is a valid '
          'Internet hostname per RFC 1123 §2.1. Labels are composed of '
          'ASCII letters, digits, and hyphens; must not start or end with '
          'a hyphen; must be 1–63 characters each; and the total length '
          'must not exceed 253 characters. Trailing dots are rejected. '
          'Matching is case-insensitive.',
      // Labels: start/end with alphanum, interior may include hyphens.
      // Single-char labels (one alphanumeric) are valid.
      (value) {
        if (value.isEmpty || value.endsWith('.') || value.length > 253) {
          return false;
        }
        final labelPattern = RegExp(
          r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$',
        );
        return value
            .split('.')
            .every((label) => label.isNotEmpty && labelPattern.hasMatch(label));
      },
    ),
    'idn-hostname': StringValidator(
      'idn-hostname',
      'A string instance is valid against this attribute if it is a valid '
          'internationalized hostname per RFC 5890. This is a best-effort '
          'check: ASCII hostnames are validated per RFC 1123; labels '
          'containing Unicode characters are accepted if they satisfy the '
          'structural rules (no leading/trailing hyphen, label ≤ 63 chars, '
          'total ≤ 253 chars). Full IDNA 2008 / Punycode conformance is not '
          'enforced; that requires Punycode processing unavailable in '
          'pure Dart without external dependencies.',
      IdnHostname.isValid,
    ),
    'uri-reference': StringValidator(
      'uri-reference',
      'A string instance is valid against this attribute if it is a valid '
          'URI reference per RFC 3986 §4.1 — either an absolute URI or a '
          'relative reference. The check uses a structural approach: '
          'Uri.tryParse must succeed AND the string must not contain '
          'characters that are illegal in both forms (unescaped spaces, '
          'ASCII control characters, or unencoded angle brackets).',
      (value) {
        // Reject strings containing unescaped spaces, ASCII control
        // characters (0x00–0x1F, 0x7F), or literal angle brackets.
        // These are illegal in both absolute URIs and relative references
        // per RFC 3986, regardless of how permissive Uri.tryParse is.
        if (RegExp(r'[\x00-\x1F\x7F <>\[\]\\^`{|}]').hasMatch(value)) {
          return false;
        }
        return Uri.tryParse(value) != null;
      },
    ),
    'json-pointer': StringValidator(
      'json-pointer',
      'A string instance is valid against this attribute if it is a valid '
          'JSON Pointer per RFC 6901. A JSON Pointer is either an empty '
          'string (pointing to the root document) or a sequence of '
          'reference tokens each prefixed by /. Within a token, ~ must '
          'only appear as ~0 (representing ~) or ~1 (representing /).',
      // Regex: empty string OR one-or-more /token sequences where each
      // token contains any character except ~ (which must be ~0 or ~1).
      (value) => RegExp(r'^(/([^~]|~[01])*)*$').hasMatch(value),
    ),
    'relative-json-pointer': StringValidator(
      'relative-json-pointer',
      'A string instance is valid against this attribute if it is a valid '
          'Relative JSON Pointer per the IETF draft (bhutton). A Relative '
          'JSON Pointer begins with a non-negative integer (no leading zeros '
          'unless the value is 0) followed by either # (referring to the '
          'key/index of the referenced location) or a JSON Pointer '
          '(including the empty string).',
      // Regex breakdown:
      //   (0|[1-9][0-9]*)   — non-negative integer, no leading zeros
      //   (#|(/([^~]|~[01])*)*)  — either '#' or a JSON Pointer
      (value) =>
          RegExp(r'^(0|[1-9][0-9]*)(#|(/([^~]|~[01])*)*)$').hasMatch(value),
    ),
  };
}

bool isValidRegex(String value) {
  try {
    RegExp(value);
  } on FormatException {
    return false;
  }
  return true;
}

bool isValidDate(String value) {
  // Reject anything that isn't strictly YYYY-MM-DD.
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final d = DateTime.tryParse(value);
  if (d == null) return false;
  // Reject overflow dates (e.g. month 13) by re-formatting and comparing.
  final reformatted =
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return reformatted == value;
}
