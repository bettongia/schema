# JSON Schema: Standard Format Strings

**Status**: Complete

**PR link**: _pending_

## Problem statement

The JSON Schema Validation 2020-12 spec (§7.3) defines a set of standard
format strings that implementations are expected to recognise. Eleven of these
are absent from `StringFormatValidator` in `formats_base.dart`. Schemas using
these format names are silently accepted today (unknown formats produce no
violations, per the spec's SHOULD language), but users have no way to opt into
validation for them.

## Open questions

- [x] **Scope of `hostname` / `idn-hostname`**: RFC 1123 hostnames and
      IDNA 2008 internationalized hostnames can be complex to validate
      precisely. Should we implement a pragmatic regex-based check (fast,
      slightly permissive) or a full conformance check?
      **Decision:** pragmatic regex for v0, with a code comment noting the
      best-effort nature. Full IDNA 2008 conformance requires Punycode
      processing with no suitable pure-Dart dependency available; can be
      upgraded in v1 if needed.

- [x] **`uri-template` (RFC 6570)**: Template syntax is non-trivial.
      A regex approximation may produce false positives. Confirm whether a
      best-effort check is acceptable or if this format should be deferred.
      **Decision:** deferred — omit from v0. The RFC 6570 expression grammar
      is complex enough that a regex approximation would pass invalid templates
      and reject valid ones. The spec's SHOULD language allows silently ignoring
      the format without breaking conformance.

- [x] **`relative-json-pointer`**: Requires parsing the JSON Pointer grammar
      plus a leading non-negative integer. A simple regex is sufficient.
      **Decision:** implement with a single regex.

## Investigation

### Formats defined by the spec but not implemented

| Format string | Standard | Notes |
|---|---|---|
| `idn-email` | RFC 6531 | Internationalized email; extends `email` to allow non-ASCII local parts and domains |
| `hostname` | RFC 1123 §2.1 | DNS hostname labels; max 253 chars, labels max 63 chars, alphanumeric + hyphen, no leading/trailing hyphen |
| `idn-hostname` | RFC 5890 §2.3.2.3 | IDNA 2008 internationalized hostname; requires IDNA processing |
| `ipv4` | RFC 2673 §3.2 | Dotted-quad notation; each octet 0–255 |
| `ipv6` | RFC 4291 §2.2 | Full and compressed colon-hex notation |
| `uri-reference` | RFC 3986 §4.1 | URI or relative reference; superset of `uri` |
| `iri` | RFC 3987 | Internationalized URI — **deferred to v1** |
| `iri-reference` | RFC 3987 | Relative IRI reference — **deferred to v1** |
| `uri-template` | RFC 6570 | URI template with `{variable}` expressions — **deferred to v1** |
| `json-pointer` | RFC 6901 | Starts with `/`, tokens separated by `/`, `~` escaped as `~0`/`~1` |
| `relative-json-pointer` | draft-bhutton | Non-negative integer prefix followed by a JSON Pointer or `#` |

### Existing format infrastructure

`StringFormatValidator` in [formats_base.dart](../../lib/src/formats/formats_base.dart)
holds a `Map<String, StringValidator>`. Adding a new format is a matter of:

1. Implementing a validation function (new file in `lib/src/formats/` or inline
   lambda for simple regex cases).
2. Adding a `StringValidator` entry to the `_supportedValidators` map.
3. Exporting the new file from `formats_base.dart` if it is non-trivial.

No changes to `SchemaRule`, `SchemaParser`, or `FormatRule` are needed —
`FormatRule` already looks up the format by name and silently ignores unknowns.

### Implementation approach per format

**`ipv4`** — Regex: four decimal octets 0–255 separated by `.`. Simple and
accurate.

**`ipv6`** — Regex is complex due to compressed notation (`::`) and mixed
IPv4-in-IPv6. Dart's `InternetAddress.tryParse` from `dart:io` can parse IPv6
but `dart:io` is not available in all Dart contexts. Use a well-tested regex
instead.

**`hostname`** — RFC 1123: labels are `[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?`,
dot-separated, total length ≤ 253. Regex approach is sufficient.

**`idn-hostname`** — Requires IDNA processing. For v0, accept any
`hostname`-valid string or a unicode label that would be valid after Punycode
encoding (pragmatic: allow unicode letters in labels). Flag in code that this
is a best-effort check.

**`uri-reference`** — RFC 3986: an absolute URI or a relative reference.
Structural check: passes if `Uri.tryParse` succeeds (covers absolute URIs and
well-formed relative references), AND the string does not contain characters
illegal in both forms (unescaped spaces, control characters, `<>` outside
delimiters). Concrete failing inputs: `"hello world"` (space), `"\x00"` (NUL),
`"[bad"` (unclosed bracket in host). Must land after `plan_json_schema_correctness`
has corrected the `uri` validator.

**`iri` / `iri-reference`** — Deferred to v1. See `docs/roadmap/v1.md`.

**`idn-email`** — Deferred to v1. Cannot be built on `Email.isValid` (30-char
cap, ASCII-only regexes). See `docs/roadmap/v1.md`.

**`uri-template`** — Deferred to v1. See `docs/roadmap/v1.md`.

**`json-pointer`** — Must start with `/` or be empty string; tokens separated
by `/`; `~` only appears as `~0` or `~1`. Simple regex.

**`relative-json-pointer`** — Non-negative integer (no leading zeros unless
`"0"`) followed by either `#` or a JSON Pointer. Simple regex.

## Implementation plan

**Prerequisite:** `plan_json_schema_correctness` must be merged first so that
the `uri` validator is correct before `uri-reference` is defined relative to it.

- [x] **`ipv4`**
  - [x] Implement regex validator inline in `formats_base.dart`; use per-octet
        alternation (`25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d`) to reject leading
        zeros and out-of-range values in a single pass
  - [x] Tests: `192.168.0.1` passes; octet `256` fails; leading zero `01.0.0.0`
        fails; missing octet `1.2.3` fails; extra octet `1.2.3.4.5` fails
- [x] **`ipv6`**
  - [x] Implement regex validator as `lib/src/formats/ipv6.dart`; cover full
        eight-group form, all `::` compressed positions, and IPv4-mapped tail
  - [x] Export from `formats_base.dart`
  - [x] Tests: `::` (all-zeros); `::1` (loopback); `1::` ; `1::2`;
        `::ffff:1.2.3.4` (IPv4-mapped); full eight-group address; two `::` fails;
        more than eight groups fails; group with five hex digits fails;
        uppercase hex accepted (case-insensitive)
- [x] **`hostname`**
  - [x] Implement regex validator inline in `formats_base.dart`; labels are
        `[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?`, dot-separated, total
        length ≤ 253; trailing dot rejected; uppercase labels accepted
  - [x] Tests: `example.com` passes; `foo.bar.baz` passes; label with leading
        hyphen fails; label with trailing hyphen fails; label > 63 chars fails;
        total > 253 chars fails; trailing dot `example.com.` fails;
        `EXAMPLE.COM` passes (case-insensitive)
- [x] **`idn-hostname`** (best-effort)
  - [x] Implement as `lib/src/formats/idn_hostname.dart`; accept any
        `hostname`-valid ASCII string or a label containing Unicode letters/digits
        (pragmatic: `[\p{L}\p{N}]` in labels); add code comment noting
        best-effort nature (not full IDNA 2008 / Punycode conformance)
  - [x] Export from `formats_base.dart`
  - [x] Tests: ASCII hostname passes; unicode label (`München.de`) passes;
        label with leading hyphen fails; invalid ASCII hostname fails
- [x] **`uri-reference`**
  - [x] Implement structural check: `Uri.tryParse` succeeds AND string contains
        no unescaped spaces, control characters, or `<>`; inline in
        `formats_base.dart`
  - [x] Tests: `https://example.com` passes; `/path/to` passes; `../foo` passes;
        `#section` passes; empty string passes (valid relative reference);
        `"hello world"` fails (space); `"\x00"` fails (NUL); `"[bad"` fails
        (unclosed bracket)
- [x] **`json-pointer`**
  - [x] Implement regex `^(/([^~]|~[01])*)*$` inline in `formats_base.dart`
  - [x] Tests: `""` (root) passes; `/foo` passes; `/foo/bar` passes;
        `/a~0b` (`~0` escape) passes; `/a~1b` (`~1` escape) passes;
        `/a~2b` (invalid escape) fails; `foo` (no leading slash) fails
- [x] **`relative-json-pointer`**
  - [x] Implement regex `^(0|[1-9][0-9]*)(#|(/([^~]|~[01])*)*)$` inline in
        `formats_base.dart`
  - [x] Tests: `0` passes; `1/foo` passes; `0#` passes; `2/a/b` passes;
        `01` fails (leading zero); `#` fails (no integer prefix)
- [x] **Update `docs/spec/`** — document the seven newly registered formats
- [x] Run `make pre_commit` and confirm all tests pass at ≥ 90% coverage

## Reviews

### Review 1: 2026-06-14

**Problem Statement Assessment**

The problem is real and well-scoped. The JSON Schema Validation 2020-12 spec
(§7.3) does define these formats, they are genuinely absent from
`StringFormatValidator`, and the roadmap (`docs/roadmap/v0.md`) lists this as a
planned v0 item. Adding opt-in validators for spec-defined formats is a sensible
correctness improvement, and the plan correctly notes that unknown formats are a
SHOULD (so the change is additive, not breaking). No objection to the goal.

One framing nit: the title and roadmap say "eleven" formats, but `uri-template`
is deferred, so this plan delivers ten. The investigation table still lists
eleven rows. Keep the count honest in the table caption to avoid confusion when
someone audits §7.3 coverage later.

**Proposed Solution Assessment**

The map-entry-per-format approach fits the existing `_supportedValidators`
structure exactly and is the right shape. The per-format breakdown is thorough
and the test enumerations are a genuine strength — edge cases (octet > 255,
leading zeros, compressed `::`, `~` escapes, leading-zero rejection in
relative-json-pointer) are called out specifically rather than hand-waved. That
is the standard this project expects.

However, the solution rests on two technical assumptions that do not hold
against the current codebase, and these are blockers:

1. **The `Uri.tryParse` strategy is far weaker than the plan implies.**
   `uri-reference`, `iri`, and `iri-reference` all lean on
   `Uri.tryParse(value) != null`. `Uri.tryParse` in Dart is extremely
   permissive: it accepts the empty string, bare words with no scheme, strings
   with spaces, and most non-ASCII input. It returns null only for a narrow set
   of structural failures (e.g. malformed host/port, bad percent-encoding). As a
   `uri-reference` validator this is *almost* defensible because RFC 3986
   relative references are themselves very permissive — but as written it will
   pass strings that are not valid references and the test "clearly malformed
   fails" / "malformed" cases (iri, iri-reference) will be hard to satisfy
   because `Uri.tryParse` rejects so little. The plan needs to specify, per
   format, *what concrete input is expected to fail* and confirm `Uri.tryParse`
   actually rejects it. Right now several of those tests are likely unwritable
   against the proposed implementation.

2. **The `iri` "percent-encode then validate as URI" approach is
   under-specified and probably wrong.** Percent-encoding an arbitrary string
   and then parsing it as a URI does not distinguish a valid IRI from arbitrary
   text — almost anything percent-encodes into something `Uri.tryParse` accepts.
   This will be a validator that passes essentially everything. Either commit to
   a real best-effort structural check (scheme + iauthority/ipath shape allowing
   the RFC 3987 ucschar ranges) or state explicitly that `iri`/`iri-reference`
   are accept-permissive stubs and write the tests to match. Do not claim
   "clearly malformed fails" if the implementation cannot deliver it.

**Architecture Fit**

The plan fits the formats subsystem cleanly. This is pure-Dart Core-layer work
(`lib/src/formats/`) with no Flutter dependency, no storage, no domain-model or
public-barrel restructuring — the library-architecture layer boundaries are not
engaged, so that skill raises nothing here. The mechanics of registration
(map entry, optional file, export) are accurately described and match
`formats_base.dart`.

Two concrete integration problems with the current file, though:

- **The `uri`/`urn` validators are currently swapped.** In `formats_base.dart`,
  the `uri` entry calls `Urn.tryParse` and the `urn` entry calls `Uri.tryParse`
  (lines 65 and 71). This is a known bug already tracked under the "spec
  correctness fixes" roadmap item and its own plan
  (`plan_json_schema_correctness.md`). It matters here because this plan adds
  `uri-reference` as a sibling of `uri` and reasons about it as "a superset of
  `uri`". If the correctness fix and this plan land independently, whichever
  lands second risks reasoning about, or copying, the wrong `tryParse` call.
  The plan should declare an explicit ordering dependency: the `uri`/`urn` swap
  fix should land first, and `uri-reference` should be defined relative to the
  *corrected* `uri` validator.

- **`Email.isValid` cannot simply be "extended" for `idn-email`.** The plan says
  to "extend or wrap `Email.isValid` to permit non-ASCII characters." Two
  obstacles: (a) the regexes in `email.dart` are `const` ASCII-only character
  classes — permitting non-ASCII means a parallel regex, not a tweak; and
  (b) `Email.tryParse` hard-caps input at `maxInputLength: 30`, which silently
  rejects perfectly valid longer addresses. Any `idn-email` validator built on
  top of `Email.isValid` inherits that 30-character cap. The plan must decide
  whether to wrap `Email` (and live with the cap, or pass a larger limit) or
  write a standalone `idn-email` validator. As written, "wrap `Email.isValid`"
  produces a validator that rejects valid long emails — that is a latent bug,
  not a best-effort approximation.

**Risk & Edge Cases**

- **`ipv4` regex vs. RFC 2673.** The plan cites RFC 2673 §3.2, but the format
  JSON Schema actually requires is the standard dotted-quad (RFC 2673 is the
  "dotted-decimal in DNS" oddity; the spec intent is an ordinary IPv4 address).
  The implementation note ("four octets 0–255") is correct; just align the
  citation so a future reader does not implement the wrong grammar. Also pin
  down leading-zero behaviour: `01.0.0.0` — the test list says "leading zeros"
  should be rejected, which is the right call (avoids ambiguous octal
  interpretation), but make the regex enforce it rather than relying on range
  alone.

- **`hostname` trailing dot.** The plan flags this as "confirm desired
  behaviour" but leaves it open. The JSON Schema test suite treats the FQDN
  trailing-dot form as a real case; decide now (recommend: reject trailing dot
  for the `hostname` format, since §7.3 points at RFC 1123 host *names*, not
  zone-file FQDNs) so the implementer is not guessing.

- **`ipv6` regex maintenance burden.** A fully correct IPv6 regex covering all
  compressed `::` positions plus IPv4-mapped tails is notoriously error-prone.
  The plan correctly rejects `dart:io` `InternetAddress` (not available on web —
  good catch, that platform reasoning is exactly right for this library). But a
  hand-rolled regex needs an unusually broad test matrix: `::`, `::1`, `1::`,
  `1::2`, IPv4-mapped `::ffff:1.2.3.4`, the all-zeros `::`, a full eight-group
  address, and the invalid cases (two `::`, more than eight groups, a group with
  five hex digits). Make the IPv6 test list exhaustive — the current "full;
  compressed; IPv4-mapped; invalid" is too coarse for the failure modes this
  regex will have.

- **No mention of normalisation / case sensitivity** for hostnames and scheme
  comparisons. Hostnames are case-insensitive; confirm the validators do not
  reject uppercase labels.

- **Spec doc update.** `docs/spec/` is currently a stub (`README.md` only). If
  the specification is intended to enumerate supported formats, this plan should
  add the ten new formats to the spec once that section exists. Not a blocker
  today given the spec is unwritten, but note it so it is not forgotten when the
  spec is fleshed out. CLAUDE.md requires spec docs be kept current.

**Recommendations**

The plan is close, but it is **not ready for implementation as written** — the
`Uri.tryParse`-based validators (`uri-reference`, `iri`, `iri-reference`) and
the `idn-email` "wrap `Email.isValid`" step rest on assumptions that the current
code contradicts, and several "malformed fails" tests are likely unwritable
against the proposed implementations. I am moving the status back to `Questions`
pending the items below. Concrete asks:

1. Re-baseline the `uri`/`urn` and `idn-email`/`iri` validators against the
   *actual* `formats_base.dart` and `email.dart`, accounting for the swapped
   `uri`/`urn` validators and the 30-char email cap.
2. For every format whose test list includes a "malformed/invalid fails" case,
   name the specific failing input and confirm the proposed implementation
   actually rejects it. This is the fastest way to surface the `Uri.tryParse`
   over-permissiveness.
3. Declare the ordering dependency on `plan_json_schema_correctness.md` (the
   `uri`/`urn` swap fix).
4. Resolve the two deferred decisions (hostname trailing dot; ipv4 leading
   zeros) in the plan body rather than in the test checklist.

The IPv4, hostname, json-pointer, and relative-json-pointer formats are
self-contained, accurate, and ready. The blockers are concentrated in the
URI/IRI/IDN cluster.

**Open questions**

- [x] **`uri-reference`, `iri`, `iri-reference` implementation.**
      **Decision:** Implement `uri-reference` with a structural check (absolute
      URI or recognisable relative-reference form). Defer `iri` and
      `iri-reference` to v1 — a proper RFC 3987 validator is out of scope for
      v0. Both are recorded in `docs/roadmap/v1.md`.
- [x] **`idn-email` implementation.**
      **Decision:** Deferred to v1. Cannot be built by wrapping `Email.isValid`
      (ASCII-only regexes, hard-coded 30-character input cap). Recorded in
      `docs/roadmap/v1.md`.
- [x] **Ordering dependency on `plan_json_schema_correctness.md`.**
      **Decision:** Yes — this plan must land after Plan 1 so that `uri` is
      already corrected before `uri-reference` is defined relative to it.
- [x] **`hostname` trailing dot.**
      **Decision:** Reject. The spec cites RFC 1123 host names, not DNS
      zone-file FQDNs.
- [x] **`ipv4` leading zeros.**
      **Decision:** Reject via the regex itself (per-octet alternation), not
      via range alone. `01.0.0.0` must not pass.

## Summary

- Added seven new JSON Schema §7.3 format validators to `StringFormatValidator`:
  `ipv4`, `ipv6`, `hostname`, `idn-hostname`, `uri-reference`, `json-pointer`,
  and `relative-json-pointer`.
- `ipv4` implemented inline in `formats_base.dart` via a per-octet regex
  alternation that rejects leading zeros and out-of-range values in a single
  pass.
- `ipv6` implemented in a new `lib/src/formats/ipv6.dart` using a group-counting
  approach (no `dart:io`) covering full 8-group, all `::` compressed positions,
  and IPv4-mapped tails. Zone ID suffixes (`%eth0`) are correctly rejected as
  they are not part of the RFC 4291 text representation grammar.
- `hostname` implemented inline per RFC 1123 §2.1; trailing dots explicitly
  rejected per the plan decision.
- `idn-hostname` implemented in a new `lib/src/formats/idn_hostname.dart`;
  best-effort Unicode label check with a clear code comment noting it is not
  full IDNA 2008 / Punycode conformance.
- `uri-reference` implemented inline: disallow character class for unescaped
  spaces, control characters, and angle brackets, combined with `Uri.tryParse`.
- `json-pointer` and `relative-json-pointer` implemented inline as single
  regexes, matching the plan's specified patterns exactly.
- Deferred formats (`iri`, `iri-reference`, `idn-email`, `uri-template`) were
  not implemented, consistent with the plan decisions.
- 165 new tests added in `test/src/formats/new_formats_test.dart` covering
  valid and invalid cases for all seven formats, plus direct class tests.
- All 914 tests pass; line coverage is 95.6% (above the 90% threshold).
- `docs/spec/README.md` updated with detailed behaviour documentation for each
  new format in the appropriate sections.
- No deviations from the plan as investigated.
