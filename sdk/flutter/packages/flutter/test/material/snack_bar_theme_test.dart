// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SnackBarThemeData copyWith, ==, hashCode basics', () {
    expect(const SnackBarThemeData(), const SnackBarThemeData().copyWith());
    expect(const SnackBarThemeData().hashCode, const SnackBarThemeData().copyWith().hashCode);
  });

  test('SnackBarThemeData null fields by default', () {
    const SnackBarThemeData snackBarTheme = SnackBarThemeData();
    expect(snackBarTheme.backgroundColor, null);
    expect(snackBarTheme.actionTextColor, null);
    expect(snackBarTheme.disabledActionTextColor, null);
    expect(snackBarTheme.contentTextStyle, null);
    expect(snackBarTheme.elevation, null);
    expect(snackBarTheme.shape, null);
    expect(snackBarTheme.behavior, null);
    expect(snackBarTheme.width, null);
    expect(snackBarTheme.insetPadding, null);
    expect(snackBarTheme.showCloseIcon, null);
    expect(snackBarTheme.closeIconColor, null);
  });

  test(
      'SnackBarTheme throws assertion if width is provided with fixed behaviour',
      () {
    expect(
        () => SnackBarThemeData(
              behavior: SnackBarBehavior.fixed,
              width: 300.0,
            ),
        throwsAssertionError);
  });

  testWidgets('Default SnackBarThemeData debugFillProperties',
      (WidgetTester tester) async {
    final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();
    const SnackBarThemeData().debugFillProperties(builder);

    final List<String> description = builder.properties
        .where((DiagnosticsNode node) => !node.isFiltered(DiagnosticLevel.info))
        .map((DiagnosticsNode node) => node.toString())
        .toList();

    expect(description, <String>[]);
  });

  testWidgets('SnackBarThemeData implements debugFillProperties', (WidgetTester tester) async {
    final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();
    const SnackBarThemeData(
      backgroundColor: Color(0xFFFFFFFF),
      actionTextColor: Color(0xFF0000AA),
      disabledActionTextColor: Color(0xFF00AA00),
      contentTextStyle: TextStyle(color: Color(0xFF123456)),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2.0))),
      behavior: SnackBarBehavior.floating,
      width: 400.0,
      insetPadding: EdgeInsets.all(10.0),
      showCloseIcon: false,
      closeIconColor: Color(0xFF0000AA),
    ).debugFillProperties(builder);

    final List<String> description = builder.properties
        .where((DiagnosticsNode node) => !node.isFiltered(DiagnosticLevel.info))
        .map((DiagnosticsNode node) => node.toString())
        .toList();

    expect(description, <String>[
      'backgroundColor: Color(0xffffffff)',
      'actionTextColor: Color(0xff0000aa)',
      'disabledActionTextColor: Color(0xff00aa00)',
      'contentTextStyle: TextStyle(inherit: true, color: Color(0xff123456))',
      'elevation: 2.0',
      'shape: RoundedRectangleBorder(BorderSide(width: 0.0, style: none), BorderRadius.circular(2.0))',
      'behavior: SnackBarBehavior.floating',
      'width: 400.0',
      'insetPadding: EdgeInsets.all(10.0)',
      'showCloseIcon: false',
      'closeIconColor: Color(0xff0000aa)',
    ]);
  });

  testWidgets('Passing no SnackBarThemeData returns defaults', (WidgetTester tester) async {
    const String text = 'I am a snack bar.';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text(text),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(label: 'ACTION', onPressed: () {}),
                ));
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));

    final Material material = _getSnackBarMaterial(tester);
    final RenderParagraph content = _getSnackBarTextRenderObject(tester, text);

    expect(content.text.style, Typography.material2018().white.titleMedium);
    expect(material.color, const Color(0xFF333333));
    expect(material.elevation, 6.0);
    expect(material.shape, null);
  });

  testWidgets('SnackBar uses values from SnackBarThemeData', (WidgetTester tester) async {
    const String text = 'I am a snack bar.';
    const String action = 'ACTION';
    final SnackBarThemeData snackBarTheme = _snackBarTheme(showCloseIcon: true);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(snackBarTheme: snackBarTheme),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text(text),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(label: action, onPressed: () {}),
                ));
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));

    final Material material = _getSnackBarMaterial(tester);
    final RenderParagraph button = _getSnackBarActionTextRenderObject(tester, action);
    final RenderParagraph content = _getSnackBarTextRenderObject(tester, text);
    final Icon icon = _getSnackBarIcon(tester);

    expect(content.text.style, snackBarTheme.contentTextStyle);
    expect(material.color, snackBarTheme.backgroundColor);
    expect(material.elevation, snackBarTheme.elevation);
    expect(material.shape, snackBarTheme.shape);
    expect(button.text.style!.color, snackBarTheme.actionTextColor);
    expect(icon.icon, Icons.close);
  });

  testWidgets('SnackBar widget properties take priority over theme', (WidgetTester tester) async {
    const Color backgroundColor = Colors.purple;
    const Color textColor = Colors.pink;
    const double elevation = 7.0;
    const String action = 'ACTION';
    const ShapeBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(9.0)),
    );
    const double snackBarWidth = 400.0;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(snackBarTheme: _snackBarTheme(showCloseIcon: true)),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: backgroundColor,
                  behavior: SnackBarBehavior.floating,
                  width: snackBarWidth,
                  elevation: elevation,
                  shape: shape,
                  content: const Text('I am a snack bar.'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(
                    textColor: textColor,
                    label: action,
                    onPressed: () {},
                  ),
                  showCloseIcon: false,
                ));
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));

    final Finder materialFinder = _getSnackBarMaterialFinder(tester);
    final Material material = _getSnackBarMaterial(tester);
    final RenderParagraph button =
        _getSnackBarActionTextRenderObject(tester, action);

    expect(material.color, backgroundColor);
    expect(material.elevation, elevation);
    expect(material.shape, shape);
    expect(button.text.style!.color, textColor);
    expect(_getSnackBarIconFinder(tester), findsNothing);
    // Assert width.
    final Offset snackBarBottomLeft = tester.getBottomLeft(materialFinder.first);
    final Offset snackBarBottomRight = tester.getBottomRight(materialFinder.first);
    expect(snackBarBottomLeft.dx, (800 - snackBarWidth) / 2); // Device width is 800.
    expect(snackBarBottomRight.dx, (800 + snackBarWidth) / 2); // Device width is 800.
  });

  testWidgets('SnackBar theme behavior is correct for floating', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating)),
      home: Scaffold(
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.send),
          onPressed: () {},
        ),
        body: Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('I am a snack bar.'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(label: 'ACTION', onPressed: () {}),
                ));
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));

    final RenderBox snackBarBox = tester.firstRenderObject(find.byType(SnackBar));
    final RenderBox floatingActionButtonBox = tester.firstRenderObject(find.byType(FloatingActionButton));

    final Offset snackBarBottomCenter = snackBarBox.localToGlobal(snackBarBox.size.bottomCenter(Offset.zero));
    final Offset floatingActionButtonTopCenter = floatingActionButtonBox.localToGlobal(floatingActionButtonBox.size.topCenter(Offset.zero));

    // Since padding and margin is handled inside snackBarBox,
    // the bottom offset of snackbar should equal with top offset of FAB
    expect(snackBarBottomCenter.dy == floatingActionButtonTopCenter.dy, true);
  });

  testWidgets('SnackBar theme behavior is correct for fixed', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.fixed),
      ),
      home: Scaffold(
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.send),
          onPressed: () {},
        ),
        body: Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('I am a snack bar.'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(label: 'ACTION', onPressed: () {}),
                ));
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    ));

    final RenderBox floatingActionButtonOriginBox= tester.firstRenderObject(find.byType(FloatingActionButton));
    final Offset floatingActionButtonOriginBottomCenter = floatingActionButtonOriginBox.localToGlobal(floatingActionButtonOriginBox.size.bottomCenter(Offset.zero));

    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));

    final RenderBox snackBarBox = tester.firstRenderObject(find.byType(SnackBar));
    final RenderBox floatingActionButtonBox = tester.firstRenderObject(find.byType(FloatingActionButton));

    final Offset snackBarTopCenter = snackBarBox.localToGlobal(snackBarBox.size.topCenter(Offset.zero));
    final Offset floatingActionButtonBottomCenter = floatingActionButtonBox.localToGlobal(floatingActionButtonBox.size.bottomCenter(Offset.zero));

    expect(floatingActionButtonOriginBottomCenter.dy > floatingActionButtonBottomCenter.dy, true);
    expect(snackBarTopCenter.dy > floatingActionButtonBottomCenter.dy, true);
  });

  Widget buildApp({
    required SnackBarBehavior themedBehavior,
    EdgeInsetsGeometry? margin,
    double? width,
  }) {
    return MaterialApp(
      theme: ThemeData(
        snackBarTheme: SnackBarThemeData(behavior: themedBehavior),
      ),
      home: Scaffold(
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.send),
          onPressed: () {},
        ),
        body: Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  margin: margin,
                  width: width,
                  content: const Text('I am a snack bar.'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(label: 'ACTION', onPressed: () {}),
                ));
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    );
  }

  testWidgets('SnackBar theme behavior will assert properly for margin use', (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/84935
    // SnackBarBehavior.floating set in theme does not assert with margin
    await tester.pumpWidget(buildApp(
      themedBehavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(8.0),
    ));
    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));
    AssertionError? exception = tester.takeException() as AssertionError?;
    expect(exception, isNull);

    // SnackBarBehavior.fixed set in theme will still assert with margin
    await tester.pumpWidget(buildApp(
      themedBehavior: SnackBarBehavior.fixed,
      margin: const EdgeInsets.all(8.0),
    ));
    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));
    exception = tester.takeException() as AssertionError;
    expect(
      exception.message,
      'Margin can only be used with floating behavior. SnackBarBehavior.fixed '
          'was set by the inherited SnackBarThemeData.',
    );
  });

  testWidgets('SnackBar theme behavior will assert properly for width use', (WidgetTester tester) async {
    // SnackBarBehavior.floating set in theme does not assert with width
    await tester.pumpWidget(buildApp(
      themedBehavior: SnackBarBehavior.floating,
      width: 5.0,
    ));
    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));
    AssertionError? exception = tester.takeException() as AssertionError?;
    expect(exception, isNull);

    // SnackBarBehavior.fixed set in theme will still assert with width
    await tester.pumpWidget(buildApp(
      themedBehavior: SnackBarBehavior.fixed,
      width: 5.0,
    ));
    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));
    exception = tester.takeException() as AssertionError;
    expect(
      exception.message,
      'Width can only be used with floating behavior. SnackBarBehavior.fixed '
      'was set by the inherited SnackBarThemeData.',
    );
  });
}

