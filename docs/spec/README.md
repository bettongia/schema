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

## `contains` (§6.4.5), `minContains` (§6.4.4), `maxContains` (§6.4.6)

The `contains` keyword validates that at least one element of an array satisfies
a sub-schema. `minContains` and `maxContains` refine how many elements must
match. The three keywords are tightly coupled and implemented together as a
single `ContainsRule`.

**Semantics:**

- Sub-schema violations from individual element tests are used only as a
  counting signal — they are never forwarded to the caller. Only the `contains`
  rule itself emits violations.
- `minContains` defaults to `1` per spec §6.4.4. A value of `0` makes the rule
  always pass unless `maxContains` is set and exceeded.
- `maxContains` is optional. When absent there is no upper bound on matching
  elements.
- `minContains` and `maxContains` have no effect when `contains` is absent from
  the schema.

**Non-array instances** are silently skipped (no violation), consistent with
every other array-keyword rule.

**Empty sub-schema** (`contains: {}`) matches every element, so
`minContains`/`maxContains` effectively become array-count constraints
(e.g. `{"contains": {}, "minContains": 3}` requires at least three elements).

## `prefixItems` (§6.4.1) and boolean `items`

In JSON Schema 2020-12, `prefixItems` is an array of schemas applied
positionally: element `i` is validated against `prefixItems[i]`. The existing
`items` keyword applies only to elements **beyond** the prefix (indices ≥
`prefixItems.length`) when `prefixItems` is present in the same schema. When
`prefixItems` is absent, `items` applies uniformly to all elements (consistent
with earlier behaviour).

**`prefixItems` array-length behaviour:**

- If the array is shorter than the prefix list, the extra prefix schemas simply
  do not apply — there is no violation. This is correct per spec and
  `minItems`/`maxItems` are the appropriate keywords to enforce length.
- `prefixItems` is independent of `minItems` and `maxItems`; all four keywords
  are evaluated simultaneously.

**Boolean `items` (2020-12):**

The spec §6.4.1 clarifies that `items` MUST be a valid JSON Schema, and `false`
is a valid boolean schema meaning "always invalid".

- `items: true` — no constraint (no rule emitted).
- `items: false` — any element in scope (all elements when no `prefixItems`;
  elements beyond the prefix otherwise) is rejected unconditionally.
- `items: <schema>` — the schema is applied to every element in scope.

Violation paths for positional elements use bracket notation, e.g. `[0]`,
`[1]`.

## `patternProperties` (§6.5.5)

A map of ECMA-262 regex strings to sub-schemas. For each property in the
instance, every pattern that matches the property name (unanchored, using
`RegExp.hasMatch`) causes the associated sub-schema to be applied to the
property value. A property may be matched by zero, one, or more patterns —
every matching sub-schema is applied and all violations are collected.

**Key points:**

- Pattern matching is **unanchored**: a pattern need only match *any substring*
  of the property name, not the full name. Use `^` and `$` anchors to force
  full-name matching.
- An invalid regex key throws `FormatException` at **parse time** (not at
  validation time). A malformed regex is a schema-authoring error that must be
  surfaced immediately.
- Properties not matched by any pattern are silently skipped by
  `PatternPropertiesRule` (no violation).
- Non-object instances are silently skipped (no violation).

**Interaction with `additionalProperties`:** a property is considered
"pattern-evaluated" if at least one pattern in `patternProperties` matches its
name. The `additionalProperties` rule skips pattern-evaluated properties just as
it skips properties declared in `properties`.

## `additionalProperties` — schema form (§6.5.6)

In addition to `additionalProperties: false` (already supported), the parser
now handles a **schema-valued** `additionalProperties`. Properties not covered
by `properties` or `patternProperties` must validate against this sub-schema.

**Evaluated-property tracking:**

The set of "evaluated" keys is determined at parse time:

1. Keys explicitly declared under `properties`.
2. Keys matched at runtime by any regex in `patternProperties` (handled by
   `PatternPropertiesRule`).

`AdditionalPropertiesSchemaRule` receives both the static declared-key set and
the compiled pattern list. At validation time it skips any key that is either
in the declared set or matched by a pattern, then applies the sub-schema to the
remaining keys.

**Guard removal:** the previous `parsedProperties != null` guard that prevented
`additionalProperties` from activating when `properties` was absent has been
removed. `additionalProperties` (both `false` and schema form) now activates
regardless of whether `properties` is present. When neither `properties` nor
`patternProperties` is declared, every key is "additional".

**`additionalProperties: false` with `patternProperties`:**
Uses `AdditionalPropertiesSchemaRule` with an `AlwaysInvalidRule` payload so
that pattern-matched keys are correctly excluded from the "additional" set
before rejection.

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
