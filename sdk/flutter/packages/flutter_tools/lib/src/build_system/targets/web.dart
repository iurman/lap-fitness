// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:package_config/package_config.dart';

import '../../artifacts.dart';
import '../../base/file_system.dart';
import '../../base/io.dart';
import '../../build_info.dart';
import '../../cache.dart';
import '../../convert.dart';
import '../../dart/language_version.dart';
import '../../dart/package_map.dart';
import '../../flutter_plugins.dart';
import '../../globals.dart' as globals;
import '../../project.dart';
import '../../web/file_generators/flutter_js.dart' as flutter_js;
import '../../web/file_generators/flutter_service_worker_js.dart';
import '../../web/file_generators/main_dart.dart' as main_dart;
import '../build_system.dart';
import '../depfile.dart';
import '../exceptions.dart';
import 'assets.dart';
import 'localizations.dart';
import 'shader_compiler.dart';

/// Whether the application has web plugins.
const String kHasWebPlugins = 'HasWebPlugins';

/// An override for the dart2js build mode.
///
/// Valid values are O1 (lowest, profile default) to O4 (highest, release default).
const String kDart2jsOptimization = 'Dart2jsOptimization';

/// If `--dump-info` should be passed to dart2js.
const String kDart2jsDumpInfo = 'Dart2jsDumpInfo';

// If `--no-frequency-based-minification` should be based to dart2js
const String kDart2jsNoFrequencyBasedMinification = 'Dart2jsNoFrequencyBasedMinification';

/// Whether to disable dynamic generation code to satisfy csp policies.
const String kCspMode = 'cspMode';

/// Base href to set in index.html in flutter build command
const String kBaseHref = 'baseHref';

/// Placeholder for base href
const String kBaseHrefPlaceholder = r'$FLUTTER_BASE_HREF';

/// The caching strategy to use for service worker generation.
const String kServiceWorkerStrategy = 'ServiceWorkerStrategy';

/// Whether the dart2js build should output source maps.
const String kSourceMapsEnabled = 'SourceMaps';

/// Whether the dart2js native null assertions are enabled.
const String kNativeNullAssertions = 'NativeNullAssertions';

const String kOfflineFirst = 'offline-first';
const String kNoneWorker = 'none';

/// Convert a [value] into a [ServiceWorkerStrategy].
ServiceWorkerStrategy _serviceWorkerStrategyFromString(String? value) {
  switch (value) {
    case kNoneWorker:
      return ServiceWorkerStrategy.none;
    // offline-first is the default value for any invalid requests.
    default:
      return ServiceWorkerStrategy.offlineFirst;
  }
}

/// Generates an entry point for a web target.
// Keep this in sync with build_runner/resident_web_runner.dart
class WebEntrypointTarget extends Target {
  const WebEntrypointTarget();

  @override
  String get name => 'web_entrypoint';

  @override
  List<Target> get dependencies => const <Target>[];

  @override
  List<Source> get inputs => const <Source>[
    Source.pattern('{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/web.dart'),
  ];

  @override
  List<Source> get outputs => const <Source>[
    Source.pattern('{BUILD_DIR}/main.dart'),
  ];

  @override
  Future<void> build(Environment environment) async {
    final String? targetFile = environment.defines[kTargetFile];
    final Uri importUri = environment.fileSystem.file(targetFile).absolute.uri;
    // TODO(zanderso): support configuration of this file.
    const String packageFile = '.packages';
    final PackageConfig packageConfig = await loadPackageConfigWithLogging(
      environment.fileSystem.file(packageFile),
      logger: environment.logger,
    );
    final FlutterProject flutterProject = FlutterProject.current();
    final LanguageVersion languageVersion = determineLanguageVersion(
      environment.fileSystem.file(targetFile),
      packageConfig[flutterProject.manifest.appName],
      Cache.flutterRoot!,
    );

    // Use the PackageConfig to find the correct package-scheme import path
    // for the user application. If the application has a mix of package-scheme
    // and relative imports for a library, then importing the entrypoint as a
    // file-scheme will cause said library to be recognized as two distinct
    // libraries. This can cause surprising behavior as types from that library
    // will be considered distinct from each other.
    // By construction, this will only be null if the .packages file does not
    // have an entry for the user's application or if the main file is
    // outside of the lib/ directory.
    final String importedEntrypoint = packageConfig.toPackageUri(importUri)?.toString()
      ?? importUri.toString();

    await injectBuildTimePluginFiles(flutterProject, webPlatform: true, destination: environment.buildDir);
    // The below works because `injectBuildTimePluginFiles` is configured to write
    // the web_plugin_registrant.dart file alongside the generated main.dart
    const String generatedImport = 'web_plugin_registrant.dart';

    final String contents = main_dart.generateMainDartFile(importedEntrypoint,
      languageVersion: languageVersion,
      pluginRegistrantEntrypoint: generatedImport,
    );

    environment.buildDir.childFile('main.dart')
      .writeAsStringSync(contents);
  }
}

