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

import 'dart:collection';

import 'package:betto_common/string.dart' show StringExtension;

import 'digit_string.dart' show DigitString;

/// Digital Object Identifier (DOI).
///
/// See: [DOI HANDBOOK](https://www.doi.org/the-identifier/resources/handbook/)
class DOI {
  final DigitString directoryIndicator;
  final List<DigitString> _registrantCodes;
  final String suffix;

  DOI({
    required this.directoryIndicator,
    required List<DigitString> registrantCodes,
    required this.suffix,
  }) : _registrantCodes = [...registrantCodes];

  DOI._(this.directoryIndicator, this._registrantCodes, this.suffix);

  static DOI? tryParse(String value) {
    bool found;
    String prefix, suffix;

    (prefix, suffix, found) = value.cutFirst('/');
    if (!found) {
      return null;
    }

    if (prefix.isEmpty || suffix.isEmpty) {
      return null;
    }

    String directoryIndicatorStr, registrantCode;
    (directoryIndicatorStr, registrantCode, found) = prefix.cutFirst('.');

    if (!found) {
      return null;
    }

    if (directoryIndicatorStr.isEmpty || registrantCode.isEmpty) {
      return null;
    }

    final parseResult = DigitString.tryParse(directoryIndicatorStr);

    if (parseResult != null) {
      DigitString directoryIndicator = parseResult;

      final registrantCodes = _parseRegistrantCode(registrantCode);
      if (registrantCodes == null || registrantCodes.isEmpty) {
        return null;
      }
      final doi = DOI._(directoryIndicator, registrantCodes, suffix);
      return doi;
    }
    return null;
  }

  static List<DigitString>? _parseRegistrantCode(String registrantCode) {
    List<DigitString> registrantCodes = [];

    for (var digit in registrantCode.split('.')) {
      final digits = DigitString.tryParse(digit);
      if (digits == null) {
        return null;
      }
      registrantCodes.add(digits);
    }
    return registrantCodes;
  }

  UnmodifiableListView<DigitString> get registrantCodes =>
      UnmodifiableListView(_registrantCodes);

  // Uri get uri => Uri(scheme: 'https', host: 'doi.org', path: toString());

  /// DOI names are case insensitive.
  ///
  /// See: [DOI Handbook, Section 2.4](https://www.doi.org/the-identifier/resources/handbook/2_numbering#2.4)
  @override
  String toString() =>
      '$directoryIndicator.${_registrantCodes.join('.')}/$suffix'.toUpperCase();

  /// Uses https://doi.org
  Uri toUri() => Uri.https('doi.org', toString());

  @override
  bool operator ==(Object other) =>
      other is DOI && other.toString() == toString();

  @override
  int get hashCode => Object.hashAll([toString()]);

  static bool isValid(String value) => tryParse(value) != null;
}
