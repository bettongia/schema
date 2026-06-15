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

import 'dart:convert';
import 'dart:io';

import 'package:betto_schema/betto_schema.dart';

const _usage = '''
Usage: validate <schema.json> [data.json]

Validates JSON data against a JSON Schema.

Arguments:
  <schema.json>  Path to a JSON Schema file.
  [data.json]    Path to a JSON data file. If omitted, JSON is read from stdin.

Exit codes:
  0  Validation passed.
  1  Validation failed (violations printed to stdout).
  2  Usage error or I/O failure (message printed to stderr).
''';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage);
    exit(0);
  }

  if (args.isEmpty || args.length > 2) {
    stderr.writeln('Error: expected 1 or 2 arguments.\n');
    stderr.write(_usage);
    exit(2);
  }

  final schemaPath = args[0];
  final dataPath = args.length == 2 ? args[1] : null;

  // Load and parse schema.
  final String schemaJson;
  try {
    schemaJson = await File(schemaPath).readAsString();
  } on FileSystemException catch (e) {
    stderr.writeln('Error reading schema file "$schemaPath": ${e.message}');
    exit(2);
  }

  final JsonSchemaValidator validator;
  try {
    validator = JsonSchemaValidator.fromJson(schemaJson);
  } on FormatException catch (e) {
    stderr.writeln('Error parsing schema file "$schemaPath": ${e.message}');
    exit(2);
  }

  // Load JSON data from file or stdin.
  final String dataJson;
  if (dataPath != null) {
    try {
      dataJson = await File(dataPath).readAsString();
    } on FileSystemException catch (e) {
      stderr.writeln('Error reading data file "$dataPath": ${e.message}');
      exit(2);
    }
  } else {
    try {
      dataJson = await stdin.transform(utf8.decoder).join();
    } on Exception catch (e) {
      stderr.writeln('Error reading from stdin: $e');
      exit(2);
    }
  }

  // Parse and validate.
  final Object? decoded;
  try {
    decoded = jsonDecode(dataJson);
  } on FormatException catch (e) {
    final source = dataPath != null ? '"$dataPath"' : 'stdin';
    stderr.writeln('Error parsing JSON data from $source: ${e.message}');
    exit(2);
  }

  if (decoded is! Map<String, dynamic>) {
    final source = dataPath != null ? '"$dataPath"' : 'stdin';
    stderr.writeln(
      'Error: JSON data from $source must be a JSON object, '
      'got ${decoded.runtimeType}',
    );
    exit(2);
  }

  final violations = validator.validate(decoded);
  if (violations.isEmpty) {
    stdout.writeln('Validation passed.');
    exit(0);
  }

  stdout.writeln('Validation failed with ${violations.length} violation(s):');
  for (final v in violations) {
    stdout.writeln('  - $v');
  }
  exit(1);
}
