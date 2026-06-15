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

/// Best-effort IDN hostname validator (RFC 5890 §2.3.2.3).
///
/// **Important:** This is a pragmatic approximation, not a full IDNA 2008 /
/// Punycode conformance check. Full IDNA 2008 conformance requires Punycode
/// encoding and Unicode normalization that are not available in a pure-Dart
/// context without external dependencies. This validator accepts:
///
/// - Any ASCII hostname valid under RFC 1123 (see `hostname` format).
/// - Labels that contain Unicode letters or digits (Unicode categories L and N)
///   in addition to ASCII alphanumerics and hyphens, with the same structural
///   rules (no leading/trailing hyphen, label ≤ 63 chars, total ≤ 253 chars).
///
/// This catches clearly invalid inputs (empty labels, leading/trailing hyphens,
/// oversized labels, oversized total) without requiring Punycode processing.
library;

/// A single ASCII hostname label per RFC 1123.
///
/// A label must:
/// - Start and end with a letter or digit (ASCII).
/// - Contain only letters, digits, or hyphens.
/// - Be between 1 and 63 characters.
///
/// Single-character labels (a letter or digit alone) are also valid.
final RegExp _asciiLabel = RegExp(
  r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$',
);

/// Validates IDN hostnames with a best-effort Unicode label check.
///
/// This is a pragmatic best-effort validator (not full IDNA 2008 / Punycode
/// conformance). It accepts ASCII hostnames and hostnames whose labels contain
/// Unicode letters or digits while still enforcing the RFC 1123 structural
/// rules (label length, total length, no leading/trailing hyphen).
///
/// Example:
/// ```dart
/// IdnHostname.isValid('example.com');   // true
/// IdnHostname.isValid('münchen.de');    // true  (best-effort: unicode label)
/// IdnHostname.isValid('-bad.com');      // false (leading hyphen)
/// IdnHostname.isValid('a' * 64 + '.com'); // false (label too long)
/// ```
class IdnHostname {
  IdnHostname._();

  /// Returns `true` if [value] is a valid IDN hostname (best-effort check).
  ///
  /// Both ASCII labels and Unicode labels are accepted. The total hostname
  /// length must be ≤ 253 characters. Each label must be ≤ 63 characters.
  /// Labels must not start or end with a hyphen.
  static bool isValid(String value) {
    if (value.isEmpty) return false;

    // Trailing dots are rejected (RFC 1123 host names, not DNS zone-file FQDNs).
    if (value.endsWith('.')) return false;

    // Total length must not exceed 253 characters.
    if (value.length > 253) return false;

    final labels = value.split('.');

    for (final label in labels) {
      if (label.isEmpty) return false;
      if (label.length > 63) return false;

      // Try the ASCII label pattern first.
      if (_asciiLabel.hasMatch(label)) continue;

      // For labels containing non-ASCII characters, apply structural rules:
      // must not start or end with a hyphen, and every character must be a
      // Unicode letter (L), Unicode digit (N), ASCII alphanumeric, or hyphen.
      // NOTE: Dart's RegExp does not support \p{L}/\p{N} Unicode properties
      // natively. We check by rejecting controls and known-invalid characters
      // rather than by allow-listing, then enforce the structural hyphen rule.
      if (!_isValidUnicodeLabel(label)) return false;
    }

    return true;
  }

  /// Validates a single label that may contain Unicode characters.
  ///
  /// Rules enforced:
  /// - Must not start or end with `-`.
  /// - Must not be empty (enforced by the caller).
  /// - Must not contain characters that are ASCII control characters, spaces,
  ///   or the explicitly disallowed set (`@`, `[`, `]`, etc.).
  /// - Must contain at least one non-hyphen character.
  ///
  /// This is a best-effort check. Full IDNA 2008 validation would require
  /// Punycode encoding and Unicode normalization (NFKC).
  static bool _isValidUnicodeLabel(String label) {
    // Must not start or end with a hyphen.
    if (label.startsWith('-') || label.endsWith('-')) return false;

    // Pattern of characters that are explicitly disallowed in any label
    // character position, regardless of Unicode category.
    // This covers ASCII control characters, space, and label-separating /
    // URI-reserved punctuation.
    final disallowed = RegExp(
      r'[\x00-\x1F\x7F !@#$%^&*()=+\[\]{};:",<>/?\\|`~]',
    );
    if (disallowed.hasMatch(label)) return false;

    // The label must contain at least one non-hyphen character.
    if (label.replaceAll('-', '').isEmpty) return false;

    return true;
  }
}
