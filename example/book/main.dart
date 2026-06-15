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

/// Builds the Book schema as a [SchemaRule] tree.
///
/// This is the programmatic equivalent of `schema.json` in this directory.
/// Using [SchemaRule] classes directly (rather than parsing a JSON file with
/// [SchemaParser]) makes the schema reusable across the codebase without any
/// I/O round-trip.
SchemaRule buildBookSchema() {
  const allowedGenres = [
    'art',
    'biography',
    'fiction',
    'history',
    'non-fiction',
    'philosophy',
    'science',
    'technology',
  ];

  return CompositeRule([
    TypeRule('object'),
    RequiredRule(['title', 'authors', 'isbn', 'publishedDate']),
    PropertiesRule({
      'title': CompositeRule([
        TypeRule('string'),
        StringRule(minLength: 1, maxLength: 300),
      ]),
      'subtitle': CompositeRule([
        TypeRule('string'),
        StringRule(maxLength: 500),
      ]),
      'authors': CompositeRule([
        TypeRule('array'),
        ArrayRule(
          minItems: 1,
          items: CompositeRule([
            TypeRule('string'),
            StringRule(minLength: 1),
          ]),
        ),
      ]),
      // betto_schema extension: validates GS1 prefix (978/979) and check digit.
      'isbn': CompositeRule([TypeRule('string'), FormatRule('isbn-13')]),
      // betto_schema extension: validates directory-indicator.registrant/suffix.
      'doi': CompositeRule([TypeRule('string'), FormatRule('doi')]),
      // RFC 3339 calendar date (YYYY-MM-DD). Overflow dates like 2020-13-01 fail.
      'publishedDate': CompositeRule([TypeRule('string'), FormatRule('date')]),
      'publisher': CompositeRule([TypeRule('string'), StringRule(minLength: 1)]),
      'edition': CompositeRule([TypeRule('integer'), NumericRule(minimum: 1)]),
      // RFC 5646 language tag, e.g. 'en', 'zh-Hant'.
      'language': CompositeRule([TypeRule('string'), FormatRule('lang')]),
      'pageCount': CompositeRule([TypeRule('integer'), NumericRule(minimum: 1)]),
      'genres': CompositeRule([
        TypeRule('array'),
        ArrayRule(
          items: CompositeRule([
            TypeRule('string'),
            EnumRule(allowedGenres),
          ]),
        ),
      ]),
    }),
    AdditionalPropertiesRule({
      'title',
      'subtitle',
      'authors',
      'isbn',
      'doi',
      'publishedDate',
      'publisher',
      'edition',
      'language',
      'pageCount',
      'genres',
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
  final schema = buildBookSchema();

  print('Book / Publication\n');

  print('Valid entries — expect no violations:');
  _run('Structure and Interpretation of Computer Programs', schema, {
    'title': 'Structure and Interpretation of Computer Programs',
    'subtitle': 'Second Edition',
    'authors': ['Harold Abelson', 'Gerald Jay Sussman'],
    'isbn': '978-0-262-51087-5',
    'doi': '10.7551/mitpress/9077.001.0001',
    'publishedDate': '1996-07-25',
    'publisher': 'MIT Press',
    'edition': 2,
    'language': 'en',
    'pageCount': 657,
    'genres': ['technology', 'science'],
  });
  _run('A Brief History of Time', schema, {
    'title': 'A Brief History of Time',
    'authors': ['Stephen Hawking'],
    'isbn': '978-0-553-38016-3',
    'publishedDate': '1988-04-01',
    'publisher': 'Bantam Books',
    'edition': 1,
    'language': 'en',
    'pageCount': 212,
    'genres': ['science', 'non-fiction'],
  });

  print('\nInvalid entries — expect violations:');
  _run('Empty title, empty authors array, bad ISBN, non-ISO date', schema, {
    'title': '',
    'authors': <dynamic>[],
    'isbn': 'not-a-valid-isbn',
    'publishedDate': '25-12-2020',
  });
  _run(
    'Wrong ISBN check digit, month 13, edition < 1, unknown genre, extra field',
    schema,
    {
      'title': 'Some Obscure Title',
      'authors': ['An Author'],
      'isbn': '978-0-000-00000-0',
      'publishedDate': '2020-13-01',
      'edition': 0,
      'genres': ['mystery'],
      'unknownField': 'not allowed',
    },
  );
}