SnackBarThemeData _snackBarTheme({bool? showCloseIcon}) {
  return SnackBarThemeData(
    backgroundColor: Colors.orange,
    actionTextColor: Colors.green,
    contentTextStyle: const TextStyle(color: Colors.blue),
    elevation: 12.0,
    showCloseIcon: showCloseIcon,
    shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  );
}

Material _getSnackBarMaterial(WidgetTester tester) {
  return tester.widget<Material>(
    _getSnackBarMaterialFinder(tester).first,
  );
}

Finder _getSnackBarMaterialFinder(WidgetTester tester) {
  return find.descendant(
    of: find.byType(SnackBar),
    matching: find.byType(Material),
  );
}

RenderParagraph _getSnackBarActionTextRenderObject(WidgetTester tester, String text) {
  return tester.renderObject(find.descendant(
    of: find.byType(TextButton),
    matching: find.text(text),
  ));
}

Icon _getSnackBarIcon(WidgetTester tester) {
  return tester.widget<Icon>(_getSnackBarIconFinder(tester));
}

Finder _getSnackBarIconFinder(WidgetTester tester) {
  return find.descendant(
    of: find.byType(SnackBar),
    matching: find.byIcon(Icons.close),
  );
}

RenderParagraph _getSnackBarTextRenderObject(WidgetTester tester, String text) {
  return tester.renderObject(find.descendant(
    of: find.byType(SnackBar),
    matching: find.text(text),
  ));
}
