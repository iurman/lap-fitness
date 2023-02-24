// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:meta/meta.dart';
import 'package:package_config/package_config_types.dart';

import '../application_package.dart';
import '../base/common.dart';
import '../base/context.dart';
import '../base/io.dart' as io;
import '../base/os.dart';
import '../base/user_messages.dart';
import '../base/utils.dart';
import '../build_info.dart';
import '../build_system/build_system.dart';
import '../bundle.dart' as bundle;
import '../cache.dart';
import '../convert.dart';
import '../dart/generate_synthetic_packages.dart';
import '../dart/language_version.dart';
import '../dart/package_map.dart';
import '../dart/pub.dart';
import '../device.dart';
import '../features.dart';
import '../globals.dart' as globals;
import '../project.dart';
import '../reporting/reporting.dart';
import 'flutter_command_runner.dart';

export '../cache.dart' show DevelopmentArtifact;

enum ExitStatus {
  success,
  warning,
  fail,
  killed,
}

/// [FlutterCommand]s' subclasses' [FlutterCommand.runCommand] can optionally
/// provide a [FlutterCommandResult] to furnish additional information for
/// analytics.
class FlutterCommandResult {
  const FlutterCommandResult(
    this.exitStatus, {
    this.timingLabelParts,
    this.endTimeOverride,
  });

  /// A command that succeeded. It is used to log the result of a command invocation.
  factory FlutterCommandResult.success() {
    return const FlutterCommandResult(ExitStatus.success);
  }

  /// A command that exited with a warning. It is used to log the result of a command invocation.
  factory FlutterCommandResult.warning() {
    return const FlutterCommandResult(ExitStatus.warning);
  }

  /// A command that failed. It is used to log the result of a command invocation.
  factory FlutterCommandResult.fail() {
    return const FlutterCommandResult(ExitStatus.fail);
  }

  final ExitStatus exitStatus;

  /// Optional data that can be appended to the timing event.
  /// https://developers.google.com/analytics/devguides/collection/analyticsjs/field-reference#timingLabel
  /// Do not add PII.
  final List<String?>? timingLabelParts;

  /// Optional epoch time when the command's non-interactive wait time is
  /// complete during the command's execution. Use to measure user perceivable
  /// latency without measuring user interaction time.
  ///
  /// [FlutterCommand] will automatically measure and report the command's
  /// complete time if not overridden.
  final DateTime? endTimeOverride;

  @override
  String toString() {
    switch (exitStatus) {
      case ExitStatus.success:
        return 'success';
      case ExitStatus.warning:
        return 'warning';
      case ExitStatus.fail:
        return 'fail';
      case ExitStatus.killed:
        return 'killed';
    }
  }
}

/// Common flutter command line options.
class FlutterOptions {
  static const String kExtraFrontEndOptions = 'extra-front-end-options';
  static const String kExtraGenSnapshotOptions = 'extra-gen-snapshot-options';
  static const String kEnableExperiment = 'enable-experiment';
  static const String kFileSystemRoot = 'filesystem-root';
  static const String kFileSystemScheme = 'filesystem-scheme';
  static const String kSplitDebugInfoOption = 'split-debug-info';
  static const String kDartObfuscationOption = 'obfuscate';
  static const String kDartDefinesOption = 'dart-define';
  static const String kDartDefineFromFileOption = 'dart-define-from-file';
  static const String kBundleSkSLPathOption = 'bundle-sksl-path';
  static const String kPerformanceMeasurementFile = 'performance-measurement-file';
  static const String kNullSafety = 'sound-null-safety';
  static const String kDeviceUser = 'device-user';
  static const String kDeviceTimeout = 'device-timeout';
  static const String kAnalyzeSize = 'analyze-size';
  static const String kCodeSizeDirectory = 'code-size-directory';
  static const String kNullAssertions = 'null-assertions';
  static const String kAndroidGradleDaemon = 'android-gradle-daemon';
  static const String kDeferredComponents = 'deferred-components';
  static const String kAndroidProjectArgs = 'android-project-arg';
  static const String kInitializeFromDill = 'initialize-from-dill';
  static const String kAssumeInitializeFromDillUpToDate = 'assume-initialize-from-dill-up-to-date';
  static const String kFatalWarnings = 'fatal-warnings';
  static const String kUseApplicationBinary = 'use-application-binary';
  static const String kWebBrowserFlag = 'web-browser-flag';
}

/// flutter command categories for usage.
class FlutterCommandCategory {
  static const String sdk = 'Flutter SDK';
  static const String project = 'Project';
  static const String tools = 'Tools & Devices';
}

abstract class FlutterCommand extends Command<void> {
  /// The currently executing command (or sub-command).
  ///
  /// Will be `null` until the top-most command has begun execution.
  static FlutterCommand? get current => context.get<FlutterCommand>();

  /// The option name for a custom observatory port.
  static const String observatoryPortOption = 'observatory-port';

  /// The option name for a custom DevTools server address.
  static const String kDevToolsServerAddress = 'devtools-server-address';

  /// The flag name for whether to launch the DevTools or not.
  static const String kEnableDevTools = 'devtools';

  /// The flag name for whether or not to use ipv6.
  static const String ipv6Flag = 'ipv6';

  /// The map used to convert web-renderer option to a List of dart-defines.
  static const Map<String, Iterable<String>> _webRendererDartDefines =
  <String, Iterable<String>> {
    'auto': <String>[
      'FLUTTER_WEB_AUTO_DETECT=true',
    ],
    'canvaskit': <String>[
      'FLUTTER_WEB_AUTO_DETECT=false',
      'FLUTTER_WEB_USE_SKIA=true',
    ],
    'html': <String>[
      'FLUTTER_WEB_AUTO_DETECT=false',
      'FLUTTER_WEB_USE_SKIA=false',
    ],
  };

  @override
  ArgParser get argParser => _argParser;
  final ArgParser _argParser = ArgParser(
    usageLineLength: globals.outputPreferences.wrapText ? globals.outputPreferences.wrapColumn : null,
  );

  @override
  FlutterCommandRunner? get runner => super.runner as FlutterCommandRunner?;

  bool _requiresPubspecYaml = false;

  /// Whether this command uses the 'target' option.
  bool _usesTargetOption = false;

  bool _usesPubOption = false;

  bool _usesPortOption = false;

  bool _usesIpv6Flag = false;

  bool _usesFatalWarnings = false;

  DeprecationBehavior get deprecationBehavior => DeprecationBehavior.none;

  bool get shouldRunPub => _usesPubOption && boolArgDeprecated('pub');

  bool get shouldUpdateCache => true;

  bool get deprecated => false;

  @override
  bool get hidden => deprecated;

  bool _excludeDebug = false;
  bool _excludeRelease = false;

  void requiresPubspecYaml() {
    _requiresPubspecYaml = true;
  }

