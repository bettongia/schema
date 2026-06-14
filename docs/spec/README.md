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
