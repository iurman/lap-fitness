// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:meta/meta.dart';

import '../base/analyze_size.dart';
import '../base/common.dart';
import '../base/logger.dart';
import '../base/process.dart';
import '../base/utils.dart';
import '../build_info.dart';
import '../convert.dart';
import '../globals.dart' as globals;
import '../ios/application_package.dart';
import '../ios/mac.dart';
import '../ios/plist_parser.dart';
import '../runner/flutter_command.dart';
import 'build.dart';

/// Builds an .app for an iOS app to be used for local testing on an iOS device
/// or simulator. Can only be run on a macOS host.
class BuildIOSCommand extends _BuildIOSSubCommand {
  BuildIOSCommand({ required super.logger, required super.verboseHelp }) {
    argParser
      ..addFlag('config-only',
        help: 'Update the project configuration without performing a build. '
          'This can be used in CI/CD process that create an archive to avoid '
          'performing duplicate work.'
      )
      ..addFlag('simulator',
        help: 'Build for the iOS simulator instead of the device. This changes '
          'the default build mode to debug if otherwise unspecified.',
      );
  }

  @override
  final String name = 'ios';

  @override
  final String description = 'Build an iOS application bundle (macOS host only).';

  @override
  final XcodeBuildAction xcodeBuildAction = XcodeBuildAction.build;

  @override
  EnvironmentType get environmentType => boolArgDeprecated('simulator') ? EnvironmentType.simulator : EnvironmentType.physical;

  @override
  bool get configOnly => boolArgDeprecated('config-only');

  @override
  Directory _outputAppDirectory(String xcodeResultOutput) => globals.fs.directory(xcodeResultOutput).parent;
}

/// The key that uniquely identifies an image file in an app icon asset.
/// It consists of (idiom, size, scale).
@immutable
class _AppIconImageFileKey {
  const _AppIconImageFileKey(this.idiom, this.size, this.scale);

  /// The idiom (iphone or ipad).
  final String idiom;
  /// The logical size in point (e.g. 83.5).
  final double size;
  /// The scale factor (e.g. 2).
  final int scale;

  @override
  int get hashCode => Object.hash(idiom, size, scale);

  @override
  bool operator ==(Object other) => other is _AppIconImageFileKey
      && other.idiom == idiom
      && other.size == size
      && other.scale == scale;

  /// The pixel size.
  int get pixelSize => (size * scale).toInt(); // pixel size must be an int.
}

/// Builds an .xcarchive and optionally .ipa for an iOS app to be generated for
/// App Store submission.
///
/// Can only be run on a macOS host.
class BuildIOSArchiveCommand extends _BuildIOSSubCommand {
  BuildIOSArchiveCommand({required super.logger, required super.verboseHelp}) {
    argParser.addOption(
      'export-method',
      defaultsTo: 'app-store',
      allowed: <String>['app-store', 'ad-hoc', 'development', 'enterprise'],
      help: 'Specify how the IPA will be distributed.',
      allowedHelp: <String, String>{
        'app-store': 'Upload to the App Store.',
        'ad-hoc': 'Test on designated devices that do not need to be registered with the Apple developer account. '
                  'Requires a distribution certificate.',
        'development': 'Test only on development devices registered with the Apple developer account.',
        'enterprise': 'Distribute an app registered with the Apple Developer Enterprise Program.',
      },
    );
    argParser.addOption(
      'export-options-plist',
      valueHelp: 'ExportOptions.plist',
      help:
          'Export an IPA with these options. See "xcodebuild -h" for available exportOptionsPlist keys.',
    );
  }

  @override
  final String name = 'ipa';

  @override
  final List<String> aliases = <String>['xcarchive'];

  @override
  final String description = 'Build an iOS archive bundle and IPA for distribution (macOS host only).';

  @override
  final XcodeBuildAction xcodeBuildAction = XcodeBuildAction.archive;