  void usesWebOptions({ required bool verboseHelp }) {
    argParser.addOption('web-hostname',
      defaultsTo: 'localhost',
      help:
        'The hostname that the web sever will use to resolve an IP to serve '
        'from. The unresolved hostname is used to launch Chrome when using '
        'the chrome Device. The name "any" may also be used to serve on any '
        'IPV4 for either the Chrome or web-server device.',
      hide: !verboseHelp,
    );
    argParser.addOption('web-port',
      help: 'The host port to serve the web application from. If not provided, the tool '
        'will select a random open port on the host.',
      hide: !verboseHelp,
    );
    argParser.addOption('web-server-debug-protocol',
      allowed: <String>['sse', 'ws'],
      defaultsTo: 'ws',
      help: 'The protocol (SSE or WebSockets) to use for the debug service proxy '
      'when using the Web Server device and Dart Debug extension. '
      'This is useful for editors/debug adapters that do not support debugging '
      'over SSE (the default protocol for Web Server/Dart Debugger extension).',
      hide: !verboseHelp,
    );
    argParser.addOption('web-server-debug-backend-protocol',
      allowed: <String>['sse', 'ws'],
      defaultsTo: 'ws',
      help: 'The protocol (SSE or WebSockets) to use for the Dart Debug Extension '
      'backend service when using the Web Server device. '
      'Using WebSockets can improve performance but may fail when connecting through '
      'some proxy servers.',
      hide: !verboseHelp,
    );
    argParser.addOption('web-server-debug-injected-client-protocol',
      allowed: <String>['sse', 'ws'],
      defaultsTo: 'ws',
      help: 'The protocol (SSE or WebSockets) to use for the injected client '
      'when using the Web Server device. '
      'Using WebSockets can improve performance but may fail when connecting through '
      'some proxy servers.',
      hide: !verboseHelp,
    );
    argParser.addFlag('web-allow-expose-url',
      help: 'Enables daemon-to-editor requests (app.exposeUrl) for exposing URLs '
        'when running on remote machines.',
      hide: !verboseHelp,
    );
    argParser.addFlag('web-run-headless',
      help: 'Launches the browser in headless mode. Currently only Chrome '
        'supports this option.',
      hide: !verboseHelp,
    );
    argParser.addOption('web-browser-debug-port',
      help: 'The debug port the browser should use. If not specified, a '
        'random port is selected. Currently only Chrome supports this option. '
        'It serves the Chrome DevTools Protocol '
        '(https://chromedevtools.github.io/devtools-protocol/).',
      hide: !verboseHelp,
    );
    argParser.addFlag('web-enable-expression-evaluation',
      defaultsTo: true,
      help: 'Enables expression evaluation in the debugger.',
      hide: !verboseHelp,
    );
    argParser.addOption('web-launch-url',
      help: 'The URL to provide to the browser. Defaults to an HTTP URL with the host '
          'name of "--web-hostname", the port of "--web-port", and the path set to "/".',
    );
    argParser.addMultiOption(
      FlutterOptions.kWebBrowserFlag,
      help: 'Additional flag to pass to a browser instance at startup.\n'
          'Chrome: https://www.chromium.org/developers/how-tos/run-chromium-with-flags/\n'
          'Firefox: https://wiki.mozilla.org/Firefox/CommandLineOptions\n'
          'Multiple flags can be passed by repeating "--${FlutterOptions.kWebBrowserFlag}" multiple times.',
      valueHelp: '--foo=bar',
      hide: !verboseHelp,
    );
  }

  void usesTargetOption() {
    argParser.addOption('target',
      abbr: 't',
      defaultsTo: bundle.defaultMainPath,
      help: 'The main entry-point file of the application, as run on the device.\n'
            'If the "--target" option is omitted, but a file name is provided on '
            'the command line, then that is used instead.',
      valueHelp: 'path');
    _usesTargetOption = true;
  }

  void usesFatalWarningsOption({ required bool verboseHelp }) {
    argParser.addFlag(FlutterOptions.kFatalWarnings,
        hide: !verboseHelp,
        help: 'Causes the command to fail if warnings are sent to the console '
              'during its execution.'
    );
    _usesFatalWarnings = true;
  }

  String get targetFile {
    if (argResults?.wasParsed('target') ?? false) {
      return stringArgDeprecated('target')!;
    }
    final List<String>? rest = argResults?.rest;
    if (rest != null && rest.isNotEmpty) {
      return rest.first;
    }
    return bundle.defaultMainPath;
  }

  /// Path to the Dart's package config file.
  ///
  /// This can be overridden by some of its subclasses.
  String? get packagesPath => globalResults?['packages'] as String?;

  /// The value of the `--filesystem-scheme` argument.
  ///
  /// This can be overridden by some of its subclasses.
  String? get fileSystemScheme =>
    argParser.options.containsKey(FlutterOptions.kFileSystemScheme)
          ? stringArgDeprecated(FlutterOptions.kFileSystemScheme)
          : null;

  /// The values of the `--filesystem-root` argument.
  ///
  /// This can be overridden by some of its subclasses.
  List<String>? get fileSystemRoots =>
    argParser.options.containsKey(FlutterOptions.kFileSystemRoot)
          ? stringsArg(FlutterOptions.kFileSystemRoot)
          : null;

  void usesPubOption({bool hide = false}) {
    argParser.addFlag('pub',
      defaultsTo: true,
      hide: hide,
      help: 'Whether to run "flutter pub get" before executing this command.');
    _usesPubOption = true;
  }

  /// Adds flags for using a specific filesystem root and scheme.
  ///
  /// The `hide` argument indicates whether or not to hide these options when
  /// the user asks for help.
  void usesFilesystemOptions({ required bool hide }) {
    argParser
      ..addOption('output-dill',
        hide: hide,
        help: 'Specify the path to frontend server output kernel file.',
      )
      ..addMultiOption(FlutterOptions.kFileSystemRoot,
        hide: hide,
        help: 'Specify the path that is used as the root of a virtual file system '
              'during compilation. The input file name should be specified as a URL '
              'using the scheme given in "--${FlutterOptions.kFileSystemScheme}".\n'
              'Requires the "--output-dill" option to be explicitly specified.',
      )
      ..addOption(FlutterOptions.kFileSystemScheme,
        defaultsTo: 'org-dartlang-root',
        hide: hide,
        help: 'Specify the scheme that is used for virtual file system used in '
              'compilation. See also the "--${FlutterOptions.kFileSystemRoot}" option.',
      );
  }

  /// Adds options for connecting to the Dart VM observatory port.
  void usesPortOptions({ required bool verboseHelp }) {
    argParser.addOption(observatoryPortOption,
        help: '(deprecated; use host-vmservice-port instead) '
              'Listen to the given port for an observatory debugger connection.\n'
              'Specifying port 0 (the default) will find a random free port.\n '
              'if the Dart Development Service (DDS) is enabled, this will not be the port '
              'of the Observatory instance advertised on the command line.',
        hide: !verboseHelp,
    );
    argParser.addOption('device-vmservice-port',
      help: 'Look for vmservice connections only from the specified port.\n'
            'Specifying port 0 (the default) will accept the first vmservice '
            'discovered.',
    );
    argParser.addOption('host-vmservice-port',
      help: 'When a device-side vmservice port is forwarded to a host-side '
            'port, use this value as the host port.\nSpecifying port 0 '
            '(the default) will find a random free host port.'
    );
    _usesPortOption = true;
  }

  /// Add option values for output directory of artifacts
  void usesOutputDir() {
    // TODO(eliasyishak): this feature has been added to [BuildWebCommand] and
    //  [BuildAarCommand]
    argParser.addOption('output',
        abbr: 'o',
        aliases: <String>['output-dir'],
        help:
            'The absolute path to the directory where the repository is generated. '
            'By default, this is <current-directory>/build/<target-platform>.\n'
            'Currently supported for subcommands: aar, web.');
  }

  void addDevToolsOptions({required bool verboseHelp}) {
    argParser.addFlag(
      kEnableDevTools,
      hide: !verboseHelp,
      defaultsTo: true,
      help: 'Enable (or disable, with "--no-$kEnableDevTools") the launching of the '
            'Flutter DevTools debugger and profiler. '
            'If specified, "--$kDevToolsServerAddress" is ignored.'
    );
    argParser.addOption(
      kDevToolsServerAddress,
      hide: !verboseHelp,
      help: 'When this value is provided, the Flutter tool will not spin up a '
            'new DevTools server instance, and will instead use the one provided '
            'at the given address. Ignored if "--no-$kEnableDevTools" is specified.'
    );
  }

  void addDdsOptions({required bool verboseHelp}) {
    argParser.addOption('dds-port',
      help: 'When this value is provided, the Dart Development Service (DDS) will be '
            'bound to the provided port.\n'
            'Specifying port 0 (the default) will find a random free port.'
    );
    argParser.addFlag(
      'dds',
      hide: !verboseHelp,
      defaultsTo: true,
      help: 'Enable the Dart Developer Service (DDS).\n'
            'It may be necessary to disable this when attaching to an application with '
            'an existing DDS instance (e.g., attaching to an application currently '
            'connected to by "flutter run"), or when running certain tests.\n'
            'Disabling this feature may degrade IDE functionality if a DDS instance is '
            'not already connected to the target application.'
    );
    argParser.addFlag(
      'disable-dds',
      hide: !verboseHelp,
      help: '(deprecated; use "--no-dds" instead) '
            'Disable the Dart Developer Service (DDS).'
    );
  }

  late final bool enableDds = () {
    bool ddsEnabled = false;
    if (argResults?.wasParsed('disable-dds') ?? false) {
      if (argResults?.wasParsed('dds') ?? false) {
        throwToolExit(
            'The "--[no-]dds" and "--[no-]disable-dds" arguments are mutually exclusive. Only specify "--[no-]dds".');
      }
      ddsEnabled = !boolArgDeprecated('disable-dds');
      // TODO(ianh): enable the following code once google3 is migrated away from --disable-dds (and add test to flutter_command_test.dart)
      if (false) { // ignore: dead_code
        if (ddsEnabled) {
          globals.printWarning('${globals.logger.terminal
              .warningMark} The "--no-disable-dds" argument is deprecated and redundant, and should be omitted.');
        } else {
          globals.printWarning('${globals.logger.terminal
              .warningMark} The "--disable-dds" argument is deprecated. Use "--no-dds" instead.');
        }
      }
    } else {
      ddsEnabled = boolArgDeprecated('dds');
    }
    return ddsEnabled;
  }();

