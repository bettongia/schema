---
title: Release Readiness Review
subtitle: betto_schema 0.1.0-dev.1
date: 2026-06-15
reviewer: release-ninja
...

# Release Readiness Review — `betto_schema` 0.1.0-dev.1

Audit date: 2026-06-15. Two release targets in scope:

1. Publication to **pub.dev**.
2. Making the **GitHub repository public**.

Verdict is based on real tool output (`dart test`, `dart pub global run
coverage:test_with_coverage`, `dart analyze`, `dart format`, `dart pub publish
--dry-run`, `dart doc --dry-run`), not static reading alone.

---

## Executive Summary

**Verdict: NO-GO for pub.dev publication. CONDITIONALLY READY for GitHub public
repo.**

The engineering substance of this package is in good shape: 914 tests pass,
line coverage is **95.60%** (above the 90% bar in CLAUDE.md), `dart analyze`
reports **no issues**, `dart format` is clean, and `dart pub publish --dry-run`
reports **0 warnings**. The pure-Dart constraint is respected — no
`package:flutter` or `dart:ui` import exists anywhere in `lib/`.

So why a NO-GO? Because the single most-read artefact on a pub.dev page — the
README — contains a **code sample that does not compile** and an **import that
does not resolve**. The first thing a prospective user does is copy the README
example. For this package, that copy-paste fails twice. Shipping a 65 KB archive
of well-tested code behind a front door that is wired backwards is not a
release; it is a support-ticket generator. These are cheap to fix (minutes), so
the NO-GO is a "fix four small things, then ship," not a structural condemnation.

The GitHub side is cleaner: no secrets, no credentials, no stray personal
information beyond the maintainer's own `noreply` commit identity and a
deliberate `AUTHORS` entry. The blockers there are governance-file omissions
(no `SECURITY.md`, no `CODE_OF_CONDUCT.md`), which are advisory-to-medium, not
hard blockers.

---

## pub.dev Readiness

### What passes (verified, not assumed)

| Check | Result |
| :-- | :-- |
| `dart pub publish --dry-run` | **0 warnings**, archive 65 KB |
| `dart analyze` | No issues found |
| `dart format --set-exit-if-changed` | 40 files, 0 changed |
| `dart test` | **914 / 914 pass** |
| Line coverage | **95.60%** (1043 / 1091 lines) |
| LICENSE present | Apache-2.0, 11 KB, recognised |
| CHANGELOG present | Yes (minimal) |
| `example/` present | Yes (3 files) |
| pubspec `description` length | 49 chars — within pub.dev's 60–180 ideal? **No, too short** |
| Dependencies resolve from pub.dev | Yes — `betto_common`, `betto_abnf` are hosted, not path deps |
| Pure Dart (no Flutter) | Verified — zero `package:flutter` / `dart:ui` in `lib/` |

### Blocking issues (P0 — must fix before publish)

**1. README primitive-validator example does not compile.**
`README.md` lines 74–87 show:

```dart
import 'package:betto_schema/schema.dart';   // <- file does not exist
final inRange = Minimum(0) & Maximum(100);    // <- operator& does not exist
```

- The library barrel is `lib/betto_schema.dart`. There is **no
  `lib/schema.dart`** — the import will not resolve. The example in
  `example/main.dart` and `example/validators.dart` correctly imports
  `package:betto_schema/betto_schema.dart`, so the README is the outlier.
- `Validator<T>` (`lib/src/validation.dart:27`) defines `bool call(T input)`
  but **no `operator &`** exists anywhere in `lib/` (verified by grep). The
  expression `Minimum(0) & Maximum(100)` is a compile error. Either add a
  combinator operator to `Validator`, or rewrite the example to compose
  validators in a supported way.

  User impact: every reader who tries the headline "compose validators
  directly" feature hits a compile error on line one. This is the package's
  Layer-1 "primary, first-class public API" per CLAUDE.md, so the broken
  example undermines exactly the selling point the architecture leads with.

