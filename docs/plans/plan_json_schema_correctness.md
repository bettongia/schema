# JSON Schema: Correctness Fixes

**Status**: Implementing

**PR link**: _pending_

## Problem statement

Four keyword implementations produce behaviour that directly contradicts the
JSON Schema Validation 2020-12 specification. These are not missing features —
they are bugs that make the library return wrong results for valid schemas today.

## Open questions

- [x] **`uri` format will accept valid URNs after the swap.**
      **Decision:** A URN is a URI (urn is a registered URI scheme), so `uri`
      accepting a valid URN is correct. The format validators aim to be a
      superset of the standard — `Uri.tryParse` behaviour is intentional.
      Tests should assert that `uri` accepts both http URLs and valid URNs;
      `urn` strictly validates URN syntax only.
- [x] **Spec docs are an 11-line stub.**
      **Decision:** In scope — populating the relevant `docs/spec/` sections
      for these four corrected behaviours is part of this plan's implementation
      checklist.
- [x] **Should this plan fix `PatternValidator` / `TypeValidator` in
      `validation.dart`?**
      **Decision:** Yes. `validation.dart` is the primary programmatic API
      (Layer 1); `SchemaRule` wraps it. Both layers must be correct and
      consistent. Fix both here. The wire-validators plan will then have correct
      validators to delegate to.

## Investigation

### 1. `pattern` is incorrectly anchored

**Spec §6.3.3:** "Regular expressions are not implicitly anchored."
A schema of `{"pattern": "foo"}` must accept `"foobar"` because the pattern
only needs to match somewhere in the string.

