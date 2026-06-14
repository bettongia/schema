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

import 'schema_rule.dart';

/// Parses a JSON Schema subset map into a [SchemaRule] tree.
///
/// The supported keyword set is defined in spec §25 (`schemaModelVersion: 1`).
/// Unknown keywords are silently ignored so that schemas written by a newer
/// KMDB version can be partially interpreted by an older one.
///
/// Example:
/// ```dart
/// final rule = SchemaParser().parse({
///   'required': ['name', 'email'],
///   'properties': {
///     'name': {'type': 'string', 'minLength': 1},
///     'email': {'type': 'string', 'format': 'email'},
///     'age': {'type': 'integer', 'minimum': 0},
///   },
/// });
/// final violations = rule.validate({'name': 'Alice'}, '');
/// // → [{path: 'email', message: 'required field is missing'}]
/// ```
final class SchemaParser {
  /// Parses [schema] into a [SchemaRule] tree.
  ///
  /// Returns a [CompositeRule] whose child rules correspond to each recognised
  /// JSON Schema keyword present in [schema]. An empty schema produces a
  /// [CompositeRule] with no children, which always validates successfully.
  SchemaRule parse(Map<String, dynamic> schema) {
    final rules = <SchemaRule>[];

    // type — spec §6.1.1 allows either a string or an array of strings.
    final type = schema['type'];
    if (type is String) {
      rules.add(TypeRule(type));
    } else if (type is List) {
      // Array form: value is valid when its type matches any listed entry.
      rules.add(TypeRule.fromList(List<String>.from(type)));
    }

    // required
    final required = schema['required'];
    if (required is List) {
      rules.add(RequiredRule(List<String>.from(required)));
    }

    // enum
    final enumValues = schema['enum'];
    if (enumValues is List) {
      rules.add(EnumRule(List<dynamic>.from(enumValues)));
    }

    // numeric constraints
    final minimum = schema['minimum'] as num?;
    final maximum = schema['maximum'] as num?;
    final exclusiveMinimum = schema['exclusiveMinimum'] as num?;
    final exclusiveMaximum = schema['exclusiveMaximum'] as num?;
    if (minimum != null ||
        maximum != null ||
        exclusiveMinimum != null ||
        exclusiveMaximum != null) {
      rules.add(
        NumericRule(
          minimum: minimum,
          maximum: maximum,
          exclusiveMinimum: exclusiveMinimum,
          exclusiveMaximum: exclusiveMaximum,
        ),
      );
    }

    // string constraints
    final minLength = schema['minLength'] as int?;
    final maxLength = schema['maxLength'] as int?;
    final patternStr = schema['pattern'] as String?;
    if (minLength != null || maxLength != null || patternStr != null) {
      rules.add(
        StringRule(
          minLength: minLength,
          maxLength: maxLength,
          pattern: patternStr != null ? RegExp(patternStr) : null,
        ),
      );
    }

    // format
    final format = schema['format'] as String?;
    if (format != null) {
      rules.add(FormatRule(format));
    }

    // properties — parse each sub-schema recursively
    final propertiesRaw = schema['properties'];
    Map<String, SchemaRule>? parsedProperties;
    if (propertiesRaw is Map) {
      parsedProperties = {
        for (final entry in propertiesRaw.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key as String: parse(entry.value as Map<String, dynamic>),
      };
      rules.add(PropertiesRule(parsedProperties));
    }

    // patternProperties — a map of ECMA-262 regex strings to sub-schemas.
    // Per spec §6.5.5, pattern matching is unanchored (hasMatch).
    // An invalid regex key throws FormatException at parse time: malformed
    // regexes are schema-authoring errors that must be surfaced immediately.
    final patternPropertiesRaw = schema['patternProperties'];
    List<(RegExp, SchemaRule)>? parsedPatterns;
    if (patternPropertiesRaw is Map) {
      parsedPatterns = [];
      for (final entry in patternPropertiesRaw.entries) {
        if (entry.value is! Map<String, dynamic>) continue;
        // Throws FormatException if the key is not a valid regex.
        final regex = RegExp(entry.key as String);
        final subRule = parse(entry.value as Map<String, dynamic>);
        parsedPatterns.add((regex, subRule));
      }
      if (parsedPatterns.isNotEmpty) {
        rules.add(PatternPropertiesRule(parsedPatterns));
      }
    }

    // additionalProperties — handles both `false` (reject all extras) and a
    // Map sub-schema (validate extras). Removed the parsedProperties != null
    // guard so this activates even when `properties` is absent.
    final additionalPropertiesRaw = schema['additionalProperties'];
    final declaredKeys = parsedProperties?.keys.toSet() ?? const <String>{};
    final patternRegexes =
        parsedPatterns?.map((p) => p.$1).toList() ?? const <RegExp>[];

    if (additionalPropertiesRaw == false) {
      // Reject all properties not covered by `properties` or
      // `patternProperties`. Use AdditionalPropertiesSchemaRule (with an
      // AlwaysInvalidRule payload) in all cases so that patternProperties
      // patterns are respected at runtime — pattern-matched keys are skipped
      // and not counted as "additional". When no patterns are present the
      // patternRegexes list is empty so all non-declared keys are rejected.
      rules.add(
        AdditionalPropertiesSchemaRule(
          schema: const AlwaysInvalidRule(),
          declaredKeys: declaredKeys,
          patternRegexes: patternRegexes,
        ),
      );
    } else if (additionalPropertiesRaw is Map<String, dynamic>) {
      final additionalSchema = parse(additionalPropertiesRaw);
      rules.add(
        AdditionalPropertiesSchemaRule(
          schema: additionalSchema,
          declaredKeys: declaredKeys,
          patternRegexes: patternRegexes,
        ),
      );
    }

    // prefixItems — list of sub-schemas applied positionally (2020-12 §6.4.1).
    // Parse before `items` so we can set the start index for items validation.
    final prefixItemsRaw = schema['prefixItems'];
    int prefixLength = 0;
    if (prefixItemsRaw is List) {
      final prefixSchemas = <SchemaRule>[];
      for (final entry in prefixItemsRaw) {
        if (entry is Map<String, dynamic>) {
          prefixSchemas.add(parse(entry));
        }
      }
      if (prefixSchemas.isNotEmpty) {
        rules.add(PrefixItemsRule(prefixSchemas));
        prefixLength = prefixSchemas.length;
      }
    }

    // array constraints — `items` applies to elements beyond the prefix when
    // `prefixItems` is present (itemsStartIndex = prefixLength), or uniformly
    // to all elements when `prefixItems` is absent (itemsStartIndex = 0).
    final minItems = schema['minItems'] as int?;
    final maxItems = schema['maxItems'] as int?;
    final itemsRaw = schema['items'];
    SchemaRule? itemsRule;
    if (itemsRaw is Map<String, dynamic>) {
      itemsRule = parse(itemsRaw);
    } else if (itemsRaw == false) {
      // Boolean `items: false` — emit a rule that rejects any element in scope.
      // The "in scope" set is elements beyond the prefix (if prefixItems is
      // present) or all elements (if not).
      itemsRule = AlwaysInvalidRule();
    }
    // items: true is a no-op — leave itemsRule as null.
    // Also emit ArrayRule when only prefixItems is present (no items/minItems/
    // maxItems) so that prefixItems can still coexist with an items schema
    // added later. When all three are absent there is nothing to add.
    if (minItems != null || maxItems != null || itemsRule != null) {
      rules.add(
        ArrayRule(
          minItems: minItems,
          maxItems: maxItems,
          items: itemsRule,
          itemsStartIndex: prefixLength,
        ),
      );
    }

    // contains / minContains / maxContains (spec §6.4.5, §6.4.4, §6.4.6).
    // minContains and maxContains have no effect without contains.
    // Use `is Map` (not Map<String,dynamic>) so that the empty schema {}
    // (which Dart infers as Map<dynamic,dynamic>) is also accepted.
    final containsRaw = schema['contains'];
    if (containsRaw is Map) {
      final containsSchema = parse(Map<String, dynamic>.from(containsRaw));
      final minContains = schema['minContains'] as int? ?? 1;
      final maxContains = schema['maxContains'] as int?;
      rules.add(
        ContainsRule(
          itemSchema: containsSchema,
          minContains: minContains,
          maxContains: maxContains,
        ),
      );
    }

    // const — value may be any JSON type including null; always active when key
    // is present (even when the declared constant is null).
    if (schema.containsKey('const')) {
      rules.add(ConstRule(schema['const']));
    }

    // multipleOf — read as num? to support both integer and float divisors
    // (e.g. 0.1). Only numeric values are validated; non-numerics are skipped
    // by the rule itself.
    final multipleOf = schema['multipleOf'] as num?;
    if (multipleOf != null) {
      rules.add(MultipleOfRule(multipleOf));
    }

    // uniqueItems — only activate when the value is exactly `true`. A value of
    // `false` (or absence) means no uniqueness constraint, so the parser must
    // guard here rather than relying solely on the rule.
    if (schema['uniqueItems'] == true) {
      rules.add(const UniqueItemsRule());
    }

    // minProperties / maxProperties — both read as int?; a single ObjectSizeRule
    // is emitted when either key is present, mirroring NumericRule's pattern.
    final minProperties = schema['minProperties'] as int?;
    final maxProperties = schema['maxProperties'] as int?;
    if (minProperties != null || maxProperties != null) {
      rules.add(
        ObjectSizeRule(
          minProperties: minProperties,
          maxProperties: maxProperties,
        ),
      );
    }

    // dependentRequired — the keyword value is a JSON object mapping trigger
    // property names to arrays of required dependent property names.
    final dependentRequiredRaw = schema['dependentRequired'];
    if (dependentRequiredRaw is Map) {
      // Cast each value to List<String>; ignore entries whose value is not a
      // list (consistent with the silent-ignore policy for unknown keyword forms).
      final dependencies = <String, List<String>>{
        for (final entry in dependentRequiredRaw.entries)
          if (entry.value is List)
            entry.key as String: List<String>.from(entry.value as List),
      };
      rules.add(DependentRequiredRule(dependencies));
    }

    return CompositeRule(rules);
  }
}
