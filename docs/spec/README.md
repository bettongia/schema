---
title: Technical Specification
subtitle: betto_schema
toc-title: "Contents"
...

- **Package:** `betto_schema`
- **Version:** 0.1.0
- **Dart SDK:** ^3.12.0

# Purpose and scope

`betto_schema` is a pure-Dart library that provides JSON Schema validation
primitives aligned with the
[JSON Schema Validation 2020-12 specification](https://json-schema.org/draft/2020-12/json-schema-validation.html).

The library exposes three layers:

- **Layer 1 — Programmatic validators** (`validation.dart`, `formats/`):
  `Validator<T>` and `StringFormatValidator` classes that developers compose
  directly without touching JSON Schema format.
- **Layer 2 — Rule tree** (`schema_rule.dart`, `schema_parser.dart`):
  `SchemaRule` subtypes that wrap Layer 1 validators, adding dot-path tracking
  and full-pass violation collection.
- **Layer 3 — Porcelain** (`json_schema_validator.dart`): `JsonSchemaValidator`,
  a thin convenience wrapper that accepts a JSON Schema string or map and
  returns a `List<SchemaViolation>`.

Layer 1 must never import Layer 2 or Layer 3. Layer 3 only calls Layer 2.

# A Vocabulary for Structural Validation

This section documents the correct behaviour of each supported JSON Schema
keyword, including edge cases and deviations from naïve implementations. Only
keywords with non-trivial or surprising implementation details are documented
here; keywords that follow the specification without deviation are omitted.

## Validation Keywords for Any Instance Type

### `type`

The `type` keyword value **MUST** be either a string or an array of strings.

**String form** — the value must match the named type exactly.

**Array form** — the value is valid if its type matches **any** entry in the
list (logical OR). For example, `{"type": ["string", "null"]}` accepts both
strings and `null`.

Supported type names: `string`, `number`, `integer`, `boolean`, `array`,
`object`, `null`. Unknown type names are silently accepted in Layer 2 (the rule
tree) and silently rejected in Layer 1 (the programmatic validators).

#### `integer` sub-type

The spec defines an integer as "a numeric instance whose value is without a
fractional part". This means:

- A Dart `int` is always a valid integer.
- A Dart `double` with a zero fractional part (e.g. `1.0`, `-3.0`) is also a
  valid integer.
- A Dart `double` with a non-zero fractional part (e.g. `3.14`) is **not** a
  valid integer.
- Non-finite doubles (`double.nan`, `double.infinity`,
  `double.negativeInfinity`) are **not** valid integers. Although
  `double.nan % 1` produces `NaN` (not `0`), the `isFinite` guard makes this
  explicit and prevents a future "simplification" from inadvertently accepting
  non-finite values.

### `const`

The `const` keyword constrains the instance to be equal to the declared constant
value. The value may be any JSON type, including `null`.

The comparison uses structural (deep) equality. Nested `List` and `Map` values
are compared element-by-element rather than by object identity. Primitive values
(`string`, `number`, `boolean`, `null`) are handled correctly by deep equality
as well.

`const` validates the **value** of the instance, not its presence. Use
`required` to enforce that a key exists; use `const` to enforce what its value
must be. A schema `{"const": null}` accepts the value `null` and rejects any
non-null value.

## Validation Keywords for Numeric Instances

### `multipleOf`

The `multipleOf` keyword validates that a numeric instance is an exact multiple
of the declared divisor. Non-numeric instances are silently skipped (no
violation).

The keyword value must be a number strictly greater than zero. A divisor of zero
is a schema-error guard: the rule produces a violation for any numeric value
rather than throwing a Dart exception.

#### Floating-point safety

The naive check `instance % divisor == 0` is numerically unsafe for decimal
divisors because of IEEE-754 rounding. For example, `0.3 % 0.1` is approximately
`2.77e-17`, not `0`. The implementation uses a quotient-based check:
`(instance / divisor) - round(instance / divisor)` is tested against an epsilon
of `1e-10`. This correctly identifies `0.3` as a multiple of `0.1`.

## Validation Keywords for Strings

### `pattern`

Regular expressions in the `pattern` keyword are **not implicitly anchored**. A
pattern need only match _somewhere_ within the string — it does not need to
match the entire string. This is identical to the behaviour of
`RegExp.hasMatch()` in Dart.

For example, `{"pattern": "foo"}` accepts `"foobar"`, `"barfoo"`, and `"foo"`.

Callers who need a full-string match must anchor their pattern explicitly using
`^` and `$` (e.g. `{"pattern": "^foo$"}`).

An empty pattern (`""`) always matches every string (correct per spec: an empty
regex has at least one match at position 0 in any string).

## Validation Keywords for Arrays

### `uniqueItems`

The `uniqueItems` keyword validates that all elements in an array are pairwise
distinct. It activates only when the keyword value is exactly `true`; a value of
`false` (or absence) means no uniqueness constraint is applied. Non-array
instances are silently skipped.

Uniqueness uses structural (deep) equality — the same `DeepCollectionEquality`
used for `const`. A naïve `toSet()` check fails to detect duplicate nested
objects or arrays because Dart compares `Map` and `List` by object identity in
the default equality. The implementation uses an O(n²) pairwise comparison,
which is simple and correct for the expected sizes of JSON Schema instances.

Empty and single-element arrays are vacuously unique.

### `contains`, `minContains`, `maxContains`

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
`minContains`/`maxContains` effectively become array-count constraints (e.g.
`{"contains": {}, "minContains": 3}` requires at least three elements).

### `prefixItems` and boolean `items`

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

Violation paths for positional elements use bracket notation, e.g. `[0]`, `[1]`.

## Validation Keywords for Objects

### `minProperties`

The `minProperties` keyword validates that an object (map) has at least the
specified number of properties. Non-object instances are silently skipped. The
bound is inclusive: `{"minProperties": 2}` accepts objects with exactly two
properties. An empty object satisfies `{"minProperties": 0}`.

### `maxProperties`

The `maxProperties` keyword validates that an object (map) has at most the
specified number of properties. Non-object instances are silently skipped. The
bound is inclusive: `{"maxProperties": 3}` accepts objects with one, two, or
three properties.

When both `minProperties` and `maxProperties` are declared, a single
`ObjectSizeRule` enforces both bounds and collects all violations in one pass.

### `dependentRequired`

The `dependentRequired` keyword declares conditional property dependencies. The
keyword value is an object where each key is a **trigger** property name that
maps to an array of **dependent** property names.

For each trigger key that is present in the instance, all listed dependent
property names must also be present. If the trigger key is absent, no validation
is performed for that entry (the dependency is not activated).

One `SchemaViolation` is emitted per missing dependent property. The violation
path follows the same format as `required`: the path is the dot-notation path to
the object, followed by the missing property name (e.g.
`"payment.billingAddress"`). The violation message is
`"required field is missing"`, consistent with `RequiredRule`.

An empty dependent list (`"trigger": []`) always passes when the trigger is
present.

### `patternProperties`

A map of ECMA-262 regex strings to sub-schemas. For each property in the
instance, every pattern that matches the property name (unanchored, using
`RegExp.hasMatch`) causes the associated sub-schema to be applied to the
property value. A property may be matched by zero, one, or more patterns — every
matching sub-schema is applied and all violations are collected.

**Key points:**

- Pattern matching is **unanchored**: a pattern need only match _any substring_
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

### `additionalProperties`

In addition to `additionalProperties: false` (already supported), the parser
handles a **schema-valued** `additionalProperties`. Properties not covered by
`properties` or `patternProperties` must validate against this sub-schema.

**Evaluated-property tracking:**

The set of "evaluated" keys is determined at parse time:

1. Keys explicitly declared under `properties`.
2. Keys matched at runtime by any regex in `patternProperties` (handled by
   `PatternPropertiesRule`).

`AdditionalPropertiesSchemaRule` receives both the static declared-key set and
the compiled pattern list. At validation time it skips any key that is either in
the declared set or matched by a pattern, then applies the sub-schema to the
remaining keys.

**Guard removal:** the previous `parsedProperties != null` guard that prevented
`additionalProperties` from activating when `properties` was absent has been
removed. `additionalProperties` (both `false` and schema form) now activates
regardless of whether `properties` is present. When neither `properties` nor
`patternProperties` is declared, every key is "additional".

**`additionalProperties: false` with `patternProperties`:** Uses
`AdditionalPropertiesSchemaRule` with an `AlwaysInvalidRule` payload so that
pattern-matched keys are correctly excluded from the "additional" set before
rejection.

# Vocabularies for Semantic Content With `format`

## Foreword

The `format` keyword assigns a semantic meaning to string instances.
`betto_schema` implements `format` as **assertion** behaviour: a string that
does not satisfy the named format produces a `SchemaViolation`. Unrecognised
format names are silently ignored (no violation).

## Defined Formats

The following formats align with JSON Schema Validation 2020-12 §7.3. Only
formats with non-trivial validation logic or notable implementation decisions
are described in detail; the remaining formats are listed with a brief summary.

### Dates, Times, and Duration

- **`date-time`** — ISO 8601 combined date-time string, validated by
  `DateTime.tryParse`.
- **`date`** — RFC 3339 full-date (`YYYY-MM-DD`). Overflow dates (e.g. month 13,
  day 32) are rejected by reformatting the parsed result and comparing it
  against the input string.
- **`time`** — RFC 3339 partial-time (`HH:mm:ss.SSS`), validated by
  `DateFormat('HH:mm:ss.SSS').tryParseStrict`.
- **`duration`** — ISO 8601 duration string (e.g. `P1Y2M3DT4H5M6S`), validated
  by `Iso8601Duration.isValid`.

### Email Addresses

- **`email`** — a pragmatic subset of RFC 5322, validated by `Email.isValid`.

### Hostnames

#### `hostname`

The `hostname` format validator accepts DNS hostnames per RFC 1123 §2.1.

Rules:

- Each dot-separated label must be 1–63 characters.
- Labels must match `[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?` — that is,
  start and end with an alphanumeric character; interior characters may be
  alphanumeric or hyphen.
- The total hostname length (all labels and dots) must not exceed 253
  characters.
- **Trailing dots are rejected.** The format targets RFC 1123 host names, not
  DNS zone-file fully-qualified domain names.
- Matching is case-insensitive (`EXAMPLE.COM` is valid).

Underscores, spaces, `@`, and other non-alphanumeric/hyphen characters in labels
are rejected.

#### `idn-hostname`

The `idn-hostname` format validator accepts internationalized hostnames per
RFC 5890. This is a **best-effort check**, not full IDNA 2008 / Punycode
conformance.

Full IDNA 2008 conformance requires Punycode encoding and Unicode normalization
(NFKC) that are not available in a pure-Dart context without external
dependencies. This may be upgraded in v1 if a suitable pure-Dart IDNA library
becomes available.

What is validated:

- Any ASCII label valid per RFC 1123 (see `hostname` above).
- Labels containing Unicode characters are accepted if they satisfy the
  structural rules: no leading or trailing hyphen, 1–63 characters per label,
  total ≤ 253 characters, and no ASCII control characters, spaces, or
  URL-reserved punctuation in the label.
- Trailing dots are rejected (same as `hostname`).

### IP Addresses

#### `ipv4`

The `ipv4` format validator accepts dotted-quad IPv4 address notation per RFC
2673 §3.2. Each of the four decimal octets must be in the range 0–255.

**Leading zeros are rejected.** `01.0.0.0` is invalid because a leading zero is
ambiguous (octal vs. decimal interpretation). The validator uses a per-octet
regex alternation (`25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d`) that enforces both the
range constraint and the no-leading-zero constraint in a single pass.

Addresses with fewer than four octets, more than four octets, or non-numeric
content are rejected.

#### `ipv6`

The `ipv6` format validator accepts IPv6 address strings per RFC 4291 §2.2. It
is implemented without `dart:io` (`InternetAddress`) so that the validator works
in browser/web environments where `dart:io` is unavailable.

Supported forms:

- Full eight-group form: `2001:db8:85a3:0:0:8a2e:370:7334`
- All compressed (`::`) positions: `::`, `::1`, `1::`, `1::2`
- IPv4-mapped tail: `::ffff:192.168.1.1`, `1:2:3:4:5:6:1.2.3.4`

Hex groups are case-insensitive. Strings containing more than one `::`, more
than eight groups in the full form, or hex groups with more than four digits are
rejected.

Zone IDs (`%eth0` suffixes) are not part of the RFC 4291 text representation
grammar and are rejected by this validator.

### Resource Identifiers

- **`uuid`** — RFC 9562 UUID string, validated by `UuidValidation.isValidUUID`.

#### `uri`

The `uri` format validator uses Dart's `Uri.tryParse()`. This is **intentionally
lenient**: it accepts any string that Dart can parse as a URI reference,
including relative references and bare words, as well as all registered URI
schemes.

In particular, a valid URN (e.g. `urn:isbn:0451450523`) **is** a valid URI
because `urn` is a registered URI scheme per RFC 3986. The `uri` validator
therefore accepts both http URLs and valid URNs.

Callers who need to enforce absolute URIs should check `Uri.isAbsolute` or apply
additional constraints beyond this format validator.

#### `urn`

The `urn` format validator uses `Urn.tryParse()` (the `Urn` class from
`lib/src/formats/urn.dart`), which strictly validates URN syntax
(`urn:<nid>:<nss>`). Plain http/https URLs and other non-URN strings are
rejected.

#### `uri-reference`

The `uri-reference` format validator accepts URI references per RFC 3986 §4.1. A
URI reference is either an absolute URI (e.g. `https://example.com`) or a
relative reference (e.g. `/path/to`, `../foo`, `#section`, `""`).

The validator uses a structural approach:

1. `Uri.tryParse` must succeed (handles structural parsing).
2. The string must not contain characters that are illegal in both absolute URIs
   and relative references: unescaped spaces, ASCII control characters
   (0x00–0x1F, 0x7F), or literal angle brackets (`<`, `>`).

The empty string is a valid `uri-reference` (it refers to the current document).
Percent-encoded spaces (e.g. `%20`) are valid; literal spaces are not.

### JSON Pointers

#### `json-pointer`

The `json-pointer` format validator accepts JSON Pointer strings per RFC 6901.

A JSON Pointer is either:

- The empty string `""` — refers to the root of the document.
- A sequence of reference tokens each prefixed by `/` — e.g. `/foo/bar/0`.

Within a reference token, the tilde character `~` must only appear as the
two-character escape sequences `~0` (representing `~`) or `~1` (representing
`/`). A bare `~` or an escape sequence other than `~0`/`~1` (e.g. `~2`) is
invalid.

Strings that do not begin with `/` (and are not the empty string) are invalid.

#### `relative-json-pointer`

The `relative-json-pointer` format validator accepts Relative JSON Pointer
strings per the IETF draft (bhutton/relative-json-pointer).

A Relative JSON Pointer begins with a non-negative integer prefix (the number of
steps to walk up the document tree) followed by either:

- `#` — referring to the key or index of the referenced location in its parent.
- A JSON Pointer (including the empty string) — applied after walking up.

**Leading zeros in the integer prefix are rejected** unless the prefix is
exactly `"0"`. So `01` and `00` are invalid, but `0` is valid.

Examples: `0`, `1`, `0#`, `1#`, `0/foo`, `2/a/b`, `10/foo`.

### `regex`

The `regex` format validator accepts any string that compiles as a valid Dart
`RegExp`. The check is performed by attempting `RegExp(value)` and catching
`FormatException`.

Note: JSON Schema 2020-12 specifies ECMA-262 regular expression syntax. Dart's
`RegExp` uses a compatible but not identical dialect; minor differences in
behaviour may exist for edge-case patterns.

## Extension Formats

The following format strings are **not** defined by the JSON Schema
specification. They are project-specific extensions provided by `betto_schema`
for use in Bettongia collection schemas. They are recognised by
`StringFormatValidator` and the Layer 2 rule tree in the same way as the
standard formats.

### `hex-string`

Accepts a string composed entirely of hexadecimal digits (`0`–`9`, `a`–`f`,
`A`–`F`). An optional `0x` prefix is permitted and stripped before validation.
Hex digits are **case-insensitive**: `DEADBEEF` and `deadbeef` are both valid.

An empty string (after stripping the optional `0x` prefix) is **invalid**.

### `digit-string`

Accepts a string composed entirely of decimal digits (`0`–`9`). No leading-zero
restriction is applied — `"007"` is valid. The string must be non-empty.

This is distinct from the `integer` type, which validates a numeric JSON value.
`digit-string` validates a **string** whose characters are all decimal digits —
useful for numeric identifiers such as barcodes, phone numbers, and EAN codes
where the value is always stored as a string.

### `roman-numeral`

Accepts a string composed entirely of recognised Roman numeral characters (`I`,
`V`, `X`, `L`, `C`, `D`, `M`, case-insensitive). The string must be non-empty.

This is a **structural** check only: it verifies that every character is a valid
Roman numeral symbol. Canonical subtractive ordering (`IV`, `IX`, etc.) is
**not** enforced — additive repetition such as `IIII` is accepted as `4`. The
apostrophus and vinculum extended notations and fractional values are not
supported.

### `isbn-13`

Accepts a 13-digit International Standard Book Number (ISBN-13) per the ISBN
Users' Manual. The input may contain hyphens or spaces as separators (they are
stripped before validation), but the total number of extracted digits must be
exactly 13.