/// Compiles a web entry point with dart2js.
class Dart2JSTarget extends Target {
  const Dart2JSTarget();

  @override
  String get name => 'dart2js';

  @override
  List<Target> get dependencies => const <Target>[
    WebEntrypointTarget(),
    GenerateLocalizationsTarget(),
  ];

  @override
  List<Source> get inputs => const <Source>[
    Source.hostArtifact(HostArtifact.flutterWebSdk),
    Source.hostArtifact(HostArtifact.dart2jsSnapshot),
    Source.hostArtifact(HostArtifact.engineDartBinary),
    Source.pattern('{BUILD_DIR}/main.dart'),
    Source.pattern('{PROJECT_DIR}/.dart_tool/package_config_subset'),
  ];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  List<String> get depfiles => const <String>[
    'dart2js.d',
  ];

  String _collectOutput(ProcessResult result) {
    final String stdout = result.stdout is List<int>
        ? utf8.decode(result.stdout as List<int>)
        : result.stdout as String;
    final String stderr = result.stderr is List<int>
        ? utf8.decode(result.stderr as List<int>)
        : result.stderr as String;
    return stdout + stderr;
  }

  @override
  Future<void> build(Environment environment) async {
    final String? buildModeEnvironment = environment.defines[kBuildMode];
    if (buildModeEnvironment == null) {
      throw MissingDefineException(kBuildMode, name);
    }
    final BuildMode buildMode = getBuildModeForName(buildModeEnvironment);
    final bool sourceMapsEnabled = environment.defines[kSourceMapsEnabled] == 'true';
    final bool nativeNullAssertions = environment.defines[kNativeNullAssertions] == 'true';
    final Artifacts artifacts = globals.artifacts!;
    final String librariesSpec = (artifacts.getHostArtifact(HostArtifact.flutterWebSdk) as Directory).childFile('libraries.json').path;
    final List<String> sharedCommandOptions = <String>[
      artifacts.getHostArtifact(HostArtifact.engineDartBinary).path,
      '--disable-dart-dev',
      artifacts.getHostArtifact(HostArtifact.dart2jsSnapshot).path,
      '--libraries-spec=$librariesSpec',
      ...decodeCommaSeparated(environment.defines, kExtraFrontEndOptions),
      if (nativeNullAssertions)
        '--native-null-assertions',
      if (buildMode == BuildMode.profile)
        '-Ddart.vm.profile=true'
      else
        '-Ddart.vm.product=true',
      for (final String dartDefine in decodeDartDefines(environment.defines, kDartDefines))
        '-D$dartDefine',
      if (!sourceMapsEnabled)
        '--no-source-maps',
    ];

    final List<String> compilationArgs = <String>[
      ...sharedCommandOptions,
      '-o',
      environment.buildDir.childFile('app.dill').path,
      '--packages=.dart_tool/package_config.json',
      '--cfe-only',
      environment.buildDir.childFile('main.dart').path, // dartfile
    ];
    globals.printTrace('compiling dart code to kernel with command "${compilationArgs.join(' ')}"');

    // Run the dart2js compilation in two stages, so that icon tree shaking can
    // parse the kernel file for web builds.
    final ProcessResult kernelResult = await globals.processManager.run(compilationArgs);
    if (kernelResult.exitCode != 0) {
      throw Exception(_collectOutput(kernelResult));
    }

    final String? dart2jsOptimization = environment.defines[kDart2jsOptimization];
    final bool dumpInfo = environment.defines[kDart2jsDumpInfo] == 'true';
    final bool noFrequencyBasedMinification = environment.defines[kDart2jsNoFrequencyBasedMinification] == 'true';
    final File outputJSFile = environment.buildDir.childFile('main.dart.js');
    final bool csp = environment.defines[kCspMode] == 'true';

    final ProcessResult javaScriptResult = await environment.processManager.run(<String>[
      ...sharedCommandOptions,
      if (dart2jsOptimization != null) '-$dart2jsOptimization' else '-O4',
      if (buildMode == BuildMode.profile) '--no-minify',
      if (dumpInfo) '--dump-info',
      if (noFrequencyBasedMinification) '--no-frequency-based-minification',
      if (csp) '--csp',
      '-o',
      outputJSFile.path,
      environment.buildDir.childFile('app.dill').path, // dartfile
    ]);
    if (javaScriptResult.exitCode != 0) {
      throw Exception(_collectOutput(javaScriptResult));
    }
    final File dart2jsDeps = environment.buildDir
      .childFile('app.dill.deps');
    if (!dart2jsDeps.existsSync()) {
      globals.printWarning('Warning: dart2js did not produced expected deps list at '
        '${dart2jsDeps.path}');
      return;
    }
    final DepfileService depfileService = DepfileService(
      fileSystem: globals.fs,
      logger: globals.logger,
    );
    final Depfile depfile = depfileService.parseDart2js(
      environment.buildDir.childFile('app.dill.deps'),
      outputJSFile,
    );
    depfileService.writeToFile(
      depfile,
      environment.buildDir.childFile('dart2js.d'),
    );
  }
}

