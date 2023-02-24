// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:package_config/package_config_types.dart';

import '../android/android_device.dart';
import '../application_package.dart';
import '../artifacts.dart';
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/platform.dart';
import '../base/signals.dart';
import '../build_info.dart';
import '../dart/package_map.dart';
import '../device.dart';
import '../drive/drive_service.dart';
import '../globals.dart' as globals;
import '../resident_runner.dart';
import '../runner/flutter_command.dart' show FlutterCommandCategory, FlutterCommandResult, FlutterOptions;
import '../web/web_device.dart';
import 'run.dart';

/// Runs integration (a.k.a. end-to-end) tests.
///
/// An integration test is a program that runs in a separate process from your
/// Flutter application. It connects to the application and acts like a user,
/// performing taps, scrolls, reading out widget properties and verifying their
/// correctness.
///
/// This command takes a target Flutter application that you would like to test
/// as the `--target` option (defaults to `lib/main.dart`). It then looks for a
/// corresponding test file within the `test_driver` directory. The test file is
/// expected to have the same name but contain the `_test.dart` suffix. The
/// `_test.dart` file would generally be a Dart program that uses
/// `package:flutter_driver` and exercises your application. Most commonly it
/// is a test written using `package:test`, but you are free to use something
/// else.
///
/// The app and the test are launched simultaneously. Once the test completes
/// the application is stopped and the command exits. If all these steps are
/// successful the exit code will be `0`. Otherwise, you will see a non-zero
/// exit code.
class DriveCommand extends RunCommandBase {
  DriveCommand({
    bool verboseHelp = false,
    @visibleForTesting FlutterDriverFactory? flutterDriverFactory,
    @visibleForTesting this.signalsToHandle = const <ProcessSignal>{ProcessSignal.sigint, ProcessSignal.sigterm},
    required FileSystem fileSystem,
    required Logger logger,
    required Platform platform,
    required this.signals,
  }) : _flutterDriverFactory = flutterDriverFactory,
       _fileSystem = fileSystem,
       _logger = logger,
       _fsUtils = FileSystemUtils(fileSystem: fileSystem, platform: platform),
       super(verboseHelp: verboseHelp) {
    requiresPubspecYaml();
    addEnableExperimentation(hide: !verboseHelp);

    // By default, the drive app should not publish the VM service port over mDNS
    // to prevent a local network permission dialog on iOS 14+,
    // which cannot be accepted or dismissed in a CI environment.
    addPublishPort(enabledByDefault: false, verboseHelp: verboseHelp);
    addMultidexOption();
    argParser
      ..addFlag('keep-app-running',
        defaultsTo: null,
        help: 'Will keep the Flutter application running when done testing.\n'
              'By default, "flutter drive" stops the application after tests are finished, '
              'and "--keep-app-running" overrides this. On the other hand, if "--use-existing-app" '
              'is specified, then "flutter drive" instead defaults to leaving the application '
              'running, and "--no-keep-app-running" overrides it.',
      )
      ..addOption('use-existing-app',
        help: 'Connect to an already running instance via the given observatory URL. '
              'If this option is given, the application will not be automatically started, '
              'and it will only be stopped if "--no-keep-app-running" is explicitly set.',
        valueHelp: 'url',
      )
      ..addOption('driver',
        help: 'The test file to run on the host (as opposed to the target file to run on '
              'the device).\n'
              'By default, this file has the same base name as the target file, but in the '
              '"test_driver/" directory instead, and with "_test" inserted just before the '
              'extension, so e.g. if the target is "lib/main.dart", the driver will be '
              '"test_driver/main_test.dart".',
        valueHelp: 'path',
      )
      ..addFlag('build',
        defaultsTo: true,
        help: '(deprecated) Build the app before running. To use an existing app, pass the "--${FlutterOptions.kUseApplicationBinary}" '
              'flag with an existing APK.',
      )
      ..addOption('screenshot',
        valueHelp: 'path/to/directory',
        help: 'Directory location to write screenshots on test failure.',
      )
      ..addOption('driver-port',
        defaultsTo: '4444',
        help: 'The port where Webdriver server is launched at.',
        valueHelp: '4444'
      )
      ..addFlag('headless',
        defaultsTo: true,
        help: 'Whether the driver browser is going to be launched in headless mode.',
      )
      ..addOption('browser-name',
        defaultsTo: 'chrome',
        help: 'Name of the browser where tests will be executed.',
        allowed: <String>[
          'android-chrome',
          'chrome',
          'edge',
          'firefox',
          'ios-safari',
          'safari',
        ],
        allowedHelp: <String, String>{
          'android-chrome': 'Chrome on Android (see also "--android-emulator").',
          'chrome': 'Google Chrome on this computer (see also "--chrome-binary").',
          'edge': 'Microsoft Edge on this computer (Windows only).',
          'firefox': 'Mozilla Firefox on this computer.',
          'ios-safari': 'Apple Safari on an iOS device.',
          'safari': 'Apple Safari on this computer (macOS only).',
        },
      )
      ..addOption('browser-dimension',
        defaultsTo: '1600,1024',
        help: 'The dimension of the browser when running a Flutter Web test. '
              'This will affect screenshot and all offset-related actions.',
        valueHelp: 'width,height',
      )
      ..addFlag('android-emulator',
        defaultsTo: true,
        help: 'Whether to perform Flutter Driver testing using an Android Emulator. '
              'Works only if "browser-name" is set to "android-chrome".')
      ..addOption('chrome-binary',
        help: 'Location of the Chrome binary. '
              'Works only if "browser-name" is set to "chrome".')
      ..addOption('write-sksl-on-exit',
        help: 'Attempts to write an SkSL file when the drive process is finished '
              'to the provided file, overwriting it if necessary.')
      ..addMultiOption('test-arguments', help: 'Additional arguments to pass to the '
          'Dart VM running The test script.')
      ..addOption('profile-memory', help: 'Launch devtools and profile application memory, writing '
          'The output data to the file path provided to this argument as JSON.',
          valueHelp: 'profile_memory.json')
      ..addOption('timeout',
        help: 'Timeout the test after the given number of seconds. If the '
              '"--screenshot" option is provided, a screenshot will be taken '
              'before exiting. Defaults to no timeout.',
        valueHelp: '360');
  }

