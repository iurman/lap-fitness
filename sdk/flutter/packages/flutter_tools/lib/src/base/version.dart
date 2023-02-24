// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

@immutable
class Version implements Comparable<Version> {
  /// Creates a new [Version] object.
  factory Version(int? major, int? minor, int? patch, {String? text}) {
    if (text == null) {
      text = major == null ? '0' : '$major';
      if (minor != null) {
        text = '$text.$minor';
      }
      if (patch != null) {
        text = '$text.$patch';
      }
    }

    return Version._(major ?? 0, minor ?? 0, patch ?? 0, text);
  }

  /// Public constant constructor when all fields are non-null, without default value fallbacks.
  const Version.withText(this.major, this.minor, this.patch, this._text);

  Version._(this.major, this.minor, this.patch, this._text) {
    if (major < 0) {
      throw ArgumentError('Major version must be non-negative.');
    }
    if (minor < 0) {
      throw ArgumentError('Minor version must be non-negative.');
    }
    if (patch < 0) {
      throw ArgumentError('Patch version must be non-negative.');
    }
  }

  /// Creates a new [Version] by parsing [text].
  static Version? parse(String? text) {
    final Match? match = versionPattern.firstMatch(text ?? '');
    if (match == null) {
      return null;
    }

    try {
      final int major = int.parse(match[1] ?? '0');
      final int minor = int.parse(match[3] ?? '0');
      final int patch = int.parse(match[5] ?? '0');
      return Version._(major, minor, patch, text ?? '');
    } on FormatException {
      return null;
    }
  }

  /// Returns the primary version out of a list of candidates.
  ///
  /// This is the highest-numbered stable version.
  static Version? primary(List<Version> versions) {
    Version? primary;
    for (final Version version in versions) {
      if (primary == null || (version > primary)) {
        primary = version;
      }
    }
    return primary;
  }


  static Version get unknown => Version(0, 0, 0, text: 'unknown');

  /// The major version number: "1" in "1.2.3".
  final int major;

  /// The minor version number: "2" in "1.2.3".
  final int minor;

  /// The patch version number: "3" in "1.2.3".
  final int patch;

  /// The original string representation of the version number.
  ///
  /// This preserves textual artifacts like leading zeros that may be left out
  /// of the parsed version.
  final String _text;

  static final RegExp versionPattern =
      RegExp(r'^(\d+)(\.(\d+)(\.(\d+))?)?');

  /// Two [Version]s are equal if their version numbers are. The version text
  /// is ignored.
  @override
  bool operator ==(Object other) {
    return other is Version
        && other.major == major
        && other.minor == minor
        && other.patch == patch;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);

  bool operator <(Version other) => compareTo(other) < 0;
  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
  bool operator >=(Version other) => compareTo(other) >= 0;

  @override
  int compareTo(Version other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => _text;
}