  bool get _hostVmServicePortProvided => (argResults?.wasParsed('observatory-port') ?? false)
      || (argResults?.wasParsed('host-vmservice-port') ?? false);

  int _tryParseHostVmservicePort() {
    final String? observatoryPort = stringArgDeprecated('observatory-port');
    final String? hostPort = stringArgDeprecated('host-vmservice-port');
    if (observatoryPort == null && hostPort == null) {
      throwToolExit('Invalid port for `--observatory-port/--host-vmservice-port`');
    }
    try {
      return int.parse((observatoryPort ?? hostPort)!);
    } on FormatException catch (error) {
      throwToolExit('Invalid port for `--observatory-port/--host-vmservice-port`: $error');
    }
  }

  int get ddsPort {
    if (argResults?.wasParsed('dds-port') != true && _hostVmServicePortProvided) {
      // If an explicit DDS port is _not_ provided, use the host-vmservice-port for DDS.
      return _tryParseHostVmservicePort();
    } else if (argResults?.wasParsed('dds-port') ?? false) {
      // If an explicit DDS port is provided, use dds-port for DDS.
      return int.tryParse(stringArgDeprecated('dds-port')!) ?? 0;
    }
    // Otherwise, DDS can bind to a random port.
    return 0;
  }

  Uri? get devToolsServerAddress {
    if (argResults?.wasParsed(kDevToolsServerAddress) ?? false) {
      final Uri? uri = Uri.tryParse(stringArgDeprecated(kDevToolsServerAddress)!);
      if (uri != null && uri.host.isNotEmpty && uri.port != 0) {
        return uri;
      }
    }
    return null;
  }

  /// Gets the vmservice port provided to in the 'observatory-port' or
  /// 'host-vmservice-port option.
  ///
  /// Only one of "host-vmservice-port" and "observatory-port" may be
  /// specified.
  ///
  /// If no port is set, returns null.
  int? get hostVmservicePort {
    if (!_usesPortOption || !_hostVmServicePortProvided) {
      return null;
    }
    if ((argResults?.wasParsed('observatory-port') ?? false)
        && (argResults?.wasParsed('host-vmservice-port') ?? false)) {
      throwToolExit('Only one of "--observatory-port" and '
        '"--host-vmservice-port" may be specified.');
    }
    // If DDS is enabled and no explicit DDS port is provided, use the
    // host-vmservice-port for DDS instead and bind the VM service to a random
    // port.
    if (enableDds && argResults?.wasParsed('dds-port') != true) {
      return null;
    }
    return _tryParseHostVmservicePort();
  }

  /// Gets the vmservice port provided to in the 'device-vmservice-port' option.
  ///
  /// If no port is set, returns null.
  int? get deviceVmservicePort {
    final String? devicePort = stringArgDeprecated('device-vmservice-port');
    if (!_usesPortOption || devicePort == null) {
      return null;
    }
    try {
      return int.parse(devicePort);
    } on FormatException catch (error) {
      throwToolExit('Invalid port for `--device-vmservice-port`: $error');
    }
  }

  void addPublishPort({ bool enabledByDefault = true, bool verboseHelp = false }) {
    argParser.addFlag('publish-port',
      hide: !verboseHelp,
      help: 'Publish the VM service port over mDNS. Disable to prevent the '
            'local network permission app dialog in debug and profile build modes (iOS devices only).',
      defaultsTo: enabledByDefault,
    );
  }

  bool get disablePortPublication => !boolArgDeprecated('publish-port');

  void usesIpv6Flag({required bool verboseHelp}) {
    argParser.addFlag(ipv6Flag,
      negatable: false,
      help: 'Binds to IPv6 localhost instead of IPv4 when the flutter tool '
            'forwards the host port to a device port. Not used when the '
            '"--debug-port" flag is not set.',
      hide: !verboseHelp,
    );
    _usesIpv6Flag = true;
  }

  bool? get ipv6 => _usesIpv6Flag ? boolArgDeprecated('ipv6') : null;

  void usesBuildNumberOption() {
    argParser.addOption('build-number',
        help: 'An identifier used as an internal version number.\n'
              'Each build must have a unique identifier to differentiate it from previous builds.\n'
              'It is used to determine whether one build is more recent than another, with higher numbers indicating more recent build.\n'
              'On Android it is used as "versionCode".\n'
              'On Xcode builds it is used as "CFBundleVersion".\n'
              'On Windows it is used as the build suffix for the product and file versions.',
    );
  }

  void usesBuildNameOption() {
    argParser.addOption('build-name',
        help: 'A "x.y.z" string used as the version number shown to users.\n'
              'For each new version of your app, you will provide a version number to differentiate it from previous versions.\n'
              'On Android it is used as "versionName".\n'
              'On Xcode builds it is used as "CFBundleShortVersionString".\n'
              'On Windows it is used as the major, minor, and patch parts of the product and file versions.',
        valueHelp: 'x.y.z');
  }

  void usesDartDefineOption() {
    argParser.addMultiOption(
      FlutterOptions.kDartDefinesOption,
      aliases: <String>[ kDartDefines ], // supported for historical reasons
      help: 'Additional key-value pairs that will be available as constants '
            'from the String.fromEnvironment, bool.fromEnvironment, int.fromEnvironment, '
            'and double.fromEnvironment constructors.\n'
            'Multiple defines can be passed by repeating "--${FlutterOptions.kDartDefinesOption}" multiple times.',
      valueHelp: 'foo=bar',
      splitCommas: false,
    );
    useDartDefineConfigJsonFileOption();
  }

  void useDartDefineConfigJsonFileOption() {
    argParser.addOption(
      FlutterOptions.kDartDefineFromFileOption,
      help: 'The path of a json format file where flutter define a global constant pool. '
          'Json entry will be available as constants from the String.fromEnvironment, bool.fromEnvironment, '
          'int.fromEnvironment, and double.fromEnvironment constructors; the key and field are json values.',
      valueHelp: 'use-define-config.json'
    );
  }

  void usesWebRendererOption() {
    argParser.addOption('web-renderer',
      defaultsTo: 'auto',
      allowed: <String>['auto', 'canvaskit', 'html'],
      help: 'The renderer implementation to use when building for the web.',
      allowedHelp: <String, String>{
        'html': 'Always use the HTML renderer. This renderer uses a combination of HTML, CSS, SVG, 2D Canvas, and WebGL.',
        'canvaskit': 'Always use the CanvasKit renderer. This renderer uses WebGL and WebAssembly to render graphics.',
        'auto': 'Use the HTML renderer on mobile devices, and CanvasKit on desktop devices.',
      }
    );
  }

  void usesDeviceUserOption() {
    argParser.addOption(FlutterOptions.kDeviceUser,
      help: 'Identifier number for a user or work profile on Android only. Run "adb shell pm list users" for available identifiers.',
      valueHelp: '10');
  }

  void usesDeviceTimeoutOption() {
    argParser.addOption(
      FlutterOptions.kDeviceTimeout,
      help: 'Time in seconds to wait for devices to attach. Longer timeouts may be necessary for networked devices.',
      valueHelp: '10'
    );
  }

  void usesApplicationBinaryOption() {
    argParser.addOption(
      FlutterOptions.kUseApplicationBinary,
      help: 'Specify a pre-built application binary to use when running. For Android applications, '
        'this must be the path to an APK. For iOS applications, the path to an IPA. Other device types '
        'do not yet support prebuilt application binaries.',
      valueHelp: 'path/to/app.apk',
    );
  }

  /// Whether it is safe for this command to use a cached pub invocation.
  bool get cachePubGet => true;

  /// Whether this command should report null safety analytics.
  bool get reportNullSafety => false;

  late final Duration? deviceDiscoveryTimeout = () {
    if ((argResults?.options.contains(FlutterOptions.kDeviceTimeout) ?? false)
        && (argResults?.wasParsed(FlutterOptions.kDeviceTimeout) ?? false)) {
      final int? timeoutSeconds = int.tryParse(stringArgDeprecated(FlutterOptions.kDeviceTimeout)!);
      if (timeoutSeconds == null) {
        throwToolExit( 'Could not parse "--${FlutterOptions.kDeviceTimeout}" argument. It must be an integer.');
      }
      return Duration(seconds: timeoutSeconds);
    }
    return null;
  }();