  final Signals signals;

  /// The [ProcessSignal]s that will lead to a screenshot being taken (if the option is provided).
  final Set<ProcessSignal> signalsToHandle;

  // `pub` must always be run due to the test script running from source,
  // even if an application binary is used. Default to true unless the user explicitly
  // specified not to.
  @override
  bool get shouldRunPub {
    if (argResults!.wasParsed('pub') && !boolArgDeprecated('pub')) {
      return false;
    }
    return true;
  }

  FlutterDriverFactory? _flutterDriverFactory;
  final FileSystem _fileSystem;
  final Logger _logger;
  final FileSystemUtils _fsUtils;
  Timer? timeoutTimer;
  Map<ProcessSignal, Object>? screenshotTokens;

  @override
  final String name = 'drive';

  @override
  final String description = 'Run integration tests for the project on an attached device or emulator.';

  @override
  String get category => FlutterCommandCategory.project;

  @override
  final List<String> aliases = <String>['driver'];

  String? get userIdentifier => stringArgDeprecated(FlutterOptions.kDeviceUser);

  String? get screenshot => stringArgDeprecated('screenshot');

  @override
  bool get startPausedDefault => true;

  @override
  bool get cachePubGet => false;

  @override
  Future<void> validateCommand() async {
    if (userIdentifier != null) {
      final Device? device = await findTargetDevice();
      if (device is! AndroidDevice) {
        throwToolExit('--${FlutterOptions.kDeviceUser} is only supported for Android');
      }
    }
    return super.validateCommand();
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    final String testFile = _getTestFile()!;
    if (testFile == null) {
      throwToolExit(null);
    }
    if (await _fileSystem.type(testFile) != FileSystemEntityType.file) {
      throwToolExit('Test file not found: $testFile');
    }
    final String? applicationBinaryPath = stringArgDeprecated(FlutterOptions.kUseApplicationBinary);
    final Device? device = await findTargetDevice(includeUnsupportedDevices: applicationBinaryPath == null);
    if (device == null) {
      throwToolExit(null);
    }
    if (screenshot != null && !device.supportsScreenshot) {
      _logger.printError('Screenshot not supported for ${device.name}.');
    }

    final bool web = device is WebServerDevice || device is ChromiumDevice;
    _flutterDriverFactory ??= FlutterDriverFactory(
      applicationPackageFactory: ApplicationPackageFactory.instance!,
      logger: _logger,
      processUtils: globals.processUtils,
      dartSdkPath: globals.artifacts!.getHostArtifact(HostArtifact.engineDartBinary).path,
      devtoolsLauncher: DevtoolsLauncher.instance!,
    );
    final PackageConfig packageConfig = await loadPackageConfigWithLogging(
      _fileSystem.file('.packages'),
      logger: _logger,
      throwOnError: false,
    );
    final DriverService driverService = _flutterDriverFactory!.createDriverService(web);
    final BuildInfo buildInfo = await getBuildInfo();
    final DebuggingOptions debuggingOptions = await createDebuggingOptions(web);
    final File? applicationBinary = applicationBinaryPath == null
      ? null
      : _fileSystem.file(applicationBinaryPath);

    bool screenshotTaken = false;
    try {
      if (stringArgDeprecated('use-existing-app') == null) {
        await driverService.start(
          buildInfo,
          device,
          debuggingOptions,
          ipv6 ?? false,
          applicationBinary: applicationBinary,
          route: route,
          userIdentifier: userIdentifier,
          mainPath: targetFile,
          platformArgs: <String, Object>{
            if (traceStartup)
              'trace-startup': traceStartup,
            if (web)
              '--no-launch-chrome': true,
            if (boolArgDeprecated('multidex'))
              'multidex': true,
          }
        );
      } else {
        final Uri? uri = Uri.tryParse(stringArgDeprecated('use-existing-app')!);
        if (uri == null) {
          throwToolExit('Invalid VM Service URI: ${stringArgDeprecated('use-existing-app')}');
        }
        await driverService.reuseApplication(
          uri,
          device,
          debuggingOptions,
          ipv6 ?? false,
        );
      }

      final Future<int> testResultFuture = driverService.startTest(
        testFile,
        stringsArg('test-arguments'),
        <String, String>{},
        packageConfig,
        chromeBinary: stringArgDeprecated('chrome-binary'),
        headless: boolArgDeprecated('headless'),
        webBrowserFlags: stringsArg(FlutterOptions.kWebBrowserFlag),
        browserDimension: stringArgDeprecated('browser-dimension')!.split(','),
        browserName: stringArgDeprecated('browser-name'),
        driverPort: stringArgDeprecated('driver-port') != null
          ? int.tryParse(stringArgDeprecated('driver-port')!)
          : null,
        androidEmulator: boolArgDeprecated('android-emulator'),
        profileMemory: stringArgDeprecated('profile-memory'),
      );

      // If the test is sent a signal or times out, take a screenshot
      _registerScreenshotCallbacks(device);

      final int testResult = await testResultFuture;

      if (timeoutTimer != null) {
        timeoutTimer!.cancel();
      }
      _unregisterScreenshotCallbacks();

      if (testResult != 0 && screenshot != null) {
        // Take a screenshot while the app is still running.
        await _takeScreenshot(device);
        screenshotTaken = true;
      }

      if (boolArgDeprecated('keep-app-running')) {
        _logger.printStatus('Leaving the application running.');
      } else {
        final File? skslFile = stringArgDeprecated('write-sksl-on-exit') != null
          ? _fileSystem.file(stringArgDeprecated('write-sksl-on-exit'))
          : null;
        await driverService.stop(userIdentifier: userIdentifier, writeSkslOnExit: skslFile);
      }
      if (testResult != 0) {
        throwToolExit(null);
      }
    } on Exception catch(_) {
      // On exceptions, including ToolExit, take a screenshot on the device
      // unless a screenshot was already taken on test failure.
      if (!screenshotTaken && screenshot != null) {
        await _takeScreenshot(device);
      }
      rethrow;
    }

    return FlutterCommandResult.success();
  }