  @override
  final EnvironmentType environmentType = EnvironmentType.physical;

  @override
  final bool configOnly = false;

  String? get exportOptionsPlist => stringArgDeprecated('export-options-plist');

  @override
  Directory _outputAppDirectory(String xcodeResultOutput) => globals.fs
      .directory(xcodeResultOutput)
      .childDirectory('Products')
      .childDirectory('Applications');

  @override
  Future<void> validateCommand() async {
    final String? exportOptions = exportOptionsPlist;
    if (exportOptions != null) {
      if (argResults?.wasParsed('export-method') ?? false) {
        throwToolExit(
          '"--export-options-plist" is not compatible with "--export-method". Either use "--export-options-plist" and '
          'a plist describing how the IPA should be exported by Xcode, or use "--export-method" to create a new plist.\n'
          'See "xcodebuild -h" for available exportOptionsPlist keys.'
        );
      }
      final FileSystemEntityType type = globals.fs.typeSync(exportOptions);
      if (type == FileSystemEntityType.notFound) {
        throwToolExit(
            '"$exportOptions" property list does not exist.');
      } else if (type != FileSystemEntityType.file) {
        throwToolExit(
            '"$exportOptions" is not a file. See "xcodebuild -h" for available keys.');
      }
    }
    return super.validateCommand();
  }

