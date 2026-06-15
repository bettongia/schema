Schema validation primitives.

`betto_schema` provides the low-level building blocks for schema creation:
individual validator functions, a sealed `SchemaRule` rule tree, and a
`SchemaParser` that compiles a JSON Schema map into a rule tree for fast,
repeated validation.

## Features

- **Primitive validators** — typed, composable validators for numeric ranges,
  string length/pattern/format, array bounds, enumerations, and required fields.
- **Format validators** — surface checks for standard JSON Schema 2020-12
  formats (`email`, `uri`, `urn`, `uri-reference`, `date-time`, `date`, `time`,
  `uuid`, `duration`, `hostname`, `idn-hostname`, `ipv4`, `ipv6`,
  `json-pointer`, `relative-json-pointer`, `regex`) and project-specific
  extensions (`hex-string`, `digit-string`, `roman-numeral`, `isbn-13`, `doi`,
  `lang`).
- **SchemaRule tree** — a sealed `SchemaRule` hierarchy that represents a parsed
  JSON Schema as an in-memory rule tree. Rules always collect all violations in
  one pass so every error is reported at once.
- **SchemaParser** — compiles a `Map<String, dynamic>` JSON Schema into a
  `SchemaRule` tree. Unknown keywords are silently ignored for forward
  compatibility.
- **SchemaViolation** — carries the dot-path to the offending field and a
  human-readable message.

## Supported JSON Schema keywords

| Keyword                                    | Rule type                        |
| :----------------------------------------- | :------------------------------- |
| `type`                                     | `TypeRule`                       |
| `required`                                 | `RequiredRule`                   |
| `properties`                               | `PropertiesRule`                 |
| `additionalProperties: false`              | `AdditionalPropertiesRule`       |
| `additionalProperties: <schema>`           | `AdditionalPropertiesSchemaRule` |
| `patternProperties`                        | `PatternPropertiesRule`          |
| `enum`                                     | `EnumRule`                       |
| `const`                                    | `ConstRule`                      |
| `minimum` / `maximum`                      | `NumericRule`                    |
| `exclusiveMinimum` / `exclusiveMaximum`    | `NumericRule`                    |
| `multipleOf`                               | `MultipleOfRule`                 |
| `minLength` / `maxLength`                  | `StringRule`                     |
| `pattern`                                  | `StringRule`                     |
| `format`                                   | `FormatRule`                     |
| `minItems` / `maxItems`                    | `ArrayRule`                      |
| `items`                                    | `ArrayRule`                      |
| `prefixItems`                              | `PrefixItemsRule`                |
| `contains` / `minContains` / `maxContains` | `ContainsRule`                   |
| `uniqueItems`                              | `UniqueItemsRule`                |
| `minProperties` / `maxProperties`          | `ObjectSizeRule`                 |
| `dependentRequired`                        | `DependentRequiredRule`          |

`additionalProperties` defaults to `true` (permissive). Set it to `false` to
reject undeclared fields, or to a sub-schema to validate them.

## Usage

### Parsing and validating a document

```dart
void main() {
  final rule = SchemaParser().parse({
    'required': ['name', 'email'],
    'properties': {
      'name': {'type': 'string', 'minLength': 1},
      'email': {'type': 'string', 'format': 'email'},
      'age': {'type': 'integer', 'minimum': 0},
    },
    'additionalProperties': false,
  });

  final violations = rule.validate({'name': 'Alice'}, '');
  // → [SchemaViolation(path: 'email', message: 'required field is missing')]

  for (final v in violations) {
    print(v); // "email: required field is missing"
  }
}
```

### Using primitive validators directly

```dart
import 'package:betto_schema/betto_schema.dart';

final atLeastZero = Minimum(0);
final atMostHundred = Maximum(100);
print(atLeastZero(42) && atMostHundred(42));    // true
print(atLeastZero(101) && atMostHundred(101));  // false

final shortEnough = MaximumLength(20);
print(shortEnough('hello')); // true

final emailFmt = StringFormatValidator().getValidator('email')!;
print(emailFmt.function('user@example.com')); // true
print(emailFmt.function('not-an-email'));      // false
```

### SchemaViolation

Each violation carries a dot-path and a message:

```dart
void main() {
  final v = SchemaViolation(
    path: 'address.city',
    message: 'required field is missing',
  );
  print(v.path); // address.city
  print(v.message); // required field is missing
  print(v); // address.city: required field is missing

  // Root-level violations use an empty `path`:
  final root = SchemaViolation(path: '', message: 'expected type object');
  print(root); // expected type object
}
```

## Examples

The `example/` directory contains three self-contained examples, each with a
JSON Schema, valid and invalid sample documents, and a runnable Dart file that
builds the same schema programmatically using `SchemaRule` classes.

| Example                | Location           | Features highlighted                                                                                                      |
| :--------------------- | :----------------- | :------------------------------------------------------------------------------------------------------------------------ |
| Book / Publication     | `example/book/`    | `isbn-13`, `doi`, `date`, `lang` format validators; `minItems` on authors; `enum` for genres; `minimum` on numeric fields |
| Recipe                 | `example/recipe/`  | Nested ingredient objects; numeric ranges for servings and times; `enum` for cuisine and difficulty; `uniqueItems`        |
| Contact / Address Book | `example/contact/` | `email`, `uri`, `date-time` format validators; E.164 phone `pattern`; nested address object; mostly optional fields       |

### Running the Dart examples

Each `main.dart` builds the schema with `SchemaRule` classes and validates a set
of inline documents, printing `[PASS]` or `[FAIL]` with any violations:

```bash
dart run example/book/main.dart
dart run example/recipe/main.dart
dart run example/contact/main.dart
```

### Validating JSON files with the CLI

`bin/validate.dart` accepts a JSON Schema file and a JSON data file (or reads
data from stdin) and exits `0` on success or `1` on failure.

```bash
# Validate a single data file against its schema
dart run bin/validate.dart example/book/schema.json example/book/data/valid_sicp.json

# Inspect the violations produced by an invalid document
dart run bin/validate.dart example/book/schema.json example/book/data/invalid_bad_fields.json

# Pipe data via stdin
cat example/recipe/data/valid_carbonara.json | dart run bin/validate.dart example/recipe/schema.json

# Check a contact entry
dart run bin/validate.dart example/contact/schema.json example/contact/data/invalid_bad_formats.json
```

## Additional information

This package is guided by the [JSON Schema](https://json-schema.org/)
specification — specifically
[JSON Schema Validation: A Vocabulary for Structural Validation of JSON](https://json-schema.org/draft/2020-12/json-schema-validation.html).
