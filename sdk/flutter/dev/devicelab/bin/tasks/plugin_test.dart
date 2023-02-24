// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/plugin_tests.dart';

Future<void> main() async {
  await task(combine(<TaskFunction>[
    PluginTest('apk', <String>['-a', 'java', '--platforms=android']),
    PluginTest('apk', <String>['-a', 'kotlin', '--platforms=android']),
    // These create the plugins using the new v2 plugin templates but create the
    // apps using the old v1 embedding app templates to make sure new plugins
    // are by default backward compatible.
    PluginTest('apk', <String>['-a', 'java', '--platforms=android'], pluginCreateEnvironment:
        <String, String>{'ENABLE_ANDROID_EMBEDDING_V2': 'true'}),
    PluginTest('apk', <String>['-a', 'kotlin', '--platforms=android'], pluginCreateEnvironment:
        <String, String>{'ENABLE_ANDROID_EMBEDDING_V2': 'true'}),
    // Test that Dart-only plugins are supported.
    PluginTest('apk', <String>['--platforms=android'], dartOnlyPlugin: true),
    // Test that FFI plugins are supported.
    PluginTest('apk', <String>['--platforms=android'], template: 'plugin_ffi'),
  ]));
}