  void addBuildModeFlags({
    required bool verboseHelp,
    bool defaultToRelease = true,
    bool excludeDebug = false,
    bool excludeRelease = false,
  }) {
    // A release build must be the default if a debug build is not possible.
    assert(defaultToRelease || !excludeDebug);
    _excludeDebug = excludeDebug;
    _excludeRelease = excludeRelease;
    defaultBuildMode = defaultToRelease ? BuildMode.release : BuildMode.debug;

    if (!excludeDebug) {
      argParser.addFlag('debug',
        negatable: false,
        help: 'Build a debug version of your app${defaultToRelease ? '' : ' (default mode)'}.');
    }
    argParser.addFlag('profile',
      negatable: false,
      help: 'Build a version of your app specialized for performance profiling.');
    if (!excludeRelease) {
      argParser.addFlag('release',
        negatable: false,
        help: 'Build a release version of your app${defaultToRelease ? ' (default mode)' : ''}.');
      argParser.addFlag('jit-release',
        negatable: false,
        hide: !verboseHelp,
        help: 'Build a JIT release version of your app${defaultToRelease ? ' (default mode)' : ''}.');
    }
  }

  void addSplitDebugInfoOption() {
    argParser.addOption(FlutterOptions.kSplitDebugInfoOption,
      help: 'In a release build, this flag reduces application size by storing '
            'Dart program symbols in a separate file on the host rather than in the '
            'application. The value of the flag should be a directory where program '
            'symbol files can be stored for later use. These symbol files contain '
            'the information needed to symbolize Dart stack traces. For an app built '
            'with this flag, the "flutter symbolize" command with the right program '
            'symbol file is required to obtain a human readable stack trace.\n'
            'This flag cannot be combined with "--${FlutterOptions.kAnalyzeSize}".',
      valueHelp: 'v1.2.3/',
    );
  }

  void addDartObfuscationOption() {
    argParser.addFlag(FlutterOptions.kDartObfuscationOption,
      help: 'In a release build, this flag removes identifiers and replaces them '
            'with randomized values for the purposes of source code obfuscation. This '
            'flag must always be combined with "--${FlutterOptions.kSplitDebugInfoOption}" option, the '
            'mapping between the values and the original identifiers is stored in the '
            'symbol map created in the specified directory. For an app built with this '
            'flag, the "flutter symbolize" command with the right program '
            'symbol file is required to obtain a human readable stack trace.\n'
            '\n'
            'Because all identifiers are renamed, methods like Object.runtimeType, '
            'Type.toString, Enum.toString, Stacktrace.toString, Symbol.toString '
            '(for constant symbols or those generated by runtime system) will '
            'return obfuscated results. Any code or tests that rely on exact names '
            'will break.'
    );
  }

  void addBundleSkSLPathOption({ required bool hide }) {
    argParser.addOption(FlutterOptions.kBundleSkSLPathOption,
      help: 'A path to a file containing precompiled SkSL shaders generated '
        'during "flutter run". These can be included in an application to '
        'improve the first frame render times.',
      hide: hide,
      valueHelp: 'flutter_1.sksl'
    );
  }

  void addTreeShakeIconsFlag({
    bool? enabledByDefault
  }) {
    argParser.addFlag('tree-shake-icons',
      defaultsTo: enabledByDefault
        ?? kIconTreeShakerEnabledDefault,
      help: 'Tree shake icon fonts so that only glyphs used by the application remain.',
    );
  }

  void addShrinkingFlag({ required bool verboseHelp }) {
    argParser.addFlag('shrink',
      hide: !verboseHelp,
      help: 'This flag has no effect. Code shrinking is always enabled in release builds. '
            'To learn more, see: https://developer.android.com/studio/build/shrink-code'
    );
  }

  void addNullSafetyModeOptions({ required bool hide }) {
    argParser.addFlag(FlutterOptions.kNullSafety,
      help:
        'Whether to override the inferred null safety mode. This allows null-safe '
        'libraries to depend on un-migrated (non-null safe) libraries. By default, '
        'Flutter mobile & desktop applications will attempt to run at the null safety '
        'level of their entrypoint library (usually lib/main.dart). Flutter web '
        'applications will default to sound null-safety, unless specifically configured.',
      defaultsTo: true,
      hide: hide,
    );
    argParser.addFlag(FlutterOptions.kNullAssertions,
      help:
        'Perform additional null assertions on the boundaries of migrated and '
        'un-migrated code. This setting is not currently supported on desktop '
        'devices.'
    );
  }

  /// Enables support for the hidden options --extra-front-end-options and
  /// --extra-gen-snapshot-options.
  void usesExtraDartFlagOptions({ required bool verboseHelp }) {
    argParser.addMultiOption(FlutterOptions.kExtraFrontEndOptions,
      aliases: <String>[ kExtraFrontEndOptions ], // supported for historical reasons
      help: 'A comma-separated list of additional command line arguments that will be passed directly to the Dart front end. '
            'For example, "--${FlutterOptions.kExtraFrontEndOptions}=--enable-experiment=nonfunction-type-aliases".',
      valueHelp: '--foo,--bar',
      hide: !verboseHelp,
    );
    argParser.addMultiOption(FlutterOptions.kExtraGenSnapshotOptions,
      aliases: <String>[ kExtraGenSnapshotOptions ], // supported for historical reasons
      help: 'A comma-separated list of additional command line arguments that will be passed directly to the Dart native compiler. '
            '(Only used in "--profile" or "--release" builds.) '
            'For example, "--${FlutterOptions.kExtraGenSnapshotOptions}=--no-strip".',
      valueHelp: '--foo,--bar',
      hide: !verboseHelp,
    );
  }

  void usesFuchsiaOptions({ bool hide = false }) {
    argParser.addOption(
      'target-model',
      help: 'Target model that determines what core libraries are available.',
      defaultsTo: 'flutter',
      hide: hide,
      allowed: const <String>['flutter', 'flutter_runner'],
    );
    argParser.addOption(
      'module',
      abbr: 'm',
      hide: hide,
      help: 'The name of the module (required if attaching to a fuchsia device).',
      valueHelp: 'module-name',
    );
  }

  void addEnableExperimentation({ required bool hide }) {
    argParser.addMultiOption(
      FlutterOptions.kEnableExperiment,
      help:
        'The name of an experimental Dart feature to enable. For more information see: '
        'https://github.com/dart-lang/sdk/blob/main/docs/process/experimental-flags.md',
      hide: hide,
    );
  }

  void addBuildPerformanceFile({ bool hide = false }) {
    argParser.addOption(
      FlutterOptions.kPerformanceMeasurementFile,
      help:
        'The name of a file where flutter assemble performance and '
        'cached-ness information will be written in a JSON format.',
      hide: hide,
    );
  }

  void addAndroidSpecificBuildOptions({ bool hide = false }) {
    argParser.addFlag(
      FlutterOptions.kAndroidGradleDaemon,
      help: 'Whether to enable the Gradle daemon when performing an Android build. '
            'Starting the daemon is the default behavior of the gradle wrapper script created '
            'in a Flutter project. Setting this flag to false corresponds to passing '
            '"--no-daemon" to the gradle wrapper script. This flag will cause the daemon '
            'process to terminate after the build is completed.',
      defaultsTo: true,
      hide: hide,
    );
    argParser.addMultiOption(
      FlutterOptions.kAndroidProjectArgs,
      help: 'Additional arguments specified as key=value that are passed directly to the gradle '
            'project via the -P flag. These can be accessed in build.gradle via the "project.property" API.',
      splitCommas: false,
      abbr: 'P',
    );
  }

  void addNativeNullAssertions({ bool hide = false }) {
    argParser.addFlag('native-null-assertions',
      defaultsTo: true,
      hide: hide,
      help: 'Enables additional runtime null checks in web applications to ensure '
        'the correct nullability of native (such as in dart:html) and external '
        '(such as with JS interop) types. This is enabled by default but only takes '
        'effect in sound mode. To report an issue with a null assertion failure in '
        'dart:html or the other dart web libraries, please file a bug at: '
        'https://github.com/dart-lang/sdk/issues/labels/web-libraries'
    );
  }

