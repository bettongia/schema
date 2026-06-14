# JSON Schema: Missing Keywords

**Status**: Complete

**PR link**: _pending_

## Problem statement

Several JSON Schema Validation 2020-12 keywords that affect structural
validation are not implemented at all. Schemas using `contains`,
`prefixItems`, `patternProperties`, or a schema-valued `additionalProperties`
are silently treated as having no constraints, which can cause invalid
documents to pass validation.

## Open questions

- [x] **Spec §25 / `schemaModelVersion` bump.**
      **Decision:** No bump — KMDB has not been released, so version tracking
      is not yet active. Update `docs/spec/` to list the newly supported
      keywords, but `schemaModelVersion` stays at `1`.
- [x] **`patternProperties` regex anchoring.**
      **Decision:** Use `regExp.hasMatch(propertyName)` (unanchored), consistent
      with spec §6.5.5 and the anchoring fix in `plan_json_schema_correctness`.
      Add this explicitly to the implementation checklist.
- [x] **Remove the `parsedProperties != null` guard.**
      **Decision:** In scope. Remove/rework the guard at `schema_parser.dart:115`
      so `additionalProperties` and `patternProperties` take effect even when
      `properties` is absent.
- [x] **Boolean `items` (`items: false`).**
      **Decision:** In scope for v0. Spec §6.4.1 is clear that `items` MUST be
      a valid JSON Schema, and `false` is a valid boolean schema meaning
      "always invalid". Parser must handle `items: true` (no-op) and
      `items: false` (emit a rule rejecting elements beyond the prefix, or all
      elements when no `prefixItems` is present).
- [x] **Invalid `patternProperties` regex key.**
      **Decision:** Throw `FormatException` at parse time. A malformed regex is
      a schema authoring error that should be surfaced immediately rather than
      silently swallowed.

## Investigation

### `contains` / `minContains` / `maxContains` (§6.4.5, §6.4.4, §6.4.6)

`contains` takes a sub-schema and passes if at least one array element
validates against it. `minContains` and `maxContains` refine how many elements
must match (defaulting to min=1, no max).

These three keywords are tightly coupled and should be implemented as a single
`ContainsRule`. The rule must:
- Count how many elements satisfy the sub-schema (violations from the sub-schema
  are a signal of non-match, not emitted to the caller).
- Emit a violation if the count is below `minContains` (default 1).
- Emit a violation if `maxContains` is set and the count exceeds it.
- `minContains: 0` makes the keyword effectively optional — the rule always
  passes unless `maxContains` is also set and violated.

Only `contains` may appear alone; `minContains`/`maxContains` have no effect
without it.

### `prefixItems` (§6.4.1) and the 2020-12 semantics of `items`

In 2020-12, `prefixItems` is an array of schemas applied positionally: element
0 is validated by `prefixItems[0]`, element 1 by `prefixItems[1]`, etc. The
keyword `items` — when `prefixItems` is present — applies only to elements
**beyond** the prefix (i.e. indices ≥ `prefixItems.length`). When `prefixItems`
is absent, `items` applies uniformly to all elements (current behaviour).

Current `ArrayRule` treats `items` as always uniform. This needs:
- A new `PrefixItemsRule` that validates positional elements and emits
  `path[i]` violations.
- `ArrayRule` (or a new coordinating rule) to limit `items` validation to
  elements beyond the prefix when `prefixItems` is present in the same schema.

### `patternProperties` (§6.5.5)

A map of ECMA-262 regex patterns to sub-schemas. For each property in the
instance, apply the sub-schema of every pattern that matches the property name.
A property may be matched by zero, one, or more patterns.

Interacts with `additionalProperties`: a property is considered "evaluated" by
`patternProperties` if at least one pattern matches it. In strict mode, the
`additionalProperties` rule should treat pattern-matched properties as
non-additional.

### `additionalProperties` as a schema (§6.5.6)

Currently only `additionalProperties: false` is handled. The spec also allows a
sub-schema value: properties not covered by `properties` or
`patternProperties` must validate against this sub-schema.

