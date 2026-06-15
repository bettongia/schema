# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## General

Work is planned using specifications in the `docs/plans` directory. When working
on plans make sure you review `docs/plans/README.md` file for guidance. When
asked to plan something do not commence implementation until explicitly told to
do so.

The `docs/roadmap` directory is used to track future work items and their
priority. This is worth reviewing when working on the codebase as current work
may intersect with the roadmap.

We'll create plans for our work and place them in the `docs/plans/` directory.
When the planned work has been completed we'll move them to
`docs/plans/completed`.

Quality assurance is critical to this project and you need to maintain a minimum
of 90% test coverage at all times. You must also run all tests successfully
before considering a task to be complete.

Consider edge-cases and failure scenarios when preparing tests - it is critical
not just to focus on easy, "golden-path" tests.

All public classes, methods and properties must have appropriate doc comments.
You may include examples in dec comments if you believe it will help another
developer.

Any complex segments of code should be commented so as to describe the process
and rationale for the approach.

All code files must have a license at the top. The template file is
@header_template.txt. You must add the comment syntax appropriate to the
programming language. Also replace `{{.Year}}` to match the current year.

## Project Overview

`betto_schema` is a **pure Dart** package (package name: `betto_schema`,
version: `0.1.0-dev.1`) that provides JSON Schema validation primitives. It
aligns with the [JSON Schema Validation specification](https://json-schema.org/draft/2020-12/json-schema-validation.html)
and is used as the low-level schema layer for KMDB's collection schema feature
(spec §25).

**Critical constraint:** This is a pure Dart library. The Flutter SDK must
**never** be added as a dependency — not in `pubspec.yaml`, not in any import,
and not in any Makefile target. Use `dart` commands only (not `flutter`).

## Repository Layout

```
lib/
  betto_schema.dart          # Public library entry point
  src/
    schema_base.dart         # Primitive validators (Minimum, MaximumLength, etc.)
    schema_rule.dart         # Sealed SchemaRule hierarchy (TypeRule, RequiredRule, etc.)
    schema_parser.dart       # Compiles Map<String,dynamic> JSON Schema → SchemaRule tree
    schema_violation.dart    # SchemaViolation (dot-path + message)
    json_schema_validator.dart  # Top-level JsonSchemaValidator
    validation.dart          # Validation helpers
    range.dart               # Numeric range helpers
    lists.dart               # List-related helpers
    formats/                 # Format validators (email, uri, date, uuid, isbn-13, etc.)
test/
  src/                       # Mirrors lib/src/ structure
example/                     # Standalone usage examples
docs/
  plans/                     # Implementation plans (see docs/plans/README.md)
  roadmap/                   # Roadmap items (v0.md, v1.md, …)
  reviews/                   # Code, security, and other review artefacts
  spec/                      # Technical specification (Pandoc Markdown)
site/                        # Built HTML site (generated via make site)
```

## Commands

The `Makefile` should contain all key development lifecycle commands. In
general, `make` should be preferred to directly running commands such as `dart`
and `flutter`.

After running tests or coverage, `*.dart.vm.json` files are generated inside
`test/`. These are build artifacts (already listed in `.gitignore`) and should
be deleted before committing. Run:

```bash
find test -name "*.dart.vm.json" -delete
```

```bash
# Run tests
make test

# Analyze/lint
make analyze

# Format code
make format

# Coverage
make coverage

# Build docs site (requires pandoc)
make site

# Run checks before committing code
make pre_commit
```

## Implementation Status

v0.1.0-dev.1 — core JSON Schema keywords implemented (see README.md for the
full keyword table). Out of scope for v1: `$ref`, `allOf`/`anyOf`/`oneOf`/`not`,
`if`/`then`/`else`, and nested `$schema` declarations.

## Architecture

This package is a pure Dart library with no Flutter dependency. It has three
layers, from core outward:

### Layer 1 — Programmatic validators (`validation.dart`, `formats/`)

`Validator<T>` and `StringFormatValidator` classes are the **primary, first-class
public API**. A Dart developer constructs and composes these directly without
ever touching JSON Schema format. Schemas here are expressed as Dart objects.

The format validators in `lib/src/formats/` implement a **superset** of the
standard JSON Schema format strings: they include all spec-defined formats
(`email`, `date-time`, `uuid`, etc.) plus project-specific extensions (`doi`,
`isbn-13`, `roman-numeral`, etc.).

### Layer 2 — Rule tree (`schema_rule.dart`, `schema_parser.dart`)

`SchemaRule` subtypes wrap the `Validator` classes from Layer 1, adding
dot-path tracking and violation collection (`List<SchemaViolation>`). They are
compiled from a `Map<String, dynamic>` JSON Schema by `SchemaParser`. This
layer exists to support JSON Schema format input — it is not intended to be
constructed by hand.

The sealed `SchemaRule` hierarchy collects **all** violations in a single pass
so callers receive the complete error list at once.

### Layer 3 — Porcelain (`json_schema_validator.dart`)

`JsonSchemaValidator` is a thin convenience wrapper whose sole job is to accept
a JSON Schema as a string or map, delegate to `SchemaParser`, and return a
`List<SchemaViolation>`. It adds no validation logic of its own.

### Invariants

- Layer 1 must never import Layer 2 or Layer 3.
- Layer 2 rules delegate to Layer 1 validators; they do not reimplement logic
  inline.
- Layer 3 only calls Layer 2; it never bypasses `SchemaParser` to touch
  `SchemaRule` subtypes directly.

## Documentation

Full specification is in [docs/spec/](docs/spec/) (Pandoc Markdown). The built
HTML lives in [site/](site/) and is generated via `make site`. Key spec files:

- [docs/spec/README.md](docs/spec/README.md) — technical specification for `betto_schema`
- [docs/roadmap/v0.md](docs/roadmap/v0.md) — v0 roadmap items
- [docs/plans/README.md](docs/plans/README.md) — plan template and workflow