**2. README "Supported JSON Schema keywords" table is stale.**
The roadmap (`docs/roadmap/v0.md`) marks `contains` / `minContains` /
`maxContains`, `prefixItems`, `patternProperties`, sub-schema
`additionalProperties`, and seven new format strings (`hostname`,
`idn-hostname`, `ipv4`, `ipv6`, `uri-reference`, `json-pointer`,
`relative-json-pointer`) as **Complete**. None of these appear in the README
keyword table (lines 29–42) or the Features format list (lines 16–17). The
README undersells the package and misrepresents its capabilities to anyone
sizing it up against alternatives. Publishing a feature table that omits
shipped, tested features is a documentation defect, not a nicety.

### Advisory issues (P1 / P2 — should fix, affects pub.dev score)

**3. CHANGELOG is a stub (P1).** It contains only `## 0.1.0-dev.1 / - Initial
version.` pub.dev surfaces the CHANGELOG prominently. For an initial dev
release this is tolerable but it should at minimum summarise what the package
provides, mirroring the keyword coverage. Empty-ish changelogs read as
abandonment signals.

**4. `pubspec.yaml` metadata thin (P1).** `description` is 49 characters —
pub.dev's analysis penalises descriptions outside ~60–180 chars. There are no
`topics:` declared (free pub.dev discoverability points; e.g. `json-schema`,
`validation`, `schema`). Add a richer description and topics.

**5. Prerelease dependencies (P1 — dependency risk).** Both `betto_common:
^0.1.0-dev.1` and `betto_abnf: ^0.1.0-dev.1` are themselves `-dev` prereleases.
A caret constraint on a `0.1.0-dev.1` version is extremely narrow and these
upstream packages can change shape without semver protection. If either is
yanked or breaks API, `betto_schema` breaks. Confirm both are actually
published and stable on pub.dev before relying on them, and consider whether
this package should depend on prerelease libraries at all for its own first
release.

**6. Unresolved dartdoc references (P2).** `dart doc --dry-run` emits 4
warnings for doc references that point at types not in scope:
- `lib/src/schema_rule.dart:29` → `[SchemaManager]` (type does not exist in
  this package)
- `lib/src/formats/lang.dart:59` → `[FormatParserException]`
- `lib/src/formats/roman.dart:73,76` → `[RomanNumeralParseException]`
- one `[Result]` reference

These render as broken links in the generated API docs that pub.dev hosts.
Either import/qualify the referenced types or convert them to plain-text
inline code.

**7. Published archive carries non-runtime files (P2).** The dry-run archive
includes `coverage_baseline/lcov.info` (8 KB), `header_template.txt`,
`analysis_options.yaml`, `AUTHORS`, `CONTRIBUTING.md`, and the entire `test/`
tree. None of this is needed by consumers. `.pubignore` already excludes
`docs/`, `Makefile`, etc., but does not exclude `coverage_baseline/`,
`header_template.txt`, or `test/`. Trimming these reduces the download and
tidies the package listing. Not a blocker (no warning raised), but it is sloppy
to ship a coverage baseline and a license header template to every consumer.

### pub.dev scoring estimate

| Dimension (weight) | Likely outcome |
| :-- | :-- |
| Follows conventions | Mostly pass; thin description and missing topics cost points |
| Provides documentation | **At risk** — example exists but is broken; 4 dartdoc warnings |
| Platform support | Pure Dart, all platforms — should score well |
| Passes analysis | Full marks (clean analyze + format) |
| Up-to-date dependencies | Partial — 5 transitive deps have newer incompatible versions; prerelease direct deps |

Realistically this lands a decent-but-not-great score **once the README is
fixed**. With the broken example in place, the documentation pillar suffers and,
more importantly, real users get burned.

---

## GitHub Public Repository Readiness

### Clean (verified)

