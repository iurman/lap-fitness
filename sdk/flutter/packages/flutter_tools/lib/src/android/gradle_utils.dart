// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '../base/common.dart';
import '../base/file_system.dart';

import '../base/logger.dart';
import '../base/os.dart';
import '../base/platform.dart';
import '../base/utils.dart';
import '../base/version.dart';
import '../build_info.dart';
import '../cache.dart';
import '../globals.dart' as globals;
import '../project.dart';
import '../reporting/reporting.dart';
import 'android_sdk.dart';

// These are the versions used in the project templates.
//
// In general, Flutter aims to default to the latest version.
// However, this currently requires to migrate existing integration tests to the latest supported values.
//
// For more information about the latest version, check:
// https://developer.android.com/studio/releases/gradle-plugin#updating-gradle
// https://kotlinlang.org/docs/releases.html#release-details
const String templateDefaultGradleVersion = '7.5';
const String templateAndroidGradlePluginVersion = '7.2.0';
const String templateDefaultGradleVersionForModule = '7.2.0';
const String templateKotlinGradlePluginVersion = '1.7.10';

// These versions should match the values in flutter.gradle (FlutterExtension).
// The Flutter Gradle plugin is only applied to app projects, and modules that are built from source
// using (include_flutter.groovy).
// The remaining projects are: plugins, and modules compiled as AARs. In modules, the ephemeral directory
// `.android` is always regenerated after flutter pub get, so new versions are picked up after a
// Flutter upgrade.
const String compileSdkVersion = '31';
const String minSdkVersion = '16';
const String targetSdkVersion = '31';
const String ndkVersion = '21.4.7075529';

final RegExp _androidPluginRegExp = RegExp(r'com\.android\.tools\.build:gradle:(\d+\.\d+\.\d+)');

/// Provides utilities to run a Gradle task, such as finding the Gradle executable
/// or constructing a Gradle project.
class GradleUtils {
  GradleUtils({
    required Platform platform,
    required Logger logger,
    required FileSystem fileSystem,
    required Cache cache,
    required OperatingSystemUtils operatingSystemUtils,
  }) : _platform = platform,
       _logger = logger,
       _cache = cache,
       _fileSystem = fileSystem,
       _operatingSystemUtils = operatingSystemUtils;

  final Cache _cache;
  final FileSystem _fileSystem;
  final Platform _platform;
  final Logger _logger;
  final OperatingSystemUtils _operatingSystemUtils;

  /// Gets the Gradle executable path and prepares the Gradle project.
  /// This is the `gradlew` or `gradlew.bat` script in the `android/` directory.
  String getExecutable(FlutterProject project) {
    final Directory androidDir = project.android.hostAppGradleRoot;
    injectGradleWrapperIfNeeded(androidDir);

    final File gradle = androidDir.childFile(
      _platform.isWindows ? 'gradlew.bat' : 'gradlew',
    );
    if (gradle.existsSync()) {
      _logger.printTrace('Using gradle from ${gradle.absolute.path}.');
      // If the Gradle executable doesn't have execute permission,
      // then attempt to set it.
      _operatingSystemUtils.makeExecutable(gradle);
      return gradle.absolute.path;
    }
    throwToolExit(
      'Unable to locate gradlew script. Please check that ${gradle.path} '
      'exists or that ${gradle.dirname} can be read.'
    );
  }

  /// Injects the Gradle wrapper files if any of these files don't exist in [directory].
  void injectGradleWrapperIfNeeded(Directory directory) {
    copyDirectory(
      _cache.getArtifactDirectory('gradle_wrapper'),
      directory,
      shouldCopyFile: (File sourceFile, File destinationFile) {
        // Don't override the existing files in the project.
        return !destinationFile.existsSync();
      },
      onFileCopied: (File source, File dest) {
        _operatingSystemUtils.makeExecutable(dest);
      }
    );
    // Add the `gradle-wrapper.properties` file if it doesn't exist.
    final Directory propertiesDirectory = directory
      .childDirectory(_fileSystem.path.join('gradle', 'wrapper'));
    final File propertiesFile = propertiesDirectory
      .childFile('gradle-wrapper.properties');

    if (propertiesFile.existsSync()) {
      return;
    }
    propertiesDirectory.createSync(recursive: true);
    final String gradleVersion = getGradleVersionForAndroidPlugin(directory, _logger);
    final String propertyContents = '''
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-$gradleVersion-all.zip
''';
    propertiesFile.writeAsStringSync(propertyContents);
  }
}

/// Returns the Gradle version that the current Android plugin depends on when found,
/// otherwise it returns a default version.
///
/// The Android plugin version is specified in the [build.gradle] file within
/// the project's Android directory.
String getGradleVersionForAndroidPlugin(Directory directory, Logger logger) {
  final File buildFile = directory.childFile('build.gradle');
  if (!buildFile.existsSync()) {
    logger.printTrace("$buildFile doesn't exist, assuming Gradle version: $templateDefaultGradleVersion");
    return templateDefaultGradleVersion;
  }
  final String buildFileContent = buildFile.readAsStringSync();
  final Iterable<Match> pluginMatches = _androidPluginRegExp.allMatches(buildFileContent);
  if (pluginMatches.isEmpty) {
    logger.printTrace("$buildFile doesn't provide an AGP version, assuming Gradle version: $templateDefaultGradleVersion");
    return templateDefaultGradleVersion;
  }
  final String? androidPluginVersion = pluginMatches.first.group(1);
  logger.printTrace('$buildFile provides AGP version: $androidPluginVersion');
  return getGradleVersionFor(androidPluginVersion ?? 'unknown');
}

