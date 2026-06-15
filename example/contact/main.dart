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

/// Builds the Contact schema as a [SchemaRule] tree.
///
/// Highlights: standard format validators (`email`, `uri`, `date`,
/// `date-time`), an E.164 phone pattern via [StringRule.pattern], a nested
/// address object with its own `required` and `additionalProperties`, and
/// [UniqueItemsRule] on the tags array.
///
/// Only `name` and `email` are required; every other field is optional,
/// demonstrating that [PropertiesRule] skips absent keys.
///
/// This is the programmatic equivalent of `schema.json` in this directory.
/// Run with:
///   dart run example/contact/main.dart
SchemaRule buildContactSchema() {
  final addressSchema = CompositeRule([
    TypeRule('object'),
    RequiredRule(['city', 'country']),
    PropertiesRule({
      'street': TypeRule('string'),
      'city': CompositeRule([TypeRule('string'), StringRule(minLength: 1)]),
      // ISO 3166-1 alpha-2 is always exactly 2 characters.
      'country': CompositeRule([
        TypeRule('string'),
        StringRule(minLength: 2, maxLength: 2),
      ]),
    }),
    AdditionalPropertiesRule({'street', 'city', 'country'}),
  ]);

  return CompositeRule([
    TypeRule('object'),
    RequiredRule(['name', 'email']),
    PropertiesRule({
      'name': CompositeRule([
        TypeRule('string'),
        StringRule(minLength: 1, maxLength: 100),
      ]),
      'email': CompositeRule([TypeRule('string'), FormatRule('email')]),
      // E.164: + sign, first digit 1–9, then 6–14 more digits (total 7–15).
      'phone': CompositeRule([
        TypeRule('string'),
        StringRule(pattern: RegExp(r'^\+[1-9]\d{6,14}$')),
      ]),
      'website': CompositeRule([TypeRule('string'), FormatRule('uri')]),
      'birthday': CompositeRule([TypeRule('string'), FormatRule('date')]),
      'lastContacted': CompositeRule([
        TypeRule('string'),
        FormatRule('date-time'),
      ]),
      'address': addressSchema,
      'tags': CompositeRule([
        TypeRule('array'),
        ArrayRule(
          items: CompositeRule([TypeRule('string'), StringRule(minLength: 1)]),
        ),
        UniqueItemsRule(),
      ]),
      'notes': CompositeRule([TypeRule('string'), StringRule(maxLength: 2000)]),
    }),
    AdditionalPropertiesRule({
      'name',
      'email',
      'phone',
      'website',
      'birthday',
      'lastContacted',
      'address',
      'tags',
      'notes',
    }),
  ]);
}

void _run(String label, SchemaRule schema, Map<String, dynamic> data) {
  final violations = schema.validate(data, '');
  if (violations.isEmpty) {
    print('  [PASS] $label');
  } else {
    print('  [FAIL] $label');
    for (final v in violations) {
      final location = v.path.isEmpty ? '(root)' : v.path;
      print('         $location: ${v.message}');
    }
  }
}

void main() {
  final schema = buildContactSchema();

  print('Contact / Address Book\n');

  print('Valid entries — expect no violations:');
  _run('Full entry with all optional fields', schema, {
    'name': 'Alice Müller',
    'email': 'alice@example.com',
    'phone': '+491701234567',
    'website': 'https://alice.example.com/about',
    'birthday': '1990-03-15',
    'lastContacted': '2026-06-01T14:30:00Z',
    'address': {'street': 'Hauptstraße 42', 'city': 'Berlin', 'country': 'DE'},
    'tags': ['colleague', 'tech', 'conference-2025'],
    'notes': 'Met at the 2025 Dart conference.',
  });
  _run('Minimal entry — only required fields', schema, {
    'name': 'Bob Smith',
    'email': 'bob.smith@work.org',
  });

  print('\nInvalid entries — expect violations:');
  _run(
    'Invalid email, phone without + prefix, non-ISO dates',
    schema,
    {
      'name': 'Charlie',
      'email': 'not-an-email',
      'phone': '01234567890',
      'birthday': 'March 15, 1990',
      'lastContacted': 'yesterday',
    },
  );
  _run(
    'Missing required name, country code too long, additional property',
    schema,
    {
      'email': 'dave@example.com',
      'address': {'city': 'Paris', 'country': 'France'},
      'unknownField': true,
    },
  );
}