- **No secrets / credentials.** Grep for API keys, tokens, passwords, private
  keys, AWS key patterns across `*.dart`, `*.yaml`, `*.yml`, `*.md`, `*.txt`
  found only false positives (JSON-pointer `token` terminology, the
  `id-token` workflow permission, `getValidator`). No real secret material.
- **No stray personal data.** The only personal identifier in tracked files is
  the maintainer's `noreply` GitHub email in `AUTHORS` and in commit metadata —
  both intentional and already designed to be public. No private email
  (`gonkamatic@…`) appears in any tracked file.
- **No junk tracked.** `.DS_Store` is not tracked; `site/`, `coverage/`,
  `coverage_baseline/` build outputs are not tracked. `.gitignore` covers
  `.dart_tool/`, `pubspec.lock`, `coverage/`, `site/`, `*.log`, `.claude`.
- **CI workflow permissions are least-privilege** (`contents: read`, plus
  pages write/id-token for deploy). Good.

### Blocking / medium concerns

**8. No `SECURITY.md` (P1).** A public repo accepting issues should tell people
how to report a vulnerability privately. Add a `SECURITY.md` (even a one-liner
pointing at a contact or GitHub private advisories). For a validation library —
where a malformed-input bypass is a plausible security report — this matters
more than for a typical utility package.

**9. No `CODE_OF_CONDUCT.md` (P2).** GitHub's community-standards checker flags
its absence. Low effort to add.

**10. `CONTRIBUTING.md` explicitly refuses PRs (advisory, not a defect).** The
file states PRs are not accepted and issues may go unanswered. That is a
legitimate maintainer choice, but pair it with `SECURITY.md` so security
reports have a channel even when feature PRs are closed.

### Advisory

**11. `.gitignore` ignores `.claude` but tracked `.claude/` directory exists.**
The working tree shows a `.claude/` directory; `.gitignore` lists `.claude`.
Confirm nothing under `.claude/` (settings, hooks, local config) is actually
tracked before going public — `git ls-files` should return nothing under it.
The `.pubignore` and `.gitignore` both reference it, which is good hygiene;
just verify it took effect.

**12. `.pubignore` references files that may not exist** (`Containerfile`,
`integration_test_app/`, `tool/`, `Claude.md` with wrong case vs `CLAUDE.md`).
Harmless, but the `Claude.md` vs `CLAUDE.md` case mismatch means `CLAUDE.md`
is **not** excluded from the published archive on case-sensitive filesystems —
verify `CLAUDE.md` is not shipping to pub.dev (it did not appear in the dry-run
file list, so likely fine, but the rule is misspelled and should be corrected).

---

## Prioritised Fix List

### P0 — must fix before any release

- **Fix README import path**: `package:betto_schema/schema.dart` →
  `package:betto_schema/betto_schema.dart` (README.md line 75).
- **Fix or remove the broken `&` example**: `Minimum(0) & Maximum(100)` does
  not compile — no `operator &` exists on `Validator`. Either implement the
  combinator and add a test, or rewrite the example using a supported
  composition pattern. Then compile-check the README snippet.

### P1 — should fix before publish

- Update README "Supported JSON Schema keywords" table and Features list to
  include `contains`/`minContains`/`maxContains`, `prefixItems`,
  `patternProperties`, sub-schema `additionalProperties`, and the seven new
  format strings shipped per `docs/roadmap/v0.md`.
- Expand `pubspec.yaml` `description` to 60–180 chars; add `topics:`.
- Flesh out CHANGELOG entry to describe the initial feature set.
- Confirm `betto_common` / `betto_abnf` are published and stable; reconsider
  depending on `-dev` prereleases for a release.
- Add `SECURITY.md`.

### P2 — nice to have

- Resolve the 4 dartdoc reference warnings (`SchemaManager`, `Result`,
  `FormatParserException`, `RomanNumeralParseException`).
