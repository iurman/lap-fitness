// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_e2e_tests/common.dart';
import 'package:web_e2e_tests/image_loading_main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Image loads asset variant based on device pixel ratio',
          (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // `pumpAndSettle` only waits until no more frames are scheduled, but the
    // test must wait for the image network requests to finish.
    await app.whenAssetImageLoads;
    await app.whenNetworkImageLoads;

    // At the time the network requests are finished the engine may not have
    // updated the DOM yet. Delay checking the DOM until the next event, which
    // will guarantee that the current frame is done rendering.
    await Future<void>.delayed(Duration.zero);

    final List<html.ImageElement> imageElements = findElements('img').cast<html.ImageElement>();
    expect(imageElements.length, 2);
    expect(imageElements[0].naturalWidth, 1.5 * 64);
    expect(imageElements[0].naturalHeight, 1.5 * 64);
    expect(imageElements[0].width, 64);
    expect(imageElements[0].height, 64);
    expect(imageElements[1].width, isNot(0));
  });
}