  void usesInitializeFromDillOption({ required bool hide }) {
    argParser.addOption(FlutterOptions.kInitializeFromDill,
      help: 'Initializes the resident compiler with a specific kernel file instead of '
        'the default cached location.',
      hide: hide,
    );
    argParser.addFlag(FlutterOptions.kAssumeInitializeFromDillUpToDate,
      help: 'If set, assumes that the file passed in initialize-from-dill is up '
        'to date and skip the check and potential invalidation of files.',
      hide: hide,
    );
  }

  void addMultidexOption({ bool hide = false }) {
    argParser.addFlag('multidex',
      defaultsTo: true,
      help: 'When enabled, indicates that the app should be built with multidex support. This '
            'flag adds the dependencies for multidex when the minimum android sdk is 20 or '
            'below. For android sdk versions 21 and above, multidex support is native.',
    );
  }

  void addIgnoreDeprecationOption({ bool hide = false }) {
    argParser.addFlag('ignore-deprecation',
      negatable: false,
      help: 'Indicates that the app should ignore deprecation warnings and continue to build '
            'using deprecated APIs. Use of this flag may cause your app to fail to build when '
            'deprecated APIs are removed.',
    );
  }

  /// Adds build options common to all of the desktop build commands.
  void addCommonDesktopBuildOptions({ required bool verboseHelp }) {
    addBuildModeFlags(verboseHelp: verboseHelp);
    addBuildPerformanceFile(hide: !verboseHelp);
    addBundleSkSLPathOption(hide: !verboseHelp);
    addDartObfuscationOption();
    addEnableExperimentation(hide: !verboseHelp);
    addNullSafetyModeOptions(hide: !verboseHelp);
    addSplitDebugInfoOption();
    addTreeShakeIconsFlag();
    usesAnalyzeSizeFlag();
    usesDartDefineOption();
    usesExtraDartFlagOptions(verboseHelp: verboseHelp);
    usesPubOption();
    usesTargetOption();
    usesTrackWidgetCreation(verboseHelp: verboseHelp);
    usesBuildNumberOption();
    usesBuildNameOption();
  }

  /// The build mode that this command will use if no build mode is
  /// explicitly specified.
  ///
  /// Use [getBuildMode] to obtain the actual effective build mode.
  BuildMode defaultBuildMode = BuildMode.debug;

  BuildMode getBuildMode() {
    // No debug when _excludeDebug is true.
    // If debug is not excluded, then take the command line flag.
    final bool debugResult = !_excludeDebug && boolArgDeprecated('debug');
    final bool jitReleaseResult = !_excludeRelease && boolArgDeprecated('jit-release');
    final bool releaseResult = !_excludeRelease && boolArgDeprecated('release');
    final List<bool> modeFlags = <bool>[
      debugResult,
      jitReleaseResult,
      boolArgDeprecated('profile'),
      releaseResult,
    ];
    if (modeFlags.where((bool flag) => flag).length > 1) {
      throw UsageException('Only one of "--debug", "--profile", "--jit-release", '
                           'or "--release" can be specified.', '');
    }
    if (debugResult) {
      return BuildMode.debug;
    }
    if (boolArgDeprecated('profile')) {
      return BuildMode.profile;
    }
    if (releaseResult) {
      return BuildMode.release;
    }
    if (jitReleaseResult) {
      return BuildMode.jitRelease;
    }
    return defaultBuildMode;
  }

  void usesFlavorOption() {
    argParser.addOption(
      'flavor',
      help: 'Build a custom app flavor as defined by platform-specific build setup.\n'
            'Supports the use of product flavors in Android Gradle scripts, and '
            'the use of custom Xcode schemes.',
    );
  }

  void usesTrackWidgetCreation({ bool hasEffect = true, required bool verboseHelp }) {
    argParser.addFlag(
      'track-widget-creation',
      hide: !hasEffect && !verboseHelp,
      defaultsTo: true,
      help: 'Track widget creation locations. This enables features such as the widget inspector. '
            'This parameter is only functional in debug mode (i.e. when compiling JIT, not AOT).',
    );
  }

  void usesAnalyzeSizeFlag() {
    argParser.addFlag(
      FlutterOptions.kAnalyzeSize,
      help: 'Whether to produce additional profile information for artifact output size. '
            'This flag is only supported on "--release" builds. When building for Android, a single '
            'ABI must be specified at a time with the "--target-platform" flag. When building for iOS, '
            'only the symbols from the arm64 architecture are used to analyze code size.\n'
            'By default, the intermediate output files will be placed in a transient directory in the '
            'build directory. This can be overridden with the "--${FlutterOptions.kCodeSizeDirectory}" option.\n'
            'This flag cannot be combined with "--${FlutterOptions.kSplitDebugInfoOption}".'
    );

    argParser.addOption(
      FlutterOptions.kCodeSizeDirectory,
      help: 'The location to write code size analysis files. If this is not specified, files '
            'are written to a temporary directory under the build directory.'
    );
  }

  void addEnableImpellerFlag({required bool verboseHelp}) {
    argParser.addFlag('enable-impeller',
        negatable: false,
        hide: !verboseHelp,
        help: 'Whether to enable the experimental Impeller rendering engine. '
              'Impeller is currently only supported on iOS and Android. This flag will '
              'be ignored when targeting other platforms.',
    );
  }

