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

// Tests for the keywords added in plan_json_schema_missing_keywords:
//   contains / minContains / maxContains
//   prefixItems / items (boolean form)
//   patternProperties
//   additionalProperties (schema form) and parser guard removal

import 'package:betto_schema/betto_schema.dart';
import 'package:test/test.dart';

void main() {
  final parser = SchemaParser();

  /// Helper: parse [schema] and validate [value] at the root path.
  List<SchemaViolation> validate(Map<String, dynamic> schema, dynamic value) =>
      parser.parse(schema).validate(value, '');

  // ── contains / minContains / maxContains ───────────────────────────────────

  group('contains', () {
    test('one matching element — passes (default minContains: 1)', () {
      expect(
        validate(
          {
            'contains': {'type': 'integer'},
          },
          [1, 'a', 'b'],
        ),
        isEmpty,
      );
    });

    test('zero matching elements — fails (default minContains: 1)', () {
      final v = validate(
        {
          'contains': {'type': 'integer'},
        },
        ['a', 'b', 'c'],
      );
      expect(v, isNotEmpty);
      expect(v.first.message, contains('at least 1'));
    });

    test('multiple matching elements — passes', () {
      expect(
        validate(
          {
            'contains': {'type': 'integer'},
          },
          [1, 2, 'x'],
        ),
        isEmpty,
      );
    });

    test('minContains: 0 always passes when no maxContains', () {
      // Even with zero matches the rule is satisfied.
      expect(
        validate(
          {
            'contains': {'type': 'integer'},
            'minContains': 0,
          },
          ['a', 'b', 'c'],
        ),
        isEmpty,
      );
    });

    test('minContains: 0 with maxContains exceeded — fails', () {
      // Zero min but max of 1; three integers → exceeds max.
      final v = validate(
        {
          'contains': {'type': 'integer'},
          'minContains': 0,
          'maxContains': 1,
        },
        [1, 2, 3],
      );
      expect(v, isNotEmpty);
      expect(v.first.message, contains('at most 1'));
    });

    test('maxContains exceeded — fails', () {
      final v = validate(
        {
          'contains': {'type': 'integer'},
          'maxContains': 2,
        },
        [1, 2, 3],
      );
      expect(v, isNotEmpty);
      expect(v.first.message, contains('at most 2'));
    });

    test('count within range passes', () {
      // minContains:2, maxContains:4 — array has 3 integers.
      expect(
        validate(
          {
            'contains': {'type': 'integer'},
            'minContains': 2,
            'maxContains': 4,
          },
          [1, 2, 3, 'x'],
        ),
        isEmpty,
      );
    });

    test('count below range fails', () {
      final v = validate(
        {
          'contains': {'type': 'integer'},
          'minContains': 3,
          'maxContains': 5,
        },
        [1, 'x', 'y'],
      );
      expect(v, isNotEmpty);
      expect(v.first.message, contains('at least 3'));
    });

    test('count above range fails', () {
      final v = validate(
        {
          'contains': {'type': 'integer'},
          'minContains': 1,
          'maxContains': 2,
        },
        [1, 2, 3],
      );
      expect(v, isNotEmpty);
      expect(v.first.message, contains('at most 2'));
    });

    test('empty schema (contains: {}) matches every element', () {
      // An empty schema is always valid, so every element matches.
      // With minContains:1 (default), the rule passes for any non-empty array.
      expect(validate({'contains': {}}, [1, 'a', null]), isEmpty);
    });

    test('contains: {} with minContains effectively counts all elements', () {
      // minContains:3 means array must have at least 3 elements (all match {}).
      expect(validate({'contains': {}, 'minContains': 3}, [1, 2, 3]), isEmpty);
      expect(validate({'contains': {}, 'minContains': 3}, [1, 2]), isNotEmpty);
    });

    test('non-array value produces no violation', () {
      final schema = {
        'contains': {'type': 'integer'},
      };
      expect(validate(schema, 'hello'), isEmpty);
      expect(validate(schema, 42), isEmpty);
      expect(validate(schema, null), isEmpty);
      expect(validate(schema, {'a': 1}), isEmpty);
    });

    test('violation path matches the array path', () {
      final rule = parser.parse({
        'contains': {'type': 'integer'},
      });
      final v = rule.validate(['a', 'b'], 'items.list');
      expect(v, hasLength(1));
      expect(v.first.path, equals('items.list'));
    });

    test('sub-schema violations are not forwarded to caller', () {
      // The contains check counts matches — inner violations must not leak.
      final v = validate(
        {
          'contains': {'minimum': 10},
        },
        [1, 2, 3],
      ); // all fail minimum:10, so count=0 → one outer violation
      expect(v, hasLength(1));
      expect(v.first.message, contains('at least 1'));
    });
  });

  // ── prefixItems ────────────────────────────────────────────────────────────

  group('prefixItems', () {
    test('each positional schema validated', () {
      final schema = {
        'prefixItems': [
          {'type': 'string'},
          {'type': 'integer'},
        ],
      };
      expect(validate(schema, ['hello', 42]), isEmpty);
    });

    test('violation for wrong positional type', () {
      final schema = {
        'prefixItems': [
          {'type': 'string'},
          {'type': 'integer'},
        ],
      };
      final v = validate(schema, ['hello', 'not-int']);
      expect(v, isNotEmpty);
      expect(v.first.path, equals('[1]'));
    });

    test('array shorter than prefix — no violation for unmatched schemas', () {
      // Spec: extra prefix schemas simply do not apply.
      final schema = {
        'prefixItems': [
          {'type': 'string'},
          {'type': 'integer'},
          {'type': 'boolean'},
        ],
      };
      // Only one element — only the first prefix schema is applied.
      expect(validate(schema, ['hello']), isEmpty);
    });

    test('element beyond prefix validated by items schema', () {
      final schema = {
        'prefixItems': [
          {'type': 'string'},
        ],
        'items': {'type': 'integer'},
      };
      // Index 0 must be string (checked by prefixItems), index 1+ by items.
      expect(validate(schema, ['hello', 42, 99]), isEmpty);
    });

    test('element beyond prefix fails items schema', () {
      final schema = {
        'prefixItems': [
          {'type': 'string'},
        ],
        'items': {'type': 'integer'},
      };
      final v = validate(schema, ['hello', 'not-int']);
      expect(v, isNotEmpty);
      expect(v.first.path, equals('[1]'));
    });

    test('element beyond prefix with no items — no constraint', () {
      // items is absent; elements beyond the prefix are unconstrained.
      final schema = {
        'prefixItems': [
          {'type': 'string'},
        ],
      };
      expect(validate(schema, ['hello', 42, true, null]), isEmpty);
    });

    test('items: false with prefixItems rejects elements beyond prefix', () {
      final schema = {
        'prefixItems': [
          {'type': 'string'},
        ],
        'items': false,
      };
      // Index 0 is fine (matched by prefixItems), index 1 is rejected.
      final v = validate(schema, ['hello', 42]);
      expect(v, isNotEmpty);
      expect(v.first.path, equals('[1]'));
    });

    test('items: false without prefixItems rejects any element', () {
      final v = validate({'items': false}, [1, 2, 3]);
      expect(v, hasLength(3));
      expect(v[0].path, equals('[0]'));
      expect(v[1].path, equals('[1]'));
      expect(v[2].path, equals('[2]'));
    });

    test('items: true always passes (no constraint)', () {
      expect(validate({'items': true}, [1, 'a', null, {}]), isEmpty);
    });

    test('prefixItems independent of minItems and maxItems', () {
      final schema = {
        'prefixItems': [
          {'type': 'string'},
          {'type': 'integer'},
        ],
        'minItems': 1,
        'maxItems': 5,
      };
      // Length 2 satisfies both bounds; both prefix schemas validated.
      expect(validate(schema, ['hi', 3]), isEmpty);
    });

    test('prefixItems with minItems violation', () {
      final v = validate(
        {
          'prefixItems': [
            {'type': 'string'},
          ],
          'minItems': 2,
        },
        ['hi'],
      );
      // minItems fails, but prefixItems passes for index 0.
      expect(v, isNotEmpty);
      expect(v.any((e) => e.message.contains('at least 2 items')), isTrue);
    });

    test('non-array value produces no violation', () {
      final schema = {
        'prefixItems': [
          {'type': 'string'},
        ],
      };
      expect(validate(schema, 'hello'), isEmpty);
      expect(validate(schema, 42), isEmpty);
      expect(validate(schema, null), isEmpty);
    });

    test('path for nested prefixItems violation uses bracket notation', () {
      final rule = parser.parse({
        'prefixItems': [
          {'type': 'integer'},
          {'type': 'string'},
        ],
      });
      final v = rule.validate([
        1,
        2,
      ], ''); // index 1: integer given, string expected
      expect(v, isNotEmpty);
      expect(v.first.path, equals('[1]'));
    });

    test('items: false with empty array produces no violations', () {
      // No elements → nothing to reject.
      expect(validate({'items': false}, []), isEmpty);
    });

    test(
      'items: false with prefixItems and array exactly at prefix — passes',
      () {
        // Array length equals prefix length → no elements beyond prefix → no
        // items: false violation.
        final schema = {
          'prefixItems': [
            {'type': 'string'},
            {'type': 'integer'},
          ],
          'items': false,
        };
        expect(validate(schema, ['hello', 42]), isEmpty);
      },
    );
  });

  // ── patternProperties ──────────────────────────────────────────────────────

  group('patternProperties', () {
    test('property matched by one pattern — validated', () {
      final schema = {
        'patternProperties': {
          r'^str_': {'type': 'string'},
        },
      };
      expect(validate(schema, {'str_name': 'Alice'}), isEmpty);
    });

    test('property matched by one pattern — wrong type fails', () {
      final schema = {
        'patternProperties': {
          r'^str_': {'type': 'string'},
        },
      };
      final v = validate(schema, {'str_count': 42});
      expect(v, isNotEmpty);
      expect(v.first.path, equals('str_count'));
    });

    test('property matched by multiple patterns — all schemas applied', () {
      // Key 'ab' matches both '^a' and 'b$'.
      final schema = {
        'patternProperties': {
          '^a': {'minLength': 3}, // 'ab' has length 2, fails
          r'b$': {'type': 'string'}, // 'ab' is a string, passes
        },
      };
      final v = validate(schema, {'ab': 'ab'});
      expect(v, isNotEmpty);
      expect(v.any((e) => e.message.contains('at least 3 characters')), isTrue);
    });

    test('property not matching any pattern — no violation', () {
      final schema = {
        'patternProperties': {
          r'^str_': {'type': 'string'},
        },
      };
      // 'count' does not start with 'str_' → no constraint applied.
      expect(validate(schema, {'count': 42}), isEmpty);
    });

    test('pattern matching is unanchored — partial match on name passes', () {
      // Pattern 'oo' matches 'foobar' because it occurs as a substring.
      final schema = {
        'patternProperties': {
          'oo': {'type': 'string'},
        },
      };
      expect(validate(schema, {'foobar': 'hello'}), isEmpty);
      final v = validate(schema, {'foobar': 42});
      expect(v, isNotEmpty);
    });

    test('invalid patternProperties regex key throws FormatException', () {
      expect(
        () => parser.parse({
          'patternProperties': {
            r'[invalid': {'type': 'string'},
          },
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('multiple violations from multiple patterns are all surfaced', () {
      // Key 'abc' matches '^a' (fails minLength:5) and 'c$' (fails type:integer).
      final schema = {
        'patternProperties': {
          '^a': {'minLength': 5},
          r'c$': {'type': 'integer'},
        },
      };
      final v = validate(schema, {'abc': 'hi'});
      expect(v.length, greaterThanOrEqualTo(2));
    });

    test('non-object value produces no violation', () {
      final schema = {
        'patternProperties': {
          r'\d+': {'type': 'string'},
        },
      };
      expect(validate(schema, 'hello'), isEmpty);
      expect(validate(schema, 42), isEmpty);
      expect(validate(schema, null), isEmpty);
      expect(validate(schema, [1, 2, 3]), isEmpty);
    });

    test('violation path uses dot-notation for matched property', () {
      final rule = parser.parse({
        'patternProperties': {
          r'^num': {'type': 'integer'},
        },
      });
      final v = rule.validate({'num_val': 'not-int'}, 'obj');
      expect(v, hasLength(1));
      expect(v.first.path, equals('obj.num_val'));
    });

    test('interaction with additionalProperties: false', () {
      // Properties matching a pattern are NOT additional.
      final schema = {
        'patternProperties': {
          r'^f': {'type': 'string'},
        },
        'additionalProperties': false,
      };
      // 'foo' matches '^f' — not additional.
      expect(validate(schema, {'foo': 'hello'}), isEmpty);
      // 'bar' does not match '^f' and is not declared — additional, rejected.
      final v = validate(schema, {'bar': 'world'});
      expect(v, isNotEmpty);
    });
  });

  // ── additionalProperties as a schema ───────────────────────────────────────

  group('additionalProperties (schema form)', () {
    test('additional property valid against schema — passes', () {
      final schema = {
        'properties': {
          'name': {'type': 'string'},
        },
        'additionalProperties': {'type': 'integer'},
      };
      // 'extra' is additional and is an integer — passes.
      expect(validate(schema, {'name': 'Alice', 'extra': 42}), isEmpty);
    });

    test('additional property invalid against schema — fails', () {
      final schema = {
        'properties': {
          'name': {'type': 'string'},
        },
        'additionalProperties': {'type': 'integer'},
      };
      final v = validate(schema, {'name': 'Alice', 'extra': 'not-int'});
      expect(v, isNotEmpty);
      expect(v.first.path, equals('extra'));
    });

    test('declared properties key is not re-validated by additionalProperties', () {
      // 'name' is declared in properties; additionalProperties must not touch it.
      final schema = {
        'properties': {
          'name': {'type': 'string'},
        },
        'additionalProperties': {'type': 'integer'},
      };
      // 'name' is a string — valid per its own schema, not rejected as "not integer"
      // by additionalProperties because it is a declared key.
      expect(validate(schema, {'name': 'Alice'}), isEmpty);
    });

    test(
      'patternProperties-matched key not re-validated by additionalProperties',
      () {
        final schema = {
          'patternProperties': {
            r'^f': {'type': 'string'},
          },
          'additionalProperties': {'type': 'integer'},
        };
        // 'foo' matches '^f' — not additional. Its value 'hello' is a string
        // (valid per pattern schema, and NOT re-checked as an integer).
        expect(validate(schema, {'foo': 'hello'}), isEmpty);
      },
    );

    test(
      'additionalProperties: false with no properties — rejects every key',
      () {
        // No properties declared → every key is additional → all rejected.
        final v = validate(
          {'additionalProperties': false},
          {'any': 1, 'key': 2},
        );
        expect(v, hasLength(2));
      },
    );

    test(
      'additionalProperties schema with no properties — validates every key',
      () {
        // No properties declared → every key is additional → schema applied.
        final v = validate(
          {
            'additionalProperties': {'type': 'integer'},
          },
          {'a': 1, 'b': 'not-int'},
        );
        expect(v, hasLength(1));
        expect(v.first.path, equals('b'));
      },
    );

    test('key matched by both properties and pattern is not re-validated', () {
      // 'name' is in both properties and matches pattern '^n'.
      // additionalProperties must not apply to it at all.
      final schema = {
        'properties': {
          'name': {'type': 'string'},
        },
        'patternProperties': {
          r'^n': {'minLength': 1},
        },
        'additionalProperties': {'type': 'integer'},
      };
      // 'name' = 'Alice': valid per properties (string) and minLength (1).
      // additionalProperties (integer) must not touch 'name'.
      expect(validate(schema, {'name': 'Alice'}), isEmpty);
    });

    test(
      'additionalProperties: false with patternProperties — extra key rejected',
      () {
        final schema = {
          'patternProperties': {
            r'^f': {'type': 'string'},
          },
          'additionalProperties': false,
        };
        // 'foo' → matches '^f' → not additional → allowed.
        // 'bar' → no match, no declared property → additional → rejected.
        final v = validate(schema, {'foo': 'hi', 'bar': 'world'});
        expect(v, hasLength(1));
        expect(v.first.path, equals('bar'));
      },
    );

    test('additionalProperties: false with no properties or patterns', () {
      // Without properties or patternProperties every key is additional.
      final v = validate({'additionalProperties': false}, {'x': 1});
      expect(v, hasLength(1));
      expect(v.first.path, equals('x'));
    });

    test('non-object value produces no violation', () {
      final schema = {
        'additionalProperties': {'type': 'string'},
      };
      expect(validate(schema, 'text'), isEmpty);
      expect(validate(schema, 42), isEmpty);
      expect(validate(schema, null), isEmpty);
      expect(validate(schema, [1, 2]), isEmpty);
    });

    test('violation path uses dot-notation', () {
      final rule = parser.parse({
        'additionalProperties': {'type': 'integer'},
      });
      final v = rule.validate({'x': 'not-int'}, 'obj');
      expect(v, hasLength(1));
      expect(v.first.path, equals('obj.x'));
    });
  });

  // ── Integration: multiple new keywords together ────────────────────────────

  group('integration — new keywords combined', () {
    test('prefixItems + items + contains', () {
      // First element must be string, subsequent elements must be integers,
      // and at least one integer must be > 10.
      final schema = {
        'prefixItems': [
          {'type': 'string'},
        ],
        'items': {'type': 'integer'},
        'contains': {'minimum': 10},
      };
      expect(validate(schema, ['hello', 5, 15]), isEmpty);
    });

    test('patternProperties + properties + additionalProperties schema', () {
      final schema = {
        'properties': {
          'name': {'type': 'string'},
        },
        'patternProperties': {
          r'^tag_': {'type': 'string'},
        },
        'additionalProperties': {'type': 'integer'},
      };
      // 'name' → properties, 'tag_color' → patternProperties, 'score' → additional integer.
      expect(
        validate(schema, {'name': 'Alice', 'tag_color': 'red', 'score': 10}),
        isEmpty,
      );
      // 'score' as string → fails additionalProperties type:integer.
      final v = validate(schema, {
        'name': 'Alice',
        'tag_color': 'red',
        'score': 'high',
      });
      expect(v, isNotEmpty);
      expect(v.first.path, equals('score'));
    });

    test('contains with minContains + maxContains + type constraint', () {
      final schema = {
        'type': 'array',
        'contains': {'type': 'string'},
        'minContains': 1,
        'maxContains': 3,
      };
      expect(validate(schema, [1, 'a', 2, 'b']), isEmpty); // 2 strings in range
      final v = validate(schema, [1, 2, 3]); // 0 strings → below min
      expect(v, isNotEmpty);
    });
  });
}
