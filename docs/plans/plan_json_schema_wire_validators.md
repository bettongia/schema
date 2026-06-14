# JSON Schema: Wire Existing Validators into the Rule Layer

**Status**: Investigated

**PR link**: _pending_

## Problem statement

Six JSON Schema keywords are fully implemented as `Validator` classes in
`validation.dart` but are not reachable via the public API because they have
no corresponding `SchemaRule` subtype and no parsing branch in `SchemaParser`.
Callers using `JsonSchemaValidator` or `SchemaParser` silently ignore these
keywords today.

## Open questions

- [x] **"Delegate vs inline" framing.**
      **Decision:** `validation.dart` (`Validator<T>` classes) is the primary
      programmatic API (Layer 1). `SchemaRule` subtypes are Layer 2 wrappers
      that add path tracking and violation collection. The intent is for rules
      to delegate to validators — this is the correct architecture, not a new
      divergence. The fact that existing rules reimplement inline is the debt
      being paid off. New rules added by this plan must delegate to Layer 1.
      Existing rules that reimplement inline are candidates for a future
      refactor plan (not in scope here — avoid churn).
- [x] **Two-layer convergence intent.**
      **Decision:** Converge. `validation.dart` is Layer 1 (primary API,
      pure bool return); `schema_rule.dart` is Layer 2 (wraps Layer 1, adds
      path + violations). `JsonSchemaValidator` is Layer 3 porcelain. This is
      now documented in CLAUDE.md.
- [x] **Spec docs scope.**
      **Decision:** In scope — populate the relevant `docs/spec/` sections for
      these six keywords as part of this plan's implementation checklist.

**Consequence for implementation:** Some `Validator` classes need to be fixed
before the rules can delegate to them (`UniqueItems` uses `toSet()` which
breaks on nested collections; `ConstValidator` uses `==` which breaks on
`List`/`Map`). Fix those validators first, then delegate from the rule. This
plan must land after `plan_json_schema_correctness` (the correctness fixes
establish the right baseline for the Layer 1 validators).

## Investigation

The following table maps each missing keyword to its existing validator class
and the spec section that defines it.

| Keyword | Existing `Validator` | Spec |
|---|---|---|
| `const` | `ConstValidator` | §6.1.3 |
| `multipleOf` | `MultipleOf` | §6.2.1 |
| `uniqueItems` | `UniqueItems` | §6.4.3 |
| `minProperties` | `MinProperties` | §6.5.2 |
| `maxProperties` | `MaxProperties` | §6.5.1 |
| `dependentRequired` | `DependentRequired` | §6.5.4 |

All validators can be found in
[validation.dart](../../lib/src/validation.dart).

For each keyword the work is mechanical:

1. Add a `SchemaRule` subclass to `schema_rule.dart` that delegates its check
   to the existing `Validator` (or re-implements inline — see notes per keyword
   below).
2. Add a parsing branch in `SchemaParser.parse()` that reads the keyword value
   from the schema map and constructs the new rule.
3. Write tests covering the happy path, boundary conditions, and type-mismatch
   (wrong type is silently skipped — rules only validate when the instance is
   the expected type).

### Per-keyword notes

**`const` (§6.1.3)**  
The value may be any JSON type including `null`. Deep equality is needed for
nested objects and arrays — Dart `==` is sufficient for primitives but not for
`List`/`Map`. Use `const DeepCollectionEquality()` from `package:collection`
(already a dependency) for the comparison.

**`multipleOf` (§6.2.1)**  
Applies only to numbers. The spec requires the keyword value to be strictly
greater than 0. The existing `MultipleOf` validator handles `divisor == 0` by
returning `false`; document this as a schema-error guard rather than a
validation violation.

**`uniqueItems` (§6.4.3)**  
Applies only when the instance is an array. The keyword value must be `true`
to activate the check (`false` or absent means no validation). The existing
`UniqueItems` validator uses `toSet().length` which works for primitive
elements but not for `List`/`Map` elements. Use `DeepCollectionEquality` here
as well.

