// Copyright 2026 The Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:characters/characters.dart';

import 'formats/formats_base.dart';
import 'schema_violation.dart';

/// Internal representation of a parsed JSON Schema.
///
/// Each [SchemaRule] subtype corresponds to one keyword group from the JSON
/// Schema subset supported by KMDB (spec §25). Rules validate a runtime
/// [dynamic] value and return every [SchemaViolation] found — all rules are
/// always evaluated so callers receive the complete list in one pass.
///
/// Rules are not exposed publicly; callers work through [SchemaParser] and
/// [SchemaManager].
sealed class SchemaRule {
  const SchemaRule();

  /// Validates [value] at [path] and returns every violation found.
  ///
  /// [path] is a dot-notation string identifying the location of [value]
  /// within the document (e.g. `'address.city'`, `''` for the root). Violations
  /// use [path] as their [SchemaViolation.path].
  List<SchemaViolation> validate(dynamic value, String path);
}

// ── Composite ────────────────────────────────────────────────────────────────

/// Runs multiple rules against the same value and collects all violations.
final class CompositeRule extends SchemaRule {
  const CompositeRule(this.rules);

  final List<SchemaRule> rules;

  @override
  List<SchemaViolation> validate(dynamic value, String path) {
    final violations = <SchemaViolation>[];
    for (final rule in rules) {
      violations.addAll(rule.validate(value, path));
    }
    return violations;
  }
}

// ── Type ─────────────────────────────────────────────────────────────────────

/// Checks whether [value] matches a single JSON Schema type string.
///
/// Returns `true` if the value satisfies [type]. Unknown type strings
/// are silently accepted (spec says unknown types are ignored).
bool _matchesType(String type, dynamic value) {
  return switch (type) {
    'string' => value is String,
    'number' => value is num,
    // Per JSON Schema spec §6.1.1, an integer is any number without a
    // fractional part — so 1.0 (a Dart double) must be accepted.
    // Non-finite doubles (NaN, Infinity) are excluded because their
    // modulo is NaN, not 0.
    'integer' =>
      value is int || (value is double && value.isFinite && value % 1 == 0),
    'boolean' => value is bool,
    'array' => value is List,
    'object' => value is Map,
    'null' => value == null,
    _ => true, // unknown types are silently ignored
  };
}

/// Validates the Dart runtime type of a value against a JSON Schema `type`.
///
/// Supports both the string form (`"type": "string"`) and the array form
/// (`"type": ["string", "null"]`) as required by JSON Schema spec §6.1.1.
/// In the array form the value is valid if it matches *any* of the listed
/// types (logical OR).
final class TypeRule extends SchemaRule {
  /// Creates a rule that accepts a single [type] string.
  TypeRule(String type) : types = [type], _single = type;

  /// Creates a rule that accepts any of [types] (array form).
  ///
  /// Per JSON Schema spec §6.1.1, a value is valid when its type matches
  /// at least one entry in the list.
  TypeRule.fromList(this.types) : _single = null;

  /// The JSON Schema type strings accepted by this rule.
  ///
  /// Contains exactly one entry in the single-string form, and two or more
  /// entries in the array form.
  final List<String> types;

  // Backing field for the single-string form; null when constructed via
  // [TypeRule.fromList].
  final String? _single;

  @override
  List<SchemaViolation> validate(dynamic value, String path) {
    if (_single != null) {
      // Single-type form: produce a targeted error message.
      if (!_matchesType(_single, value)) {
        return [SchemaViolation(path: path, message: 'expected type $_single')];
      }
      return [];
    }
    // Array form — value must match at least one listed type.
    for (final t in types) {
      if (_matchesType(t, value)) return [];
    }
    return [
      SchemaViolation(
        path: path,
        message: 'expected type to be one of: ${types.join(', ')}',
      ),
    ];
  }
}

// ── Required ─────────────────────────────────────────────────────────────────

/// Validates that all named fields are present in a map.
///
/// A field is considered present when its key exists in the map, even if
/// the value is `null`.
final class RequiredRule extends SchemaRule {
  const RequiredRule(this.fields);

  final List<String> fields;

  @override
  List<SchemaViolation> validate(dynamic value, String path) {
    if (value is! Map) return [];
    return [
      for (final field in fields)
        if (!value.containsKey(field))
          SchemaViolation(
            path: path.isEmpty ? field : '$path.$field',
            message: 'required field is missing',
          ),
    ];
  }
}

// ── Properties ───────────────────────────────────────────────────────────────

/// Recursively validates named fields in a map against per-field schemas.
///
/// Fields that are absent in the value are skipped — use [RequiredRule] to
/// enforce presence.
final class PropertiesRule extends SchemaRule {
  const PropertiesRule(this.properties);

  final Map<String, SchemaRule> properties;

  @override
  List<SchemaViolation> validate(dynamic value, String path) {
    if (value is! Map) return [];
    final violations = <SchemaViolation>[];
    for (final MapEntry(:key, value: rule) in properties.entries) {
      if (!value.containsKey(key)) continue;
      final fieldPath = path.isEmpty ? key : '$path.$key';
      violations.addAll(rule.validate(value[key], fieldPath));
    }
    return violations;
  }
}

// ── AdditionalProperties ─────────────────────────────────────────────────────