  /// Compute the [BuildInfo] for the current flutter command.
  /// Commands that build multiple build modes can pass in a [forcedBuildMode]
  /// to be used instead of parsing flags.
  ///
  /// Throws a [ToolExit] if the current set of options is not compatible with
  /// each other.
  Future<BuildInfo> getBuildInfo({ BuildMode? forcedBuildMode, File? forcedTargetFile }) async {
    final bool trackWidgetCreation = argParser.options.containsKey('track-widget-creation') &&
      boolArgDeprecated('track-widget-creation');

    final String? buildNumber = argParser.options.containsKey('build-number')
      ? stringArgDeprecated('build-number')
      : null;

    final File packagesFile = globals.fs.file(
      packagesPath ?? globals.fs.path.absolute('.dart_tool', 'package_config.json'));
    final PackageConfig packageConfig = await loadPackageConfigWithLogging(
        packagesFile, logger: globals.logger, throwOnError: false);

    final List<String> experiments =
      argParser.options.containsKey(FlutterOptions.kEnableExperiment)
        ? stringsArg(FlutterOptions.kEnableExperiment).toList()
        : <String>[];
    final List<String> extraGenSnapshotOptions =
      argParser.options.containsKey(FlutterOptions.kExtraGenSnapshotOptions)
        ? stringsArg(FlutterOptions.kExtraGenSnapshotOptions).toList()
        : <String>[];
    final List<String> extraFrontEndOptions =
      argParser.options.containsKey(FlutterOptions.kExtraFrontEndOptions)
          ? stringsArg(FlutterOptions.kExtraFrontEndOptions).toList()
          : <String>[];

    if (experiments.isNotEmpty) {
      for (final String expFlag in experiments) {
        final String flag = '--enable-experiment=$expFlag';
        extraFrontEndOptions.add(flag);
        extraGenSnapshotOptions.add(flag);
      }
    }

    String? codeSizeDirectory;
    if (argParser.options.containsKey(FlutterOptions.kAnalyzeSize) && boolArgDeprecated(FlutterOptions.kAnalyzeSize)) {
      Directory directory = globals.fsUtils.getUniqueDirectory(
        globals.fs.directory(getBuildDirectory()),
        'flutter_size',
      );
      if (argParser.options.containsKey(FlutterOptions.kCodeSizeDirectory) && stringArgDeprecated(FlutterOptions.kCodeSizeDirectory) != null) {
        directory = globals.fs.directory(stringArgDeprecated(FlutterOptions.kCodeSizeDirectory));
      }
      directory.createSync(recursive: true);
      codeSizeDirectory = directory.path;
    }

    NullSafetyMode nullSafetyMode = NullSafetyMode.sound;
    if (argParser.options.containsKey(FlutterOptions.kNullSafety)) {
      // Explicitly check for `true` and `false` so that `null` results in not
      // passing a flag. Examine the entrypoint file to determine if it
      // is opted in or out.
      final bool wasNullSafetyFlagParsed = argResults?.wasParsed(FlutterOptions.kNullSafety) ?? false;
      if (!wasNullSafetyFlagParsed && (argParser.options.containsKey('target') || forcedTargetFile != null)) {
        final File entrypointFile = forcedTargetFile ?? globals.fs.file(targetFile);
        final LanguageVersion languageVersion = determineLanguageVersion(
          entrypointFile,
          packageConfig.packageOf(entrypointFile.absolute.uri),
          Cache.flutterRoot!,
        );
        // Extra frontend options are only provided if explicitly
        // requested.
        if (languageVersion.major >= nullSafeVersion.major && languageVersion.minor >= nullSafeVersion.minor) {
          nullSafetyMode = NullSafetyMode.sound;
        } else {
          nullSafetyMode = NullSafetyMode.unsound;
        }
      } else if (!wasNullSafetyFlagParsed) {
        // This mode is only used for commands which do not build a single target like
        // 'flutter test'.
        nullSafetyMode = NullSafetyMode.autodetect;
      } else if (boolArgDeprecated(FlutterOptions.kNullSafety)) {
        nullSafetyMode = NullSafetyMode.sound;
        extraFrontEndOptions.add('--sound-null-safety');
      } else {
        nullSafetyMode = NullSafetyMode.unsound;
        extraFrontEndOptions.add('--no-sound-null-safety');
      }
    }

    final bool dartObfuscation = argParser.options.containsKey(FlutterOptions.kDartObfuscationOption)
      && boolArgDeprecated(FlutterOptions.kDartObfuscationOption);

    final String? splitDebugInfoPath = argParser.options.containsKey(FlutterOptions.kSplitDebugInfoOption)
      ? stringArgDeprecated(FlutterOptions.kSplitDebugInfoOption)
      : null;

    final bool androidGradleDaemon = !argParser.options.containsKey(FlutterOptions.kAndroidGradleDaemon)
      || boolArgDeprecated(FlutterOptions.kAndroidGradleDaemon);

    final List<String> androidProjectArgs = argParser.options.containsKey(FlutterOptions.kAndroidProjectArgs)
      ? stringsArg(FlutterOptions.kAndroidProjectArgs)
      : <String>[];

    if (dartObfuscation && (splitDebugInfoPath == null || splitDebugInfoPath.isEmpty)) {
      throwToolExit(
        '"--${FlutterOptions.kDartObfuscationOption}" can only be used in '
        'combination with "--${FlutterOptions.kSplitDebugInfoOption}"',
      );
    }
    final BuildMode buildMode = forcedBuildMode ?? getBuildMode();
    if (buildMode != BuildMode.release && codeSizeDirectory != null) {
      throwToolExit('"--${FlutterOptions.kAnalyzeSize}" can only be used on release builds.');
    }
    if (codeSizeDirectory != null && splitDebugInfoPath != null) {
      throwToolExit('"--${FlutterOptions.kAnalyzeSize}" cannot be combined with "--${FlutterOptions.kSplitDebugInfoOption}".');
    }

    final bool treeShakeIcons = argParser.options.containsKey('tree-shake-icons')
      && buildMode.isPrecompiled == true
      && boolArgDeprecated('tree-shake-icons');

    final String? bundleSkSLPath = argParser.options.containsKey(FlutterOptions.kBundleSkSLPathOption)
      ? stringArgDeprecated(FlutterOptions.kBundleSkSLPathOption)
      : null;

    if (bundleSkSLPath != null && !globals.fs.isFileSync(bundleSkSLPath)) {
      throwToolExit('No SkSL shader bundle found at $bundleSkSLPath.');
    }

    final String? performanceMeasurementFile = argParser.options.containsKey(FlutterOptions.kPerformanceMeasurementFile)
      ? stringArgDeprecated(FlutterOptions.kPerformanceMeasurementFile)
      : null;

    List<String> dartDefines = argParser.options.containsKey(FlutterOptions.kDartDefinesOption)
        ? stringsArg(FlutterOptions.kDartDefinesOption)
        : <String>[];

    if (argParser.options.containsKey('web-renderer')) {
      dartDefines = updateDartDefines(dartDefines, stringArgDeprecated('web-renderer')!);
    }

    Map<String, Object>? defineConfigJsonMap;
    if (argParser.options.containsKey(FlutterOptions.kDartDefineFromFileOption)) {
      final String? configJsonPath = stringArg(FlutterOptions.kDartDefineFromFileOption);
      if (configJsonPath != null && globals.fs.isFileSync(configJsonPath)) {
        final String configJsonRaw = globals.fs.file(configJsonPath).readAsStringSync();
        try {
          defineConfigJsonMap = <String, Object>{};
          // Fix json convert Object value :type '_InternalLinkedHashMap<String, dynamic>' is not a subtype of type 'Map<String, Object>' in type cast
          (json.decode(configJsonRaw) as Map<String, dynamic>).forEach((String key, dynamic value) {
            defineConfigJsonMap?[key]=value as Object;
          });
          defineConfigJsonMap.forEach((String key, Object value) {
            dartDefines.add('$key=$value');
          });
        } on FormatException catch (err) {
          throwToolExit('Json config define file "--${FlutterOptions.kDartDefineFromFileOption}=$configJsonPath" format err, '
              'please fix first! format err:\n$err');
        }
      }
    }

    return BuildInfo(buildMode,
      argParser.options.containsKey('flavor')
        ? stringArgDeprecated('flavor')
        : null,
      trackWidgetCreation: trackWidgetCreation,
      extraFrontEndOptions: extraFrontEndOptions.isNotEmpty
        ? extraFrontEndOptions
        : null,
      extraGenSnapshotOptions: extraGenSnapshotOptions.isNotEmpty
        ? extraGenSnapshotOptions
        : null,
      fileSystemRoots: fileSystemRoots,
      fileSystemScheme: fileSystemScheme,
      buildNumber: buildNumber,
      buildName: argParser.options.containsKey('build-name')
          ? stringArgDeprecated('build-name')
          : null,
      treeShakeIcons: treeShakeIcons,
      splitDebugInfoPath: splitDebugInfoPath,
      dartObfuscation: dartObfuscation,
      dartDefines: dartDefines,
      bundleSkSLPath: bundleSkSLPath,
      dartExperiments: experiments,
      performanceMeasurementFile: performanceMeasurementFile,
      dartDefineConfigJsonMap: defineConfigJsonMap,
      packagesPath: packagesPath ?? globals.fs.path.absolute('.dart_tool', 'package_config.json'),
      nullSafetyMode: nullSafetyMode,
      codeSizeDirectory: codeSizeDirectory,
      androidGradleDaemon: androidGradleDaemon,
      packageConfig: packageConfig,
      androidProjectArgs: androidProjectArgs,
      initializeFromDill: argParser.options.containsKey(FlutterOptions.kInitializeFromDill)
          ? stringArgDeprecated(FlutterOptions.kInitializeFromDill)
          : null,
      assumeInitializeFromDillUpToDate: argParser.options.containsKey(FlutterOptions.kAssumeInitializeFromDillUpToDate)
          && boolArgDeprecated(FlutterOptions.kAssumeInitializeFromDillUpToDate),
    );
  }

  void setupApplicationPackages() {
    applicationPackages ??= ApplicationPackageFactory.instance;
  }

  /// The path to send to Google Analytics. Return null here to disable
  /// tracking of the command.
  Future<String?> get usagePath async {
    if (parent is FlutterCommand) {
      final FlutterCommand? commandParent = parent as FlutterCommand?;
      final String? path = await commandParent?.usagePath;
      // Don't report for parents that return null for usagePath.
      return path == null ? null : '$path/$name';
    } else {
      return name;
    }
  }

  /// Additional usage values to be sent with the usage ping.
  Future<CustomDimensions> get usageValues async => const CustomDimensions();

  /// Runs this command.
  ///
  /// Rather than overriding this method, subclasses should override
  /// [verifyThenRunCommand] to perform any verification
  /// and [runCommand] to execute the command
  /// so that this method can record and report the overall time to analytics.
  @override
  Future<void> run() {
    final DateTime startTime = globals.systemClock.now();

    return context.run<void>(
      name: 'command',
      overrides: <Type, Generator>{FlutterCommand: () => this},
      body: () async {
        if (_usesFatalWarnings) {
          globals.logger.fatalWarnings = boolArgDeprecated(FlutterOptions.kFatalWarnings);
        }
        // Prints the welcome message if needed.
        globals.flutterUsage.printWelcome();
        _printDeprecationWarning();
        final String? commandPath = await usagePath;
        if (commandPath != null) {
          _registerSignalHandlers(commandPath, startTime);
        }
        FlutterCommandResult commandResult = FlutterCommandResult.fail();
        try {
          commandResult = await verifyThenRunCommand(commandPath);
        } finally {
          final DateTime endTime = globals.systemClock.now();
          globals.printTrace(userMessages.flutterElapsedTime(name, getElapsedAsMilliseconds(endTime.difference(startTime))));
          if (commandPath != null) {
            _sendPostUsage(commandPath, commandResult, startTime, endTime);
          }
          if (_usesFatalWarnings) {
            globals.logger.checkForFatalLogs();
          }
        }
      },
    );
  }