**`minProperties` / `maxProperties` (§6.5.2 / §6.5.1)**  
Apply only when the instance is an object (Dart `Map`). Both validators
already exist and are correct. These can share a single `ObjectSizeRule` or be
two separate rules — two separate rules keeps the pattern consistent with
`NumericRule` (which combines minimum/maximum into one class).

**`dependentRequired` (§6.5.4)**  
The keyword value is a JSON object where each key maps to an array of required
property names. The `DependentRequired` validator is correct for its bool API
but cannot be delegated to for violation collection — `call()` returns `bool`,
not a list of which dependent properties are missing. `DependentRequiredRule`
must implement the violation collection inline (one `SchemaViolation` per
missing dependent property), keeping `DependentRequired` as-is for direct
caller use.

## Implementation plan

**Prerequisite:** `plan_json_schema_correctness` must be merged first so that
Layer 1 validators have their known bugs fixed before this plan adds delegation
from Layer 2.

- [ ] **Fix Layer 1 validators before delegating**
  - [ ] `ConstValidator`: replace `==` with `DeepCollectionEquality().equals()`
        for nested `List`/`Map` equality
  - [ ] `UniqueItems`: replace `toSet().length` comparison with
        `DeepCollectionEquality` pairwise check so nested objects are compared
        by value
  - [ ] `DependentRequired.call()`: cannot be delegated to as-is (returns
        `bool`); the rule must collect per-property violations — leave validator
        as-is and implement violation collection inline in `DependentRequiredRule`
- [ ] **`ConstRule`**
  - [ ] Add `ConstRule` to `schema_rule.dart`; delegate equality check to
        updated `ConstValidator`
  - [ ] Add `'const'` branch to `SchemaParser.parse()`
  - [ ] Tests: primitive match/mismatch; `const: null`; nested object equality;
        array equality; `const: null` key present with wrong value vs absent
- [ ] **`MultipleOfRule`**
  - [ ] Add `MultipleOfRule` to `schema_rule.dart`; delegate to `MultipleOf`
        validator; skip non-numeric instances; read keyword as `num?`
  - [ ] Add `'multipleOf'` branch to `SchemaParser.parse()`
  - [ ] Tests: divisible passes; not divisible fails; non-numeric skipped;
        floating-point divisor (e.g. `0.01`); `multipleOf: 0` schema guard
- [ ] **`UniqueItemsRule`**
  - [ ] Add `UniqueItemsRule` to `schema_rule.dart`; delegate to updated
        `UniqueItems` validator; skip non-List; skip when keyword value is not
        `true`
  - [ ] Add `'uniqueItems'` branch to `SchemaParser.parse()`
  - [ ] Tests: unique primitives pass; duplicates fail; `uniqueItems: false`
        always passes; nested object duplicates detected
- [ ] **`ObjectSizeRule`** (covers `minProperties` and `maxProperties`)
  - [ ] Add `ObjectSizeRule` to `schema_rule.dart`; delegate to `MinProperties`
        / `MaxProperties` validators; skip non-Map instances
  - [ ] Add `'minProperties'` and `'maxProperties'` branches to
        `SchemaParser.parse()`
  - [ ] Tests: within range passes; below min fails; above max fails; combined
        min+max; non-object skipped
- [ ] **`DependentRequiredRule`**
  - [ ] Add `DependentRequiredRule` to `schema_rule.dart`; implement violation
        collection inline (one `SchemaViolation` per missing dependent property,
        path consistent with `RequiredRule` format)
  - [ ] Add `'dependentRequired'` branch to `SchemaParser.parse()`
  - [ ] Tests: trigger property absent → no validation; trigger present +
        dependents present → pass; trigger present + dependent missing →
        violation with correct path; multiple trigger properties; empty
        dependent list always passes
- [ ] **Update `docs/spec/`** — document the six newly supported keywords
- [ ] Run `make pre_commit` and confirm all tests pass at ≥ 90% coverage

