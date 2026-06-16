# Changelog

## 0.1.0-dev.2

## 0.1.0-dev.1

Initial development release. Pure Dart JSON Schema validation primitives aligned
with
[JSON Schema Validation 2020-12](https://json-schema.org/draft/2020-12/json-schema-validation.html).

### Primitive validators (`validation.dart`)

Typed, composable validators that form the primary public API. Dart developers
construct and combine these directly without touching JSON Schema format.

| Validator                                         | Description                                           |
| :------------------------------------------------ | :---------------------------------------------------- |
| `EnumValidator<T>`                                | Value must be one of a declared set                   |
| `ConstValidator<T>`                               | Value must equal a constant (deep equality)           |
| `Minimum<T>` / `Maximum<T>`                       | Inclusive numeric bounds                              |
| `ExclusiveMinimum<T>` / `ExclusiveMaximum<T>`     | Exclusive numeric bounds                              |
| `MultipleOf<T>`                                   | Divisibility check (floating-point-safe)              |
| `InRange`                                         | Value within a `Range`                                |
| `MinimumLength` / `MaximumLength` / `ExactLength` | Unicode-aware string length                           |
| `InRangeLength`                                   | String length within a `Range`                        |
| `PatternValidator`                                | Regex match (unanchored, per JSON Schema §6.3.3)      |
| `MinItems<T>` / `MaxItems<T>` / `ItemCount<T>`    | Array size bounds                                     |
| `UniqueItems<T>`                                  | All array elements pairwise distinct (deep equality)  |
| `ItemsValidator<T>`                               | Every array element satisfies a sub-validator         |
| `MinProperties` / `MaxProperties`                 | Object property count bounds                          |
| `Required`                                        | All named properties present in a map                 |
| `TypeValidator`                                   | JSON Schema type check — single string and array form |
| `PropertiesValidator`                             | Per-key validators for a map                          |
| `AdditionalPropertiesValidator`                   | Rejects undeclared object keys                        |
| `DependentRequired`                               | Conditional required properties                       |

### JSON Schema rule tree (`schema_rule.dart`)

A sealed `SchemaRule` hierarchy compiled from a JSON Schema by `SchemaParser`.
All rules collect every violation in a single pass so callers receive the
complete error list at once.

| Rule                             | JSON Schema keyword(s)                                       |
| :------------------------------- | :----------------------------------------------------------- |
| `TypeRule`                       | `type` (string and array forms)                              |
| `RequiredRule`                   | `required`                                                   |
| `PropertiesRule`                 | `properties`                                                 |
| `AdditionalPropertiesRule`       | `additionalProperties: false`                                |
| `AdditionalPropertiesSchemaRule` | `additionalProperties: <schema>`                             |
| `EnumRule`                       | `enum`                                                       |
| `ConstRule`                      | `const`                                                      |
| `NumericRule`                    | `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum` |
| `MultipleOfRule`                 | `multipleOf`                                                 |
| `StringRule`                     | `minLength`, `maxLength`, `pattern`                          |
| `FormatRule`                     | `format`                                                     |
| `ArrayRule`                      | `minItems`, `maxItems`, `items`                              |
| `PrefixItemsRule`                | `prefixItems`                                                |
| `ContainsRule`                   | `contains`, `minContains`, `maxContains`                     |
| `UniqueItemsRule`                | `uniqueItems`                                                |
| `ObjectSizeRule`                 | `minProperties`, `maxProperties`                             |
| `PatternPropertiesRule`          | `patternProperties`                                          |
| `DependentRequiredRule`          | `dependentRequired`                                          |
| `CompositeRule`                  | (internal — runs multiple rules in one pass)                 |
| `AlwaysInvalidRule`              | `false` boolean schema (e.g. `items: false`)                 |

### Format validators (`formats/`)

`StringFormatValidator` provides named format validators. The set covers all
standard JSON Schema 2020-12 format strings implemented in this release, plus
project-specific extensions.

**Standard JSON Schema formats**

| Format                  | Spec                                                            |
| :---------------------- | :-------------------------------------------------------------- |
| `uri`                   | RFC 3986                                                        |
| `urn`                   | RFC 8141                                                        |
| `email`                 | RFC 5322 (pragmatic subset)                                     |
| `date-time`             | ISO 8601                                                        |
| `date`                  | RFC 3339                                                        |
| `time`                  | RFC 3339                                                        |
| `uuid`                  | RFC 9562                                                        |
| `duration`              | ISO 8601 / RFC 3339                                             |
| `hostname`              | RFC 1123                                                        |
| `idn-hostname`          | RFC 5890 (best-effort; Punycode conformance not enforced)       |
| `ipv4`                  | RFC 2673 — four decimal octets 0–255, leading zeros rejected    |
| `ipv6`                  | RFC 4291 — full and `::` compressed forms, IPv4-mapped accepted |
| `uri-reference`         | RFC 3986 §4.1 — absolute URI or relative reference              |
| `json-pointer`          | RFC 6901                                                        |
| `relative-json-pointer` | IETF draft                                                      |
| `regex`                 | ECMA-262 dialect                                                |

Deferred to v1: `idn-email`, `iri`, `iri-reference`, `uri-template`.

**Project-specific extensions**

| Format          | Description                           |
| :-------------- | :------------------------------------ |
| `hex-string`    | Hexadecimal digit string              |
| `digit-string`  | Decimal digit string                  |
| `roman-numeral` | Roman numeral string                  |
| `isbn-13`       | ISBN-13 with check-digit verification |
| `doi`           | Digital Object Identifier             |
| `lang`          | BCP 47 / RFC 5646 language tag        |

### Porcelain (`json_schema_validator.dart`)

`JsonSchemaValidator` accepts a JSON Schema as a `String` or
`Map<String, dynamic>`, delegates to `SchemaParser`, and returns
`List<SchemaViolation>`. No validation logic of its own.

### Supporting types

- `SchemaViolation` — dot-path (`path`) and human-readable `message`; root
  violations use an empty path
- `SchemaParser` — compiles `Map<String, dynamic>` JSON Schema to a `SchemaRule`
  tree; unknown keywords are silently ignored
- `Range` — inclusive/exclusive numeric range helper used by primitive
  validators

### Spec-correctness fixes applied during this release

- `pattern` is unanchored — `hasMatch()` not a full-string check (JSON Schema
  §6.3.3)
- `integer` accepts whole-number doubles (e.g. `1.0`); non-finite values
  rejected (§6.1.1)
- `type` array form (`["string", "null"]`) is parsed and validated correctly
  (§6.1.1)
- `uri` and `urn` format validators correctly distinguished (were swapped)

### Examples (`example/`)

Six runnable examples are included:

| Entry point                 | Demonstrates                                                                                   |
| :-------------------------- | :--------------------------------------------------------------------------------------------- |
| `example/main.dart`         | Parsing a JSON Schema with `SchemaParser` and collecting `SchemaViolation`s                    |
| `example/validators.dart`   | Composing `Validator` primitives directly (`MaximumLength`, `StringFormatValidator`)           |
| `example/violation.dart`    | Constructing and printing `SchemaViolation` values                                             |
| `example/book/main.dart`    | A book schema: enum genres, `prefixItems`, `additionalProperties`, `contains`, format strings  |
| `example/contact/main.dart` | A contact schema: nested address object, `email`/`uri`/`date` formats, `uniqueItems`, patterns |
| `example/recipe/main.dart`  | A recipe schema: nested ingredient objects, numeric ranges, enum values, `uniqueItems`         |

Each domain example (`book`, `contact`, `recipe`) ships with a `schema.json` and
sample data files so it can be run standalone with `dart run`.

### CLI

- Added `bin/validate.dart` — a command-line tool that validates a JSON data
  file (or stdin) against a JSON Schema file. Exits `0` on success, `1` on
  validation failures (violations printed to stdout), and `2` on usage or I/O
  errors.

### Out of scope (planned for v1)

`$ref`, `allOf` / `anyOf` / `oneOf` / `not`, `if` / `then` / `else`, nested
`$schema` declarations, `idn-email`, `iri`, `iri-reference`, `uri-template`.
