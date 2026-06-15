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

/// Tests for the seven new JSON Schema §7.3 format validators:
/// ipv4, ipv6, hostname, idn-hostname, uri-reference,
/// json-pointer, relative-json-pointer.
void main() {
  final sfv = StringFormatValidator();

  bool validate(String format, String value) =>
      sfv.getValidator(format)!.function(value);

  // ── ipv4 ────────────────────────────────────────────────────────────────────

  group('ipv4', () {
    group('valid', () {
      for (final addr in [
        '0.0.0.0',
        '1.2.3.4',
        '192.168.0.1',
        '10.0.0.1',
        '172.16.254.1',
        '255.255.255.255',
        '0.0.0.255',
        '9.9.9.9',
        '99.99.99.99',
        '199.199.199.199',
        '249.249.249.249',
        '254.254.254.254',
      ]) {
        test('accepts $addr', () => expect(validate('ipv4', addr), isTrue));
      }
    });

    group('invalid', () {
      for (final addr in [
        '',
        '256.0.0.1', // octet out of range
        '1.2.3.256', // last octet out of range
        '1.2.3', // only three octets
        '1.2.3.4.5', // five octets
        '01.0.0.0', // leading zero in first octet
        '1.02.0.0', // leading zero in second octet
        '1.2.03.0', // leading zero in third octet
        '1.2.3.04', // leading zero in fourth octet
        '00.0.0.0', // double leading zero
        '1.2.3.4.', // trailing dot
        '.1.2.3.4', // leading dot
        '1.2.3.-1', // negative octet
        'a.b.c.d', // letters instead of digits
        '192.168.0', // missing octet
        '300.0.0.1', // first octet > 255
        '1.2.3.4/24', // CIDR notation
      ]) {
        test('rejects "$addr"', () => expect(validate('ipv4', addr), isFalse));
      }
    });
  });

  // ── ipv6 ────────────────────────────────────────────────────────────────────

  group('ipv6', () {
    group('valid', () {
      for (final addr in [
        '::', // all-zeros compressed
        '::1', // loopback
        '1::', // leading group only
        '1::2', // groups on both sides of ::
        '::ffff:1.2.3.4', // IPv4-mapped
        '::1.2.3.4', // IPv4-compatible (deprecated but structurally valid)
        '2001:db8:85a3:0:0:8a2e:370:7334', // full eight-group
        '2001:0db8:0000:0000:0000:0000:0000:0001', // full with zeros
        'fe80::1', // link-local
        '2001:db8::1', // common compressed form
        '::ffff:192.168.1.1', // IPv4-mapped with private address
        '64:ff9b::1.2.3.4', // NAT64
        'FFFF:FFFF:FFFF:FFFF:FFFF:FFFF:FFFF:FFFF', // uppercase
        '1:2:3:4:5:6:7:8', // full eight-group low values
        '1:2:3:4:5:6:1.2.3.4', // six hex groups + IPv4
        '::0.0.0.0', // all-zeros IPv4-compatible
        '0:0:0:0:0:0:0:1', // loopback uncompressed
        '0:0:0:0:0:0:0:0', // all-zeros uncompressed
      ]) {
        test('accepts $addr', () => expect(validate('ipv6', addr), isTrue));
      }
    });

    group('invalid', () {
      for (final addr in [
        '', // empty
        '1::2::3', // two :: groups
        ':::1', // triple colon
        '1:2:3:4:5:6:7:8:9', // nine groups
        '1:2:3:4:5:6:7', // only seven groups (no ::)
        'gggg::1', // invalid hex digit
        '12345::1', // five-digit hex group
        '1::2::3::4', // multiple ::
        '1.2.3.4', // plain IPv4 is not IPv6
        '256.0.0.1', // invalid IPv4 tail
        '1:2:3:4:5:6:7:8:1.2.3.4', // too many groups with IPv4 tail
      ]) {
        test('rejects "$addr"', () => expect(validate('ipv6', addr), isFalse));
      }
    });
  });

  // ── hostname ─────────────────────────────────────────────────────────────────

  group('hostname', () {
    group('valid', () {
      for (final host in [
        'example.com',
        'foo.bar.baz',
        'a', // single character label
        'a1', // alphanumeric label
        'my-host', // hyphen in interior
        'xn--nxasmq6b', // ACE-encoded label (looks like ASCII)
        'EXAMPLE.COM', // uppercase — hostname is case-insensitive
        'Example.Com',
        '123.456', // all-numeric labels are valid per RFC 1123
        'foo.bar.baz.qux.example.com',
      ]) {
        test(
          'accepts "$host"',
          () => expect(validate('hostname', host), isTrue),
        );
      }
    });

    group('invalid', () {
      final longLabel = 'a' * 64; // 64 chars — one over the 63-char limit
      final longHost =
          '${'a' * 63}.${'b' * 63}.${'c' * 63}.${'d' * 63}.e'; // > 253

      for (final host in [
        '', // empty
        '-example.com', // leading hyphen in label
        'example-.com', // trailing hyphen in label
        '-', // just a hyphen
        'example..com', // empty label (double dot)
        'example.com.', // trailing dot
        '$longLabel.com', // label > 63 chars
        longHost, // total > 253 chars
        'foo bar.com', // space
        'foo@bar.com', // @ sign
        'foo_bar.com', // underscore (not valid per RFC 1123)
      ]) {
        test(
          'rejects "$host"',
          () => expect(validate('hostname', host), isFalse),
        );
      }
    });
  });

  // ── idn-hostname ──────────────────────────────────────────────────────────

  group('idn-hostname', () {
    group('valid', () {
      for (final host in [
        'example.com', // plain ASCII
        'münchen.de', // German umlaut label
        'xn--nxasmq6b.com', // ACE prefix — accepted as ASCII
        '日本語.jp', // Japanese characters
        'Üniversität.de', // mixed Unicode/ASCII
        'foo-bar.com', // hyphen interior
      ]) {
        test(
          'accepts "$host"',
          () => expect(validate('idn-hostname', host), isTrue),
        );
      }
    });

    group('invalid', () {
      final longIdnLabel = 'a' * 64;

      for (final host in [
        '', // empty
        '-münchen.de', // leading hyphen
        'münchen-.de', // trailing hyphen
        'example.com.', // trailing dot
        '$longIdnLabel.de', // label > 63 chars
        'foo bar.com', // space in label
        'foo@bar.com', // @ sign
      ]) {
        test(
          'rejects "$host"',
          () => expect(validate('idn-hostname', host), isFalse),
        );
      }
    });
  });

  // ── uri-reference ─────────────────────────────────────────────────────────

  group('uri-reference', () {
    group('valid', () {
      for (final ref in [
        'https://example.com',
        'http://example.com/path?q=1#frag',
        '/path/to/resource',
        '../foo',
        '.',
        '#section',
        '', // empty string is a valid relative reference (refers to current doc)
        'urn:isbn:0451450523',
        'mailto:user@example.com',
        'foo',
        'foo/bar',
        '?query',
        '/path?query=value&other=1',
        'https://example.com/path%20with%20encoded%20spaces',
      ]) {
        test(
          'accepts "$ref"',
          () => expect(validate('uri-reference', ref), isTrue),
        );
      }
    });

    group('invalid', () {
      for (final ref in [
        'hello world', // unescaped space
        '\x00', // NUL control character
        '\x1F', // control character
        'foo<bar', // unencoded <
        'foo>bar', // unencoded >
        'path with spaces', // spaces are not allowed unescaped
        'a b', // space
      ]) {
        test(
          'rejects "$ref"',
          () => expect(validate('uri-reference', ref), isFalse),
        );
      }
    });
  });

  // ── json-pointer ──────────────────────────────────────────────────────────

  group('json-pointer', () {
    group('valid', () {
      for (final ptr in [
        '', // root (empty pointer)
        '/foo',
        '/foo/bar',
        '/foo/0',
        '/a~0b', // ~ escaped as ~0
        '/a~1b', // / escaped as ~1
        '/~01', // ~0 then 1 — valid token
        '/foo/bar/baz',
        '/0',
        '/', // pointer to key ""
        '/a/b/c/d',
      ]) {
        test(
          'accepts "$ptr"',
          () => expect(validate('json-pointer', ptr), isTrue),
        );
      }
    });

    group('invalid', () {
      for (final ptr in [
        'foo', // no leading slash (not empty, not /...)
        'foo/bar', // no leading slash
        '/a~2b', // ~2 is an invalid escape sequence
        '/a~', // lone ~ at end
        '/a~3', // ~3 is invalid
        '/~', // lone ~
      ]) {
        test(
          'rejects "$ptr"',
          () => expect(validate('json-pointer', ptr), isFalse),
        );
      }
    });
  });

  // ── relative-json-pointer ─────────────────────────────────────────────────

  group('relative-json-pointer', () {
    group('valid', () {
      for (final ptr in [
        '0', // zero steps up, current location
        '1', // one step up
        '99', // multiple steps up
        '0#', // index/key of current location
        '1#', // index/key of parent
        '0/foo', // zero steps then /foo
        '1/foo', // one step then /foo
        '2/a/b', // two steps then /a/b
        '0/', // zero steps then pointer to ""
        '1/a~0b', // tilde escape in pointer part
        '1/a~1b', // slash escape in pointer part
        '10/foo', // two-digit step count
      ]) {
        test(
          'accepts "$ptr"',
          () => expect(validate('relative-json-pointer', ptr), isTrue),
        );
      }
    });

    group('invalid', () {
      for (final ptr in [
        '', // empty
        '01', // leading zero in integer prefix
        '00', // leading zero
        '#', // # without integer prefix
        '/foo', // no integer prefix (looks like absolute JSON Pointer)
        'a', // non-digit prefix
        '-1', // negative integer
        '1/a~2b', // invalid escape in pointer part
        '1~', // tilde after step count without slash
      ]) {
        test(
          'rejects "$ptr"',
          () => expect(validate('relative-json-pointer', ptr), isFalse),
        );
      }
    });
  });

  // ── StringFormatValidator: new keys registered ────────────────────────────

  group('StringFormatValidator registration', () {
    final validators = StringFormatValidator().supportedValidators;

    for (final format in [
      'ipv4',
      'ipv6',
      'hostname',
      'idn-hostname',
      'uri-reference',
      'json-pointer',
      'relative-json-pointer',
    ]) {
      test('contains "$format"', () => expect(validators, contains(format)));
    }
  });

  // ── Ipv6 class direct tests ───────────────────────────────────────────────

  group('Ipv6.isValid direct', () {
    test(':: is valid (all zeros)', () => expect(Ipv6.isValid('::'), isTrue));
    test('empty string is invalid', () => expect(Ipv6.isValid(''), isFalse));
    test('full 8-group uppercase', () {
      expect(Ipv6.isValid('FFFF:FFFF:FFFF:FFFF:FFFF:FFFF:FFFF:FFFF'), isTrue);
    });
  });

  // ── IdnHostname class direct tests ────────────────────────────────────────

  group('IdnHostname.isValid direct', () {
    test('plain ASCII hostname', () {
      expect(IdnHostname.isValid('example.com'), isTrue);
    });
    test('unicode label', () {
      expect(IdnHostname.isValid('münchen.de'), isTrue);
    });
    test('trailing dot rejected', () {
      expect(IdnHostname.isValid('example.com.'), isFalse);
    });
    test('empty string rejected', () {
      expect(IdnHostname.isValid(''), isFalse);
    });
  });
}