## Reviews

### Review 1: 2026-06-14

**Problem Statement Assessment**

The problem is real and worth solving. I verified the gap directly:
`SchemaParser.parse()` has no branch for `const`, `multipleOf`, `uniqueItems`,
`minProperties`, `maxProperties`, or `dependentRequired`, and `schema_rule.dart`
has no rule subtype for any of them. A schema using these keywords silently
produces no violations — exactly the "invalid documents silently pass" failure
mode the roadmap flags as a correctness concern. The work aligns with the v0
roadmap entry "wire existing validators into the rule layer". Scope is tight and
appropriate. No objection to doing the work.

My objection is to the framing, which I think is misleading and will lead the
implementer astray (see below).

**Proposed Solution Assessment**

Strengths: the keyword-by-keyword breakdown is clear, the per-keyword notes
catch the genuinely tricky cases (deep equality for `const` and `uniqueItems`,
`multipleOf` divisor-zero guard, `dependentRequired` needing per-property
violations rather than a single bool), and the test checklist names real
boundary and type-mismatch cases rather than golden-path-only. The decision to
emit one violation per missing dependent property is the right call and matches
how `RequiredRule` already reports per-field.

The core weakness is the central premise. The plan repeatedly says each rule
should "delegate its check to the existing `Validator`". This does not match the
codebase. I checked every rule in `schema_rule.dart`: none of them delegate to a
`Validator`. `TypeRule` reimplements the `switch` from `TypeValidator` inline;
`NumericRule` reimplements `Minimum`/`Maximum`; `ArrayRule` reimplements
`MinItems`/`MaxItems`. `schema_rule.dart` does not even import `validation.dart`.
The two layers are entirely parallel code paths. So "wire the existing
validators in" is not what the surrounding code does, and following the premise
literally would make these six rules the only ones in the file that reach into
`validation.dart` — an inconsistency, new coupling, and a `Validator`/`bool` vs
`SchemaRule`/`List<SchemaViolation>` impedance mismatch the plan already half-
acknowledges (it says to reimplement `dependentRequired` inline, and to use
`DeepCollectionEquality` for `const`/`uniqueItems` because the existing
validators use plain `==` / `toSet()` which are wrong for nested collections).

In other words: for three of the six keywords the plan already concludes the
existing validator is unsuitable and must be reimplemented. That strongly
suggests the honest framing is "implement six new `SchemaRule` subtypes inline,
following the existing rule pattern" — not "wire existing validators in". The
validators in `validation.dart` are essentially dead code relative to this
pipeline. The plan should say so plainly, because an implementer who tries to
delegate will either fight the type mismatch or introduce an oddly inconsistent
file.

**Architecture Fit**

Mechanically the fit is good: each new keyword becomes a `final class … extends
SchemaRule` with the standard `if (value is! Expected) return [];` type-guard
skip, plus a parser branch. That is exactly the existing idiom and the new rules
will slot in cleanly. Recommend two consolidations consistent with current
structure:

- `minProperties`/`maxProperties` as a single `ObjectSizeRule` mirroring how
  `NumericRule` and `ArrayRule` bundle min/max. The plan already proposes this —
  good, keep it. Add the parser to emit one `ObjectSizeRule` when either key is
  present (matching the `NumericRule` construction pattern), not two rules.
- Parser type handling: note the existing parser reads `schema['minItems'] as
  int?` etc. For `multipleOf` the value may be a `double` (e.g. `0.01`), so read
  it as `num?`, not `int?`. For `minProperties`/`maxProperties` read as `int?`.
  For `uniqueItems` read the raw value and only activate when it is exactly
  `true` (the plan notes this — make sure the parser, not just the rule, guards
  it, otherwise `uniqueItems: false` would still construct an active rule).