- Exclude `test/`, `coverage_baseline/`, `header_template.txt`,
  `analysis_options.yaml`, `AUTHORS`, `CONTRIBUTING.md` from the published
  archive via `.pubignore`.
- Add `CODE_OF_CONDUCT.md`.
- Fix the `Claude.md` (wrong case) entry in `.pubignore`.
- Verify nothing under `.claude/` is git-tracked.

---

## Open Questions for the Maintainer

1. **Is `Validator` composition (`&` / `|`) an intended public feature?** The
   README advertises it but the code does not implement it. Should it be added
   to the API (it is genuinely useful for Layer 1), or was the example
   aspirational and should be removed?
2. **Are `betto_common` and `betto_abnf` published on pub.dev at stable
   versions you control?** Publishing `betto_schema` will pull them; if either
   is unpublished or volatile, this release is built on sand.
3. **Do you intend to ship a `0.1.0-dev.1` prerelease to pub.dev, or cut a
   `0.1.0` stable first?** A `-dev` version is fine for early adopters but the
   broken README will still be the public face — fix it regardless.
4. **Given `CONTRIBUTING.md` declines PRs, how should security issues be
   reported?** This drives the contents of `SECURITY.md`.

---

## Bottom Line

The code is release-grade. The packaging is not — yet. Fix the two P0 README
defects (an hour of work, including recompiling the snippet), refresh the
keyword table, and the technical case for publishing is strong. Do not publish
with a README whose first example fails to compile.

---

## Follow-up Review — 2026-06-15

Reviewer: release-ninja. Fresh tool runs: `dart doc --dry-run`, `dart analyze`,
`dart test`, `dart pub publish --dry-run`. All commands executed against the
current working tree.

### Tool results (fresh)

| Tool | Result |
| :-- | :-- |
| `dart test` | **914 / 914 pass** |
| `dart analyze` | No issues found |
| `dart pub publish --dry-run` | **0 warnings**, archive 72 KB |
| `dart doc --dry-run` | **0 warnings, 0 errors** |

### What was fixed (verified)

**P0.1 — README import path** (was blocking). The import in the primitive
validator example now reads `package:betto_schema/betto_schema.dart` —
the correct barrel. The old `package:betto_schema/schema.dart` is gone.
Verified by inspection of `README.md` lines 84–96.

**P0.2 — Broken `&` operator example** (was blocking). The expression
`Minimum(0) & Maximum(100)` has been removed. The replacement example composes
two validators with `&&` on separate `bool call(...)` results, which compiles
correctly and accurately demonstrates the supported API. Example verified
against `Validator<T>` interface in `lib/src/validation.dart`.

**P1 — README keyword table** (was advisory, now resolved). The table now
includes `patternProperties`→`PatternPropertiesRule`, `additionalProperties:
<schema>`→`AdditionalPropertiesSchemaRule`, `prefixItems`→`PrefixItemsRule`,
and `contains` / `minContains` / `maxContains`→`ContainsRule`. The Features
format list now enumerates all seven previously missing format strings
(`hostname`, `idn-hostname`, `ipv4`, `ipv6`, `uri-reference`, `json-pointer`,
`relative-json-pointer`). No implemented keyword is missing from the public
documentation.

**pubspec `description`** (was P1, 49 chars → 159 chars — now well within the
60–180 char band). Verified: `"Pure Dart JSON Schema 2020-12 library. Typed,
composable validators, a full keyword rule tree, and format validators for
email, URI, date-time, UUID, and more."` = 159 characters.

**pubspec `topics:`** — `schema`, `json-schema`, `validation` were already
present before this review; original finding was incorrect on this point.

**CHANGELOG** (was P1 stub). The entry is now 10 KB and fully documents the
primitive-validator table, the rule tree with every `SchemaRule` subtype, all
format validators (standard and project-specific), the CLI tool, six runnable
examples, and spec-correctness fixes. No longer a stub.

