import 'dart:developer' as developer;

import 'package:logging/logging.dart';

/// App-wide logger. Use instead of `print` so output is levelled and can be
/// routed to a crash reporter later.
final Logger appLogger = Logger('lap_fitness');

/// Wire the logging framework into the platform log. Call once at startup.
void initLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}