/// Unpacks the dart2js compilation and resources to a given output directory.
class WebReleaseBundle extends Target {
  const WebReleaseBundle();

  @override
  String get name => 'web_release_bundle';

  @override
  List<Target> get dependencies => const <Target>[
    Dart2JSTarget(),
  ];

  @override
  List<Source> get inputs => const <Source>[
    Source.pattern('{BUILD_DIR}/main.dart.js'),
    Source.pattern('{PROJECT_DIR}/pubspec.yaml'),
  ];

  @override
  List<Source> get outputs => const <Source>[
    Source.pattern('{OUTPUT_DIR}/main.dart.js'),
  ];

  @override
  List<String> get depfiles => const <String>[
    'dart2js.d',
    'flutter_assets.d',
    'web_resources.d',
  ];

  @override
  Future<void> build(Environment environment) async {
    for (final File outputFile in environment.buildDir.listSync(recursive: true).whereType<File>()) {
      final String basename = globals.fs.path.basename(outputFile.path);
      if (!basename.contains('main.dart.js')) {
        continue;
      }
      // Do not copy the deps file.
      if (basename.endsWith('.deps')) {
        continue;
      }
      outputFile.copySync(
        environment.outputDir.childFile(globals.fs.path.basename(outputFile.path)).path
      );
    }

    createVersionFile(environment, environment.defines);
    final Directory outputDirectory = environment.outputDir.childDirectory('assets');
    outputDirectory.createSync(recursive: true);
    final Depfile depfile = await copyAssets(
      environment,
      environment.outputDir.childDirectory('assets'),
      targetPlatform: TargetPlatform.web_javascript,
      shaderTarget: ShaderTarget.sksl,
    );
    final DepfileService depfileService = DepfileService(
      fileSystem: globals.fs,
      logger: globals.logger,
    );
    depfileService.writeToFile(
      depfile,
      environment.buildDir.childFile('flutter_assets.d'),
    );

    final Directory webResources = environment.projectDir
      .childDirectory('web');
    final List<File> inputResourceFiles = webResources
      .listSync(recursive: true)
      .whereType<File>()
      .toList();

    // Copy other resource files out of web/ directory.
    final List<File> outputResourcesFiles = <File>[];
    for (final File inputFile in inputResourceFiles) {
      final File outputFile = globals.fs.file(globals.fs.path.join(
        environment.outputDir.path,
        globals.fs.path.relative(inputFile.path, from: webResources.path)));
      if (!outputFile.parent.existsSync()) {
        outputFile.parent.createSync(recursive: true);
      }
      outputResourcesFiles.add(outputFile);
      // insert a random hash into the requests for service_worker.js. This is not a content hash,
      // because it would need to be the hash for the entire bundle and not just the resource
      // in question.
      if (environment.fileSystem.path.basename(inputFile.path) == 'index.html') {
        final String randomHash = Random().nextInt(4294967296).toString();
        String resultString = inputFile.readAsStringSync()
          .replaceFirst(
            'var serviceWorkerVersion = null',
            "var serviceWorkerVersion = '$randomHash'",
          )
          // This is for legacy index.html that still use the old service
          // worker loading mechanism.
          .replaceFirst(
            "navigator.serviceWorker.register('flutter_service_worker.js')",
            "navigator.serviceWorker.register('flutter_service_worker.js?v=$randomHash')",
          );
        final String? baseHref = environment.defines[kBaseHref];
        if (resultString.contains(kBaseHrefPlaceholder) && baseHref == null) {
          resultString = resultString.replaceAll(kBaseHrefPlaceholder, '/');
        } else if (resultString.contains(kBaseHrefPlaceholder) && baseHref != null) {
          resultString = resultString.replaceAll(kBaseHrefPlaceholder, baseHref);
        }
        outputFile.writeAsStringSync(resultString);
        continue;
      }
      inputFile.copySync(outputFile.path);
    }
    final Depfile resourceFile = Depfile(inputResourceFiles, outputResourcesFiles);
    depfileService.writeToFile(
      resourceFile,
      environment.buildDir.childFile('web_resources.d'),
    );
  }