  int? get _timeoutSeconds {
    final String? timeoutString = stringArg('timeout');
    if (timeoutString == null) {
      return null;
    }
    final int? timeoutSeconds = int.tryParse(timeoutString);
    if (timeoutSeconds == null || timeoutSeconds <= 0) {
      throwToolExit(
        'Invalid value "$timeoutString" provided to the option --timeout: '
        'expected a positive integer representing seconds.',
      );
    }
    return timeoutSeconds;
  }

  void _registerScreenshotCallbacks(Device device) {
    _logger.printTrace('Registering signal handlers...');
    final Map<ProcessSignal, Object> tokens = <ProcessSignal, Object>{};
    for (final ProcessSignal signal in signalsToHandle) {
      tokens[signal] = signals.addHandler(
        signal,
        (ProcessSignal signal) {
          _unregisterScreenshotCallbacks();
          _logger.printError('Caught $signal');
          return _takeScreenshot(device);
        },
      );
    }
    screenshotTokens = tokens;

    final int? timeoutSeconds = _timeoutSeconds;
    if (timeoutSeconds != null) {
      timeoutTimer = Timer(
        Duration(seconds: timeoutSeconds),
        () {
          _unregisterScreenshotCallbacks();
          _takeScreenshot(device);
          throwToolExit('Timed out after $timeoutSeconds seconds');
        }
      );
    }
  }