Current code in `StringRule.validate()` ([schema_rule.dart:259–263](../../lib/src/schema_rule.dart#L259)):

```dart
final m = pattern!.firstMatch(value);
if (m == null || m.start != 0 || m.end != value.length) {
```

And in `PatternValidator.call()` ([validation.dart:403–406](../../lib/src/validation.dart#L403)):

```dart
final match = pattern.firstMatch(input);
return match != null && match.start == 0 && match.end == input.length;
```

Both enforce a full-string match, which is anchoring.

**Fix:** replace both with `pattern.hasMatch(value)` /
`pattern.hasMatch(input)`.

---

### 2. `integer` type rejects numbers with zero fractional part

**Spec §6.1.1:** "A numeric instance is valid against `integer` if its value
is without a fractional part." So `1.0` (a Dart `double`) must be accepted.

Current code in `TypeRule.validate()` ([schema_rule.dart:76](../../lib/src/schema_rule.dart#L76)):

```dart
'integer' => value is int,
```

And in `TypeValidator.call()` ([validation.dart:624](../../lib/src/validation.dart#L624)):

```dart
'integer' => input is int,
```

**Fix:** `value is int || (value is double && value % 1 == 0)` in both places.

---

### 3. `type` only accepts a string, not an array

**Spec §6.1.1:** "The value of this keyword MUST be either a string or an
array." An instance is valid when its type matches any entry in the array.
e.g. `{"type": ["string", "null"]}` accepts both strings and `null`.

Current parser ([schema_parser.dart:46–49](../../lib/src/schema_parser.dart#L46)):

```dart
final type = schema['type'];
if (type is String) {
  rules.add(TypeRule(type));
}
```

A `List` value is silently ignored.

**Fix:** When `type` is a `List`, add a `TypeArrayRule` (or expand `TypeRule`)
that checks whether the value matches any of the listed types using the same
per-type logic as the existing switch. `TypeValidator` in `validation.dart`
has the same single-string limitation and should be updated consistently.

---

### 4. `uri` and `urn` format validators are swapped

In [formats_base.dart:61–72](../../lib/src/formats/formats_base.dart#L61), the
`uri` entry calls `Urn.tryParse()` and the `urn` entry calls `Uri.tryParse()`.
These are inverted.

**Fix:** Swap the implementations so `uri` validates with `Uri.tryParse()` and
`urn` validates with `Urn.tryParse()`.

---

## Implementation plan

- [ ] **Fix `pattern` anchoring**
  - [ ] `StringRule.validate()` in `schema_rule.dart`: replace firstMatch
        anchored check with `pattern!.hasMatch(value)`
  - [ ] `PatternValidator.call()` in `validation.dart`: same replacement
  - [ ] Add tests: pattern mid-string match passes; pattern with anchored-only
        match against wrong impl now passes; empty-pattern edge case
  - [ ] Update existing anchored `PatternValidator` tests in `validation_test.dart`
        (lines ~357–384) — they currently pin the buggy behaviour and will fail
- [ ] **Fix `integer` type**
  - [ ] `TypeRule` in `schema_rule.dart`: update `'integer'` branch to
        `value is int || (value is double && value % 1 == 0)`
  - [ ] `TypeValidator` in `validation.dart`: same change
  - [ ] Add tests: `1.0` valid as integer; `1.5` still invalid; `1` still valid;
        `double.nan` rejected; `double.infinity` rejected
- [ ] **Fix `type` array support**
  - [ ] Add `TypeArrayRule` to `schema_rule.dart` that accepts any value whose
        type matches at least one entry in the list
  - [ ] Update `SchemaParser.parse()` to handle `type is List` and emit
        `TypeArrayRule`
  - [ ] Update `TypeValidator` in `validation.dart` to accept a list of types
  - [ ] Add tests: `["string","null"]` accepts strings and null; rejects integers;
        single-element array equivalent to string form
- [ ] **Fix `uri`/`urn` swap**
  - [ ] Swap the two validator lambdas in `formats_base.dart`
  - [ ] Add tests: `https://example.com` passes `uri`; `urn:isbn:0451450523`
        passes both `uri` (URN is a URI) and `urn`; an http URL fails `urn`
- [ ] **Update `docs/spec/`**
  - [ ] Document the four corrected behaviours in the relevant spec sections
- [ ] Run `make pre_commit` and confirm all tests pass at ≥ 90% coverage

## Reviews

### Review 1: 2026-06-14

**Problem Statement Assessment**

Strong. All four claims are real bugs, and I verified each against the source:

- `pattern` anchoring — `schema_rule.dart:259–261` and `validation.dart:404–406`
  both enforce `start == 0 && end == length`, which is full-string anchoring.
  Contradicts the "not implicitly anchored" rule. Confirmed.
- `integer` — `schema_rule.dart:73` and `validation.dart:626` use `value is int`,
  so `1.0` (a Dart `double` with zero fractional part) is wrongly rejected.
  Confirmed.
- `type` array form — `schema_parser.dart:46–49` only handles `type is String`;
  a `List` value is silently dropped. Confirmed. Note `TypeRule` itself never
  sees the array because the parser discards it first, so the parser is the
  primary fix site.
- `uri`/`urn` swap — `formats_base.dart:65` (`uri` → `Urn.tryParse`) and `:71`
  (`urn` → `Uri.tryParse`) are inverted. Confirmed.

These are correctness bugs, not feature gaps, and the roadmap (`docs/roadmap/v0.md`)
lists this exact item as a v0 blocker. Worth solving, correctly scoped, aligned
with planned work. No conflicts with the roadmap.

**Proposed Solution Assessment**

The fixes for bugs 1, 2, and 3 are correct and minimal.

- Pattern: `hasMatch` is the right call.
- Integer: `value is int || (value is double && value % 1 == 0)` is correct.
  Worth an explicit test for the non-finite edge cases — `double.nan % 1` is
  `NaN` (not `== 0`, correctly rejected) and `double.infinity % 1` is `NaN`
  (correctly rejected). Add those two as regression tests so the guard is not
  later "simplified" into a bug.
- Type-as-array: extending `TypeRule` to hold a `List<String>` is cleaner than a
  separate `TypeArrayRule` — it avoids duplicating the per-type switch and keeps
  one rule type for one keyword. Either works; prefer the single-rule approach.

The bug-4 fix is where the plan is too glib. See Risk & Edge Cases.

**Architecture Fit**

Two structural points the plan does not surface:

1. There are **two parallel validation engines** in this library. The public
   `JsonSchemaValidator` is built entirely on `SchemaParser` → `schema_rule.dart`
   and never imports `validation.dart`. The `Validator` classes in
   `validation.dart` (`PatternValidator`, `TypeValidator`) are a separate,
   exported-but-not-wired layer, exercised only by their own direct tests. The
   plan's "fix in both places" framing treats this as mechanical duplication
   without noting that the two are not connected, and that the convergence of
   the two layers is an *open architectural question* in the sibling
   `plan_json_schema_wire_validators` plan. Fixing `validation.dart` here is
   defensible (those classes are public and currently wrong), but the plan
   should state the relationship explicitly so the two plans do not collide.

2. `docs/spec/` is currently an 11-line stub. The plan cites spec §6.1.1 /
   §6.3.3 (external JSON Schema spec text) and the code doc comments reference
   "§25 / schemaModelVersion: 1" — neither exists in this repo. CLAUDE.md
   requires spec docs to be updated as part of implementation. The plan has no
   step for this. Either bring the four corrected behaviours into `docs/spec/`
   or explicitly record that spec authoring is deferred to a separate effort.

**Risk & Edge Cases**

- **The bug-4 test assertion is incorrect.** Dart's `Uri.tryParse` is lenient:
  it returns non-null for almost any non-empty string, and crucially
  `urn:isbn:0451450523` *is* a syntactically valid URI (urn is a registered
  scheme). After the swap, the `uri` validator will **accept** that URN, so the
  planned test "each rejects the other's input" cannot hold for the `uri` side.
  The `urn` side is fine — `Urn.tryParse` is strictly anchored (`^...$`,
  `urn.dart:179`) and rejects `https://example.com`. Recommend asserting: `uri`
  accepts both an http URL and a URN; `urn` accepts only the URN and rejects the
  http URL. If the intent is for `uri` to *exclude* URNs, that is extra logic
  the plan does not describe and should be called out.
- `Uri.tryParse` also accepts bare words like `"foobar"` as relative-reference
  URIs. If `uri` is meant to require an absolute URI, `hasScheme`/`isAbsolute`
  checks are needed. Decide and document the intended strictness; otherwise the
  `uri` format is near-vacuous.
- Empty-pattern edge case (already noted in the plan): `RegExp('').hasMatch(x)`
  is always true — correct per spec, good that it is called out.
- Coverage: `validation_test.dart` already pins the *current* (buggy) behaviour
  of `TypeValidator('integer')(3.14)` etc. Those expectations are fine, but make
  sure the existing `PatternValidator` tests that assert anchored behaviour
  (`validation_test.dart:357–384`) are updated, not just added to — a stale
  assertion will fail or silently mask the fix.

**Recommendations**

Close to ready; not quite. Resolve the three open questions before promoting to
`Investigated`:

1. Correct the `uri`/`urn` test expectations (the URN-is-a-valid-URI issue) and
   decide intended `uri` strictness.
2. Decide spec-doc scope (update `docs/spec/` or explicitly defer).
3. State the relationship to `plan_json_schema_wire_validators` so the
   `validation.dart` edits do not churn against that work.

The core code fixes for bugs 1–3 are sound and can proceed as written. Add the
NaN/Infinity regression tests for the integer guard.

**Open questions**

- [ ] Correct the bug-4 test plan: a valid URN is a valid URI under
      `Uri.tryParse`, so `uri` cannot reject it. Define intended `uri`
      strictness (lenient superset vs absolute-URI-only).
- [ ] Decide whether `docs/spec/` updates are in scope or explicitly deferred.
- [ ] Confirm whether modifying `PatternValidator`/`TypeValidator` in
      `validation.dart` belongs here or in `plan_json_schema_wire_validators`.

## Summary

_Pending implementation._