  /// Create version.json file that contains data about version for package_info
  void createVersionFile(Environment environment, Map<String, String> defines) {
    final Map<String, dynamic> versionInfo =
        jsonDecode(FlutterProject.current().getVersionInfo())
            as Map<String, dynamic>;

    if (defines.containsKey(kBuildNumber)) {
      versionInfo['build_number'] = defines[kBuildNumber];
    }

    if (defines.containsKey(kBuildName)) {
      versionInfo['version'] = defines[kBuildName];
    }

    environment.outputDir
        .childFile('version.json')
        .writeAsStringSync(jsonEncode(versionInfo));
  }
}

/// Static assets provided by the Flutter SDK that do not change, such as
/// CanvasKit.
///
/// These assets can be cached forever and are only invalidated when the
/// Flutter SDK is upgraded to a new version.
class WebBuiltInAssets extends Target {
  const WebBuiltInAssets(this.fileSystem, this.cache);

  final FileSystem fileSystem;
  final Cache cache;

  @override
  String get name => 'web_static_assets';

  @override
  List<Target> get dependencies => const <Target>[];

  @override
  List<String> get depfiles => const <String>[];

  @override
  List<Source> get inputs => const <Source>[];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  Future<void> build(Environment environment) async {
    // TODO(yjbanov): https://github.com/flutter/flutter/issues/52588
    //
    // Update this when we start building CanvasKit from sources. In the
    // meantime, get the Web SDK directory from cache rather than through
    // Artifacts. The latter is sensitive to `--local-engine`, which changes
    // the directory to point to ENGINE/src/out. However, CanvasKit is not yet
    // built as part of the engine, but fetched from CIPD, and so it won't be
    // found in ENGINE/src/out.
    final Directory flutterWebSdk = cache.getWebSdkDirectory();
    final Directory canvasKitDirectory = flutterWebSdk.childDirectory('canvaskit');
    for (final File file in canvasKitDirectory.listSync(recursive: true).whereType<File>()) {
      final String relativePath = fileSystem.path.relative(file.path, from: canvasKitDirectory.path);
      final String targetPath = fileSystem.path.join(environment.outputDir.path, 'canvaskit', relativePath);
      file.copySync(targetPath);
    }

    // Write the flutter.js file
    final File flutterJsFile = environment.outputDir.childFile('flutter.js');
    flutterJsFile.writeAsStringSync(flutter_js.generateFlutterJsFile());
  }
}

/// Generate a service worker for a web target.
class WebServiceWorker extends Target {
  const WebServiceWorker(this.fileSystem, this.cache);

  final FileSystem fileSystem;
  final Cache cache;

  @override
  String get name => 'web_service_worker';

  @override
  List<Target> get dependencies => <Target>[
    const Dart2JSTarget(),
    const WebReleaseBundle(),
    WebBuiltInAssets(fileSystem, cache),
  ];

  @override
  List<String> get depfiles => const <String>[
    'service_worker.d',
  ];

  @override
  List<Source> get inputs => const <Source>[];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  Future<void> build(Environment environment) async {
    final List<File> contents = environment.outputDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => !file.path.endsWith('flutter_service_worker.js')
        && !globals.fs.path.basename(file.path).startsWith('.'))
      .toList();

    final Map<String, String> urlToHash = <String, String>{};
    for (final File file in contents) {
      // Do not force caching of source maps.
      if (file.path.endsWith('main.dart.js.map') ||
        file.path.endsWith('.part.js.map')) {
        continue;
      }
      final String url = globals.fs.path.toUri(
        globals.fs.path.relative(
          file.path,
          from: environment.outputDir.path),
        ).toString();
      final String hash = md5.convert(await file.readAsBytes()).toString();
      urlToHash[url] = hash;
      // Add an additional entry for the base URL.
      if (globals.fs.path.basename(url) == 'index.html') {
        urlToHash['/'] = hash;
      }
    }

    final File serviceWorkerFile = environment.outputDir
      .childFile('flutter_service_worker.js');
    final Depfile depfile = Depfile(contents, <File>[serviceWorkerFile]);
    final ServiceWorkerStrategy serviceWorkerStrategy = _serviceWorkerStrategyFromString(
      environment.defines[kServiceWorkerStrategy],
    );
    final String serviceWorker = generateServiceWorker(
      urlToHash,
      <String>[
        'main.dart.js',
        'index.html',
        if (urlToHash.containsKey('assets/AssetManifest.json'))
          'assets/AssetManifest.json',
        if (urlToHash.containsKey('assets/FontManifest.json'))
          'assets/FontManifest.json',
      ],
      serviceWorkerStrategy: serviceWorkerStrategy,
    );
    serviceWorkerFile
      .writeAsStringSync(serviceWorker);
    final DepfileService depfileService = DepfileService(
      fileSystem: globals.fs,
      logger: globals.logger,
    );
    depfileService.writeToFile(
      depfile,
      environment.buildDir.childFile('service_worker.d'),
    );
  }
}