/// Returns true if [targetVersion] is within the range [min] and [max] inclusive.
bool _isWithinVersionRange(
  String targetVersion, {
  required String min,
  required String max,
}) {
  assert(min != null);
  assert(max != null);
  final Version? parsedTargetVersion = Version.parse(targetVersion);
  final Version? minVersion = Version.parse(min);
  final Version? maxVersion = Version.parse(max);
  return minVersion != null &&
      maxVersion != null &&
      parsedTargetVersion != null &&
      parsedTargetVersion >= minVersion &&
      parsedTargetVersion <= maxVersion;
}

/// Returns the Gradle version that is required by the given Android Gradle plugin version
/// by picking the largest compatible version from
/// https://developer.android.com/studio/releases/gradle-plugin#updating-gradle
@visibleForTesting
String getGradleVersionFor(String androidPluginVersion) {
  if (_isWithinVersionRange(androidPluginVersion, min: '1.0.0', max: '1.1.3')) {
    return '2.3';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '1.2.0', max: '1.3.1')) {
    return '2.9';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '1.5.0', max: '1.5.0')) {
    return '2.2.1';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '2.0.0', max: '2.1.2')) {
    return '2.13';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '2.1.3', max: '2.2.3')) {
    return '2.14.1';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '2.3.0', max: '2.9.9')) {
    return '3.3';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '3.0.0', max: '3.0.9')) {
    return '4.1';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '3.1.0', max: '3.1.9')) {
    return '4.4';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '3.2.0', max: '3.2.1')) {
    return '4.6';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '3.3.0', max: '3.3.2')) {
    return '4.10.2';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '3.4.0', max: '3.5.0')) {
    return '5.6.2';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '4.0.0', max: '4.1.0')) {
    return '6.7';
  }
  if (_isWithinVersionRange(androidPluginVersion, min: '7.0', max: '7.5')) {
    return '7.5';
  }
  throwToolExit('Unsupported Android Plugin version: $androidPluginVersion.');
}

/// Overwrite local.properties in the specified Flutter project's Android
/// sub-project, if needed.
///
/// If [requireAndroidSdk] is true (the default) and no Android SDK is found,
/// this will fail with a [ToolExit].
void updateLocalProperties({
  required FlutterProject project,
  BuildInfo? buildInfo,
  bool requireAndroidSdk = true,
}) {
  if (requireAndroidSdk && globals.androidSdk == null) {
    exitWithNoSdkMessage();
  }
  final File localProperties = project.android.localPropertiesFile;
  bool changed = false;

  SettingsFile settings;
  if (localProperties.existsSync()) {
    settings = SettingsFile.parseFromFile(localProperties);
  } else {
    settings = SettingsFile();
    changed = true;
  }

  void changeIfNecessary(String key, String? value) {
    if (settings.values[key] == value) {
      return;
    }
    if (value == null) {
      settings.values.remove(key);
    } else {
      settings.values[key] = value;
    }
    changed = true;
  }

  final AndroidSdk? androidSdk = globals.androidSdk;
  if (androidSdk != null) {
    changeIfNecessary('sdk.dir', globals.fsUtils.escapePath(androidSdk.directory.path));
  }

  changeIfNecessary('flutter.sdk', globals.fsUtils.escapePath(Cache.flutterRoot!));
  if (buildInfo != null) {
    changeIfNecessary('flutter.buildMode', buildInfo.modeName);
    final String? buildName = validatedBuildNameForPlatform(
      TargetPlatform.android_arm,
      buildInfo.buildName ?? project.manifest.buildName,
      globals.logger,
    );
    changeIfNecessary('flutter.versionName', buildName);
    final String? buildNumber = validatedBuildNumberForPlatform(
      TargetPlatform.android_arm,
      buildInfo.buildNumber ?? project.manifest.buildNumber,
      globals.logger,
    );
    changeIfNecessary('flutter.versionCode', buildNumber);
  }

  if (changed) {
    settings.writeContents(localProperties);
  }
}

/// Writes standard Android local properties to the specified [properties] file.
///
/// Writes the path to the Android SDK, if known.
void writeLocalProperties(File properties) {
  final SettingsFile settings = SettingsFile();
  final AndroidSdk? androidSdk = globals.androidSdk;
  if (androidSdk != null) {
    settings.values['sdk.dir'] = globals.fsUtils.escapePath(androidSdk.directory.path);
  }
  settings.writeContents(properties);
}

void exitWithNoSdkMessage() {
  BuildEvent('unsupported-project', type: 'gradle', eventError: 'android-sdk-not-found', flutterUsage: globals.flutterUsage).send();
  throwToolExit(
    '${globals.logger.terminal.warningMark} No Android SDK found. '
    'Try setting the ANDROID_SDK_ROOT environment variable.'
  );
}