  @visibleForOverriding
  String get deprecationWarning {
    return '${globals.logger.terminal.warningMark} The "$name" command is '
           'deprecated and will be removed in a future version of Flutter. '
           'See https://flutter.dev/docs/development/tools/sdk/releases '
           'for previous releases of Flutter.\n';
  }

  void _printDeprecationWarning() {
    if (deprecated) {
      globals.printWarning(deprecationWarning);
    }
  }

  /// Updates dart-defines based on [webRenderer].
  @visibleForTesting
  static List<String> updateDartDefines(List<String> dartDefines, String webRenderer) {
    final Set<String> dartDefinesSet = dartDefines.toSet();
    if (!dartDefines.any((String d) => d.startsWith('FLUTTER_WEB_AUTO_DETECT='))
        && dartDefines.any((String d) => d.startsWith('FLUTTER_WEB_USE_SKIA='))) {
      dartDefinesSet.removeWhere((String d) => d.startsWith('FLUTTER_WEB_USE_SKIA='));
    }
    final Iterable<String>? webRendererDefine = _webRendererDartDefines[webRenderer];
    if (webRendererDefine != null) {
      dartDefinesSet.addAll(webRendererDefine);
    }
    return dartDefinesSet.toList();
  }

  void _registerSignalHandlers(String commandPath, DateTime startTime) {
    void handler(io.ProcessSignal s) {
      globals.cache.releaseLock();
      _sendPostUsage(
        commandPath,
        const FlutterCommandResult(ExitStatus.killed),
        startTime,
        globals.systemClock.now(),
      );
    }
    globals.signals.addHandler(io.ProcessSignal.sigterm, handler);
    globals.signals.addHandler(io.ProcessSignal.sigint, handler);
  }

  /// Logs data about this command.
  ///
  /// For example, the command path (e.g. `build/apk`) and the result,
  /// as well as the time spent running it.
  void _sendPostUsage(
    String commandPath,
    FlutterCommandResult commandResult,
    DateTime startTime,
    DateTime endTime,
  ) {
    if (commandPath == null) {
      return;
    }
    assert(commandResult != null);
    // Send command result.
    CommandResultEvent(commandPath, commandResult.toString()).send();

    // Send timing.
    final List<String?> labels = <String?>[
      if (commandResult.exitStatus != null)
        getEnumName(commandResult.exitStatus),
      if (commandResult.timingLabelParts?.isNotEmpty ?? false)
        ...?commandResult.timingLabelParts,
    ];

    final String label = labels
        .where((String? label) => label != null && !_isBlank(label))
        .join('-');
    globals.flutterUsage.sendTiming(
      'flutter',
      name,
      // If the command provides its own end time, use it. Otherwise report
      // the duration of the entire execution.
      (commandResult.endTimeOverride ?? endTime).difference(startTime),
      // Report in the form of `success-[parameter1-parameter2]`, all of which
      // can be null if the command doesn't provide a FlutterCommandResult.
      label: label == '' ? null : label,
    );
  }

  /// Perform validation then call [runCommand] to execute the command.
  /// Return a [Future] that completes with an exit code
  /// indicating whether execution was successful.
  ///
  /// Subclasses should override this method to perform verification
  /// then call this method to execute the command
  /// rather than calling [runCommand] directly.
  @mustCallSuper
  Future<FlutterCommandResult> verifyThenRunCommand(String? commandPath) async {
    globals.preRunValidator.validate();
    // Populate the cache. We call this before pub get below so that the
    // sky_engine package is available in the flutter cache for pub to find.
    if (shouldUpdateCache) {
      // First always update universal artifacts, as some of these (e.g.
      // ios-deploy on macOS) are required to determine `requiredArtifacts`.
      final bool offline;
      if (argParser.options.containsKey('offline')) {
        offline = boolArgDeprecated('offline');
      } else {
        offline = false;
      }
      await globals.cache.updateAll(<DevelopmentArtifact>{DevelopmentArtifact.universal}, offline: offline);
      await globals.cache.updateAll(await requiredArtifacts, offline: offline);
    }
    globals.cache.releaseLock();

    await validateCommand();

    final FlutterProject project = FlutterProject.current();
    project.checkForDeprecation(deprecationBehavior: deprecationBehavior);

    if (shouldRunPub) {
      final Environment environment = Environment(
        artifacts: globals.artifacts!,
        logger: globals.logger,
        cacheDir: globals.cache.getRoot(),
        engineVersion: globals.flutterVersion.engineRevision,
        fileSystem: globals.fs,
        flutterRootDir: globals.fs.directory(Cache.flutterRoot),
        outputDir: globals.fs.directory(getBuildDirectory()),
        processManager: globals.processManager,
        platform: globals.platform,
        usage: globals.flutterUsage,
        projectDir: project.directory,
        generateDartPluginRegistry: true,
      );

      await generateLocalizationsSyntheticPackage(
        environment: environment,
        buildSystem: globals.buildSystem,
      );

      await pub.get(
        context: PubContext.getVerifyContext(name),
        project: project,
        checkUpToDate: cachePubGet,
      );
      await project.regeneratePlatformSpecificTooling();
      if (reportNullSafety) {
        await _sendNullSafetyAnalyticsEvents(project);
      }
    }

    setupApplicationPackages();

    if (commandPath != null) {
      Usage.command(commandPath, parameters: CustomDimensions(
        commandHasTerminal: globals.stdio.hasTerminal,
      ).merge(await usageValues));
    }

    return runCommand();
  }

  Future<void> _sendNullSafetyAnalyticsEvents(FlutterProject project) async {
    final BuildInfo buildInfo = await getBuildInfo();
    NullSafetyAnalysisEvent(
      buildInfo.packageConfig,
      buildInfo.nullSafetyMode,
      project.manifest.appName,
      globals.flutterUsage,
    ).send();
  }

  /// The set of development artifacts required for this command.
  ///
  /// Defaults to an empty set. Including [DevelopmentArtifact.universal] is
  /// not required as it is always updated.
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async => const <DevelopmentArtifact>{};

  /// Subclasses must implement this to execute the command.
  /// Optionally provide a [FlutterCommandResult] to send more details about the
  /// execution for analytics.
  Future<FlutterCommandResult> runCommand();

  /// Find and return all target [Device]s based upon currently connected
  /// devices and criteria entered by the user on the command line.
  /// If no device can be found that meets specified criteria,
  /// then print an error message and return null.
  Future<List<Device>?> findAllTargetDevices({
    bool includeUnsupportedDevices = false,
  }) async {
    if (!globals.doctor!.canLaunchAnything) {
      globals.printError(userMessages.flutterNoDevelopmentDevice);
      return null;
    }
    final DeviceManager deviceManager = globals.deviceManager!;
    List<Device> devices = await deviceManager.findTargetDevices(
      includeUnsupportedDevices ? null : FlutterProject.current(),
      timeout: deviceDiscoveryTimeout,
    );

    if (devices.isEmpty) {
      if (deviceManager.hasSpecifiedDeviceId) {
        globals.logger.printStatus(userMessages.flutterNoMatchingDevice(deviceManager.specifiedDeviceId!));
        final List<Device> allDevices = await deviceManager.getAllConnectedDevices();
        if (allDevices.isNotEmpty) {
          globals.logger.printStatus('');
          globals.logger.printStatus('The following devices were found:');
          await Device.printDevices(allDevices, globals.logger);
        }
        return null;
      } else if (deviceManager.hasSpecifiedAllDevices) {
        globals.logger.printStatus(userMessages.flutterNoDevicesFound);
        await _printUnsupportedDevice(deviceManager);
        return null;
      } else {
        globals.logger.printStatus(userMessages.flutterNoSupportedDevices);
        await _printUnsupportedDevice(deviceManager);
        return null;
      }
    } else if (devices.length > 1) {
      if (deviceManager.hasSpecifiedDeviceId) {
        globals.logger.printStatus(userMessages.flutterFoundSpecifiedDevices(devices.length, deviceManager.specifiedDeviceId!));
        return null;
      } else if (!deviceManager.hasSpecifiedAllDevices) {
        if (globals.terminal.stdinHasTerminal) {
          // If DeviceManager was not able to prioritize a device. For example, if the user
          // has two active Android devices running, then we request the user to
          // choose one. If the user has two nonEphemeral devices running, we also
          // request input to choose one.
          globals.logger.printStatus(userMessages.flutterMultipleDevicesFound);
          await Device.printDevices(devices, globals.logger);
          final Device chosenDevice = await _chooseOneOfAvailableDevices(devices);

          // Update the [DeviceManager.specifiedDeviceId] so that we will not be prompted again.
          deviceManager.specifiedDeviceId = chosenDevice.id;

          devices = <Device>[chosenDevice];
        } else {
          // Show an error message asking the user to specify `-d all` if they
          // want to run on multiple devices.
          final List<Device> allDevices = await deviceManager.getAllConnectedDevices();
          globals.logger.printStatus(userMessages.flutterSpecifyDeviceWithAllOption);
          globals.logger.printStatus('');
          await Device.printDevices(allDevices, globals.logger);
          return null;
        }
      }
    }

    return devices;
  }