The parser branch is in [schema_parser.dart:114–117](../../lib/src/schema_parser.dart#L114):

```dart
if (schema['additionalProperties'] == false && parsedProperties != null) {
  rules.add(AdditionalPropertiesRule(parsedProperties.keys.toSet()));
}
```

This needs to be extended to handle a `Map` value by parsing it into a
sub-schema rule and applying it to the extra properties. The existing
`AdditionalPropertiesRule` rejects extra properties outright; a new
`AdditionalPropertiesSchemaRule` should validate them instead.

### Interaction between keywords

When `properties`, `patternProperties`, and `additionalProperties` coexist:
- `properties` covers explicitly named keys.
- `patternProperties` covers keys matching a pattern.
- `additionalProperties` covers everything else.

The evaluated-properties set must be tracked across all three to determine
what is "additional". Implement this interaction in `SchemaParser` at parse
time (build the combined allowed-key set) rather than at runtime where
cross-rule communication would be complex.

## Implementation plan

- [x] **`ContainsRule`** (`contains` / `minContains` / `maxContains`)
  - [x] Add `ContainsRule` to `schema_rule.dart`; fields: `itemSchema`,
        `minContains` (default 1), `maxContains` (nullable); no-op on non-List
  - [x] Validation: count elements where `itemSchema.validate(el, path).isEmpty`
        (sub-schema violations are a counting signal only — never emitted);
        emit violations for under/over count
  - [x] Add `'contains'` branch to `SchemaParser.parse()`; read `minContains`
        and `maxContains` only when `contains` is present
  - [x] Tests: one match passes; zero matches fails; `minContains: 0` always
        passes when no `maxContains`; `maxContains` exceeded fails; combined
        range within/outside bounds; `contains: {}` matches every element
        (empty schema = always valid); non-array value produces no violation
- [x] **`PrefixItemsRule`** and updated `ArrayRule` / boolean `items`
  - [x] Add `PrefixItemsRule` to `schema_rule.dart`; validates elements by index
        against a `List<SchemaRule>`; emits `path[i]` violations; array shorter
        than prefix → extra prefix schemas simply do not apply (no violation)
  - [x] Update `SchemaParser.parse()` to parse `prefixItems` as a list of
        sub-schemas and emit `PrefixItemsRule`
  - [x] Update `ArrayRule` so `items` only applies to indices ≥
        `prefixItems.length` when `prefixItems` is present
  - [x] Handle boolean `items` in the parser: `items: true` → no rule emitted;
        `items: false` → emit a rule that rejects any element in scope (all
        elements when no `prefixItems`; elements beyond the prefix otherwise)
  - [x] Tests: each positional schema validated; item beyond prefix validated
        by `items` schema; item beyond prefix with no `items` → no constraint;
        array shorter than prefix → no violation for unmatched prefix schemas;
        `items: false` with `prefixItems` rejects third element; `items: false`
        without `prefixItems` rejects any element; `items: true` always passes;
        `prefixItems` independent of `minItems`/`maxItems`
- [x] **`PatternPropertiesRule`**
  - [x] Add `PatternPropertiesRule` to `schema_rule.dart`; field:
        `List<(RegExp, SchemaRule)> patterns`; match property names with
        `regExp.hasMatch(name)` (unanchored per spec §6.5.5); apply sub-schema
        of every matching pattern
  - [x] Add `'patternProperties'` branch to `SchemaParser.parse()`; throw
        `FormatException` for any pattern key that is not a valid regex
  - [x] Tests: property matched by one pattern; property matched by multiple
        patterns (all matching schemas validated, all violations surfaced);
        unmatched property produces no violation; invalid `patternProperties`
        regex key throws `FormatException` at parse time; interaction with
        `additionalProperties: false`; pattern matching is unanchored (partial
        match on property name passes)
- [x] **`AdditionalPropertiesSchemaRule`** and parser guard removal
  - [x] Remove the `parsedProperties != null` guard at `schema_parser.dart:115`;
        `additionalProperties` (false or schema) must be active even when
        `properties` is absent
  - [x] Build the "evaluated" key set at parse time: union of `properties` keys
        and all property names matched by any `patternProperties` pattern is
        computed at parse time where possible; remaining runtime matching handled
        by `PatternPropertiesRule`
  - [x] Add `AdditionalPropertiesSchemaRule` to `schema_rule.dart`; applies a
        sub-schema to every property not covered by `properties` or
        `patternProperties`; `false` still emits existing `AdditionalPropertiesRule`
  - [x] Update `SchemaParser.parse()` to detect `additionalProperties` as a
        `Map`, parse as sub-schema, emit `AdditionalPropertiesSchemaRule`
  - [x] Tests: additional property valid against schema passes; additional
        property invalid against schema fails; declared `properties` key not
        re-validated; `patternProperties`-matched key not re-validated;
        `additionalProperties: false` with no `properties` rejects every key;
        `additionalProperties` schema with no `properties` validates every key;
        key matched by both `properties` and a pattern only validated by
        `properties` (not re-validated by `additionalProperties`)
- [x] **Update `docs/spec/`** — document the newly supported keywords
- [x] Run `make pre_commit` and confirm all tests pass at ≥ 90% coverage

## Reviews

### Review 1: 2026-06-14

**Problem Statement Assessment**

The problem is real and worth solving. Silently passing invalid documents is the
worst failure mode for a validator — it gives false confidence. The four keyword
groups are genuinely absent today (confirmed against `schema_parser.dart` and
`schema_rule.dart`), and the omission is not cosmetic: a schema author writing
`prefixItems`, `contains`, `patternProperties`, or schema-valued
`additionalProperties` gets zero enforcement with no warning. The plan aligns
with the `docs/roadmap/v0.md` entry "JSON Schema: missing keywords", so it is on
the planned path rather than scope creep.

One scoping observation: the spec README (`docs/spec/`) is currently a stub and
references "spec §25" / "schemaModelVersion: 1" for the supported keyword set
(see the `SchemaParser` doc comment). Adding four keyword groups changes the
supported-keyword surface. If §25 enumerates the supported keywords, that list
must be updated as part of this work, and a `schemaModelVersion` bump may be
warranted since older readers will silently ignore these new constraints. This
is currently absent from the implementation plan — see open questions.

**Proposed Solution Assessment**

The rule-per-keyword decomposition fits the existing `sealed class SchemaRule`
architecture cleanly, and the decision to resolve the
`properties`/`patternProperties`/`additionalProperties` interaction at *parse*
time (building the combined allowed-key set) rather than via runtime cross-rule
communication is the right call — the current `SchemaRule.validate` contract is
deliberately stateless and independent, and threading "evaluated properties"
between rules at runtime would break that cleanly. Good instinct.

Strengths:
- `ContainsRule` correctly bundles the three coupled keywords into one rule.
- The "violations from the sub-schema are a counting signal, not emitted"
  framing for `contains` is exactly right and avoids leaking inner failures.
- The `minContains: 0` semantics are called out correctly.

Weaknesses / gaps to resolve before implementation:

1. **`patternProperties` regex anchoring.** The plan says "apply the sub-schema
   of every pattern that matches the property name" but does not specify match
   semantics. Per spec §6.5.5, `patternProperties` keys are ECMA-262 regexes
   that are **not anchored** — a pattern matches a property name if it matches
   *any substring*. This is the exact bug the sibling plan
   `plan_json_schema_correctness.md` is fixing for `pattern` (replacing anchored
   `firstMatch` checks with `hasMatch`). The implementation here must use
   `RegExp.hasMatch` for name matching, not the anchored `firstMatch`/full-span
   logic copied from `StringRule`. Call this out explicitly so the implementer
   does not reproduce the anchoring bug.

2. **The "only active when properties declared" caveat must not carry over.**
   The current parser only emits `AdditionalPropertiesRule` when
   `parsedProperties != null` (line 115). That guard is wrong for the new world:
   `additionalProperties` (false *or* schema) is valid with no `properties` at
   all — every key is then "additional". With `patternProperties` present but no
   `properties`, the allowed-key set is empty and the pattern set is non-empty.
   The plan's parse-time combined-set approach handles this, but the existing
   `parsedProperties != null` guard needs to be explicitly removed/reworked or
   the new behaviour will silently no-op when `properties` is omitted. This is
   not yet in the implementation checklist.

3. **`prefixItems` array-length edge cases.** The plan covers the main path but
   should state behaviour when the array is *shorter* than `prefixItems`
   (extra prefix schemas simply do not apply — no violation; this is correct per
   spec but must be a test) and confirm that `prefixItems` is independent of
   `minItems`/`maxItems`. Also note `items: false` (boolean) in 2020-12 forbids
   any elements beyond the prefix — the plan only contemplates `items` as a
   schema (`Map`). Decide whether boolean `items` is in scope; the current
   parser only handles `Map` items, so this may be a pre-existing gap to leave
   alone, but it should be a conscious decision.

4. **`contains` does not require `type: array`.** As written, `ContainsRule`
   should no-op on non-array values (consistent with every other rule guarding
   its type), leaving array-ness enforcement to a separate `TypeRule`. Worth a
   test asserting `contains` produces no violation on a non-array, matching the
   established convention (`ArrayRule`, `PropertiesRule` etc. all `return []` on
   type mismatch).

**Architecture Fit**

Strong fit. This is pure Core-layer work (`lib/src/`) in a package with no
Flutter or UI surface, so the design/inclusivity skills do not apply and the
library-architecture layering is trivially preserved — every new rule lives
alongside the existing rules in `schema_rule.dart` and is reached only through
`SchemaParser`. Rules remain unexposed publicly, consistent with the existing
doc comment contract. No public API surface change beyond the keywords the
parser now recognises. CBOR encoding and UUIDv7 conventions are not touched.

**Risk & Edge Cases**

- **Coverage.** Four new rules plus a reworked parser interaction must clear the
  90% threshold. The test bullets are reasonable but light on the *interaction*
  cases, which is where the real risk lives: `properties` + `patternProperties`
  + `additionalProperties: <schema>` all present, a key matched by both
  `properties` and a pattern, a key matched by multiple patterns where one
  sub-schema passes and another fails (both violations must surface).
- **Regex compilation failure.** A malformed `patternProperties` key is an
  invalid `RegExp` and will throw at parse time. Decide the policy: skip the
  bad pattern, or surface a parse error? The current parser is lenient
  ("unknown keywords silently ignored") so silently skipping is the consistent
  choice, but it should be deliberate and tested.
- **Empty `contains` sub-schema** (`contains: {}`) matches every element, so
  `minContains`/`maxContains` effectively become array-count constraints. Worth
  a test.
- **Performance is a non-issue** at this scale; no concern.

**Recommendations**

Solid plan, correct architecture, aligned with the roadmap. It is close to
implementation-ready but I am holding it at `Questions` rather than promoting it,
because three of the gaps above (anchoring semantics, the `parsedProperties !=
null` guard removal, and the spec/`schemaModelVersion` update) are correctness
issues that will produce wrong behaviour or an undocumented surface if missed —
not mere test additions. Once the open questions are resolved and the
implementation checklist absorbs items 1–3, this is ready for `Investigated`.

**Open questions**

- [x] `schemaModelVersion` stays at `1`; no bump. `docs/spec/` updated to list
      newly supported keywords.
- [x] `patternProperties` uses unanchored `RegExp.hasMatch`. Added to checklist.
- [x] `parsedProperties != null` guard removal is in scope. Added to checklist.
- [x] Boolean `items` is in scope for v0. Added to checklist.
- [x] Invalid `patternProperties` regex → throw `FormatException` at parse time.

## Summary

- Added `AlwaysInvalidRule` to `schema_rule.dart` — a sentinel that always fails, used as the payload for boolean `false` schemas (`items: false`, `additionalProperties: false` with pattern properties).
- Added `ContainsRule` to `schema_rule.dart` implementing `contains` / `minContains` / `maxContains` (§6.4.4–6.4.6). Sub-schema violations are used as a counting signal only and never forwarded to the caller.
- Added `PrefixItemsRule` to `schema_rule.dart` for positional element validation per `prefixItems` (§6.4.1). Arrays shorter than the prefix list produce no violation for unmatched schemas.
- Extended `ArrayRule` with an `itemsStartIndex` parameter so `items` applies only to elements beyond the prefix when `prefixItems` is present. Boolean `items: true` is a no-op; `items: false` emits `AlwaysInvalidRule`.
- Added `PatternPropertiesRule` to `schema_rule.dart` with unanchored `RegExp.hasMatch` matching per spec §6.5.5. Invalid regex keys throw `FormatException` at parse time.
- Added `AdditionalPropertiesSchemaRule` to `schema_rule.dart` that validates additional properties against a sub-schema while correctly skipping both declared keys and pattern-matched keys.
- Updated `SchemaParser` to wire all new rules; removed the `parsedProperties != null` guard so `additionalProperties` (both `false` and schema form) now activates even when `properties` is absent.
- Parser now uses `AdditionalPropertiesSchemaRule` (with `AlwaysInvalidRule`) for `additionalProperties: false` in all cases, ensuring `patternProperties`-matched keys are correctly excluded at runtime.
- Added `test/src/schema_missing_keywords_test.dart` with 53 tests covering all new rules, edge cases, boundary conditions, and keyword interactions.
- Updated `docs/spec/README.md` to document `contains`/`minContains`/`maxContains`, `prefixItems` and boolean `items`, `patternProperties`, and the schema form of `additionalProperties`.
- All 749 tests pass; coverage 95.5% (above the 90% threshold); zero analyzer issues.
- No deviations from the plan. The `parsedProperties != null` guard was cleanly replaced by always using `AdditionalPropertiesSchemaRule` for both `false` and schema forms.
- `schemaModelVersion` stays at `1` per the decision recorded in open questions.