Spec alignment is the bigger gap. The plan cites §6.1.3, §6.2.1, §6.4.3,
§6.5.1, §6.5.2, §6.5.4. None of these exist — `docs/spec/README.md` is an
11-line stub. The rule/parser doc comments also reference "spec §25" and
`schemaModelVersion: 1`, which likewise do not exist in `docs/spec/`. CLAUDE.md
requires spec docs to be updated as part of implementation. Either the spec
sections are authored elsewhere (point me at them) or authoring the relevant
spec entries must be added to this plan's checklist. As written, the plan
references a specification that isn't in the repo.

Library-architecture check: this work touches only the pure-Dart core
(`lib/src/*.dart`), adds no Flutter imports, and changes no public barrel
beyond what is already exported (`schema_rule.dart`, `schema_parser.dart` are
already exported via `betto_schema.dart`; rules remain internal-by-convention
and are reached through `SchemaParser`/`JsonSchemaValidator`). No layer-boundary
concerns. No UI, so design/inclusivity skills do not apply.

**Risk & Edge Cases**

Mostly well covered. Additional cases the implementer should not miss:

- `multipleOf` floating-point: `0.3 % 0.1` is not `0` in IEEE-754. The existing
  `MultipleOf.multipleOf` uses `input % divisor == 0`, which will produce false
  violations for cases like `multipleOf: 0.1` against `0.3`. The plan lists a
  `0.01` test but does not flag that the naive modulo is numerically unsafe.
  Decide the tolerance strategy (e.g. divide and check the quotient is integral
  within an epsilon) and add a test that would fail under naive modulo. This is
  precisely why reimplementing rather than delegating to `MultipleOf` is the
  right move.
- `const` with `null`: the plan notes the value may be `null`. Confirm the rule
  distinguishes "field absent" from "field present and `null`" the same way the
  rest of the pipeline does — `const` validates the value it is handed; presence
  is `required`'s job. A test for `const: null` against an actual `null` value
  passing, and against a non-null value failing, is needed.
- `uniqueItems` deep equality cost: `DeepCollectionEquality` with `toSet()`
  needs a matching deep hasher (`DeepCollectionEquality().hash`) or an O(n²)
  pairwise comparison. Pick one explicitly; a naive `LinkedHashSet` with deep
  equality but default hashing will not dedupe correctly.
- `dependentRequired` path semantics: the plan says "violation with correct
  path". Confirm whether the violation path points at the object (`path`) or the
  missing dependent key (`path.key`). `RequiredRule` uses `path.field` for the
  missing field — match that for consistency, and add the test asserting the
  exact path string.
- Empty-object and empty-array edge cases for `minProperties: 0` / empty array
  `uniqueItems` (vacuously unique) — cheap to add, easy to forget.

**Recommendations**

1. Reframe the plan: these are six new `SchemaRule` subtypes implemented inline
   in the established pattern, not a wiring of existing validators. Drop the
   "delegate to the existing `Validator`" language (or justify why this work
   alone should introduce delegation). This is the most important change.
2. Resolve the spec question: either link the authoritative spec or add spec
   authoring to the checklist. Do not cite section numbers that don't exist.
3. Add the `multipleOf` floating-point tolerance decision and test.
4. Pin down `uniqueItems` deep-equality hashing strategy and
   `dependentRequired` violation path, with asserting tests for each.
5. Keep the `ObjectSizeRule` consolidation; ensure the parser guards
   `uniqueItems` on `== true` and reads `multipleOf` as `num?`.

The underlying work is sound and low-risk. I am holding the plan at `Questions`
rather than `Investigated` because the framing contradiction and the missing
spec reference are decisions the author should make before implementation, not
during it. Once the three open questions are answered, this is ready to proceed.

**Open questions** (mirrored at top-level `## Open questions`)

- [ ] Inline implementation vs delegation to `Validator` classes — which pattern?
- [ ] Do the `Validator` layer and the `SchemaRule` pipeline converge or stay
      parallel?
- [ ] Where is the authoritative spec text, and is spec authoring in scope?

## Summary

_Pending implementation._
