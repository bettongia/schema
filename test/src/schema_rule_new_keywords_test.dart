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

// Tests for the six keywords added in plan_json_schema_wire_validators:
//   const, multipleOf, uniqueItems, minProperties, maxProperties,
//   dependentRequired.
//
// Each group tests both the SchemaRule directly and the full
// SchemaParser→validate pipeline, verifying that the keywords are reachable
// via the public API.

import 'package:betto_schema/betto_schema.dart';
import 'package:test/test.dart';

void main() {
  final parser = SchemaParser();

  /// Helper: parse [schema] and validate [value] at the root path.
  List<SchemaViolation> validate(Map<String, dynamic> schema, dynamic value) =>
      parser.parse(schema).validate(value, '');

  // ── const ───────────────────────────────────────────────────────────────────

  group('const', () {
    test('primitive string match passes', () {
      expect(validate({'const': 'hello'}, 'hello'), isEmpty);
    });

    test('primitive string mismatch fails', () {
      final v = validate({'const': 'hello'}, 'world');
      expect(v, hasLength(1));
      expect(v.first.message, contains('must be equal to'));
    });

    test('integer match passes', () {
      expect(validate({'const': 42}, 42), isEmpty);
    });

    test('integer mismatch fails', () {
      expect(validate({'const': 42}, 43), isNotEmpty);
    });

    test('const: null accepts null', () {
      expect(validate({'const': null}, null), isEmpty);
    });

    test('const: null rejects non-null', () {
      expect(validate({'const': null}, 'anything'), isNotEmpty);
      expect(validate({'const': null}, 0), isNotEmpty);
      expect(validate({'const': null}, false), isNotEmpty);
    });

    test('const: false accepts false, rejects 0 and null', () {
      expect(validate({'const': false}, false), isEmpty);
      expect(validate({'const': false}, 0), isNotEmpty);
      expect(validate({'const': false}, null), isNotEmpty);
    });

    test('nested object deep equality passes', () {
      expect(
        validate(
          {
            'const': {
              'a': 1,
              'b': [2, 3],
            },
          },
          {
            'a': 1,
            'b': [2, 3],
          },
        ),
        isEmpty,
      );
    });

    test('nested object structural mismatch fails', () {
      expect(
        validate(
          {
            'const': {'a': 1},
          },
          {'a': 2},
        ),
        isNotEmpty,
      );
    });

    test('nested array deep equality passes', () {
      expect(
        validate(
          {
            'const': [1, 2, 3],
          },
          [1, 2, 3],
        ),
        isEmpty,
      );
    });

    test('nested array structural mismatch fails', () {
      expect(
        validate(
          {
            'const': [1, 2, 3],
          },
          [1, 2, 4],
        ),
        isNotEmpty,
      );
    });

    test('deeply nested structure passes', () {
      final value = {
        'x': [
          1,
          {'y': 'z'},
        ],
      };
      expect(
        validate(
          {'const': value},
          {
            'x': [
              1,
              {'y': 'z'},
            ],
          },
        ),
        isEmpty,
      );
    });

    test('deeply nested structure fails when inner value differs', () {
      final schema = {
        'x': [
          1,
          {'y': 'z'},
        ],
      };
      expect(
        validate(
          {'const': schema},
          {
            'x': [
              1,
              {'y': 'DIFFERENT'},
            ],
          },
        ),
        isNotEmpty,
      );
    });

    test('violation path is the field path', () {
      // At nested path 'a.b' the violation path should reflect the path given.
      final rule = parser.parse({'const': 'expected'});
      final v = rule.validate('actual', 'a.b');
      expect(v, hasLength(1));
      expect(v.first.path, equals('a.b'));
    });
  });

  // ── multipleOf ──────────────────────────────────────────────────────────────

  group('multipleOf', () {
    test('integer divisible by integer passes', () {
      expect(validate({'multipleOf': 3}, 9), isEmpty);
      expect(validate({'multipleOf': 3}, 0), isEmpty);
      expect(validate({'multipleOf': 3}, -6), isEmpty);
    });

    test('integer not divisible by integer fails', () {
      final v = validate({'multipleOf': 3}, 7);
      expect(v, hasLength(1));
      expect(v.first.message, contains('must be a multiple of'));
    });

    test('float divisor — 0.3 is a multiple of 0.1 (IEEE-754 safe)', () {
      // Naive modulo: 0.3 % 0.1 ≈ 2.77e-17 (not exactly 0), so this test
      // would fail if the rule used plain modulo arithmetic.
      expect(validate({'multipleOf': 0.1}, 0.3), isEmpty);
      expect(validate({'multipleOf': 0.1}, 0.1), isEmpty);
      expect(validate({'multipleOf': 0.1}, 0.2), isEmpty);
    });

    test('float divisor — value not a multiple fails', () {
      // 0.15 is not a multiple of 0.1 (0.15 / 0.1 = 1.5, not whole)
      expect(validate({'multipleOf': 0.1}, 0.15), isNotEmpty);
    });

    test('divisor 0.01 — 0.01 passes', () {
      expect(validate({'multipleOf': 0.01}, 0.01), isEmpty);
    });

    test('non-numeric value is silently skipped', () {
      expect(validate({'multipleOf': 3}, 'not a number'), isEmpty);
      expect(validate({'multipleOf': 3}, true), isEmpty);
      expect(validate({'multipleOf': 3}, null), isEmpty);
      expect(validate({'multipleOf': 3}, [1, 2]), isEmpty);
      expect(validate({'multipleOf': 3}, {'a': 1}), isEmpty);
    });

    test('divisor of 0 is a schema-error guard — numeric value fails', () {
      // The JSON Schema spec requires multipleOf > 0. A zero divisor produces
      // a violation rather than throwing an exception.
      final v = validate({'multipleOf': 0}, 5);
      expect(v, hasLength(1));
      expect(v.first.message, contains('divisor'));
    });

    test('divisor of 0 skips non-numeric value', () {
      // Non-numeric values are skipped before the divisor guard is reached.
      expect(validate({'multipleOf': 0}, 'text'), isEmpty);
    });

    test('double value that is a whole number passes integer multipleOf', () {
      expect(validate({'multipleOf': 2}, 4.0), isEmpty);
    });
  });

  // ── uniqueItems ─────────────────────────────────────────────────────────────

  group('uniqueItems', () {
    test('unique primitives pass', () {
      expect(validate({'uniqueItems': true}, [1, 2, 3]), isEmpty);
      expect(validate({'uniqueItems': true}, ['a', 'b', 'c']), isEmpty);
    });

    test('duplicate primitives fail', () {
      final v = validate({'uniqueItems': true}, [1, 2, 1]);
      expect(v, hasLength(1));
      expect(v.first.message, contains('unique'));
    });

    test('adjacent duplicate strings fail', () {
      expect(validate({'uniqueItems': true}, ['x', 'x']), isNotEmpty);
    });

    test('uniqueItems: false always passes even with duplicates', () {
      // uniqueItems: false must not construct an active rule in the parser.
      expect(validate({'uniqueItems': false}, [1, 1, 1]), isEmpty);
    });

    test('uniqueItems absent means no constraint', () {
      expect(validate({}, [1, 1, 1]), isEmpty);
    });

    test('nested object duplicates detected', () {
      // toSet() would fail here because Map identity differs.
      final v = validate(
        {'uniqueItems': true},
        [
          {'a': 1},
          {'a': 1},
        ],
      );
      expect(v, hasLength(1));
    });

    test('nested array duplicates detected', () {
      final v = validate(
        {'uniqueItems': true},
        [
          [1, 2],
          [1, 2],
        ],
      );
      expect(v, hasLength(1));
    });

    test('structurally different nested objects pass', () {
      expect(
        validate(
          {'uniqueItems': true},
          [
            {'a': 1},
            {'a': 2},
          ],
        ),
        isEmpty,
      );
    });

    test('empty list is vacuously unique', () {
      expect(validate({'uniqueItems': true}, []), isEmpty);
    });

    test('single-element list is vacuously unique', () {
      expect(validate({'uniqueItems': true}, [42]), isEmpty);
    });

    test('non-array instance is silently skipped', () {
      expect(validate({'uniqueItems': true}, 'not an array'), isEmpty);
      expect(validate({'uniqueItems': true}, 42), isEmpty);
      expect(validate({'uniqueItems': true}, null), isEmpty);
      expect(validate({'uniqueItems': true}, {'a': 1}), isEmpty);
    });

    test('violation path matches the array path', () {
      final rule = parser.parse({'uniqueItems': true});
      final v = rule.validate([1, 1], 'items.list');
      expect(v, hasLength(1));
      expect(v.first.path, equals('items.list'));
    });
  });

  // ── minProperties / maxProperties ──────────────────────────────────────────

  group('minProperties', () {
    test('object meeting minimum passes', () {
      expect(validate({'minProperties': 2}, {'a': 1, 'b': 2}), isEmpty);
    });

    test('object with more than minimum passes', () {
      expect(validate({'minProperties': 2}, {'a': 1, 'b': 2, 'c': 3}), isEmpty);
    });

    test('object below minimum fails', () {
      final v = validate({'minProperties': 2}, {'a': 1});
      expect(v, hasLength(1));
      expect(v.first.message, contains('at least 2 properties'));
    });

    test('empty object with minProperties: 0 passes', () {
      expect(validate({'minProperties': 0}, {}), isEmpty);
    });

    test('empty object with minProperties: 1 fails', () {
      expect(validate({'minProperties': 1}, {}), isNotEmpty);
    });

    test('non-object is silently skipped', () {
      expect(validate({'minProperties': 2}, 'text'), isEmpty);
      expect(validate({'minProperties': 2}, 42), isEmpty);
      expect(validate({'minProperties': 2}, [1, 2]), isEmpty);
      expect(validate({'minProperties': 2}, null), isEmpty);
    });
  });

  group('maxProperties', () {
    test('object at maximum passes', () {
      expect(validate({'maxProperties': 2}, {'a': 1, 'b': 2}), isEmpty);
    });

    test('object below maximum passes', () {
      expect(validate({'maxProperties': 2}, {'a': 1}), isEmpty);
    });

    test('object above maximum fails', () {
      final v = validate({'maxProperties': 2}, {'a': 1, 'b': 2, 'c': 3});
      expect(v, hasLength(1));
      expect(v.first.message, contains('at most 2 properties'));
    });

    test('empty object with maxProperties: 0 passes', () {
      expect(validate({'maxProperties': 0}, {}), isEmpty);
    });

    test('non-object is silently skipped', () {
      expect(validate({'maxProperties': 2}, 'text'), isEmpty);
      expect(validate({'maxProperties': 2}, 42), isEmpty);
      expect(validate({'maxProperties': 2}, null), isEmpty);
    });
  });

  group('minProperties and maxProperties combined', () {
    test('object within range passes', () {
      expect(
        validate(
          {'minProperties': 2, 'maxProperties': 4},
          {'a': 1, 'b': 2, 'c': 3},
        ),
        isEmpty,
      );
    });

    test('object at lower bound passes', () {
      expect(
        validate({'minProperties': 2, 'maxProperties': 4}, {'a': 1, 'b': 2}),
        isEmpty,
      );
    });

    test('object at upper bound passes', () {
      expect(
        validate(
          {'minProperties': 2, 'maxProperties': 4},
          {'a': 1, 'b': 2, 'c': 3, 'd': 4},
        ),
        isEmpty,
      );
    });

    test('object below range fails', () {
      final v = validate({'minProperties': 2, 'maxProperties': 4}, {'a': 1});
      expect(v, isNotEmpty);
      expect(v.any((e) => e.message.contains('at least 2')), isTrue);
    });

    test('object above range fails', () {
      final v = validate(
        {'minProperties': 2, 'maxProperties': 4},
        {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5},
      );
      expect(v, isNotEmpty);
      expect(v.any((e) => e.message.contains('at most 4')), isTrue);
    });

    test('both violations collected when impossible range satisfied', () {
      // minProperties > maxProperties is a schema error but should not throw;
      // both violations are reported when neither bound is satisfiable.
      final v = validate(
        {'minProperties': 5, 'maxProperties': 2},
        {'a': 1, 'b': 2, 'c': 3},
      );
      // The object has 3 properties: above max (2) and below min (5).
      expect(v.any((e) => e.message.contains('at least 5')), isTrue);
      expect(v.any((e) => e.message.contains('at most 2')), isTrue);
    });
  });

  // ── dependentRequired ───────────────────────────────────────────────────────

  group('dependentRequired', () {
    test('trigger absent — no validation, passes', () {
      // 'creditCard' is absent, so 'billingAddress' is not required.
      expect(
        validate(
          {
            'dependentRequired': {
              'creditCard': ['billingAddress'],
            },
          },
          {'name': 'Alice'},
        ),
        isEmpty,
      );
    });

    test('trigger present and dependent present — passes', () {
      expect(
        validate(
          {
            'dependentRequired': {
              'creditCard': ['billingAddress'],
            },
          },
          {'creditCard': '1234', 'billingAddress': '1 Main St'},
        ),
        isEmpty,
      );
    });

    test('trigger present and dependent missing — one violation', () {
      final v = validate(
        {
          'dependentRequired': {
            'creditCard': ['billingAddress'],
          },
        },
        {'creditCard': '1234'},
      );
      expect(v, hasLength(1));
      expect(v.first.message, contains('required field is missing'));
    });

    test('violation path points at the missing dependent property', () {
      final rule = parser.parse({
        'dependentRequired': {
          'creditCard': ['billingAddress'],
        },
      });
      final v = rule.validate({'creditCard': '1234'}, '');
      expect(v, hasLength(1));
      expect(v.first.path, equals('billingAddress'));
    });

    test('violation path uses dot-notation for nested context', () {
      final rule = parser.parse({
        'dependentRequired': {
          'creditCard': ['billingAddress'],
        },
      });
      final v = rule.validate({'creditCard': '1234'}, 'payment');
      expect(v, hasLength(1));
      expect(v.first.path, equals('payment.billingAddress'));
    });

    test('multiple trigger properties — only present triggers enforced', () {
      // Schema: if 'a' is present, 'b' is required; if 'c' is present, 'd' is
      // required.  Object has 'a' but not 'c', so only 'b' must be checked.
      final v = validate(
        {
          'dependentRequired': {
            'a': ['b'],
            'c': ['d'],
          },
        },
        {'a': 1},
      );
      // 'b' is missing → violation; 'c' absent so 'd' is not checked.
      expect(v, hasLength(1));
      expect(v.first.path, equals('b'));
    });

    test(
      'multiple dependents missing — one violation per missing property',
      () {
        final v = validate(
          {
            'dependentRequired': {
              'a': ['b', 'c'],
            },
          },
          {'a': 1},
        );
        expect(v, hasLength(2));
        final paths = v.map((e) => e.path).toSet();
        expect(paths, containsAll(['b', 'c']));
      },
    );

    test('empty dependent list always passes when trigger is present', () {
      expect(
        validate(
          {
            'dependentRequired': {'a': []},
          },
          {'a': 1},
        ),
        isEmpty,
      );
    });

    test('non-map value is silently skipped', () {
      expect(
        validate({
          'dependentRequired': {
            'a': ['b'],
          },
        }, 'text'),
        isEmpty,
      );
      expect(
        validate({
          'dependentRequired': {
            'a': ['b'],
          },
        }, 42),
        isEmpty,
      );
      expect(
        validate({
          'dependentRequired': {
            'a': ['b'],
          },
        }, null),
        isEmpty,
      );
    });

    test('all triggers present with all dependents present — passes', () {
      expect(
        validate(
          {
            'dependentRequired': {
              'foo': ['bar', 'baz'],
              'qux': ['quux'],
            },
          },
          {'foo': 1, 'bar': 2, 'baz': 3, 'qux': 4, 'quux': 5},
        ),
        isEmpty,
      );
    });

    test('dependent can also be the value of another trigger', () {
      // 'b' is both required when 'a' is present, and is itself a trigger.
      expect(
        validate(
          {
            'dependentRequired': {
              'a': ['b'],
              'b': ['c'],
            },
          },
          {'a': 1, 'b': 2, 'c': 3},
        ),
        isEmpty,
      );
    });

    test('chain dependency — missing c causes violation', () {
      final v = validate(
        {
          'dependentRequired': {
            'a': ['b'],
            'b': ['c'],
          },
        },
        {'a': 1, 'b': 2},
      );
      // 'b' is present so 'c' is required but missing.
      expect(v.any((e) => e.path == 'c'), isTrue);
    });
  });

  // ── Integration: multiple new keywords in one schema ────────────────────────

  group('integration — multiple new keywords', () {
    test('const + type — wrong type fails type, not const', () {
      // type fails first in the composite rule collection; const is also
      // checked (all rules run), but type produces the first violation.
      final v = validate({'type': 'number', 'const': 42}, 'forty-two');
      expect(v, isNotEmpty);
      expect(v.any((e) => e.message.contains('expected type')), isTrue);
    });

    test('multipleOf + minimum — both constraints applied', () {
      // 9 >= 6 but 9 % 4 != 0
      final v = validate({'minimum': 6, 'multipleOf': 4}, 9);
      expect(v.any((e) => e.message.contains('multiple of')), isTrue);
      // 9 >= 6, so no minimum violation
      expect(v.any((e) => e.message.contains('>=')), isFalse);
    });

    test('uniqueItems + minItems — both violations collected', () {
      // [1,1] has 1 distinct item (< minItems 2) AND has duplicates.
      // Actually [1,1] has length 2, meeting minItems:2 but failing uniqueItems.
      final v = validate({'uniqueItems': true, 'minItems': 3}, [1, 1]);
      expect(v.any((e) => e.message.contains('unique')), isTrue);
      expect(v.any((e) => e.message.contains('at least 3 items')), isTrue);
    });

    test('minProperties + required — both violations collected', () {
      final v = validate(
        {
          'minProperties': 3,
          'required': ['name', 'email'],
        },
        {'name': 'Alice'},
      );
      expect(v.any((e) => e.message.contains('at least 3 properties')), isTrue);
      expect(
        v.any((e) => e.message.contains('required field is missing')),
        isTrue,
      );
    });
  });
}
