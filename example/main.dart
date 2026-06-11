// Copyright 2026 The Authors. See the AUTHORS file for details.
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
import 'package:betto_schema/betto_schema.dart';

void main() {
  final rule = SchemaParser().parse({
    'required': ['name', 'email'],
    'properties': {
      'name': {'type': 'string', 'minLength': 1},
      'email': {'type': 'string', 'format': 'email'},
      'age': {'type': 'integer', 'minimum': 0},
    },
    'additionalProperties': false,
  });

  final violations = rule.validate({'name': 'Alice'}, '');
  // → [SchemaViolation(path: 'email', message: 'required field is missing')]

  for (final v in violations) {
    print(v); // "email: required field is missing"
  }
}
