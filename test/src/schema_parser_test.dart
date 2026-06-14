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

void main() {
  final parser = SchemaParser();

  List<SchemaViolation> validate(Map<String, dynamic> schema, dynamic value) =>
      parser.parse(schema).validate(value, '');

  group('empty schema', () {
    test('accepts any value', () {
      expect(validate({}, 'hello'), isEmpty);
      expect(validate({}, 42), isEmpty);
      expect(validate({}, null), isEmpty);
      expect(validate({}, {'a': 1}), isEmpty);
    });
  });

  group('type', () {
    test('string passes', () {
      expect(validate({'type': 'string'}, 'hello'), isEmpty);
    });
    test('string fails for int', () {
      expect(validate({'type': 'string'}, 42), isNotEmpty);
    });
    test('number passes for int and double', () {
      expect(validate({'type': 'number'}, 3), isEmpty);
      expect(validate({'type': 'number'}, 3.14), isEmpty);
    });
    test('integer passes for int and whole-number double (spec §6.1.1)', () {
      expect(validate({'type': 'integer'}, 3), isEmpty);
      expect(validate({'type': 'integer'}, 1.0), isEmpty);
      expect(validate({'type': 'integer'}, -2.0), isEmpty);
      expect(validate({'type': 'integer'}, 3.14), isNotEmpty);
      // Non-finite doubles must be rejected (regression guard).
      expect(validate({'type': 'integer'}, double.nan), isNotEmpty);
      expect(validate({'type': 'integer'}, double.infinity), isNotEmpty);
    });
    test('boolean', () {
      expect(validate({'type': 'boolean'}, true), isEmpty);
      expect(validate({'type': 'boolean'}, 1), isNotEmpty);
    });
    test('array', () {
      expect(validate({'type': 'array'}, [1, 2]), isEmpty);
      expect(validate({'type': 'array'}, {}), isNotEmpty);
    });
    test('object', () {
      expect(validate({'type': 'object'}, {'a': 1}), isEmpty);
      expect(validate({'type': 'object'}, []), isNotEmpty);
    });
    test('null passes for null only', () {
      expect(validate({'type': 'null'}, null), isEmpty);
      expect(validate({'type': 'null'}, 0), isNotEmpty);
    });
    test('violation path is correct', () {
      final violations = validate({'type': 'string'}, 42);
      expect(violations.first.path, '');
      expect(violations.first.message, contains('string'));
    });

    // Per JSON Schema spec §6.1.1, type may be an array of strings.
    group('array form', () {
      test('accepts value matching any listed type', () {
        expect(
          validate({
            'type': ['string', 'null'],
          }, 'hello'),
          isEmpty,
        );
        expect(
          validate({
            'type': ['string', 'null'],
          }, null),
          isEmpty,
        );
      });

      test('rejects value matching none of the listed types', () {
        expect(
          validate({
            'type': ['string', 'null'],
          }, 42),
          isNotEmpty,
        );
      });

      test('single-element array equivalent to string form', () {
        expect(
          validate({
            'type': ['string'],
          }, 'hi'),
          isEmpty,
        );
        expect(
          validate({
            'type': ['string'],
          }, 42),
          isNotEmpty,
        );
      });
    });
  });

  group('required', () {
    test('all present — passes', () {
      expect(
        validate(
          {
            'required': ['a', 'b'],
          },
          {'a': 1, 'b': 2},
        ),
        isEmpty,
      );
    });
    test('extra fields ok', () {
      expect(
        validate(
          {
            'required': ['a'],
          },
          {'a': 1, 'b': 2},
        ),
        isEmpty,
      );
    });
    test('missing field — violation', () {
      final v = validate(
        {
          'required': ['a', 'b'],
        },
        {'a': 1},
      );
      expect(v.length, 1);
      expect(v.first.message, contains('missing'));
    });
    test('null value satisfies required', () {
      expect(
        validate(
          {
            'required': ['a'],
          },
          {'a': null},
        ),
        isEmpty,
      );
    });
    test('absent field fails required', () {
      expect(
        validate({
          'required': ['a'],
        }, {}),
        isNotEmpty,
      );
    });
    test('path for nested required violation', () {
      final rule = parser.parse({
        'properties': {
          'addr': {
            'required': ['city'],
          },
        },
      });
      final violations = rule.validate({'addr': {}}, '');
      expect(violations.first.path, 'addr.city');
    });
  });

  group('enum', () {
    test('matching value passes', () {
      expect(
        validate({
          'enum': ['a', 'b'],
        }, 'a'),
        isEmpty,
      );
    });
    test('null in enum list', () {
      expect(
        validate({
          'enum': [null, 'x'],
        }, null),
        isEmpty,
      );
    });
    test('non-matching fails', () {
      expect(
        validate({
          'enum': ['a', 'b'],
        }, 'c'),
        isNotEmpty,
      );
    });
  });

  group('numeric constraints', () {
    test('minimum inclusive', () {
      expect(validate({'minimum': 5}, 5), isEmpty);
      expect(validate({'minimum': 5}, 4), isNotEmpty);
    });
    test('maximum inclusive', () {
      expect(validate({'maximum': 10}, 10), isEmpty);
      expect(validate({'maximum': 10}, 11), isNotEmpty);
    });
    test('exclusiveMinimum', () {
      expect(validate({'exclusiveMinimum': 5}, 6), isEmpty);
      expect(validate({'exclusiveMinimum': 5}, 5), isNotEmpty);
    });
    test('exclusiveMaximum', () {
      expect(validate({'exclusiveMaximum': 10}, 9), isEmpty);
      expect(validate({'exclusiveMaximum': 10}, 10), isNotEmpty);
    });
    test('non-numeric value skipped', () {
      expect(validate({'minimum': 5}, 'hello'), isEmpty);
    });
  });

  group('string constraints', () {
    test('minLength passes', () {
      expect(validate({'minLength': 3}, 'abc'), isEmpty);
      expect(validate({'minLength': 3}, 'ab'), isNotEmpty);
    });
    test('maxLength passes', () {
      expect(validate({'maxLength': 5}, 'abc'), isEmpty);
      expect(validate({'maxLength': 5}, 'abcdef'), isNotEmpty);
    });
    test('pattern match — anchored pattern still works', () {
      expect(validate({'pattern': r'^\d+$'}, '123'), isEmpty);
      expect(validate({'pattern': r'^\d+$'}, 'abc'), isNotEmpty);
    });

    // Per JSON Schema spec §6.3.3, patterns are NOT implicitly anchored.
    test('pattern match — mid-string match is valid (spec §6.3.3)', () {
      expect(validate({'pattern': r'foo'}, 'foobar'), isEmpty);
      expect(validate({'pattern': r'foo'}, 'barfoo'), isEmpty);
      expect(validate({'pattern': r'\d+'}, 'abc123'), isEmpty);
      expect(validate({'pattern': r'foo'}, 'bar'), isNotEmpty);
    });
    test('non-string skipped', () {
      expect(validate({'minLength': 3}, 42), isEmpty);
    });
  });

  group('format', () {
    test('valid email', () {
      expect(validate({'format': 'email'}, 'user@example.com'), isEmpty);
    });
    test('invalid email', () {
      expect(validate({'format': 'email'}, 'not-an-email'), isNotEmpty);
    });
    test('valid uuid', () {
      expect(
        validate({'format': 'uuid'}, '550e8400-e29b-41d4-a716-446655440000'),
        isEmpty,
      );
    });
    test('unknown format is ignored', () {
      expect(validate({'format': 'custom-thing'}, 'anything'), isEmpty);
    });
    test('non-string skipped', () {
      expect(validate({'format': 'email'}, 42), isEmpty);
    });

    // uri format: accepts http URLs and valid URNs (a URN is a URI).
    test('uri format accepts http URL', () {
      expect(validate({'format': 'uri'}, 'https://example.com'), isEmpty);
    });
    test('uri format accepts a valid URN (URN is a URI)', () {
      expect(validate({'format': 'uri'}, 'urn:isbn:0451450523'), isEmpty);
    });
    // Note: Uri.tryParse is intentionally lenient — the uri validator is a
    // lenient superset (accepts relative references, bare words, etc.). This
    // is documented behaviour; see plan_json_schema_correctness for rationale.

    // urn format: accepts only URNs, not plain http URLs.
    test('urn format accepts valid URN', () {
      expect(validate({'format': 'urn'}, 'urn:example:foo'), isEmpty);
    });
    test('urn format rejects http URL', () {
      expect(validate({'format': 'urn'}, 'https://example.com'), isNotEmpty);
    });
  });

  group('properties', () {
    test('validates present fields', () {
      final schema = {
        'properties': {
          'name': {'type': 'string'},
          'age': {'type': 'integer'},
        },
      };
      expect(validate(schema, {'name': 'Alice', 'age': 30}), isEmpty);
    });

    test('skips absent fields', () {
      final schema = {
        'properties': {
          'name': {'type': 'string'},
        },
      };
      expect(validate(schema, {}), isEmpty);
    });

    test('violation path includes field name', () {
      final schema = {
        'properties': {
          'age': {'type': 'integer'},
        },
      };
      final violations = validate(schema, {'age': 'thirty'});
      expect(violations.first.path, 'age');
    });

    test('nested properties', () {
      final schema = {
        'properties': {
          'address': {
            'properties': {
              'city': {'type': 'string'},
            },
          },
        },
      };
      final violations = validate(schema, {
        'address': {'city': 42},
      });
      expect(violations.first.path, 'address.city');
    });
  });

  group('additionalProperties: false', () {
    test('allowed fields pass', () {
      final schema = {
        'properties': {
          'name': {'type': 'string'},
        },
        'additionalProperties': false,
      };
      expect(validate(schema, {'name': 'Alice'}), isEmpty);
    });

    test('extra field fails', () {
      final schema = {
        'properties': {
          'name': {'type': 'string'},
        },
        'additionalProperties': false,
      };
      expect(validate(schema, {'name': 'Alice', 'extra': true}), isNotEmpty);
    });

    test('additionalProperties: true (default) allows extras', () {
      final schema = {
        'properties': {
          'name': {'type': 'string'},
        },
      };
      expect(validate(schema, {'name': 'Alice', 'extra': true}), isEmpty);
    });
  });

  group('array constraints', () {
    test('minItems', () {
      expect(validate({'minItems': 2}, [1, 2]), isEmpty);
      expect(validate({'minItems': 2}, [1]), isNotEmpty);
    });
    test('maxItems', () {
      expect(validate({'maxItems': 3}, [1, 2, 3]), isEmpty);
      expect(validate({'maxItems': 3}, [1, 2, 3, 4]), isNotEmpty);
    });
    test('items type check', () {
      final schema = {
        'items': {'type': 'string'},
      };
      expect(validate(schema, ['a', 'b']), isEmpty);
      expect(validate(schema, ['a', 42]), isNotEmpty);
    });
    test('items path includes index', () {
      final schema = {
        'items': {'type': 'string'},
      };
      final violations = validate(schema, ['a', 42]);
      expect(violations.first.path, '[1]');
    });
    test('non-list skipped', () {
      expect(validate({'minItems': 2}, 'hello'), isEmpty);
    });
  });

  group('combined schema', () {
    test('full contact schema — valid', () {
      final schema = {
        'required': ['name', 'email'],
        'properties': {
          'name': {'type': 'string', 'minLength': 1},
          'email': {'type': 'string', 'format': 'email'},
          'age': {'type': 'integer', 'minimum': 0},
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'additionalProperties': false,
      };
      expect(
        validate(schema, {
          'name': 'Alice',
          'email': 'alice@example.com',
          'age': 30,
          'tags': ['vip', 'member'],
        }),
        isEmpty,
      );
    });

    test('full contact schema — multiple violations', () {
      final schema = {
        'required': ['name', 'email'],
        'properties': {
          'name': {'type': 'string', 'minLength': 1},
          'email': {'type': 'string', 'format': 'email'},
        },
        'additionalProperties': false,
      };
      final violations = validate(schema, {'name': '', 'extra': true});
      // missing email (required) + name too short + extra field
      expect(violations.length, greaterThanOrEqualTo(3));
    });
  });
}
