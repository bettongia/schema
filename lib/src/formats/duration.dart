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

/// Duration ala ISO 8601.
///
/// This is a purposefully simple implementation and is not intended
/// to provide DateTime-style functionality. The main issues is that
/// having [months] and [years] makes the duration contextual and we
/// can't then boil it down to seconds (e.g. _how many seconds in a
/// month?_).
///
/// From my reading of Appendix A of RFC 3339, negative values are
/// not allowed.
///
/// See:
///
///  - [Appendix A of RFC 3339](https://www.rfc-editor.org/info/rfc3339)
///  - [Wikipedia](https://en.wikipedia.org/wiki/ISO_8601#Durations)
class Iso8601Duration {
  static final RegExp iso8601Duration = RegExp(
    r'^P'
    r'((?<years>\d+)Y)?'
    r'((?<months>\d+)M)?'
    r'((?<days>\d+)D)?'
    r'(T'
    r'((?<hours>\d+)H)?'
    r'((?<minutes>\d+)M)?'
    r'((?<seconds>\d+)S)?)?$',
  );

  final int years;
  final int months;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  Iso8601Duration._({
    this.years = 0,
    this.months = 0,
    this.days = 0,
    this.hours = 0,
    this.minutes = 0,
    this.seconds = 0,
  });

  /// Whether this [Iso8601Duration] properties are an exact match with [other].
  ///
  /// Nothing fancy is done here - no converting to seconds or normalising, it's
  /// just a comparison of properties.
  @override
  bool operator ==(Object other) {
    if (other is Iso8601Duration &&
        seconds == other.seconds &&
        minutes == other.minutes &&
        hours == other.hours &&
        days == other.days &&
        months == other.months &&
        years == other.years) {
      return true;
    }
    return false;
  }

  @override
  String toString() {
    return 'P${years}Y${months}M${days}DT${hours}H${minutes}M${seconds}S';
  }

  /// Returns a [Duration] representation of this [Iso8601Duration].
  ///
  /// Importantly, this returns `null` if the [Iso8601Duration] has the
  /// [years] and/or the [months] fields set to a value other than zero.
  Duration? get duration {
    if (years != 0 && months != 0) {
      return null;
    }

    return Duration(
      seconds: seconds,
      minutes: minutes,
      hours: hours,
      days: days,
    );
  }

  /// Parse an ISO 8601 duration [input] string into a [Iso8601Duration].
  ///
  /// [maxInputLength] is the maximum number of [input] characters
  ///
  /// Examples:
  ///
  ///   - `P1S` - One second
  ///   - `P1M` - One month
  ///   - `P1MT1M` - One month and one minute
  ///   - `P1Y2M3DT4H5M6S` - One year, two months, three days, four hours, five minutes, six seconds
  ///
  /// Returns (null, false) if the [input] is not a valid duration.
  static Iso8601Duration? tryParse(String input, {int maxInputLength = 24}) {
    // Guard the RegEx from dodgy strings
    if (input.substring(0, 1) != 'P' ||
        input.length > maxInputLength ||
        [
          'Y',
          'M',
          'D',
          'H',
          'S',
          'T',
        ].contains(input.substring(input.length - 2))) {
      return null;
    }

    var match = iso8601Duration.firstMatch(input);
    if (match == null) {
      return null;
    }

    int? seconds = int.tryParse(match.namedGroup('seconds') ?? '0');
    int? minutes = int.tryParse(match.namedGroup('minutes') ?? '0');
    int? hours = int.tryParse(match.namedGroup('hours') ?? '0');
    int? days = int.tryParse(match.namedGroup('days') ?? '0');
    int? months = int.tryParse(match.namedGroup('months') ?? '0');
    int? years = int.tryParse(match.namedGroup('years') ?? '0');

    if ([seconds, minutes, hours, days, months, years].any((e) => e == null)) {
      return null;
    }

    return Iso8601Duration._(
      years: years!,
      months: months!,
      days: days!,
      hours: hours!,
      minutes: minutes!,
      seconds: seconds!,
    );
  }

  @override
  int get hashCode =>
      Object.hashAll([years, months, days, hours, minutes, seconds]);

  static bool isValid(String value) => tryParse(value) != null;
}