  Future<void> _printUnsupportedDevice(DeviceManager deviceManager) async {
    final List<Device> unsupportedDevices = await deviceManager.getDevices();
    if (unsupportedDevices.isNotEmpty) {
      final StringBuffer result = StringBuffer();
      result.writeln(userMessages.flutterFoundButUnsupportedDevices);
      result.writeAll(
        (await Device.descriptions(unsupportedDevices))
            .map((String desc) => desc)
            .toList(),
        '\n',
      );
      result.writeln();
      result.writeln(userMessages.flutterMissPlatformProjects(
        Device.devicesPlatformTypes(unsupportedDevices),
      ));
      globals.logger.printStatus(result.toString());
    }
  }

  Future<Device> _chooseOneOfAvailableDevices(List<Device> devices) async {
    _displayDeviceOptions(devices);
    final String userInput =  await _readUserInput(devices.length);
    if (userInput.toLowerCase() == 'q') {
      throwToolExit('');
    }
    return devices[int.parse(userInput) - 1];
  }

  void _displayDeviceOptions(List<Device> devices) {
    int count = 1;
    for (final Device device in devices) {
      globals.logger.printStatus(userMessages.flutterChooseDevice(count, device.name, device.id));
      count++;
    }
  }

  Future<String> _readUserInput(int deviceCount) async {
    globals.terminal.usesTerminalUi = true;
    final String result = await globals.terminal.promptForCharInput(
      <String>[ for (int i = 0; i < deviceCount; i++) '${i + 1}', 'q', 'Q'],
      displayAcceptedCharacters: false,
      logger: globals.logger,
      prompt: userMessages.flutterChooseOne,
    );
    return result;
  }

  /// Find and return the target [Device] based upon currently connected
  /// devices and criteria entered by the user on the command line.
  /// If a device cannot be found that meets specified criteria,
  /// then print an error message and return null.
  ///
  /// If [includeUnsupportedDevices] is true, the tool does not filter
  /// the list by the current project support list.
  Future<Device?> findTargetDevice({
    bool includeUnsupportedDevices = false,
  }) async {
    List<Device>? deviceList = await findAllTargetDevices(includeUnsupportedDevices: includeUnsupportedDevices);
    if (deviceList == null) {
      return null;
    }
    if (deviceList.length > 1) {
      globals.printStatus(userMessages.flutterSpecifyDevice);
      deviceList = await globals.deviceManager!.getAllConnectedDevices();
      globals.printStatus('');
      await Device.printDevices(deviceList, globals.logger);
      return null;
    }
    return deviceList.single;
  }

  @protected
  @mustCallSuper
  Future<void> validateCommand() async {
    if (_requiresPubspecYaml && globalResults?.wasParsed('packages') != true) {
      // Don't expect a pubspec.yaml file if the user passed in an explicit .packages file path.

      // If there is no pubspec in the current directory, look in the parent
      // until one can be found.
      final String? path = findProjectRoot(globals.fs, globals.fs.currentDirectory.path);
      if (path == null) {
        throwToolExit(userMessages.flutterNoPubspec);
      }
      if (path != globals.fs.currentDirectory.path) {
        globals.fs.currentDirectory = path;
        globals.printStatus('Changing current working directory to: ${globals.fs.currentDirectory.path}');
      }
    }

    if (_usesTargetOption) {
      final String targetPath = targetFile;
      if (!globals.fs.isFileSync(targetPath)) {
        throw ToolExit(userMessages.flutterTargetFileMissing(targetPath));
      }
    }
  }

  @override
  String get usage {
    final String usageWithoutDescription = super.usage.substring(
      // The description plus two newlines.
      description.length + 2,
    );
    final String help = <String>[
      if (deprecated)
        '${globals.logger.terminal.warningMark} Deprecated. This command will be removed in a future version of Flutter.',
      description,
      '',
      'Global options:',
      '${runner?.argParser.usage}',
      '',
      usageWithoutDescription,
    ].join('\n');
    return help;
  }

  ApplicationPackageFactory? applicationPackages;

  /// Gets the parsed command-line option named [name] as a `bool`.
  /// This has been deprecated, use [boolArg] instead.
  bool boolArgDeprecated(String name) => argResults?[name] as bool? ?? false;

  /// Gets the parsed command-line option named [name] as a `bool?`.
  bool? boolArg(String name) {
    if (!argParser.options.containsKey(name)) {
      return null;
    }
    return argResults![name] as bool;
  }

  /// Gets the parsed command-line option named [name] as a `String`.
  String? stringArgDeprecated(String name) => argResults?[name] as String?;

  String? stringArg(String name) {
    if (!argParser.options.containsKey(name)) {
      return null;
    }
    return argResults![name] as String?;
  }

  /// Gets the parsed command-line option named [name] as an `int`.
  int? intArg(String name) => argResults?[name] as int?;

  /// Gets the parsed command-line option named [name] as `List<String>`.
  List<String> stringsArg(String name) {
    return argResults![name]! as List<String>? ?? <String>[];
  }
}

/// A mixin which applies an implementation of [requiredArtifacts] that only
/// downloads artifacts corresponding to an attached device.
mixin DeviceBasedDevelopmentArtifacts on FlutterCommand {
  @override
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async {
    // If there are no attached devices, use the default configuration.
    // Otherwise, only add development artifacts which correspond to a
    // connected device.
    final List<Device> devices = await globals.deviceManager!.getDevices();
    if (devices.isEmpty) {
      return super.requiredArtifacts;
    }
    final Set<DevelopmentArtifact> artifacts = <DevelopmentArtifact>{
      DevelopmentArtifact.universal,
    };
    for (final Device device in devices) {
      final TargetPlatform targetPlatform = await device.targetPlatform;
      final DevelopmentArtifact? developmentArtifact = artifactFromTargetPlatform(targetPlatform);
      if (developmentArtifact != null) {
        artifacts.add(developmentArtifact);
      }
    }
    return artifacts;
  }
}

// Returns the development artifact for the target platform, or null
// if none is supported
@protected
DevelopmentArtifact? artifactFromTargetPlatform(TargetPlatform targetPlatform) {
  switch (targetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.android_arm:
    case TargetPlatform.android_arm64:
    case TargetPlatform.android_x64:
    case TargetPlatform.android_x86:
      return DevelopmentArtifact.androidGenSnapshot;
    case TargetPlatform.web_javascript:
      return DevelopmentArtifact.web;
    case TargetPlatform.ios:
      return DevelopmentArtifact.iOS;
    case TargetPlatform.darwin:
      if (featureFlags.isMacOSEnabled) {
        return DevelopmentArtifact.macOS;
      }
      return null;
    case TargetPlatform.windows_x64:
      if (featureFlags.isWindowsEnabled) {
        return DevelopmentArtifact.windows;
      }
      return null;
    case TargetPlatform.linux_x64:
    case TargetPlatform.linux_arm64:
      if (featureFlags.isLinuxEnabled) {
        return DevelopmentArtifact.linux;
      }
      return null;
    case TargetPlatform.fuchsia_arm64:
    case TargetPlatform.fuchsia_x64:
    case TargetPlatform.tester:
      return null;
  }
}

/// Returns true if s is either null, empty or is solely made of whitespace characters (as defined by String.trim).
bool _isBlank(String s) => s == null || s.trim().isEmpty;
