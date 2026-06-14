---
title: Technical Specification
subtitle: betto_schema
toc-title: "Contents"
...

- **Package:** `betto_schema`
- **Version:** 0.1.0-dev.1
- **Dart SDK:** ^3.12.0

# Purpose and scope

`betto_schema` is a pure-Dart library that provides JSON Schema validation
primitives aligned with the
[JSON Schema Validation 2020-12 specification](https://json-schema.org/draft/2020-12/json-schema-validation.html).
It is used as the low-level schema layer for KMDB's collection schema feature.

The library exposes three layers:

- **Layer 1 — Programmatic validators** (`validation.dart`, `formats/`):
  `Validator<T>` and `StringFormatValidator` classes that developers compose
  directly without touching JSON Schema format.
- **Layer 2 — Rule tree** (`schema_rule.dart`, `schema_parser.dart`):
  `SchemaRule` subtypes that wrap Layer 1 validators, adding dot-path tracking
  and full-pass violation collection.
- **Layer 3 — Porcelain** (`json_schema_validator.dart`):
  `JsonSchemaValidator`, a thin convenience wrapper that accepts a JSON Schema
  string or map and returns a `List<SchemaViolation>`.

Layer 1 must never import Layer 2 or Layer 3. Layer 3 only calls Layer 2.

# Keyword behaviour

This section documents the correct behaviour of each supported JSON Schema
keyword, including edge cases and deviations from naïve implementations.

## `type` (§6.1.1)

The `type` keyword value **MUST** be either a string or an array of strings.

**String form** — the value must match the named type exactly.

**Array form** — the value is valid if its type matches **any** entry in the
list (logical OR). For example, `{"type": ["string", "null"]}` accepts both
strings and `null`.

Supported type names: `string`, `number`, `integer`, `boolean`, `array`,
`object`, `null`. Unknown type names are silently accepted in Layer 2 (the
rule tree) and silently rejected in Layer 1 (the programmatic validators).

### `integer` sub-type

The spec defines an integer as "a numeric instance whose value is without a
fractional part". This means:

- A Dart `int` is always a valid integer.
- A Dart `double` with a zero fractional part (e.g. `1.0`, `-3.0`) is also a
  valid integer.
- A Dart `double` with a non-zero fractional part (e.g. `3.14`) is **not**
  a valid integer.
- Non-finite doubles (`double.nan`, `double.infinity`,
  `double.negativeInfinity`) are **not** valid integers. Although
  `double.nan % 1` produces `NaN` (not `0`), the `isFinite` guard makes this
  explicit and prevents a future "simplification" from inadvertently accepting
  non-finite values.

## `pattern` (§6.3.3)

Regular expressions in the `pattern` keyword are **not implicitly anchored**.
A pattern need only match *somewhere* within the string — it does not need to
match the entire string. This is identical to the behaviour of
`RegExp.hasMatch()` in Dart.

For example, `{"pattern": "foo"}` accepts `"foobar"`, `"barfoo"`, and
`"foo"`.

Callers who need a full-string match must anchor their pattern explicitly
using `^` and `$` (e.g. `{"pattern": "^foo$"}`).

An empty pattern (`""`) always matches every string (correct per spec: an
empty regex has at least one match at position 0 in any string).

## `const` (§6.1.3)

The `const` keyword constrains the instance to be equal to the declared
constant value. The value may be any JSON type, including `null`.

The comparison uses structural (deep) equality. Nested `List` and `Map` values
are compared element-by-element rather than by object identity. Primitive values
(`string`, `number`, `boolean`, `null`) are handled correctly by deep equality
as well.

`const` validates the **value** of the instance, not its presence. Use
`required` to enforce that a key exists; use `const` to enforce what its value
must be. A schema `{"const": null}` accepts the value `null` and rejects any
non-null value.

## `multipleOf` (§6.2.1)

The `multipleOf` keyword validates that a numeric instance is an exact multiple
of the declared divisor. Non-numeric instances are silently skipped (no
violation).

The keyword value must be a number strictly greater than zero. A divisor of
zero is a schema-error guard: the rule produces a violation for any numeric
value rather than throwing a Dart exception.

### Floating-point safety

The naive check `instance % divisor == 0` is numerically unsafe for decimal
divisors because of IEEE-754 rounding. For example, `0.3 % 0.1` is
approximately `2.77e-17`, not `0`. The implementation uses a quotient-based
check: `(instance / divisor) - round(instance / divisor)` is tested against an
epsilon of `1e-10`. This correctly identifies `0.3` as a multiple of `0.1`.

## `uniqueItems` (§6.4.3)

The `uniqueItems` keyword validates that all elements in an array are pairwise
distinct. It activates only when the keyword value is exactly `true`; a value
of `false` (or absence) means no uniqueness constraint is applied. Non-array
instances are silently skipped.

Uniqueness uses structural (deep) equality — the same `DeepCollectionEquality`
used for `const`. A naïve `toSet()` check fails to detect duplicate nested
objects or arrays because Dart compares `Map` and `List` by object identity in
the default equality. The implementation uses an O(n²) pairwise comparison,
which is simple and correct for the expected sizes of JSON Schema instances.

Empty and single-element arrays are vacuously unique.

## `minProperties` (§6.5.2)

The `minProperties` keyword validates that an object (map) has at least the
specified number of properties. Non-object instances are silently skipped. The
bound is inclusive: `{"minProperties": 2}` accepts objects with exactly two
properties. An empty object satisfies `{"minProperties": 0}`.

## `maxProperties` (§6.5.1)

The `maxProperties` keyword validates that an object (map) has at most the
specified number of properties. Non-object instances are silently skipped. The
bound is inclusive: `{"maxProperties": 3}` accepts objects with one, two, or
three properties.

When both `minProperties` and `maxProperties` are declared, a single
`ObjectSizeRule` enforces both bounds and collects all violations in one pass.

## `dependentRequired` (§6.5.4)

The `dependentRequired` keyword declares conditional property dependencies. The
keyword value is an object where each key is a **trigger** property name that
maps to an array of **dependent** property names.

For each trigger key that is present in the instance, all listed dependent
property names must also be present. If the trigger key is absent, no
validation is performed for that entry (the dependency is not activated).

One `SchemaViolation` is emitted per missing dependent property. The violation
path follows the same format as `required`: the path is the dot-notation path
to the object, followed by the missing property name
(e.g. `"payment.billingAddress"`). The violation message is
`"required field is missing"`, consistent with `RequiredRule`.

An empty dependent list (`"trigger": []`) always passes when the trigger is
present.

## `format` — `uri` and `urn`

### `uri`

The `uri` format validator uses Dart's `Uri.tryParse()`. This is
**intentionally lenient**: it accepts any string that Dart can parse as a
URI reference, including relative references and bare words, as well as all
registered URI schemes.

In particular, a valid URN (e.g. `urn:isbn:0451450523`) **is** a valid URI
because `urn` is a registered URI scheme per RFC 3986. The `uri` validator
therefore accepts both http URLs and valid URNs.

Callers who need to enforce absolute URIs should check `Uri.isAbsolute` or
apply additional constraints beyond this format validator.

### `urn`

The `urn` format validator uses `Urn.tryParse()` (the `Urn` class from
`lib/src/formats/urn.dart`), which strictly validates URN syntax
(`urn:<nid>:<nss>`). Plain http/https URLs and other non-URN strings are
rejected.