Validation rules:

- The GS1 prefix must be `978` or `979`.
- The check digit (digit 13) must satisfy the weighted modulo-10 calculation
  defined in the ISBN Users' Manual (weights alternating `1` and `3` over digits
  1–12).

Inputs longer than 22 characters (before digit extraction) are rejected to guard
against pathologically long strings.

### `doi`

Accepts a Digital Object Identifier (DOI) string per the
[DOI Handbook](https://www.doi.org/the-identifier/resources/handbook/). A DOI
has the form:

```
<prefix>/<suffix>
```

where the **prefix** has the form `<directory-indicator>.<registrant-code>` (the
directory indicator and each registrant-code segment must be all-digit strings,
and segments are separated by `.`), and the **suffix** is any non-empty string.
Both prefix and suffix must be non-empty, and the `/` separator must be present.

DOI names are **case-insensitive** per DOI Handbook §2.4. The string form is
normalised to uppercase in the `DOI` class, but `isValid` accepts any case.

### `lang`

Accepts a language tag per [RFC 5646](https://www.rfc-editor.org/info/rfc5646).
Three tag forms are recognised:

- **`langtag`** — the normal form: an ISO 639 language code optionally extended
  with script (ISO 15924), region (ISO 3166-1 alpha-2 or UN M.49), and variant
  subtags, all separated by `-`.
- **`privateuse`** — begins with `x-` followed by at least one private subtag.
- **`grandfathered`** — legacy tags listed in the RFC (e.g. `i-klingon`,
  `art-lojban`). These are deprecated in favour of new subtags but remain valid.

Language tags are **case-insensitive** per RFC 5646. The `lang` format validator
accepts any casing; the `LanguageTag` class normalises output to the recommended
conventions (lowercase language, uppercase region, Title Case script).

Extended language subtags (e.g. `zh-cmn-Hans-CN`) are supported per RFC 5646
§2.2.2.
