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
import 'isbn.dart';
import 'lang.dart';
import 'roman.dart';
import 'urn.dart';

export 'digit_string.dart';
export 'doi.dart';
export 'duration.dart';
export 'email.dart';
export 'hex.dart';
export 'isbn.dart';
export 'lang.dart';
export 'roman.dart';
export 'urn.dart';

class StringValidator {
  final String name;
  final String description;
  final bool Function(String) function;

  StringValidator(this.name, this.description, this.function);
}

abstract class StringValidatorService {
  Map<String, StringValidator> get supportedValidators;
  StringValidator? getValidator(String name);
}

class StringFormatValidator implements StringValidatorService {
  @override
  Map<String, StringValidator> get supportedValidators =>
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
      'lamg',
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