  void _unregisterScreenshotCallbacks() {
    if (screenshotTokens != null) {
      _logger.printTrace('Unregistering signal handlers...');
      for (final MapEntry<ProcessSignal, Object> entry in screenshotTokens!.entries) {
        signals.removeHandler(entry.key, entry.value);
      }
    }
    timeoutTimer?.cancel();
  }

  String? _getTestFile() {
    if (argResults!['driver'] != null) {
      return stringArgDeprecated('driver');
    }

    // If the --driver argument wasn't provided, then derive the value from
    // the target file.
    String appFile = _fileSystem.path.normalize(targetFile);

    // This command extends `flutter run` and therefore CWD == package dir
    final String packageDir = _fileSystem.currentDirectory.path;

    // Make appFile path relative to package directory because we are looking
    // for the corresponding test file relative to it.
    if (!_fileSystem.path.isRelative(appFile)) {
      if (!_fileSystem.path.isWithin(packageDir, appFile)) {
        _logger.printError(
          'Application file $appFile is outside the package directory $packageDir'
        );
        return null;
      }

      appFile = _fileSystem.path.relative(appFile, from: packageDir);
    }

    final List<String> parts = _fileSystem.path.split(appFile);

    if (parts.length < 2) {
      _logger.printError(
        'Application file $appFile must reside in one of the sub-directories '
        'of the package structure, not in the root directory.'
      );
      return null;
    }

    // Look for the test file inside `test_driver/` matching the sub-path, e.g.
    // if the application is `lib/foo/bar.dart`, the test file is expected to
    // be `test_driver/foo/bar_test.dart`.
    final String pathWithNoExtension = _fileSystem.path.withoutExtension(_fileSystem.path.joinAll(
      <String>[packageDir, 'test_driver', ...parts.skip(1)]));
    return '${pathWithNoExtension}_test${_fileSystem.path.extension(appFile)}';
  }

  Future<void> _takeScreenshot(Device device) async {
    if (!device.supportsScreenshot) {
      return;
    }
    try {
      final Directory outputDirectory = _fileSystem.directory(screenshot)
        ..createSync(recursive: true);
      final File outputFile = _fsUtils.getUniqueFile(
        outputDirectory,
        'drive',
        'png',
      );
      await device.takeScreenshot(outputFile);
      _logger.printStatus('Screenshot written to ${outputFile.path}');
    } on Exception catch (error) {
      _logger.printError('Error taking screenshot: $error');
    }
  }
}
