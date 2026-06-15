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

/// Builds the Recipe schema as a [SchemaRule] tree.
///
/// Highlights: nested object validation for each ingredient entry, numeric
/// range constraints on servings and cook/prep times, enum values for cuisine
/// and difficulty, and [UniqueItemsRule] for the tags array.
///
/// This is the programmatic equivalent of `schema.json` in this directory.
/// Run with:
///   dart run example/recipe/main.dart
SchemaRule buildRecipeSchema() {
  // Each ingredient is itself an object with its own required fields and
  // additionalProperties restriction.
  final ingredientSchema = CompositeRule([
    TypeRule('object'),
    RequiredRule(['name', 'quantity']),
    PropertiesRule({
      'name': CompositeRule([TypeRule('string'), StringRule(minLength: 1)]),
      'quantity': CompositeRule([TypeRule('string'), StringRule(minLength: 1)]),
      'notes': TypeRule('string'),
    }),
    AdditionalPropertiesRule({'name', 'quantity', 'notes'}),
  ]);

  return CompositeRule([
    TypeRule('object'),
    RequiredRule(['title', 'ingredients', 'servings', 'prepTimeMins']),
    PropertiesRule({
      'title': CompositeRule([
        TypeRule('string'),
        StringRule(minLength: 1, maxLength: 200),
      ]),
      'description': CompositeRule([
        TypeRule('string'),
        StringRule(maxLength: 1000),
      ]),
      'cuisine': CompositeRule([
        TypeRule('string'),
        EnumRule([
          'american',
          'chinese',
          'french',
          'indian',
          'italian',
          'japanese',
          'mediterranean',
          'mexican',
          'other',
          'thai',
        ]),
      ]),
      'difficulty': CompositeRule([
        TypeRule('string'),
        EnumRule(['easy', 'medium', 'hard']),
      ]),
      // Capped at 50 — sensible upper bound for a home recipe.
      'servings': CompositeRule([
        TypeRule('integer'),
        NumericRule(minimum: 1, maximum: 50),
      ]),
      // Capped at 1440 minutes (24 hours).
      'prepTimeMins': CompositeRule([
        TypeRule('integer'),
        NumericRule(minimum: 1, maximum: 1440),
      ]),
      // cookTimeMins may be 0 for no-cook dishes such as salads.
      'cookTimeMins': CompositeRule([
        TypeRule('integer'),
        NumericRule(minimum: 0, maximum: 1440),
      ]),
      'ingredients': CompositeRule([
        TypeRule('array'),
        ArrayRule(minItems: 1, items: ingredientSchema),
      ]),
      'steps': CompositeRule([
        TypeRule('array'),
        ArrayRule(
          items: CompositeRule([TypeRule('string'), StringRule(minLength: 1)]),
        ),
      ]),
      'tags': CompositeRule([
        TypeRule('array'),
        ArrayRule(items: TypeRule('string')),
        UniqueItemsRule(),
      ]),
    }),
    AdditionalPropertiesRule({
      'title',
      'description',
      'cuisine',
      'difficulty',
      'servings',
      'prepTimeMins',
      'cookTimeMins',
      'ingredients',
      'steps',
      'tags',
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
  final schema = buildRecipeSchema();

  print('Recipe\n');

  print('Valid entries — expect no violations:');
  _run('Spaghetti Carbonara', schema, {
    'title': 'Spaghetti Carbonara',
    'description':
        'A classic Roman pasta dish with eggs, cheese, pancetta, and black pepper.',
    'cuisine': 'italian',
    'difficulty': 'medium',
    'servings': 4,
    'prepTimeMins': 15,
    'cookTimeMins': 20,
    'ingredients': [
      {'name': 'spaghetti', 'quantity': '400g'},
      {'name': 'pancetta', 'quantity': '150g', 'notes': 'cut into small cubes'},
      {'name': 'egg yolks', 'quantity': '4'},
      {'name': 'Pecorino Romano', 'quantity': '100g', 'notes': 'finely grated'},
      {'name': 'black pepper', 'quantity': 'to taste', 'notes': 'freshly ground'},
    ],
    'tags': ['pasta', 'eggs', 'italian', 'classic', 'quick'],
  });
  _run('Garden Salad (minimal fields, no-cook)', schema, {
    'title': 'Garden Salad',
    'servings': 2,
    'prepTimeMins': 10,
    'ingredients': [
      {'name': 'mixed salad greens', 'quantity': '100g'},
      {'name': 'cherry tomatoes', 'quantity': '10'},
    ],
  });

  print('\nInvalid entries — expect violations:');
  _run(
    'Empty title, servings out of range, prepTimeMins = 0, empty ingredients',
    schema,
    {
      'title': '',
      'servings': 100,
      'prepTimeMins': 0,
      'ingredients': <dynamic>[],
    },
  );
  _run(
    'Unknown cuisine value, invalid difficulty, duplicate tags',
    schema,
    {
      'title': 'Vegemite Toast',
      'cuisine': 'australian',
      'difficulty': 'beginner',
      'servings': 1,
      'prepTimeMins': 5,
      'ingredients': [
        {'name': 'bread', 'quantity': '2 slices'},
      ],
      'tags': ['toast', 'toast'],
    },
  );
}
