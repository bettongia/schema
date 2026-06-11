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

/// An email address.
///
/// See:
///
/// - [RFC 5321](https://www.rfc-editor.org/rfc/rfc5321.html#section-4.1.2)
/// - [RFC 5322](https://www.rfc-editor.org/rfc/rfc5322#section-3.4.1)
class Email {
  final String localPart;
  final String domain;

  Email._({required this.localPart, required this.domain});

  @override
  String toString() => '$localPart@$domain';

  Uri toUri() => Uri(scheme: 'mailto', path: toString());

  static const _localPartRegex =
      r"(?<localPart>[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+)";

  static const _domainRegex =
      r"(?<domain>[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)";

  static const _addrSpec = '$_localPartRegex@$_domainRegex';

  static final _emailRegex = RegExp('^$_addrSpec\$');

  /// Parse [input], returning a valid email address.
  ///
  /// This is based on the HTML Living Standard, section 4.10.5 The input element.
  ///
  /// See: https://html.spec.whatwg.org/multipage/input.html#email-state-(type=email)
  ///
  /// The approach is a pragmatic subset of RFC 5322.
  static Email? tryParse(String input, {int maxInputLength = 30}) {
    if (input.length > maxInputLength) {
      return null;
    }

    var match = _emailRegex.firstMatch(input);
    if (match == null) {
      return null;
    }
    var localPart = match.namedGroup('localPart');
    var domain = match.namedGroup('domain');

    if (localPart == null || domain == null) {
      return null;
    }
    return Email._(localPart: localPart, domain: domain);
  }

  static bool isValid(String value) => tryParse(value) != null;
}
