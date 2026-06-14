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

import 'package:betto_schema/betto_schema.dart';
import 'package:test/test.dart';

void main() {
  group('SchemaViolation', () {
    test('stores path and message', () {
      final v = SchemaViolation(path: 'address.city', message: 'required');
      expect(v.path, 'address.city');
      expect(v.message, 'required');
    });

    test('toString with path includes path prefix', () {
      final v = SchemaViolation(path: 'name', message: 'too short');
      expect(v.toString(), 'name: too short');
    });

    test('toString with empty path omits prefix', () {
      final v = SchemaViolation(path: '', message: 'root error');
      expect(v.toString(), 'root error');
    });

    test('equality — same path and message', () {
      final a = SchemaViolation(path: 'x', message: 'bad');
      final b = SchemaViolation(path: 'x', message: 'bad');
      expect(a, equals(b));
    });

    test('equality — different path', () {
      final a = SchemaViolation(path: 'x', message: 'bad');
      final b = SchemaViolation(path: 'y', message: 'bad');
      expect(a, isNot(equals(b)));
    });

    test('equality — different message', () {
      final a = SchemaViolation(path: 'x', message: 'bad');
      final b = SchemaViolation(path: 'x', message: 'worse');
      expect(a, isNot(equals(b)));
    });

    test('equality — different type', () {
      final a = SchemaViolation(path: 'x', message: 'bad');
      expect(a, isNot(equals('x: bad')));
    });

    test('hashCode is consistent', () {
      final a = SchemaViolation(path: 'x', message: 'bad');
      final b = SchemaViolation(path: 'x', message: 'bad');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode differs for different violations', () {
      final a = SchemaViolation(path: 'x', message: 'bad');
      final b = SchemaViolation(path: 'y', message: 'bad');
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });
}
