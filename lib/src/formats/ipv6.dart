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

/// IPv6 address format validator (RFC 4291 §2.2).
///
/// Validates IPv6 address strings without using `dart:io`, which is unavailable
/// in some Dart environments (e.g. the browser). The implementation uses a
/// group-counting approach rather than a single monolithic regex, making the
/// logic more readable and the edge-case handling explicit.
///
/// Supported forms:
/// - Full eight-group form: `2001:db8:85a3:0:0:8a2e:370:7334`
/// - All compressed (`::`) positions: `::1`, `1::`, `1::2`, `::`
/// - IPv4-mapped tail: `::ffff:192.168.1.1`
///
/// This is a best-effort structural check, not a full RFC 4291 parser.
library;

/// Pattern matching a single hex group (1–4 hex digits), case-insensitive.
final RegExp _hexGroup = RegExp(r'^[0-9a-fA-F]{1,4}$');

/// Pattern matching a valid IPv4 dotted-quad with no leading zeros in any
/// octet, per the per-octet alternation that rejects values > 255.
final RegExp _ipv4Dotted = RegExp(
  r'^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)'
  r'\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)'
  r'\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)'
  r'\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)$',
);

/// Validates IPv6 address strings (RFC 4291 §2.2).
///
/// Both compressed and uncompressed forms are accepted. Group matching is
/// case-insensitive (e.g. `2001:DB8::1` is valid). The empty string and
/// strings with trailing/leading whitespace are rejected.
///
/// Example:
/// ```dart
/// Ipv6.isValid('::1');             // true  (loopback)
/// Ipv6.isValid('::');              // true  (all-zeros)
/// Ipv6.isValid('::ffff:1.2.3.4'); // true  (IPv4-mapped)
/// Ipv6.isValid('gggg::1');         // false (invalid hex digit)
/// Ipv6.isValid('1::2::3');         // false (two :: groups)
/// ```
class Ipv6 {
  Ipv6._();

  /// Returns `true` if [value] is a syntactically valid IPv6 address string.
  static bool isValid(String value) {
    if (value.isEmpty) return false;

    // At most one '::' is allowed in any IPv6 address.
    final dcCount = '::'.allMatches(value).length;
    if (dcCount > 1) return false;

    final hasDoubleColon = dcCount == 1;

    // Detect an IPv4-mapped tail (e.g. ::ffff:1.2.3.4).
    // The IPv4 portion appears after the last ':' when the string contains a
    // dotted-quad pattern.
    final lastColon = value.lastIndexOf(':');
    if (lastColon >= 0) {
      final tail = value.substring(lastColon + 1);
      if (tail.contains('.')) {
        // The tail looks like an IPv4 address — validate as IPv4-mapped.
        return _validateIpv4Mapped(value, tail, hasDoubleColon);
      }
    }

    // Pure hex form (no IPv4 tail).
    if (hasDoubleColon) {
      return _validateCompressed(value);
    } else {
      return _validateFull(value);
    }
  }

  /// Validates a full (uncompressed) eight-group IPv6 address.
  ///
  /// Expects exactly eight colon-separated hex groups.
  static bool _validateFull(String value) {
    final groups = value.split(':');
    if (groups.length != 8) return false;
    return groups.every(_hexGroup.hasMatch);
  }

  /// Validates a compressed IPv6 address that contains exactly one `::`.
  ///
  /// The `::` expands to fill the remaining groups so the total reaches eight.
  /// Each side of `::` may have zero to six explicit hex groups.
  static bool _validateCompressed(String value) {
    final sides = value.split('::');
    // split('::') on a valid compressed address always produces exactly 2
    // parts (even if one or both are empty strings).
    if (sides.length != 2) return false;

    final left = sides[0].isEmpty ? <String>[] : sides[0].split(':');
    final right = sides[1].isEmpty ? <String>[] : sides[1].split(':');

    // The total explicit groups must leave at least one slot for :: to expand,
    // so at most 6 groups across both sides (8 total − 2 from ::).
    // Exception: '::' alone has 0 explicit groups, which is fine (all zeros).
    if (left.length + right.length > 6) return false;

    return [...left, ...right].every(_hexGroup.hasMatch);
  }

  /// Validates an IPv6 address that has an IPv4 dotted-quad tail.
  ///
  /// Legal forms under RFC 4291 §2.2 rule 3:
  /// ```
  /// x:x:x:x:x:x:d.d.d.d
  /// ```
  /// where there are exactly six hex groups before the IPv4 part, or a
  /// `::` compressed form where the hex groups plus the IPv4 tail account for
  /// the full 128 bits (IPv4 counts as two 16-bit groups).
  ///
  /// [tail] is the portion after the last `:` (the IPv4 address string).
  static bool _validateIpv4Mapped(
    String value,
    String tail,
    bool hasDoubleColon,
  ) {
    // The IPv4 dotted-quad must itself be valid.
    if (!_ipv4Dotted.hasMatch(tail)) return false;

    // Strip the IPv4 tail (plus the preceding colon) to get the hex prefix.
    final prefixWithColon = value.substring(0, value.lastIndexOf(':') + 1);
    // prefixWithColon now ends in ':', e.g. "::ffff:" or "::".

    if (hasDoubleColon) {
      // Split on '::'.
      final dcIndex = prefixWithColon.indexOf('::');
      final leftStr = prefixWithColon.substring(0, dcIndex);
      // The portion after '::' ends in ':', strip the trailing colon.
      final rightStr = prefixWithColon.substring(dcIndex + 2);
      final rightClean = rightStr.endsWith(':')
          ? rightStr.substring(0, rightStr.length - 1)
          : rightStr;

      final left = leftStr.isEmpty ? <String>[] : leftStr.split(':');
      final right = rightClean.isEmpty ? <String>[] : rightClean.split(':');

      // The IPv4 tail counts as 2 hex groups, so at most 4 explicit hex
      // groups are allowed across both sides of '::'.
      if (left.length + right.length > 4) return false;

      return [
        ...left,
        ...right,
      ].every((g) => g.isEmpty || _hexGroup.hasMatch(g));
    } else {
      // No '::'. The prefix must be exactly 6 hex groups separated by ':'.
      // prefixWithColon ends with ':', so split gives a trailing empty string.
      final groups = prefixWithColon
          .split(':')
          .where((s) => s.isNotEmpty)
          .toList();
      if (groups.length != 6) return false;
      return groups.every(_hexGroup.hasMatch);
    }
  }
}