**dartdoc warnings** (was P2, 4 warnings). `dart doc --dry-run` now reports 0
warnings and 0 errors. All four broken cross-references (`[SchemaManager]`,
`[FormatParserException]`, `[RomanNumeralParseException]`, `[Result]`) have
been resolved. The generated API docs will link correctly.

**`isValidRegex` / `isValidDate` hidden from public barrel** (was P2). The
barrel at `lib/betto_schema.dart` now exports `src/formats/formats_base.dart`
with `hide isValidRegex, isValidDate`, removing these implementation-detail
helpers from the public surface.

**`StringValidatorService.supportedValidators` return type** (was P2). The
method signature is now `UnmodifiableMapView<String, StringValidator>` and the
implementation wraps `_supportedValidators` in `UnmodifiableMapView(...)`.
Mutation through the returned map is now impossible.

**`'lamg'` typo in lang validator** (was P2). The key in `formats_base.dart`
is now `'lang'`. Verified by grep.

**`SchemaRule` doc comment** (was P2). The class-level doc now correctly
references `SchemaParser.parse` and `JsonSchemaValidator` rather than the
former stub text.

**`AdditionalPropertiesRule` doc** (was P2). The doc comment now carries an
explicit `**Limitation:**` paragraph explaining that this rule has no
knowledge of `PatternPropertiesRule` and directing maintainers to use
`AdditionalPropertiesSchemaRule` when `patternProperties` is involved.

**`header_template.txt`** — now excluded from the published archive via
`.pubignore`. Confirmed absent from dry-run file list.

### What remains open

**P2 — `.pubignore` does not exclude `test/` or non-essential metadata files.**
The maintainer listed this as an item to fix, but the dry-run archive still
contains the full `test/` tree (11 test files, ~88 KB uncompressed), plus
`analysis_options.yaml`, `AUTHORS`, and `CONTRIBUTING.md`. The old
`coverage_baseline/` directory no longer exists (removed from the tree), so
that concern is resolved automatically. Excluding `test/` alone would save
the bulk of the unnecessary weight. Suggested additions to `.pubignore`:

```
test/
analysis_options.yaml
AUTHORS
CONTRIBUTING.md
```

This is not a blocker — `dart pub publish --dry-run` reports 0 warnings with
these files included, and pub.dev imposes no penalty. It is purely a hygiene
issue that makes the download smaller and the package listing cleaner. Archive
is currently 72 KB; trimming `test/` would bring it materially closer to the
`lib/` + `example/` core.

### Items intentionally out of scope (not re-checked)

Per the maintainer's instructions the following original findings were not
re-evaluated:

- Item 5 (prerelease deps `betto_common` / `betto_abnf`) — intentional; both
  packages are maintainer-controlled.
- Items 8, 9, 10 (`SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md` PR
  policy) — not a concern for this release.
- Item 12 (`.pubignore` referencing non-existent files) — confirmed non-issue.
- Item 11 (`.claude/` git-tracking) — confirmed non-issue.

### Updated verdict

**CONDITIONAL GO.**

Both original P0 blockers (import path, broken `&` example) are fixed and
verified. The README now correctly represents the package's feature set. Tool
suite is clean: 914 tests pass, 0 analyze issues, 0 dartdoc warnings, 0
publish warnings.

The one remaining open item — `test/` and a handful of metadata files shipping
in the archive — is cosmetic and carries no pub.dev penalty. It can be
addressed in a follow-up `.pubignore` commit immediately before or after
publication without gating the release.

**The package is ready to publish.** Fix `.pubignore` at any time; it does not
need to block.

### Punch list

| Priority | Item | Status |
| :-- | :-- | :-- |
| P2 | Add `test/`, `analysis_options.yaml`, `AUTHORS`, `CONTRIBUTING.md` to `.pubignore` | Open — cosmetic, does not block |
