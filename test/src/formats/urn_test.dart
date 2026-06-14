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
import 'package:collection/collection.dart';
import 'package:test/test.dart';

void main() {
  // ── StringFormatValidator: service methods ────────────────────────────────

  group('StringFormatValidator service', () {
    test('supportedValidators contains expected keys', () {
      final validators = StringFormatValidator().supportedValidators;
      expect(validators, contains('uri'));
      expect(validators, contains('urn'));
      expect(validators, contains('email'));
      expect(validators, contains('uuid'));
      expect(validators, contains('date'));
      expect(validators, contains('date-time'));
    });

    test('getValidator returns null for unknown format', () {
      expect(StringFormatValidator().getValidator('no-such-format'), isNull);
    });
  });

  // ── StringFormatValidator: 'uri' and 'urn' ──────────────────────────────────

  group('StringFormatValidator uri', () {
    final validator = StringFormatValidator().getValidator('uri')!.function;

    test('accepts a plain http URL', () {
      expect(validator('https://example.com'), isTrue);
      expect(validator('http://example.com/path?q=1#frag'), isTrue);
    });

    // A URN is a valid URI (urn is a registered URI scheme per RFC 3986),
    // so the uri validator must accept it.
    test('accepts a valid URN (URN is a URI)', () {
      expect(validator('urn:isbn:0451450523'), isTrue);
      expect(validator('urn:example:foo'), isTrue);
    });

    // Note: Uri.tryParse is intentionally lenient — it accepts almost any
    // non-null string, including empty strings and relative references.
    // This is by design; see plan_json_schema_correctness for rationale.
  });

  group('StringFormatValidator urn', () {
    final validator = StringFormatValidator().getValidator('urn')!.function;

    test('accepts a valid URN', () {
      expect(validator('urn:isbn:0451450523'), isTrue);
      expect(validator('urn:example:foo'), isTrue);
    });

    // Plain http/https URLs are not valid URNs (wrong scheme).
    test('rejects an http URL', () {
      expect(validator('https://example.com'), isFalse);
      expect(validator('http://example.com/path'), isFalse);
    });

    test('rejects an empty string', () {
      expect(validator(''), isFalse);
    });
  });

  // ── Urn class ────────────────────────────────────────────────────────────────

  group('urn', () {
    for (var urn in [
      'urn:example:foo',
      'urn:example:a123,z456',
      'URN:example:a123,z456',
      'urn:EXAMPLE:a123,z456',
      'urn:example:1/406/47452/2',
      'urn:example:foo-bar-baz-qux',
    ]) {
      test('Check valid URN: $urn', () async {
        expect(Urn.tryParse(urn), isNotNull);
      });
    }

    ({
      'urn:example:foo': Urn(nid: 'example', nss: 'foo'),
      'urn:example:bar': Urn(nid: 'example', nss: 'bar'),
      'urn:example:1/406/47452/2': Urn(nid: 'example', nss: '1/406/47452/2'),
      'urn:example:bar#baz': Urn(nid: 'example', nss: 'bar', fragment: 'baz'),
    }).forEach((key, value) {
      // Check the NID, NSS and equivalence
      test('URN basic instance check: $key', () async {
        final urn = Urn.tryParse(key);
        expect(urn, isNotNull);
        expect(urn!.nid, equals(value.nid));
        expect(urn.nss, equals(value.nss));
        expect(urn, equals(value));
      });
    });

    for (var urn in [
      'urn:example:foo',
      'urn:example:a123,z456',
      'urn:example:1/406/47452/2',
      'urn:example:foo-bar-baz-qux',
      'urn:example:bar#baz'
          'urn:example:foo-bar-baz-qux?+CCResolve:cc=uk',
      'urn:example:foo-bar-baz-qux?+CCResolve:cc=uk#baz',
    ]) {
      test('Check toString: $urn', () async {
        final result = Urn.tryParse(urn);
        expect(result!.toString(), equals(urn));
      });
    }

    ({
      'urn:example:foo': Urn(nid: 'example', nss: 'foo'),
      'urn:example:bar': Urn(nid: 'example', nss: 'bar'),
      'urn:example:1/406/47452/2': Urn(nid: 'example', nss: '1/406/47452/2'),
      'urn:example:bar#baz': Urn(nid: 'example', nss: 'bar', fragment: 'baz'),
    }).forEach((key, value) {
      // Check the NID, NSS and equivalence
      test('URN basic instance check: $key', () async {
        var urn = Urn.tryParse(key);
        expect(urn, isNotNull);
        expect(urn!.nid, equals(value.nid));
        expect(urn.nss, equals(value.nss));
        expect(urn, equals(value));
      });
    });

    ({
      'urn:example:bar': '',
      'urn:example:bar#': '',
      'urn:example:bar#baz': 'baz',
    }).forEach((key, value) {
      test('URN fragment check: $key', () async {
        var urn = Urn.tryParse(key);
        expect(urn, isNotNull);
        expect(urn!.fragment, equals(value));
      });
    });

    ({
      'urn:example:foo-bar-baz-qux?+CCResolve:cc=uk': 'CCResolve:cc=uk',
      'urn:example:weather?+CCResolve:cc=uk?=op=map&lat=39.56&lon=-104.85':
          'CCResolve:cc=uk',
      'urn:example:weather?+CCResolve:cc=uk?=op=map&lat=39.56&lon=-104.85#boop':
          'CCResolve:cc=uk',
    }).forEach((key, value) {
      test('URN r_component check: $key', () async {
        var urn = Urn.tryParse(key);
        expect(urn, isNotNull);
        expect(urn!.rComponent, equals(value));
      });
    });

    ({
      'urn:example:weather?=op=map&lat=39.56&lon=-104.85&datetime=1969-07-21T02:56:15Z':
          {
            'op': 'map',
            'lat': '39.56',
            'lon': '-104.85',
            'datetime': '1969-07-21T02:56:15Z',
          },
      'urn:example:weather?+CCResolve:cc=uk?=op=map&lat=39.56&lon=-104.85': {
        'op': 'map',
        'lat': '39.56',
        'lon': '-104.85',
      },
      'urn:example:weather?+CCResolve:cc=uk?=op=map&lat=39.56&lon=-104.85#boop':
          {'op': 'map', 'lat': '39.56', 'lon': '-104.85'},
    }).forEach((key, value) {
      test('URN q_component check: $key', () async {
        var urn = Urn.tryParse(key);
        expect(urn, isNotNull);
        expect(MapEquality().equals(urn!.qComponentParameters, value), isTrue);
      });
    });
  });
}