/// Rejects map keys that are not in the declared set.
///
/// Corresponds to `additionalProperties: false` in JSON Schema.
final class AdditionalPropertiesRule extends SchemaRule {
  const AdditionalPropertiesRule(this.allowed);

  final Set<String> allowed;

  @override
  List<SchemaViolation> validate(dynamic value, String path) {
    if (value is! Map) return [];
    return [
      for (final key in value.keys.cast<String>())
        if (!allowed.contains(key))
          SchemaViolation(
            path: path.isEmpty ? key : '$path.$key',
            message: 'additional property not allowed',
          ),
    ];
  }
}

// ── Enum ─────────────────────────────────────────────────────────────────────

/// Validates that a value is one of an enumerated set.
final class EnumRule extends SchemaRule {
  const EnumRule(this.values);

  final List<dynamic> values;

  @override
  List<SchemaViolation> validate(dynamic value, String path) {
    if (!values.contains(value)) {
      return [
        SchemaViolation(
          path: path,
          message: 'must be one of: ${values.join(', ')}',
        ),
      ];
    }
    return [];
  }
}

// ── Numeric ──────────────────────────────────────────────────────────────────

/// Validates numeric range constraints.
final class NumericRule extends SchemaRule {
  const NumericRule({
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
  });

  final num? minimum;
  final num? maximum;
  final num? exclusiveMinimum;
  final num? exclusiveMaximum;

  @override
  List<SchemaViolation> validate(dynamic value, String path) {
    if (value is! num) return [];
    final violations = <SchemaViolation>[];
    if (minimum != null && value < minimum!) {
      violations.add(
        SchemaViolation(path: path, message: 'must be >= $minimum'),
      );
    }
    if (maximum != null && value > maximum!) {
      violations.add(
        SchemaViolation(path: path, message: 'must be <= $maximum'),
      );
    }
    if (exclusiveMinimum != null && value <= exclusiveMinimum!) {
      violations.add(
        SchemaViolation(path: path, message: 'must be > $exclusiveMinimum'),
      );
    }
    if (exclusiveMaximum != null && value >= exclusiveMaximum!) {
      violations.add(
        SchemaViolation(path: path, message: 'must be < $exclusiveMaximum'),
      );
    }
    return violations;
  }
}

// ── String ───────────────────────────────────────────────────────────────────

/// Validates string length and pattern constraints.
final class StringRule extends SchemaRule {
  const StringRule({this.minLength, this.maxLength, this.pattern});

  final int? minLength;
  final int? maxLength;

  /// Pre-compiled regex for the `pattern` keyword.
  final RegExp? pattern;

  @override
  List<SchemaViolation> validate(dynamic value, String path) {
    if (value is! String) return [];
    final violations = <SchemaViolation>[];
    final len = value.characters.length;
    if (minLength != null && len < minLength!) {
      violations.add(
        SchemaViolation(
          path: path,
          message: 'must have at least $minLength characters',
        ),
      );
    }
    if (maxLength != null && len > maxLength!) {
      violations.add(
        SchemaViolation(
          path: path,
          message: 'must have at most $maxLength characters',
        ),
      );
    }
    if (pattern != null) {
      // Per JSON Schema spec §6.3.3, patterns are not implicitly anchored —
      // the pattern only needs to match somewhere within the string.
      if (!pattern!.hasMatch(value)) {
        violations.add(
          SchemaViolation(
            path: path,
            message: 'must match pattern ${pattern!.pattern}',
          ),
        );
      }
    }
    return violations;
  }
}

// ── Format ───────────────────────────────────────────────────────────────────

/// Surface-validates a string against a named format from [StringFormatValidator].
///
/// Unknown format names produce no violations (the spec says implementations
/// SHOULD support formats but are not required to reject unknown ones).
final class FormatRule extends SchemaRule {
  FormatRule(this.format)
    : _fn = StringFormatValidator().getValidator(format)?.function;

  final String format;
  final bool Function(String)? _fn;

  @override
  List<SchemaViolation> validate(dynamic value, String path) {
    if (value is! String || _fn == null) return [];
    if (!_fn(value)) {
      return [SchemaViolation(path: path, message: 'must be a valid $format')];
    }
    return [];
  }
}

// ── Array ────────────────────────────────────────────────────────────────────

/// Validates array length and per-element schema constraints.
final class ArrayRule extends SchemaRule {
  const ArrayRule({this.minItems, this.maxItems, this.items});

  final int? minItems;
  final int? maxItems;

  /// Schema applied to every element in the array.
  final SchemaRule? items;

  @override
  List<SchemaViolation> validate(dynamic value, String path) {
    if (value is! List) return [];
    final violations = <SchemaViolation>[];
    if (minItems != null && value.length < minItems!) {
      violations.add(
        SchemaViolation(
          path: path,
          message: 'must have at least $minItems items',
        ),
      );
    }
    if (maxItems != null && value.length > maxItems!) {
      violations.add(
        SchemaViolation(
          path: path,
          message: 'must have at most $maxItems items',
        ),
      );
    }
    if (items != null) {
      for (var i = 0; i < value.length; i++) {
        violations.addAll(items!.validate(value[i], '$path[$i]'));
      }
    }
    return violations;
  }
}