  // Parses Contents.json into a map, with the key to be _AppIconImageFileKey, and value to be the icon image file name.
  Map<_AppIconImageFileKey, String> _parseIconContentsJson(String contentsJsonDirName) {
    final Directory contentsJsonDirectory = globals.fs.directory(contentsJsonDirName);
    if (!contentsJsonDirectory.existsSync()) {
      return <_AppIconImageFileKey, String>{};
    }
    final File contentsJsonFile = contentsJsonDirectory.childFile('Contents.json');
    final Map<String, dynamic> contents = json.decode(contentsJsonFile.readAsStringSync()) as Map<String, dynamic>? ?? <String, dynamic>{};
    final List<dynamic> images = contents['images'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic> info = contents['info'] as Map<String, dynamic>? ?? <String, dynamic>{};
    if ((info['version'] as int?) != 1) {
      // Skips validation for unknown format.
      return <_AppIconImageFileKey, String>{};
    }

    final Map<_AppIconImageFileKey, String> iconInfo = <_AppIconImageFileKey, String>{};
    for (final dynamic image in images) {
      final Map<String, dynamic> imageMap = image as Map<String, dynamic>;
      final String? idiom = imageMap['idiom'] as String?;
      final String? size = imageMap['size'] as String?;
      final String? scale = imageMap['scale'] as String?;
      final String? fileName = imageMap['filename'] as String?;

      if (size == null || idiom == null || scale == null || fileName == null) {
        continue;
      }

      // for example, "64x64". Parse the width since it is a square.
      final Iterable<double> parsedSizes = size.split('x')
          .map((String element) => double.tryParse(element))
          .whereType<double>();
      if (parsedSizes.isEmpty) {
        continue;
      }
      final double parsedSize = parsedSizes.first;

      // for example, "3x".
      final Iterable<int> parsedScales = scale.split('x')
          .map((String element) => int.tryParse(element))
          .whereType<int>();
      if (parsedScales.isEmpty) {
        continue;
      }
      final int parsedScale = parsedScales.first;

      iconInfo[_AppIconImageFileKey(idiom, parsedSize, parsedScale)] = fileName;
    }

    return iconInfo;
  }

  Future<void> _validateIconsAfterArchive(StringBuffer messageBuffer) async {
    final BuildableIOSApp app = await buildableIOSApp;
    final String templateIconImageDirName = await app.templateAppIconDirNameForImages;

    final Map<_AppIconImageFileKey, String> templateIconMap = _parseIconContentsJson(app.templateAppIconDirNameForContentsJson);
    final Map<_AppIconImageFileKey, String> projectIconMap = _parseIconContentsJson(app.projectAppIconDirName);

    // validate each of the project icon images.
    final List<String> filesWithTemplateIcon = <String>[];
    final List<String> filesWithWrongSize = <String>[];
    for (final MapEntry<_AppIconImageFileKey, String> entry in projectIconMap.entries) {
      final String projectIconFileName = entry.value;
      final String? templateIconFileName = templateIconMap[entry.key];
      final File projectIconFile = globals.fs.file(globals.fs.path.join(app.projectAppIconDirName, projectIconFileName));
      if (!projectIconFile.existsSync()) {
        continue;
      }
      final Uint8List projectIconBytes = projectIconFile.readAsBytesSync();

      // validate conflict with template icon file.
      if (templateIconFileName != null) {
        final File templateIconFile = globals.fs.file(globals.fs.path.join(
            templateIconImageDirName, templateIconFileName));
        if (templateIconFile.existsSync() && md5.convert(projectIconBytes) ==
            md5.convert(templateIconFile.readAsBytesSync())) {
          filesWithTemplateIcon.add(entry.value);
        }
      }

      // validate image size is correct.
      // PNG file's width is at byte [16, 20), and height is at byte [20, 24), in big endian format.
      // Based on https://en.wikipedia.org/wiki/Portable_Network_Graphics#File_format
      final ByteData projectIconData = projectIconBytes.buffer.asByteData();
      if (projectIconData.lengthInBytes < 24) {
        continue;
      }
      final int width = projectIconData.getInt32(16);
      final int height = projectIconData.getInt32(20);
      if (width != entry.key.pixelSize || height != entry.key.pixelSize) {
        filesWithWrongSize.add(entry.value);
      }
    }

    if (filesWithTemplateIcon.isNotEmpty) {
      messageBuffer.writeln('\nWarning: App icon is set to the default placeholder icon. Replace with unique icons.');
    }
    if (filesWithWrongSize.isNotEmpty) {
      messageBuffer.writeln('\nWarning: App icon is using the wrong size (e.g. ${filesWithWrongSize.first}).');
    }
  }

  Future<void> _validateXcodeBuildSettingsAfterArchive(StringBuffer messageBuffer) async {
    final BuildableIOSApp app = await buildableIOSApp;

    final String plistPath = app.builtInfoPlistPathAfterArchive;

    if (!globals.fs.file(plistPath).existsSync()) {
      globals.printError('Invalid iOS archive. Does not contain Info.plist.');
      return;
    }

    final Map<String, String?> xcodeProjectSettingsMap = <String, String?>{};

    xcodeProjectSettingsMap['Version Number'] = globals.plistParser.getStringValueFromFile(plistPath, PlistParser.kCFBundleShortVersionStringKey);
    xcodeProjectSettingsMap['Build Number'] = globals.plistParser.getStringValueFromFile(plistPath, PlistParser.kCFBundleVersionKey);
    xcodeProjectSettingsMap['Display Name'] = globals.plistParser.getStringValueFromFile(plistPath, PlistParser.kCFBundleDisplayNameKey);
    xcodeProjectSettingsMap['Deployment Target'] = globals.plistParser.getStringValueFromFile(plistPath, PlistParser.kMinimumOSVersionKey);
    xcodeProjectSettingsMap['Bundle Identifier'] = globals.plistParser.getStringValueFromFile(plistPath, PlistParser.kCFBundleIdentifierKey);

    xcodeProjectSettingsMap.forEach((String title, String? info) {
      messageBuffer.writeln('$title: ${info ?? "Missing"}');
    });

    if (xcodeProjectSettingsMap.values.any((String? element) => element == null)) {
      messageBuffer.writeln('\nYou must set up the missing settings.');
    }
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    final BuildInfo buildInfo = await cachedBuildInfo;
    displayNullSafetyMode(buildInfo);
    final FlutterCommandResult xcarchiveResult = await super.runCommand();

    final StringBuffer validationMessageBuffer = StringBuffer();
    await _validateXcodeBuildSettingsAfterArchive(validationMessageBuffer);
    await _validateIconsAfterArchive(validationMessageBuffer);
    validationMessageBuffer.write('\nTo update the settings, please refer to https://docs.flutter.dev/deployment/ios');
    globals.printBox(validationMessageBuffer.toString(), title: 'App Settings');

    // xcarchive failed or not at expected location.
    if (xcarchiveResult.exitStatus != ExitStatus.success) {
      globals.printStatus('Skipping IPA.');
      return xcarchiveResult;
    }

    if (!shouldCodesign) {
      globals.printStatus('Codesigning disabled with --no-codesign, skipping IPA.');
      return xcarchiveResult;
    }

    // Build IPA from generated xcarchive.
    final BuildableIOSApp app = await buildableIOSApp;
    Status? status;
    RunResult? result;
    final String relativeOutputPath = app.ipaOutputPath;
    final String absoluteOutputPath = globals.fs.path.absolute(relativeOutputPath);
    final String absoluteArchivePath = globals.fs.path.absolute(app.archiveBundleOutputPath);
    final String exportMethod = stringArgDeprecated('export-method')!;
    final bool isAppStoreUpload = exportMethod  == 'app-store';
    File? generatedExportPlist;
    try {
      final String exportMethodDisplayName = isAppStoreUpload ? 'App Store' : exportMethod;
      status = globals.logger.startProgress('Building $exportMethodDisplayName IPA...');
      String? exportOptions = exportOptionsPlist;
      if (exportOptions == null) {
        generatedExportPlist = _createExportPlist();
        exportOptions = generatedExportPlist.path;
      }

      result = await globals.processUtils.run(
        <String>[
          ...globals.xcode!.xcrunCommand(),
          'xcodebuild',
          '-exportArchive',
          if (shouldCodesign) ...<String>[
            '-allowProvisioningDeviceRegistration',
            '-allowProvisioningUpdates',
          ],
          '-archivePath',
          absoluteArchivePath,
          '-exportPath',
          absoluteOutputPath,
          '-exportOptionsPlist',
          globals.fs.path.absolute(exportOptions),
        ],
      );
    } finally {
      generatedExportPlist?.deleteSync();
      status?.stop();
    }

    if (result.exitCode != 0) {
      final StringBuffer errorMessage = StringBuffer();

      // "error:" prefixed lines are the nicely formatted error message, the
      // rest is the same message but printed as a IDEFoundationErrorDomain.
      // Example:
      // error: exportArchive: exportOptionsPlist error for key 'method': expected one of {app-store, ad-hoc, enterprise, development, validation}, but found developmentasdasd
      // Error Domain=IDEFoundationErrorDomain Code=1 "exportOptionsPlist error for key 'method': expected one of {app-store, ad-hoc, enterprise, development, validation}, but found developmentasdasd" ...
      LineSplitter.split(result.stderr)
          .where((String line) => line.contains('error: '))
          .forEach(errorMessage.writeln);

      globals.printError('Encountered error while creating the IPA:');
      globals.printError(errorMessage.toString());
      globals.printError('Try distributing the app in Xcode: "open $absoluteArchivePath"');

      // Even though the IPA step didn't succeed, the xcarchive did.
      // Still count this as success since the user has been instructed about how to
      // recover in Xcode.
      return FlutterCommandResult.success();
    }

    globals.printStatus('Built IPA to $absoluteOutputPath.');

    if (isAppStoreUpload) {
      globals.printStatus('To upload to the App Store either:');
      globals.printStatus(
        '1. Drag and drop the "$relativeOutputPath/*.ipa" bundle into the Apple Transporter macOS app https://apps.apple.com/us/app/transporter/id1450874784',
        indent: 4,
      );
      globals.printStatus(
        '2. Run "xcrun altool --upload-app --type ios -f $relativeOutputPath/*.ipa --apiKey your_api_key --apiIssuer your_issuer_id".',
        indent: 4,
      );
      globals.printStatus(
        'See "man altool" for details about how to authenticate with the App Store Connect API key.',
        indent: 7,
      );
    }

    return FlutterCommandResult.success();
  }

  File _createExportPlist() {
    // Create the plist to be passed into xcodebuild -exportOptionsPlist.
    final StringBuffer plistContents = StringBuffer('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>method</key>
        <string>${stringArgDeprecated('export-method')}</string>
        <key>uploadBitcode</key>
        <false/>
    </dict>
</plist>
''');

    final File tempPlist = globals.fs.systemTempDirectory
        .createTempSync('flutter_build_ios.').childFile('ExportOptions.plist');
    tempPlist.writeAsStringSync(plistContents.toString());

    return tempPlist;
  }
}

abstract class _BuildIOSSubCommand extends BuildSubCommand {
  _BuildIOSSubCommand({
    required super.logger,
    required bool verboseHelp
  }) : super(verboseHelp: verboseHelp) {
    addTreeShakeIconsFlag();
    addSplitDebugInfoOption();
    addBuildModeFlags(verboseHelp: verboseHelp);
    usesTargetOption();
    usesFlavorOption();
    usesPubOption();
    usesBuildNumberOption();
    usesBuildNameOption();
    addDartObfuscationOption();
    usesDartDefineOption();
    usesExtraDartFlagOptions(verboseHelp: verboseHelp);
    addEnableExperimentation(hide: !verboseHelp);
    addBuildPerformanceFile(hide: !verboseHelp);
    addBundleSkSLPathOption(hide: !verboseHelp);
    addNullSafetyModeOptions(hide: !verboseHelp);
    usesAnalyzeSizeFlag();
    argParser.addFlag('codesign',
      defaultsTo: true,
      help: 'Codesign the application bundle (only available on device builds).',
    );
  }

  @override
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async => const <DevelopmentArtifact>{
    DevelopmentArtifact.iOS,
  };

  XcodeBuildAction get xcodeBuildAction;

  /// The result of the Xcode build command. Null until it finishes.
  @protected
  XcodeBuildResult? xcodeBuildResult;

  EnvironmentType get environmentType;
  bool get configOnly;

  bool get shouldCodesign => boolArgDeprecated('codesign');

  late final Future<BuildInfo> cachedBuildInfo = getBuildInfo();

  late final Future<BuildableIOSApp> buildableIOSApp = () async {
    final BuildableIOSApp? app = await applicationPackages?.getPackageForPlatform(
      TargetPlatform.ios,
      buildInfo: await cachedBuildInfo,
    ) as BuildableIOSApp?;

    if (app == null) {
      throwToolExit('Application not configured for iOS');
    }
    return app;
  }();

  Directory _outputAppDirectory(String xcodeResultOutput);

  @override
  bool get supported => globals.platform.isMacOS;

  @override
  Future<FlutterCommandResult> runCommand() async {
    defaultBuildMode = environmentType == EnvironmentType.simulator ? BuildMode.debug : BuildMode.release;
    final BuildInfo buildInfo = await cachedBuildInfo;

    if (!supported) {
      throwToolExit('Building for iOS is only supported on macOS.');
    }
    if (environmentType == EnvironmentType.simulator && !buildInfo.supportsSimulator) {
      throwToolExit('${sentenceCase(buildInfo.friendlyModeName)} mode is not supported for simulators.');
    }
    if (configOnly && buildInfo.codeSizeDirectory != null) {
      throwToolExit('Cannot analyze code size without performing a full build.');
    }
    if (environmentType == EnvironmentType.physical && !shouldCodesign) {
      globals.printStatus(
        'Warning: Building for device with codesigning disabled. You will '
        'have to manually codesign before deploying to device.',
      );
    }

    final BuildableIOSApp app = await buildableIOSApp;

    final String logTarget = environmentType == EnvironmentType.simulator ? 'simulator' : 'device';
    final String typeName = globals.artifacts!.getEngineType(TargetPlatform.ios, buildInfo.mode);
    if (xcodeBuildAction == XcodeBuildAction.build) {
      globals.printStatus('Building $app for $logTarget ($typeName)...');
    } else {
      globals.printStatus('Archiving $app...');
    }
    final XcodeBuildResult result = await buildXcodeProject(
      app: app,
      buildInfo: buildInfo,
      targetOverride: targetFile,
      environmentType: environmentType,
      codesign: shouldCodesign,
      configOnly: configOnly,
      buildAction: xcodeBuildAction,
      deviceID: globals.deviceManager?.specifiedDeviceId,
    );
    xcodeBuildResult = result;

    if (!result.success) {
      await diagnoseXcodeBuildFailure(result, globals.flutterUsage, globals.logger);
      final String presentParticiple = xcodeBuildAction == XcodeBuildAction.build ? 'building' : 'archiving';
      throwToolExit('Encountered error while $presentParticiple for $logTarget.');
    }

    if (buildInfo.codeSizeDirectory != null) {
      final SizeAnalyzer sizeAnalyzer = SizeAnalyzer(
        fileSystem: globals.fs,
        logger: globals.logger,
        flutterUsage: globals.flutterUsage,
        appFilenamePattern: 'App'
      );
      // Only support 64bit iOS code size analysis.
      final String arch = getNameForDarwinArch(DarwinArch.arm64);
      final File aotSnapshot = globals.fs.directory(buildInfo.codeSizeDirectory)
        .childFile('snapshot.$arch.json');
      final File precompilerTrace = globals.fs.directory(buildInfo.codeSizeDirectory)
        .childFile('trace.$arch.json');

      final String? resultOutput = result.output;
      if (resultOutput == null) {
        throwToolExit('Could not find app to analyze code size');
      }
      final Directory outputAppDirectoryCandidate = _outputAppDirectory(resultOutput);

      Directory? appDirectory;
      if (outputAppDirectoryCandidate.existsSync()) {
        appDirectory = outputAppDirectoryCandidate.listSync()
            .whereType<Directory>()
            .where((Directory directory) {
          return globals.fs.path.extension(directory.path) == '.app';
        }).first;
      }
      if (appDirectory == null) {
        throwToolExit('Could not find app to analyze code size in ${outputAppDirectoryCandidate.path}');
      }
      final Map<String, Object?> output = await sizeAnalyzer.analyzeAotSnapshot(
        aotSnapshot: aotSnapshot,
        precompilerTrace: precompilerTrace,
        outputDirectory: appDirectory,
        type: 'ios',
      );
      final File outputFile = globals.fsUtils.getUniqueFile(
        globals.fs
          .directory(globals.fsUtils.homeDirPath)
          .childDirectory('.flutter-devtools'), 'ios-code-size-analysis', 'json',
      )..writeAsStringSync(jsonEncode(output));
      // This message is used as a sentinel in analyze_apk_size_test.dart
      globals.printStatus(
        'A summary of your iOS bundle analysis can be found at: ${outputFile.path}',
      );

      // DevTools expects a file path relative to the .flutter-devtools/ dir.
      final String relativeAppSizePath = outputFile.path.split('.flutter-devtools/').last.trim();
      globals.printStatus(
        '\nTo analyze your app size in Dart DevTools, run the following command:\n'
        'flutter pub global activate devtools; flutter pub global run devtools '
        '--appSizeBase=$relativeAppSizePath'
      );
    }

    if (result.output != null) {
      globals.printStatus('Built ${result.output}.');

      return FlutterCommandResult.success();
    }

    return FlutterCommandResult.fail();
  }
}
