// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/format.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/test_flutter_command_runner.dart';

void main() {
  group('format', () {
    late Directory tempDir;
    late BufferLogger logger;

    setUp(() {
      Cache.disableLocking();
      tempDir = globals.fs.systemTempDirectory.createTempSync('flutter_tools_format_test.');
      logger = BufferLogger.test();
    });

    tearDown(() {
      tryToDelete(tempDir);
    });

    testUsingContext('shows deprecation warning', () async {
      final String projectPath = await createProject(tempDir);

      final File srcFile = globals.fs.file(globals.fs.path.join(projectPath, 'lib', 'main.dart'));
      final String original = srcFile.readAsStringSync();
      srcFile.writeAsStringSync(original);

      final FormatCommand command = FormatCommand(verboseHelp: false);
      final CommandRunner<void> runner = createTestCommandRunner(command);
      await runner.run(<String>['format', srcFile.path]);
      expect(
        logger.warningText,
        contains('The "format" command is deprecated and will be removed in a future version of Flutter'),
      );
    }, overrides: <Type, Generator>{
      Logger: () => logger,
    });

    testUsingContext('a file', () async {
      final String projectPath = await createProject(tempDir);

      final File srcFile = globals.fs.file(globals.fs.path.join(projectPath, 'lib', 'main.dart'));
      final String original = srcFile.readAsStringSync();
      srcFile.writeAsStringSync(original.replaceFirst('main()', 'main(  )'));

      final FormatCommand command = FormatCommand(verboseHelp: false);
      final CommandRunner<void> runner = createTestCommandRunner(command);
      await runner.run(<String>['format', srcFile.path]);

      final String formatted = srcFile.readAsStringSync();
      expect(formatted, original);
    }, overrides: <Type, Generator>{
      Logger: () => logger,
    });

    testUsingContext('dry-run', () async {
      final String projectPath = await createProject(tempDir);

      final File srcFile = globals.fs.file(
          globals.fs.path.join(projectPath, 'lib', 'main.dart'));
      final String nonFormatted = srcFile.readAsStringSync().replaceFirst(
          'main()', 'main(  )');
      srcFile.writeAsStringSync(nonFormatted);

      final FormatCommand command = FormatCommand(verboseHelp: false);
      final CommandRunner<void> runner = createTestCommandRunner(command);
      await runner.run(<String>['format', '--dry-run', srcFile.path]);

      final String shouldNotFormatted = srcFile.readAsStringSync();
      expect(shouldNotFormatted, nonFormatted);
    }, overrides: <Type, Generator>{
      Logger: () => logger,
    });

    testUsingContext('dry-run with -n', () async {
      final String projectPath = await createProject(tempDir);

      final File srcFile = globals.fs.file(
          globals.fs.path.join(projectPath, 'lib', 'main.dart'));
      final String nonFormatted = srcFile.readAsStringSync().replaceFirst(
          'main()', 'main(  )');
      srcFile.writeAsStringSync(nonFormatted);

      final FormatCommand command = FormatCommand(verboseHelp: false);
      final CommandRunner<void> runner = createTestCommandRunner(command);
      await runner.run(<String>['format', '-n', srcFile.path]);

      final String shouldNotFormatted = srcFile.readAsStringSync();
      expect(shouldNotFormatted, nonFormatted);
    });

    testUsingContext('dry-run with set-exit-if-changed', () async {
      final String projectPath = await createProject(tempDir);

      final File srcFile = globals.fs.file(
          globals.fs.path.join(projectPath, 'lib', 'main.dart'));
      final String nonFormatted = srcFile.readAsStringSync().replaceFirst(
          'main()', 'main(  )');
      srcFile.writeAsStringSync(nonFormatted);

      final FormatCommand command = FormatCommand(verboseHelp: false);
      final CommandRunner<void> runner = createTestCommandRunner(command);

      expect(runner.run(<String>[
        'format', '--dry-run', '--set-exit-if-changed', srcFile.path,
      ]), throwsException);

      final String shouldNotFormatted = srcFile.readAsStringSync();
      expect(shouldNotFormatted, nonFormatted);
    });

    testUsingContext('line-length', () async {
      const int lineLengthShort = 50;
      const int lineLengthLong = 120;
      final String projectPath = await createProject(tempDir);

      final File srcFile = globals.fs.file(
          globals.fs.path.join(projectPath, 'lib', 'main.dart'));
      final String nonFormatted = srcFile.readAsStringSync();
      srcFile.writeAsStringSync(
          nonFormatted.replaceFirst('main()',
              'main(anArgument1, anArgument2, anArgument3, anArgument4, anArgument5)'));

      final String nonFormattedWithLongLine = srcFile.readAsStringSync();
      final FormatCommand command = FormatCommand(verboseHelp: false);
      final CommandRunner<void> runner = createTestCommandRunner(command);

      await runner.run(<String>['format', '--line-length', '$lineLengthLong', srcFile.path]);
      final String notFormatted = srcFile.readAsStringSync();
      expect(nonFormattedWithLongLine, notFormatted);

      await runner.run(<String>['format', '--line-length', '$lineLengthShort', srcFile.path]);
      final String shouldFormatted = srcFile.readAsStringSync();
      expect(nonFormattedWithLongLine, isNot(shouldFormatted));
    });
  });
}
