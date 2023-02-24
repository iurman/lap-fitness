// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// no-shuffle:
//   //TODO(gspencergoog): Remove this tag once this test's state leaks/test
//   dependencies have been fixed.
//   https://github.com/flutter/flutter/issues/85160
//   Fails with "flutter test --test-randomize-ordering-seed=456"
// reduced-test-set:
//   This file is run as part of a reduced test set in CI on Mac and Windows
//   machines.
@Tags(<String>['reduced-test-set', 'no-shuffle'])

import 'dart:ui' as ui show BoxHeightStyle, BoxWidthStyle, Color;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior, PointerDeviceKind, kDoubleTapTimeout, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../rendering/mock_canvas.dart';
import '../widgets/clipboard_utils.dart';
import '../widgets/editable_text_utils.dart' show OverflowWidgetTextEditingController;
import '../widgets/semantics_tester.dart';

// On web, the context menu (aka toolbar) is provided by the browser.
const bool isContextMenuProvidedByPlatform = isBrowser;

class MockTextSelectionControls extends TextSelectionControls {
  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    throw UnimplementedError();
  }

  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset position,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ClipboardStatusNotifier? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    throw UnimplementedError();
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    throw UnimplementedError();
  }

  @override
  Size getHandleSize(double textLineHeight) {
    throw UnimplementedError();
  }
}

class PathBoundsMatcher extends Matcher {
  const PathBoundsMatcher({
    this.rectMatcher,
    this.topMatcher,
    this.leftMatcher,
    this.rightMatcher,
    this.bottomMatcher,
  }) : super();

  final Matcher? rectMatcher;
  final Matcher? topMatcher;
  final Matcher? leftMatcher;
  final Matcher? rightMatcher;
  final Matcher? bottomMatcher;

  @override
  bool matches(covariant Path item, Map<dynamic, dynamic> matchState) {
    final Rect bounds = item.getBounds();

    final List<Matcher?> matchers = <Matcher?> [rectMatcher, topMatcher, leftMatcher, rightMatcher, bottomMatcher];
    final List<dynamic> values = <dynamic> [bounds, bounds.top, bounds.left, bounds.right, bounds.bottom];
    final Map<Matcher, dynamic> failedMatcher = <Matcher, dynamic> {};

    for(int idx = 0; idx < matchers.length; idx++) {
      if (!(matchers[idx]?.matches(values[idx], matchState) ?? true)) {
        failedMatcher[matchers[idx]!] = values[idx];
      }
    }

    matchState['failedMatcher'] = failedMatcher;
    return failedMatcher.isEmpty;
  }

  @override
  Description describe(Description description) => description.add('The actual Rect does not match');

  @override
  Description describeMismatch(covariant Path item, Description mismatchDescription, Map<dynamic, dynamic> matchState, bool verbose) {
    final Description description = super.describeMismatch(item, mismatchDescription, matchState, verbose);
    final Map<Matcher, dynamic> map = matchState['failedMatcher'] as Map<Matcher, dynamic>;
    final Iterable<String> descriptions = map.entries
      .map<String>(
        (MapEntry<Matcher, dynamic> entry) => entry.key.describeMismatch(entry.value, StringDescription(), matchState, verbose).toString(),
      );

    // description is guaranteed to be non-null.
    return description
        ..add('mismatch Rect: ${item.getBounds()}')
        .addAll(': ', ', ', '. ', descriptions);
  }
}

class PathPointsMatcher extends Matcher {
  const PathPointsMatcher({
    this.includes = const <Offset>[],
    this.excludes = const <Offset>[],
  }) : super();

  final Iterable<Offset> includes;
  final Iterable<Offset> excludes;

  @override
  bool matches(covariant Path item, Map<dynamic, dynamic> matchState) {
    final Offset? notIncluded = includes.cast<Offset?>().firstWhere((Offset? offset) => !item.contains(offset!), orElse: () => null);
    final Offset? notExcluded = excludes.cast<Offset?>().firstWhere((Offset? offset) => item.contains(offset!), orElse: () => null);

    matchState['notIncluded'] = notIncluded;
    matchState['notExcluded'] = notExcluded;
    return (notIncluded ?? notExcluded) == null;
  }

  @override
  Description describe(Description description) => description.add('must include these points $includes and must not include $excludes');

  @override
  Description describeMismatch(covariant Path item, Description mismatchDescription, Map<dynamic, dynamic> matchState, bool verbose) {
    final Offset? notIncluded = matchState['notIncluded'] as Offset?;
    final Offset? notExcluded = matchState['notExcluded'] as Offset?;
    final Description desc = super.describeMismatch(item, mismatchDescription, matchState, verbose);

    if ((notExcluded ?? notIncluded) != null) {
      desc.add('Within the bounds of the path ${item.getBounds()}: ');
    }

    if (notIncluded != null) {
      desc.add('$notIncluded is not included. ');
    }
    if (notExcluded != null) {
      desc.add('$notExcluded is not excluded. ');
    }
    return desc;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final MockClipboard mockClipboard = MockClipboard();
  TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, mockClipboard.handleMethodCall);

  // Returns the first RenderEditable.
  RenderEditable findRenderEditable(WidgetTester tester) {
    final RenderObject root = tester.renderObject(find.byType(EditableText));
    expect(root, isNotNull);

    RenderEditable? renderEditable;
    void recursiveFinder(RenderObject child) {
      if (child is RenderEditable) {
        renderEditable = child;
        return;
      }
      child.visitChildren(recursiveFinder);
    }
    root.visitChildren(recursiveFinder);
    expect(renderEditable, isNotNull);
    return renderEditable!;
  }

  List<TextSelectionPoint> globalize(Iterable<TextSelectionPoint> points, RenderBox box) {
    return points.map<TextSelectionPoint>((TextSelectionPoint point) {
      return TextSelectionPoint(
        box.localToGlobal(point.point),
        point.direction,
      );
    }).toList();
  }

  Offset textOffsetToBottomLeftPosition(WidgetTester tester, int offset) {
    final RenderEditable renderEditable = findRenderEditable(tester);
    final List<TextSelectionPoint> endpoints = globalize(
      renderEditable.getEndpointsForSelection(
        TextSelection.collapsed(offset: offset),
      ),
      renderEditable,
    );
    expect(endpoints.length, 1);
    return endpoints[0].point;
  }

  // Web has a less threshold for downstream/upstream text position.
  Offset textOffsetToPosition(WidgetTester tester, int offset) => textOffsetToBottomLeftPosition(tester, offset) + const Offset(kIsWeb ? 1 : 0, -2);

  setUp(() async {
    EditableText.debugDeterministicCursor = false;
    // Fill the clipboard so that the Paste option is available in the text
    // selection menu.
    await Clipboard.setData(const ClipboardData(text: 'Clipboard data'));
  });

  testWidgets('can use the desktop cut/copy/paste buttons on Mac', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'blah1 blah2',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints.loose(const Size(400, 200)),
            child: CupertinoTextField(controller: controller),
          ),
        ),
      ),
    );

    // Initially, the menu is not shown and there is no selection.
    expect(find.byType(CupertinoButton), findsNothing);
    expect(controller.selection, const TextSelection(baseOffset: -1, extentOffset: -1));

    final Offset midBlah1 = textOffsetToPosition(tester, 2);

    // Right clicking shows the menu.
    final TestGesture gesture = await tester.startGesture(
      midBlah1,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);

    // Copy the first word.
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(controller.text, 'blah1 blah2');
    expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
    expect(find.byType(CupertinoButton), findsNothing);

    // Paste it at the end.
    await gesture.down(textOffsetToPosition(tester, controller.text.length));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.selection, const TextSelection(baseOffset: 11, extentOffset: 11, affinity: TextAffinity.upstream));
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Paste'), findsOneWidget);
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(controller.text, 'blah1 blah2blah1');
    expect(controller.selection, const TextSelection.collapsed(offset: 16));

    // Cut the first word.
    await gesture.down(midBlah1);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
    expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
    await tester.tap(find.text('Cut'));
    await tester.pumpAndSettle();
    expect(controller.text, ' blah2blah1');
    expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 0));
    expect(find.byType(CupertinoButton), findsNothing);
  },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.macOS }),
    skip: kIsWeb, // [intended] the web handles this on its own.
  );

  testWidgets('can get text selection color initially on desktop', (WidgetTester tester) async {
    final FocusNode focusNode = FocusNode();
    final TextEditingController controller = TextEditingController(
      text: 'blah1 blah2',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: RepaintBoundary(
            child: CupertinoTextField(
              key: const ValueKey<int>(1),
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ),
    );

    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 11);
    focusNode.requestFocus();
    await tester.pump();

    expect(focusNode.hasFocus, true);
    await expectLater(
      find.byKey(const ValueKey<int>(1)),
      matchesGoldenFile('text_field_golden.text_selection_color.0.png'),
    );
  });

  testWidgets('Activates the text field when receives semantics focus on Mac, Windows', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);
    final SemanticsOwner semanticsOwner = tester.binding.pipelineOwner.semanticsOwner!;
    final FocusNode focusNode = FocusNode();
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoTextField(focusNode: focusNode),
      ),
    );
    expect(semantics, hasSemantics(
      TestSemantics.root(
        children: <TestSemantics>[
          TestSemantics(
            id: 1,
            textDirection: TextDirection.ltr,
            children: <TestSemantics>[
              TestSemantics(
                id: 2,
                children: <TestSemantics>[
                  TestSemantics(
                    id: 3,
                    flags: <SemanticsFlag>[SemanticsFlag.scopesRoute],
                    children: <TestSemantics>[
                      TestSemantics(
                        id: 4,
                        flags: <SemanticsFlag>[SemanticsFlag.isTextField,
                          SemanticsFlag.hasEnabledState, SemanticsFlag.isEnabled,],
                        actions: <SemanticsAction>[SemanticsAction.tap,
                          SemanticsAction.didGainAccessibilityFocus,],
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      ignoreRect: true,
      ignoreTransform: true,
    ));

    expect(focusNode.hasFocus, isFalse);
    semanticsOwner.performAction(4, SemanticsAction.didGainAccessibilityFocus);
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    semantics.dispose();
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.macOS, TargetPlatform.windows }));

  testWidgets(
    'takes available space horizontally and takes intrinsic space vertically no-strut',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints.loose(const Size(200, 200)),
              child: const CupertinoTextField(strutStyle: StrutStyle.disabled),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)),
        const Size(200, 31), // 31 is the height of the default font + padding etc.
      );
    },
  );

  testWidgets(
    'takes available space horizontally and takes intrinsic space vertically',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints.loose(const Size(200, 200)),
              child: const CupertinoTextField(),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)),
        const Size(200, 31), // 31 is the height of the default font (17) + decoration (12).
      );
    },
  );

  testWidgets(
    'uses DefaultSelectionStyle for selection and cursor colors if provided',
    (WidgetTester tester) async {
      const Color selectionColor = Colors.black;
      const Color cursorColor = Colors.white;

      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: DefaultSelectionStyle(
              selectionColor: selectionColor,
              cursorColor: cursorColor,
              child: CupertinoTextField(
                autofocus: true,
              )
            ),
          ),
        ),
      );
      await tester.pump();
      final EditableTextState state = tester.state<EditableTextState>(find.byType(EditableText));
      expect(state.widget.selectionColor, selectionColor);
      expect(state.widget.cursorColor, cursorColor);
    },
  );

  testWidgets('Text field drops selection color when losing focus', (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/103341.
    final Key key1 = UniqueKey();
    final Key key2 = UniqueKey();
    final TextEditingController controller1 = TextEditingController();
    const Color selectionColor = Colors.orange;
    const Color cursorColor = Colors.red;

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: DefaultSelectionStyle(
            selectionColor: selectionColor,
            cursorColor: cursorColor,
            child: Column(
              children: <Widget>[
                CupertinoTextField(
                  key: key1,
                  controller: controller1,
                ),
                CupertinoTextField(key: key2),
              ],
            ),
          ),
        ),
      ),
    );

    const TextSelection selection = TextSelection(baseOffset: 0, extentOffset: 4);
    final EditableTextState state1 = tester.state<EditableTextState>(find.byType(EditableText).first);
    final EditableTextState state2 = tester.state<EditableTextState>(find.byType(EditableText).last);

    await tester.tap(find.byKey(key1));
    await tester.enterText(find.byKey(key1), 'abcd');
    await tester.pump();

    await tester.tap(find.byKey(key2));
    await tester.enterText(find.byKey(key2), 'dcba');
    await tester.pump();

    // Focus and selection is active on first TextField, so the second TextFields
    // selectionColor should be dropped.
    await tester.tap(find.byKey(key1));
    controller1.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    await tester.pump();
    expect(controller1.selection, selection);
    expect(state1.widget.selectionColor, selectionColor);
    expect(state2.widget.selectionColor, null);

    // Focus and selection is active on second TextField, so the first TextFields
    // selectionColor should be dropped.
    await tester.tap(find.byKey(key2));
    await tester.pump();
    expect(state1.widget.selectionColor, null);
    expect(state2.widget.selectionColor, selectionColor);
  });

  testWidgets(
    'multi-lined text fields are intrinsically taller no-strut',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints.loose(const Size(200, 200)),
              child: const CupertinoTextField(
                maxLines: 3,
                strutStyle: StrutStyle.disabled,
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)),
        const Size(200, 65), // 65 is the height of the default font (17) * maxlines (3) + decoration height (12).
      );
    },
  );

  testWidgets(
    'multi-lined text fields are intrinsically taller',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints.loose(const Size(200, 200)),
              child: const CupertinoTextField(maxLines: 3),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)),
        const Size(200, 65),
      );
    },
  );

  testWidgets(
    'strut height override',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints.loose(const Size(200, 200)),
              child: const CupertinoTextField(
                maxLines: 3,
                strutStyle: StrutStyle(
                  fontSize: 8,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)),
        const Size(200, 38),
      );
    },
    // TODO(mdebbar): Strut styles support.
    skip: isBrowser, // https://github.com/flutter/flutter/issues/32243
  );

  testWidgets(
    'strut forces field taller',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints.loose(const Size(200, 200)),
              child: const CupertinoTextField(
                maxLines: 3,
                style: TextStyle(fontSize: 10),
                strutStyle: StrutStyle(
                  fontSize: 18,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)),
        const Size(200, 68),
      );
    },
    // TODO(mdebbar): Strut styles support.
    skip: isBrowser, // https://github.com/flutter/flutter/issues/32243
  );

  testWidgets(
    'default text field has a border',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(),
          ),
        ),
      );

      BoxDecoration decoration = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(CupertinoTextField),
          matching: find.byType(DecoratedBox),
        ),
      ).decoration as BoxDecoration;

      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(5)),
      );
      expect(
        decoration.border!.bottom.color.value,
        0x33000000,
      );

      // Dark mode.
      await tester.pumpWidget(
        const CupertinoApp(
          theme: CupertinoThemeData(brightness: Brightness.dark),
          home: Center(
            child: CupertinoTextField(),
          ),
        ),
      );

      decoration = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(CupertinoTextField),
          matching: find.byType(DecoratedBox),
        ),
      ).decoration as BoxDecoration;

      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(5)),
      );
      expect(
        decoration.border!.bottom.color.value,
        0x33FFFFFF,
      );
    },
  );

  testWidgets(
    'decoration can be overrriden',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              decoration: null,
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(CupertinoTextField),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'text entries are padded by default',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: TextEditingController(text: 'initial'),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('initial')) - tester.getTopLeft(find.byType(CupertinoTextField)),
        const Offset(7.0, 7.0),
      );
    },
  );

  testWidgets('iOS cursor has offset', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoTextField(),
      ),
    );

    final EditableText editableText = tester.firstWidget(find.byType(EditableText));
    expect(editableText.cursorOffset, const Offset(-2.0 / 3.0, 0));
  });

  testWidgets('Cursor radius is 2.0', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoTextField(),
      ),
    );

    final EditableTextState editableTextState = tester.firstState(find.byType(EditableText));
    final RenderEditable renderEditable = editableTextState.renderEditable;

    expect(renderEditable.cursorRadius, const Radius.circular(2.0));
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }));

  testWidgets('Cupertino cursor android golden', (WidgetTester tester) async {
    final Widget widget = CupertinoApp(
      home: Center(
        child: RepaintBoundary(
          key: const ValueKey<int>(1),
          child: ConstrainedBox(
            constraints: BoxConstraints.loose(const Size(400, 400)),
            child: const CupertinoTextField(),
          ),
        ),
      ),
    );
    await tester.pumpWidget(widget);

    const String testValue = 'A short phrase';
    await tester.enterText(find.byType(CupertinoTextField), testValue);
    await tester.pump();

    await tester.tapAt(textOffsetToPosition(tester, testValue.length));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey<int>(1)),
      matchesGoldenFile('text_field_cursor_test.cupertino.0.png'),
    );
  });

  testWidgets('Cupertino cursor golden', (WidgetTester tester) async {
    final Widget widget = CupertinoApp(
      home: Center(
        child: RepaintBoundary(
          key: const ValueKey<int>(1),
          child: ConstrainedBox(
            constraints: BoxConstraints.loose(const Size(400, 400)),
            child: const CupertinoTextField(),
          ),
        ),
      ),
    );
    await tester.pumpWidget(widget);

    const String testValue = 'A short phrase';
    await tester.enterText(find.byType(CupertinoTextField), testValue);
    await tester.pump();

    await tester.tapAt(textOffsetToPosition(tester, testValue.length));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey<int>(1)),
      matchesGoldenFile(
        'text_field_cursor_test.cupertino_${debugDefaultTargetPlatformOverride!.name.toLowerCase()}.1.png',
      ),
    );
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets(
    'can control text content via controller',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      controller.text = 'controller text';
      await tester.pump();

      expect(find.text('controller text'), findsOneWidget);

      controller.text = '';
      await tester.pump();

      expect(find.text('controller text'), findsNothing);
    },
  );

  testWidgets(
    'placeholder respects textAlign',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              placeholder: 'placeholder',
              textAlign: TextAlign.right,
            ),
          ),
        ),
      );

      final Text placeholder = tester.widget(find.text('placeholder'));
      expect(placeholder.textAlign, TextAlign.right);

      await tester.enterText(find.byType(CupertinoTextField), 'input');
      await tester.pump();

      final EditableText inputText = tester.widget(find.text('input'));
      expect(placeholder.textAlign, inputText.textAlign);
    },
  );

  testWidgets('placeholder dark mode', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        theme: CupertinoThemeData(brightness: Brightness.dark),
        home: Center(
          child: CupertinoTextField(
            placeholder: 'placeholder',
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );

    final Text placeholder = tester.widget(find.text('placeholder'));
    expect(placeholder.style!.color!.value, CupertinoColors.placeholderText.darkColor.value);
  });

  testWidgets(
    'placeholders are lightly colored and disappears once typing starts',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              placeholder: 'placeholder',
            ),
          ),
        ),
      );

      final Text placeholder = tester.widget(find.text('placeholder'));
      expect(placeholder.style!.color!.value, CupertinoColors.placeholderText.color.value);

      await tester.enterText(find.byType(CupertinoTextField), 'input');
      await tester.pump();
      expect(find.text('placeholder'), findsNothing);
    },
  );

  testWidgets(
    "placeholderStyle modifies placeholder's style and doesn't affect text's style",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              placeholder: 'placeholder',
              style: TextStyle(
                color: Color(0x00FFFFFF),
                fontWeight: FontWeight.w300,
              ),
              placeholderStyle: TextStyle(
                color: Color(0xAAFFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

      final Text placeholder = tester.widget(find.text('placeholder'));
      expect(placeholder.style!.color, const Color(0xAAFFFFFF));
      expect(placeholder.style!.fontWeight, FontWeight.w600);

      await tester.enterText(find.byType(CupertinoTextField), 'input');
      await tester.pump();

      final EditableText inputText = tester.widget(find.text('input'));
      expect(inputText.style.color, const Color(0x00FFFFFF));
      expect(inputText.style.fontWeight, FontWeight.w300);
    },
  );

  testWidgets(
    'prefix widget is in front of the text',
    (WidgetTester tester) async {
      final FocusNode focusNode = FocusNode();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              focusNode: focusNode,
              prefix: const Icon(CupertinoIcons.add),
              controller: TextEditingController(text: 'input'),
            ),
          ),
        ),
      );

      expect(
        tester.getTopRight(find.byIcon(CupertinoIcons.add)).dx + 7.0, // 7px standard padding around input.
        tester.getTopLeft(find.byType(EditableText)).dx,
      );

      expect(
        tester.getTopLeft(find.byType(EditableText)).dx,
        tester.getTopLeft(find.byType(CupertinoTextField)).dx
            + tester.getSize(find.byIcon(CupertinoIcons.add)).width
            + 7.0,
      );
    },
  );

  testWidgets(
    'prefix widget respects visibility mode',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              prefix: Icon(CupertinoIcons.add),
              prefixMode: OverlayVisibilityMode.editing,
            ),
          ),
        ),
      );

      expect(find.byIcon(CupertinoIcons.add), findsNothing);
      // The position should just be the edge of the whole text field plus padding.
      expect(
        tester.getTopLeft(find.byType(EditableText)).dx,
        tester.getTopLeft(find.byType(CupertinoTextField)).dx + 7.0,
      );

      await tester.enterText(find.byType(CupertinoTextField), 'text input');
      await tester.pump();

      expect(find.text('text input'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.add), findsOneWidget);

      // Text is now moved to the right.
      expect(
        tester.getTopLeft(find.byType(EditableText)).dx,
        tester.getTopLeft(find.byType(CupertinoTextField)).dx
            + tester.getSize(find.byIcon(CupertinoIcons.add)).width
            + 7.0,
      );
    },
  );

  testWidgets(
    'suffix widget is after the text',
    (WidgetTester tester) async {
      final FocusNode focusNode = FocusNode();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              focusNode: focusNode,
              suffix: const Icon(CupertinoIcons.add),
            ),
          ),
        ),
      );

      expect(
        tester.getTopRight(find.byType(EditableText)).dx + 7.0,
        tester.getTopLeft(find.byIcon(CupertinoIcons.add)).dx, // 7px standard padding around input.
      );

      expect(
        tester.getTopRight(find.byType(EditableText)).dx,
        tester.getTopRight(find.byType(CupertinoTextField)).dx
            - tester.getSize(find.byIcon(CupertinoIcons.add)).width
            - 7.0,
      );
    },
  );

  testWidgets(
    'suffix widget respects visibility mode',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              suffix: Icon(CupertinoIcons.add),
              suffixMode: OverlayVisibilityMode.notEditing,
            ),
          ),
        ),
      );

      expect(find.byIcon(CupertinoIcons.add), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField), 'text input');
      await tester.pump();

      expect(find.text('text input'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.add), findsNothing);
    },
  );

  testWidgets(
    'can customize padding',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(EditableText)),
        tester.getSize(find.byType(CupertinoTextField)),
      );
    },
  );

  testWidgets(
    'padding is in between prefix and suffix no-strut',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              padding: EdgeInsets.all(20.0),
              prefix: SizedBox(height: 100.0, width: 100.0),
              suffix: SizedBox(height: 50.0, width: 50.0),
              strutStyle: StrutStyle.disabled,
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byType(EditableText)).dx,
        // Size of prefix + padding.
        100.0 + 20.0,
      );

      expect(tester.getTopLeft(find.byType(EditableText)).dy, 291.5);

      expect(
        tester.getTopRight(find.byType(EditableText)).dx,
        800.0 - 50.0 - 20.0,
      );

      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              padding: EdgeInsets.all(30.0),
              prefix: SizedBox(height: 100.0, width: 100.0),
              suffix: SizedBox(height: 50.0, width: 50.0),
              strutStyle: StrutStyle.disabled,
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byType(EditableText)).dx,
        100.0 + 30.0,
      );

      // Since the highest component, the prefix box, is higher than
      // the text + paddings, the text's vertical position isn't affected.
      expect(tester.getTopLeft(find.byType(EditableText)).dy, 291.5);

      expect(
        tester.getTopRight(find.byType(EditableText)).dx,
        800.0 - 50.0 - 30.0,
      );
    },
  );

  testWidgets(
    'padding is in between prefix and suffix',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              padding: EdgeInsets.all(20.0),
              prefix: SizedBox(height: 100.0, width: 100.0),
              suffix: SizedBox(height: 50.0, width: 50.0),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byType(EditableText)).dx,
        // Size of prefix + padding.
        100.0 + 20.0,
      );

      expect(tester.getTopLeft(find.byType(EditableText)).dy, 291.5);

      expect(
        tester.getTopRight(find.byType(EditableText)).dx,
        800.0 - 50.0 - 20.0,
      );

      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              padding: EdgeInsets.all(30.0),
              prefix: SizedBox(height: 100.0, width: 100.0),
              suffix: SizedBox(height: 50.0, width: 50.0),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byType(EditableText)).dx,
        100.0 + 30.0,
      );

      // Since the highest component, the prefix box, is higher than
      // the text + paddings, the text's vertical position isn't affected.
      expect(tester.getTopLeft(find.byType(EditableText)).dy, 291.5);

      expect(
        tester.getTopRight(find.byType(EditableText)).dx,
        800.0 - 50.0 - 30.0,
      );
    },
  );

  testWidgets(
    'clear button shows with right visibility mode',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'placeholder does not affect clear button',
              clearButtonMode: OverlayVisibilityMode.always,
            ),
          ),
        ),
      );

      expect(find.byIcon(CupertinoIcons.clear_thick_circled), findsOneWidget);

      expect(
        tester.getTopRight(find.byType(EditableText)).dx,
        800.0 - 30.0  /* size of button */ - 7.0 /* padding */,
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'placeholder does not affect clear button',
              clearButtonMode: OverlayVisibilityMode.editing,
            ),
          ),
        ),
      );

      expect(find.byIcon(CupertinoIcons.clear_thick_circled), findsNothing);
      expect(
        tester.getTopRight(find.byType(EditableText)).dx,
        800.0 - 7.0 /* padding */,
      );

      await tester.enterText(find.byType(CupertinoTextField), 'text input');
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.clear_thick_circled), findsOneWidget);
      expect(find.text('text input'), findsOneWidget);
      expect(
        tester.getTopRight(find.byType(EditableText)).dx,
        800.0 - 30.0 - 7.0,
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'placeholder does not affect clear button',
              clearButtonMode: OverlayVisibilityMode.notEditing,
            ),
          ),
        ),
      );
      expect(find.byIcon(CupertinoIcons.clear_thick_circled), findsNothing);

      controller.text = '';
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.clear_thick_circled), findsOneWidget);
    },
  );

  testWidgets(
    'clear button removes text',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'placeholder',
              clearButtonMode: OverlayVisibilityMode.editing,
            ),
          ),
        ),
      );

      controller.text = 'text entry';
      await tester.pump();

      await tester.tap(find.byIcon(CupertinoIcons.clear_thick_circled));
      await tester.pump();

      expect(controller.text, '');
      expect(find.text('placeholder'), findsOneWidget);
      expect(find.text('text entry'), findsNothing);
      expect(find.byIcon(CupertinoIcons.clear_thick_circled), findsNothing);
    },
  );

  testWidgets(
    'tapping clear button also calls onChanged when text not empty',
    (WidgetTester tester) async {
      String value = 'text entry';
      final TextEditingController controller = TextEditingController();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'placeholder',
              onChanged: (String newValue) => value = newValue,
              clearButtonMode: OverlayVisibilityMode.always,
            ),
          ),
        ),
      );

      controller.text = value;
      await tester.pump();

      await tester.tap(find.byIcon(CupertinoIcons.clear_thick_circled));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(find.text('text entry'), findsNothing);
      expect(value, isEmpty);
    },
  );

  testWidgets(
    'clear button yields precedence to suffix',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
              clearButtonMode: OverlayVisibilityMode.always,
              suffix: const Icon(CupertinoIcons.add_circled_solid),
              suffixMode: OverlayVisibilityMode.editing,
            ),
          ),
        ),
      );

      expect(find.byIcon(CupertinoIcons.clear_thick_circled), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.add_circled_solid), findsNothing);

      expect(
        tester.getTopRight(find.byType(EditableText)).dx,
        800.0 - 30.0  /* size of button */ - 7.0 /* padding */,
      );

      controller.text = 'non empty text';
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.clear_thick_circled), findsNothing);
      expect(find.byIcon(CupertinoIcons.add_circled_solid), findsOneWidget);

      // Still just takes the space of one widget.
      expect(
        tester.getTopRight(find.byType(EditableText)).dx,
        800.0 - 24.0  /* size of button */ - 7.0 /* padding */,
      );
    },
  );

  testWidgets(
    'font style controls intrinsic height no-strut',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              strutStyle: StrutStyle.disabled,
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)).height,
        31.0,
      );

      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              style: TextStyle(
                // A larger font.
                fontSize: 50.0,
              ),
              strutStyle: StrutStyle.disabled,
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)).height,
        64.0,
      );
    },
  );

  testWidgets(
    'font style controls intrinsic height',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)).height,
        31.0,
      );

      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              style: TextStyle(
                // A larger font.
                fontSize: 50.0,
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)).height,
        64.0,
      );
    },
  );

  testWidgets(
    'RTL puts attachments to the right places',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: CupertinoTextField(
                padding: EdgeInsets.all(20.0),
                prefix: Icon(CupertinoIcons.book),
                clearButtonMode: OverlayVisibilityMode.always,
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byIcon(CupertinoIcons.book)).dx,
        800.0 - 24.0,
      );

      expect(
        tester.getTopRight(find.byIcon(CupertinoIcons.clear_thick_circled)).dx,
        24.0,
      );
    },
  );

  testWidgets(
    'text fields with no max lines can grow no-strut',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              maxLines: null,
              strutStyle: StrutStyle.disabled,
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)).height,
        31.0, // Initially one line high.
      );

      await tester.enterText(find.byType(CupertinoTextField), '\n');
      await tester.pump();

      expect(
        tester.getSize(find.byType(CupertinoTextField)).height,
        48.0, // Initially one line high.
      );
    },
  );

  testWidgets(
    'text fields with no max lines can grow',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              maxLines: null,
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CupertinoTextField)).height,
        31.0, // Initially one line high.
      );

      await tester.enterText(find.byType(CupertinoTextField), '\n');
      await tester.pump();

      expect(
        tester.getSize(find.byType(CupertinoTextField)).height,
        48.0, // Initially one line high.
      );
    },
  );

  testWidgets('cannot enter new lines onto single line TextField', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(CupertinoTextField), 'abc\ndef');

    expect(controller.text, 'abcdef');
  });

  testWidgets('toolbar has the same visual regardless of theming', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: "j'aime la poutine",
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: Column(
          children: <Widget>[
            CupertinoTextField(
              controller: controller,
            ),
          ],
        ),
      ),
    );

    await tester.longPressAt(
      tester.getTopRight(find.text("j'aime la poutine")),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    Text text = tester.widget<Text>(find.text('Paste'));
    expect(text.style!.color, CupertinoColors.white);
    expect(text.style!.fontSize, 14);
    expect(text.style!.letterSpacing, -0.15);
    expect(text.style!.fontWeight, FontWeight.w400);

    // Change the theme.
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(
          brightness: Brightness.dark,
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(fontSize: 100, fontWeight: FontWeight.w800),
          ),
        ),
        home: Column(
          children: <Widget>[
            CupertinoTextField(
              controller: controller,
            ),
          ],
        ),
      ),
    );

    await tester.longPressAt(
      tester.getTopRight(find.text("j'aime la poutine")),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    text = tester.widget<Text>(find.text('Paste'));
    // The toolbar buttons' text are still the same style.
    expect(text.style!.color, CupertinoColors.white);
    expect(text.style!.fontSize, 14);
    expect(text.style!.letterSpacing, -0.15);
    expect(text.style!.fontWeight, FontWeight.w400);
  }, skip: isContextMenuProvidedByPlatform); // [intended] only applies to platforms where we supply the context menu.

  testWidgets('text field toolbar options correctly changes options on Apple Platforms', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Column(
          children: <Widget>[
            CupertinoTextField(
              controller: controller,
              toolbarOptions: const ToolbarOptions(copy: true),
            ),
          ],
        ),
      ),
    );

    // Long press to put the cursor after the "w".
    const int index = 3;
    await tester.longPressAt(textOffsetToPosition(tester, index));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection.collapsed(offset: index),
    );

    // Double tap on the same location to select the word around the cursor.
    await tester.tapAt(textOffsetToPosition(tester, index));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(textOffsetToPosition(tester, index));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 7),
    );

    // Selected text shows 'Copy'.
    expect(find.text('Paste'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Select All'), findsNothing);
  },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }),
    skip: isContextMenuProvidedByPlatform, // [intended] only applies to platforms where we supply the context menu.
  );

  testWidgets('text field toolbar options correctly changes options on non-Apple Platforms', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Column(
          children: <Widget>[
            CupertinoTextField(
              controller: controller,
              toolbarOptions: const ToolbarOptions(copy: true),
            ),
          ],
        ),
      ),
    );

    // Long press to select 'Atwater'
    const int index = 3;
    await tester.longPressAt(textOffsetToPosition(tester, index));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 7),
    );

    // Tap elsewhere to hide the context menu so that subsequent taps don't
    // collide with it.
    await tester.tapAt(textOffsetToPosition(tester, controller.text.length));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection.collapsed(offset: 35, affinity: TextAffinity.upstream),
    );

    // Double tap on the same location to select the word around the cursor.
    await tester.tapAt(textOffsetToPosition(tester, 10));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(textOffsetToPosition(tester, 10));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 8, extentOffset: 12),
    );

    // Selected text shows 'Copy'.
    expect(find.text('Paste'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Select All'), findsNothing);
  },
    variant: TargetPlatformVariant.all(excluding: <TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }),
    skip: isContextMenuProvidedByPlatform, // [intended] only applies to platforms where we supply the context menu.
  );

  testWidgets('Read only text field', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(text: 'readonly');

    await tester.pumpWidget(
      CupertinoApp(
        home: Column(
          children: <Widget>[
            CupertinoTextField(
              controller: controller,
              readOnly: true,
            ),
          ],
        ),
      ),
    );
    // Read only text field cannot open keyboard.
    await tester.showKeyboard(find.byType(CupertinoTextField));
    expect(tester.testTextInput.hasAnyClients, false);

    await tester.longPressAt(
      tester.getTopRight(find.text('readonly')),
    );

    await tester.pump();

    expect(find.text('Paste'), findsNothing);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Select All'), findsOneWidget);

    await tester.tap(find.text('Select All'));
    await tester.pump();

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Paste'), findsNothing);
    expect(find.text('Cut'), findsNothing);
  }, skip: isContextMenuProvidedByPlatform); // [intended] only applies to platforms where we supply the context menu.

  testWidgets('copy paste', (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Column(
          children: const <Widget>[
            CupertinoTextField(
              placeholder: 'field 1',
            ),
            CupertinoTextField(
              placeholder: 'field 2',
            ),
          ],
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'field 1'),
      "j'aime la poutine",
    );
    await tester.pump();

    // Tap an area inside the EditableText but with no text.
    await tester.longPressAt(
      tester.getTopRight(find.text("j'aime la poutine")),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Select All'));
    await tester.pump();

    await tester.tap(find.text('Cut'));
    await tester.pump();

    // Placeholder 1 is back since the text is cut.
    expect(find.text('field 1'), findsOneWidget);
    expect(find.text('field 2'), findsOneWidget);

    await tester.longPress(find.text('field 2'), warnIfMissed: false); // can't actually hit placeholder
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Paste'));
    await tester.pump();

    expect(find.text('field 1'), findsOneWidget);
    expect(find.text("j'aime la poutine"), findsOneWidget);
    expect(find.text('field 2'), findsNothing);
  }, skip: isContextMenuProvidedByPlatform); // [intended] only applies to platforms where we supply the context menu.

  testWidgets(
    'tap moves cursor to the edge of the word it tapped on',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

      await tester.tapAt(textFieldStart + const Offset(50.0, 5.0));
      await tester.pump();

      // We moved the cursor.
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 7, affinity: TextAffinity.upstream),
      );

      // But don't trigger the toolbar.
      expect(find.byType(CupertinoButton), findsNothing);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS }));

  testWidgets(
    'slow double tap does not trigger double tap',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      // On iOS/iPadOS, during a tap we select the edge of the word closest to the tap.
      // On macOS, we select the precise position of the tap.
      final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.iOS;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset pos = textOffsetToPosition(tester, 6); // Index of 'Atwate|r'.

      await tester.tapAt(pos);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(pos);
      await tester.pump();

      // Plain collapsed selection.
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, isTargetPlatformMobile ? 7 : 6);

      // Toolbar shows on mobile.
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : isTargetPlatformMobile ? findsNWidgets(2) : findsNothing);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets(
    'Tapping on a collapsed selection toggles the toolbar',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure Angrignon Peel Côte-des-Neigse Atwater Peel Sherbrooke Bonaventure Angrignon Peel Côte-des-Neiges',
      );
      // On iOS/iPadOS, during a tap we select the edge of the word closest to the tap.
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
              maxLines: 2,
            ),
          ),
        ),
      );

      final double lineHeight = findRenderEditable(tester).preferredLineHeight;
      final Offset begPos = textOffsetToPosition(tester, 0);
      final Offset endPos = textOffsetToPosition(tester, 35) + const Offset(200.0, 0.0); // Index of 'Bonaventure|' + Offset(200.0,0), which is at the end of the first line.
      final Offset vPos = textOffsetToPosition(tester, 29); // Index of 'Bonav|enture'.
      final Offset wPos = textOffsetToPosition(tester, 3); // Index of 'Atw|ater'.

      // This tap just puts the cursor somewhere different than where the double
      // tap will occur to test that the double tap moves the existing cursor first.
      await tester.tapAt(wPos);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tapAt(vPos);
      await tester.pump(const Duration(milliseconds: 500));
      // First tap moved the cursor. Here we tap the position where 'v' is located.
      // On iOS this will select the closest word edge, in this case the cursor is placed
      // at the end of the word 'Bonaventure|'.
      expect(controller.selection.isCollapsed, true);
      expect(controller.selection.baseOffset, 35);
      expect(find.byType(CupertinoButton), findsNothing);

      await tester.tapAt(vPos);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      // Second tap toggles the toolbar. Here we tap on 'v' again, and select the word edge. Since
      // the selection has not changed we toggle the toolbar.
      expect(controller.selection.isCollapsed, true);
      expect(controller.selection.baseOffset, 35);
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(2));

      // Tap the 'v' position again to hide the toolbar.
      await tester.tapAt(vPos);
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, true);
      expect(controller.selection.baseOffset, 35);
      expect(find.byType(CupertinoButton), findsNothing);

      // Long press at the end of the first line to move the cursor to the end of the first line
      // where the word wrap is. Since there is a word wrap here, and the direction of the text is LTR,
      // the TextAffinity will be upstream and against the natural direction. The toolbar is also
      // shown after a long press.
      await tester.longPressAt(endPos);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(controller.selection.isCollapsed, true);
      expect(controller.selection.baseOffset, 46);
      expect(controller.selection.affinity, TextAffinity.upstream);
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(2));

      // Tap at the same position to toggle the toolbar.
      await tester.tapAt(endPos);
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, true);
      expect(controller.selection.baseOffset, 46);
      expect(controller.selection.affinity, TextAffinity.upstream);
      expect(find.byType(CupertinoButton), findsNothing);

      // Tap at the beginning of the second line to move the cursor to the front of the first word on the
      // second line, where the word wrap is. Since there is a word wrap here, and the direction of the text is LTR,
      // the TextAffinity will be downstream and following the natural direction. The toolbar will be hidden after this tap.
      await tester.tapAt(begPos + Offset(0.0, lineHeight));
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, true);
      expect(controller.selection.baseOffset, 46);
      expect(controller.selection.affinity, TextAffinity.downstream);
      expect(find.byType(CupertinoButton), findsNothing);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS }),
  );

  testWidgets(
    'Tapping on a non-collapsed selection toggles the toolbar and retains the selection',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      // On iOS/iPadOS, during a tap we select the edge of the word closest to the tap.
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset vPos = textOffsetToPosition(tester, 29); // Index of 'Bonav|enture'.
      final Offset ePos = textOffsetToPosition(tester, 35) + const Offset(7.0, 0.0); // Index of 'Bonaventure|' + Offset(7.0,0), which taps slightly to the right of the end of the text.
      final Offset wPos = textOffsetToPosition(tester, 3); // Index of 'Atw|ater'.

      // This tap just puts the cursor somewhere different than where the double
      // tap will occur to test that the double tap moves the existing cursor first.
      await tester.tapAt(wPos);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tapAt(vPos);
      await tester.pump(const Duration(milliseconds: 50));
      // First tap moved the cursor.
      expect(controller.selection.isCollapsed, true);
      expect(
        controller.selection.baseOffset,
        35,
      );
      await tester.tapAt(vPos);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Second tap selects the word around the cursor.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 24, extentOffset: 35),
      );

      // Selected text shows 3 toolbar buttons.
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(3));

      // Tap the selected word to hide the toolbar and retain the selection.
      await tester.tapAt(vPos);
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 24, extentOffset: 35),
      );
      expect(find.byType(CupertinoButton), findsNothing);

      // Tap the selected word to show the toolbar and retain the selection.
      await tester.tapAt(vPos);
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 24, extentOffset: 35),
      );
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(3));

      // Tap past the selected word to move the cursor and hide the toolbar.
      await tester.tapAt(ePos);
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, true);
      expect(controller.selection.baseOffset, 35);
      expect(find.byType(CupertinoButton), findsNothing);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS }),
  );

  testWidgets(
    'double tap selects word for non-Apple platforms',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      // Long press to select 'Atwater'.
      const int index = 3;
      await tester.longPressAt(textOffsetToPosition(tester, index));
      await tester.pump();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );

      // Tap elsewhere to hide the context menu so that subsequent taps don't
      // collide with it.
      await tester.tapAt(textOffsetToPosition(tester, controller.text.length));
      await tester.pump();
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 35, affinity: TextAffinity.upstream),
      );

      // Double tap in the middle of 'Peel' to select the word.
      await tester.tapAt(textOffsetToPosition(tester, 10));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(textOffsetToPosition(tester, 10));
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 8, extentOffset: 12),
      );

      // Selected text shows 3 toolbar buttons.
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(4));

      // Tap somewhere else to move the cursor.
      await tester.tapAt(textOffsetToPosition(tester, index));
      await tester.pumpAndSettle();
      expect(controller.selection, const TextSelection.collapsed(offset: index));
    },
    variant: TargetPlatformVariant.all(excluding: <TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS}),
  );

  testWidgets(
    'double tap selects word for Apple platforms',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      // Long press to put the cursor after the "w".
      const int index = 3;
      await tester.longPressAt(textOffsetToPosition(tester, index));
      await tester.pump();
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: index),
      );

      // Double tap to select the word around the cursor. Move slightly left of
      // the previous tap in order to avoid hitting the text selection toolbar
      // on Mac.
      await tester.tapAt(textOffsetToPosition(tester, index) - const Offset(1.0, 0.0));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(textOffsetToPosition(tester, index));
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );

      if (isContextMenuProvidedByPlatform) {
        expect(find.byType(CupertinoButton), findsNothing);
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.macOS:
          case TargetPlatform.iOS:
            expect(find.byType(CupertinoButton), findsNWidgets(3));
            break;
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.linux:
          case TargetPlatform.windows:
            expect(find.byType(CupertinoButton), findsNWidgets(4));
            break;
        }
      }
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }),
  );

  testWidgets(
    'double tap does not select word on read-only obscured field',
        (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              readOnly: true,
              obscureText: true,
              controller: controller,
            ),
          ),
        ),
      );

      // Long press to put the cursor after the "w".
      const int index = 3;
      await tester.longPressAt(textOffsetToPosition(tester, index));
      await tester.pump();

      // Second tap doesn't select anything.
      await tester.tapAt(textOffsetToPosition(tester, index));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(textOffsetToPosition(tester, index));
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 35),
      );

      // Selected text shows nothing.
      expect(find.byType(CupertinoButton), findsNothing);
    },
  );

  testWidgets('Readonly text field does not have tap action', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);

    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            maxLength: 10,
            readOnly: true,
          ),
        ),
      ),
    );

    expect(semantics, isNot(includesNodeWith(actions: <SemanticsAction>[SemanticsAction.tap])));

    semantics.dispose();
  });

  testWidgets(
    'double tap selects word and first tap of double tap moves cursor',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      // On iOS/iPadOS, during a tap we select the edge of the word closest to the tap.
      // On macOS, we select the precise position of the tap.
      final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.iOS;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset ePos = textOffsetToPosition(tester, 6); // Index of 'Atwate|r'.
      final Offset pPos = textOffsetToPosition(tester, 9); // Index of 'P|eel'.


      await tester.tapAt(ePos);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tapAt(pPos);
      await tester.pump(const Duration(milliseconds: 50));
      // First tap moved the cursor.
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, isTargetPlatformMobile ? 12 : 9);

      await tester.tapAt(pPos);
      await tester.pumpAndSettle();

      // Second tap selects the word around the cursor.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 8, extentOffset: 12),
      );

      // Selected text shows 3 toolbar buttons.
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(3));
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets(
    'double tap hold selects word',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

      await tester.tapAt(textFieldStart + const Offset(150.0, 5.0));
      await tester.pump(const Duration(milliseconds: 50));
      final TestGesture gesture =
         await tester.startGesture(textFieldStart + const Offset(150.0, 5.0));
      // Hold the press.
      await tester.pumpAndSettle();

      expect(
        controller.selection,
        const TextSelection(baseOffset: 8, extentOffset: 12),
      );

      final Matcher matchToolbarButtons;
      if (isContextMenuProvidedByPlatform) {
        matchToolbarButtons = findsNothing;
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.macOS:
          case TargetPlatform.iOS:
            matchToolbarButtons = findsNWidgets(3);
            break;
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.linux:
          case TargetPlatform.windows:
            matchToolbarButtons = findsNWidgets(4);
            break;
        }
      }
      expect(find.byType(CupertinoButton), matchToolbarButtons);

      await gesture.up();
      await tester.pump();

      // Still selected.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 8, extentOffset: 12),
      );
      expect(find.byType(CupertinoButton), matchToolbarButtons);
    },
  );

  testWidgets(
    'tap after a double tap select is not affected',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      // On iOS/iPadOS, during a tap we select the edge of the word closest to the tap.
      // On macOS, we select the precise position of the tap.
      final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.iOS;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset pPos = textOffsetToPosition(tester, 9); // Index of 'P|eel'.
      final Offset ePos = textOffsetToPosition(tester, 6); // Index of 'Atwate|r'

      await tester.tapAt(pPos);
      await tester.pump(const Duration(milliseconds: 50));
      // First tap moved the cursor.
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, isTargetPlatformMobile ? 12 : 9);

      await tester.tapAt(pPos);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tapAt(ePos);
      await tester.pump();

      // Plain collapsed selection at the edge of first word. In iOS 12, the
      // first tap after a double tap ends up putting the cursor at where
      // you tapped instead of the edge like every other single tap. This is
      // likely a bug in iOS 12 and not present in other versions.
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, isTargetPlatformMobile ? 7 : 6);

      // No toolbar.
      expect(find.byType(CupertinoButton), findsNothing);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets('double tapping a space selects the previous word on iOS', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: ' blah blah  \n  blah',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
            maxLines: 2,
          ),
        ),
      ),
    );

    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, -1);
    expect(controller.value.selection.extentOffset, -1);

    // Put the cursor at the end of the field.
    await tester.tapAt(textOffsetToPosition(tester, 19));
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 19);
    expect(controller.value.selection.extentOffset, 19);

    // Double tapping the second space selects the previous word.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(textOffsetToPosition(tester, 5));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(textOffsetToPosition(tester, 5));
    await tester.pumpAndSettle();
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 1);
    expect(controller.value.selection.extentOffset, 5);

    // Put the cursor at the end of the field.
    await tester.tapAt(textOffsetToPosition(tester, 19));
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 19);
    expect(controller.value.selection.extentOffset, 19);

    // Double tapping the first space selects the space.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(textOffsetToPosition(tester, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(textOffsetToPosition(tester, 0));
    await tester.pumpAndSettle();
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 0);
    expect(controller.value.selection.extentOffset, 1);

    // Put the cursor at the end of the field.
    await tester.tapAt(textOffsetToPosition(tester, 19));
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 19);
    expect(controller.value.selection.extentOffset, 19);

    // Double tapping the last space selects all previous contiguous spaces on
    // both lines and the previous word.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(textOffsetToPosition(tester, 14));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(textOffsetToPosition(tester, 14));
    await tester.pumpAndSettle();
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 6);
    expect(controller.value.selection.extentOffset, 14);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS }));

  testWidgets('double tapping a space selects the space on Mac', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: ' blah blah',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, -1);
    expect(controller.value.selection.extentOffset, -1);

    // Put the cursor at the end of the field.
    await tester.tapAt(textOffsetToPosition(tester, 10));
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 10);
    expect(controller.value.selection.extentOffset, 10);

    // Double tapping the second space selects it.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(textOffsetToPosition(tester, 5));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(textOffsetToPosition(tester, 5));
    await tester.pumpAndSettle();

    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 5);
    expect(controller.value.selection.extentOffset, 6);

    // Tap at the end of the text to move the selection to the end. On some
    // platforms, the context menu "Cut" button blocks this tap, so move it out
    // of the way by an Offset.
    await tester.tapAt(textOffsetToPosition(tester, 10) + const Offset(200.0, 0.0));
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 10);
    expect(controller.value.selection.extentOffset, 10);

    // Double tapping the first space selects it.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(textOffsetToPosition(tester, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(textOffsetToPosition(tester, 0));
    await tester.pumpAndSettle();
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 0);
    expect(controller.value.selection.extentOffset, 1);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.macOS }));

  testWidgets('double clicking a space selects the space on Mac', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: ' blah blah',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, -1);
    expect(controller.value.selection.extentOffset, -1);

    // Put the cursor at the end of the field.
    final TestGesture gesture = await tester.startGesture(
      textOffsetToPosition(tester, 10),
      pointer: 7,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.up();
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 10);
    expect(controller.value.selection.extentOffset, 10);

    // Double tapping the second space selects it.
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.down(textOffsetToPosition(tester, 5));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.down(textOffsetToPosition(tester, 5));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 5);
    expect(controller.value.selection.extentOffset, 6);

    // Put the cursor at the end of the field.
    await gesture.down(textOffsetToPosition(tester, 10));
    await tester.pump();
    await gesture.up();
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 10);
    expect(controller.value.selection.extentOffset, 10);

    // Double tapping the first space selects it.
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.down(textOffsetToPosition(tester, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.down(textOffsetToPosition(tester, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.value.selection, isNotNull);
    expect(controller.value.selection.baseOffset, 0);
    expect(controller.value.selection.extentOffset, 1);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.macOS }));

  testWidgets(
    'An obscured CupertinoTextField is not selectable when disabled',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
              obscureText: true,
              enableInteractiveSelection: false,
            ),
          ),
        ),
      );

      final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

      await tester.tapAt(textFieldStart + const Offset(150.0, 5.0));
      await tester.pump(const Duration(milliseconds: 50));
      final TestGesture gesture =
         await tester.startGesture(textFieldStart + const Offset(150.0, 5.0));
      // Hold the press.
      await tester.pump(const Duration(milliseconds: 500));

      // Nothing is selected despite the double tap long press gesture.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 35, extentOffset: 35),
      );

      // The selection menu is not present.
      expect(find.byType(CupertinoButton), findsNWidgets(0));

      await gesture.up();
      await tester.pump();

      // Still nothing selected and no selection menu.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 35, extentOffset: 35),
      );
      expect(find.byType(CupertinoButton), findsNWidgets(0));
    },
  );

  testWidgets(
    'A read-only obscured CupertinoTextField is not selectable',
        (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
              obscureText: true,
              readOnly: true,
            ),
          ),
        ),
      );

      final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

      await tester.tapAt(textFieldStart + const Offset(150.0, 5.0));
      await tester.pump(const Duration(milliseconds: 50));
      final TestGesture gesture =
      await tester.startGesture(textFieldStart + const Offset(150.0, 5.0));
      // Hold the press.
      await tester.pump(const Duration(milliseconds: 500));

      // Nothing is selected despite the double tap long press gesture.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 35, extentOffset: 35),
      );

      // The selection menu is not present.
      expect(find.byType(CupertinoButton), findsNWidgets(0));

      await gesture.up();
      await tester.pump();

      // Still nothing selected and no selection menu.
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 35),
      );
      expect(find.byType(CupertinoButton), findsNWidgets(0));
    },
  );

  testWidgets(
    'An obscured CupertinoTextField is selectable by default',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
              obscureText: true,
            ),
          ),
        ),
      );

      final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

      await tester.tapAt(textFieldStart + const Offset(150.0, 5.0));
      await tester.pump(const Duration(milliseconds: 50));
      final TestGesture gesture =
         await tester.startGesture(textFieldStart + const Offset(150.0, 5.0));
      // Hold the press.
      await tester.pumpAndSettle();

      // The obscured text is treated as one word, should select all
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 35),
      );

      // Selected text shows paste toolbar buttons.
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(1));

      await gesture.up();
      await tester.pump();

      // Still selected.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 35),
      );
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(1));
    },
  );

  testWidgets('An obscured TextField has correct default context menu', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
            obscureText: true,
          ),
        ),
      ),
    );

    final Offset textFieldStart = tester.getCenter(find.byType(CupertinoTextField));

    await tester.tapAt(textFieldStart + const Offset(150.0, 5.0));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.longPressAt(textFieldStart + const Offset(150.0, 5.0));
    await tester.pump();

    // Should only have paste option when whole obscure text is selected.
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Select All'), findsNothing);

    // Tap to cancel selection.
    final Offset textFieldEnd = tester.getTopRight(find.byType(CupertinoTextField));
    await tester.tapAt(textFieldEnd + const Offset(-10.0, 5.0));
    await tester.pump(const Duration(milliseconds: 50));
    // Long tap at the end.
    await tester.longPressAt(textFieldEnd + const Offset(-10.0, 5.0));
    await tester.pump();

    // Should have paste and select all options when collapse.
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Cut'), findsNothing);
  }, skip: isContextMenuProvidedByPlatform); // [intended] only applies to platforms where we supply the context menu.

  testWidgets(
    'long press selects the word at the long press position and shows toolbar on non-Apple platforms',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

      await tester.longPressAt(textFieldStart + const Offset(50.0, 5.0));
      await tester.pumpAndSettle();

      // Select word, 'Atwater, on long press.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7, affinity: TextAffinity.upstream),
      );

      // Non-Collapsed toolbar shows 4 buttons.
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(4));
    },
    variant: TargetPlatformVariant.all(excluding: <TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }),
  );

  testWidgets(
    'long press moves cursor to the exact long press position and shows toolbar on Apple platforms',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

      await tester.longPressAt(textFieldStart + const Offset(50.0, 5.0));
      await tester.pumpAndSettle();

      // Collapsed cursor for iOS long press.
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 3, affinity: TextAffinity.upstream),
      );

      // Collapsed toolbar shows 2 buttons.
      expect(
        find.byType(CupertinoButton),
        isContextMenuProvidedByPlatform
            ? findsNothing
            : defaultTargetPlatform == TargetPlatform.iOS
                ? findsNWidgets(2)
                : findsNWidgets(1),
      );
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }),
  );

  testWidgets(
    'long press tap cannot initiate a double tap',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset ePos = textOffsetToPosition(tester, 6); // Index of 'Atwate|r'

      await tester.longPressAt(ePos);
      await tester.pump(const Duration(milliseconds: 50));

      final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.iOS;
      if (kIsWeb) {
        expect(find.byType(CupertinoButton), findsNothing);
      } else {
        expect(find.byType(CupertinoButton), findsNWidgets(isTargetPlatformMobile ? 2 : 1));
      }
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, 6);

      // Tap in a slightly different position to avoid hitting the context menu
      // on desktop.
      final Offset secondTapPos = isTargetPlatformMobile
          ? ePos
          : ePos + const Offset(-1.0, 0.0);
      await tester.tapAt(secondTapPos);
      await tester.pump();

      // The cursor does not move and the toolbar is toggled.
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, 6);

      // The toolbar from the long press is now dismissed by the second tap.
      expect(find.byType(CupertinoButton), findsNothing);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets(
    'long press drag selects word by word and shows toolbar on lift on non-Apple platforms',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

      final TestGesture gesture =
          await tester.startGesture(textFieldStart + const Offset(50.0, 5.0));
      await tester.pump(const Duration(milliseconds: 500));

      // Long press on non-Apple platforms selects the word at the long press position.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7, affinity: TextAffinity.upstream),
      );
      // Toolbar only shows up on long press up.
      expect(find.byType(CupertinoButton), findsNothing);

      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();

      // The selection is extended word by word to the drag position.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 12, affinity: TextAffinity.upstream),
      );
      expect(find.byType(CupertinoButton), findsNothing);

      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();

      // The selection is extended word by word to the drag position.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 23, affinity: TextAffinity.upstream),
      );
      expect(find.byType(CupertinoButton), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();

      // The selection isn't affected by the gesture lift.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 23, affinity: TextAffinity.upstream),
      );
      // The toolbar now shows up.
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(4));
    },
    variant: TargetPlatformVariant.all(excluding: <TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }),
  );

  testWidgets(
    'long press drag moves the cursor under the drag and shows toolbar on lift on Apple platforms',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

      final TestGesture gesture =
          await tester.startGesture(textFieldStart + const Offset(50.0, 5.0));
      await tester.pump(const Duration(milliseconds: 500));

      // Long press on iOS shows collapsed selection cursor.
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 3, affinity: TextAffinity.upstream),
      );
      // Toolbar only shows up on long press up.
      expect(find.byType(CupertinoButton), findsNothing);

      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      // The selection position is now moved with the drag.
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 6, affinity: TextAffinity.upstream),
      );
      expect(find.byType(CupertinoButton), findsNothing);

      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      // The selection position is now moved with the drag.
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 9, affinity: TextAffinity.upstream),
      );
      expect(find.byType(CupertinoButton), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();

      // The selection isn't affected by the gesture lift.
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 9, affinity: TextAffinity.upstream),
      );
      // The toolbar now shows up.
      expect(
        find.byType(CupertinoButton),
        isContextMenuProvidedByPlatform
            ? findsNothing
            : defaultTargetPlatform == TargetPlatform.iOS
                ? findsNWidgets(2)
                : findsNWidgets(1),
      );
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }),
  );

  testWidgets('long press drag can edge scroll on non-Apple platforms', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure Angrignon Peel Côte-des-Neiges',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    final RenderEditable renderEditable = findRenderEditable(tester);

    List<TextSelectionPoint> lastCharEndpoint = renderEditable.getEndpointsForSelection(
      const TextSelection.collapsed(offset: 66), // Last character's position.
    );

    expect(lastCharEndpoint.length, 1);
    // Just testing the test and making sure that the last character is off
    // the right side of the screen.
    expect(lastCharEndpoint[0].point.dx, moreOrLessEquals(1094.73, epsilon: 0.25));

    final Offset textfieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

    final TestGesture gesture =
        await tester.startGesture(textfieldStart);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 7, affinity: TextAffinity.upstream),
    );
    expect(find.byType(CupertinoButton), findsNothing);

    await gesture.moveBy(const Offset(950, 5));
    // To the edge of the screen basically.
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 59),
    );
    // Keep moving out.
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 66),
    );
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 66, affinity: TextAffinity.upstream),
    ); // We're at the edge now.
    expect(find.byType(CupertinoButton), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();

    // The selection isn't affected by the gesture lift.
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 66, affinity: TextAffinity.upstream),
    );
    // The toolbar now shows up.
    expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(3));

    lastCharEndpoint = renderEditable.getEndpointsForSelection(
      const TextSelection.collapsed(offset: 66), // Last character's position.
    );

    expect(lastCharEndpoint.length, 1);
    // The last character is now on screen near the right edge.
    expect(lastCharEndpoint[0].point.dx, moreOrLessEquals(785.40, epsilon: 1));

    final List<TextSelectionPoint> firstCharEndpoint = renderEditable.getEndpointsForSelection(
      const TextSelection.collapsed(offset: 0), // First character's position.
    );
    expect(firstCharEndpoint.length, 1);
    // The first character is now offscreen to the left.
    expect(firstCharEndpoint[0].point.dx, moreOrLessEquals(-309.30, epsilon: 1));
  }, variant: TargetPlatformVariant.all(excluding: <TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }));

  testWidgets('long press drag can edge scroll on Apple platforms', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure Angrignon Peel Côte-des-Neiges',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    final RenderEditable renderEditable = tester.renderObject<RenderEditable>(
      find.byElementPredicate((Element element) => element.renderObject is RenderEditable).last,
    );

    List<TextSelectionPoint> lastCharEndpoint = renderEditable.getEndpointsForSelection(
      const TextSelection.collapsed(offset: 66), // Last character's position.
    );

    expect(lastCharEndpoint.length, 1);
    // Just testing the test and making sure that the last character is off
    // the right side of the screen.
    expect(lastCharEndpoint[0].point.dx, moreOrLessEquals(1094.73, epsilon: 0.25));

    final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

    final TestGesture gesture =
        await tester.startGesture(textFieldStart + const Offset(300, 5));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      controller.selection,
      const TextSelection.collapsed(offset: 18, affinity: TextAffinity.upstream),
    );
    expect(find.byType(CupertinoButton), findsNothing);

    await gesture.moveBy(const Offset(600, 0));
    // To the edge of the screen basically.
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection.collapsed(offset: 54, affinity: TextAffinity.upstream),
    );
    // Keep moving out.
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection.collapsed(offset: 61, affinity: TextAffinity.upstream),
    );
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection.collapsed(offset: 66, affinity: TextAffinity.upstream),
    ); // We're at the edge now.
    expect(find.byType(CupertinoButton), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();

    // The selection isn't affected by the gesture lift.
    expect(
      controller.selection,
      const TextSelection.collapsed(offset: 66, affinity: TextAffinity.upstream),
    );
    // The toolbar now shows up.
    final int toolbarButtons;
    if (isContextMenuProvidedByPlatform) {
      toolbarButtons = 0;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      toolbarButtons = 2;
    } else {
      // MacOS has no 'Select all' button.
      toolbarButtons = 1;
    }
    expect(find.byType(CupertinoButton), findsNWidgets(toolbarButtons));

    lastCharEndpoint = renderEditable.getEndpointsForSelection(
      const TextSelection.collapsed(offset: 66), // Last character's position.
    );

    expect(lastCharEndpoint.length, 1);
    // The last character is now on screen.
    expect(lastCharEndpoint[0].point.dx, moreOrLessEquals(784.73, epsilon: 0.25));

    final List<TextSelectionPoint> firstCharEndpoint = renderEditable.getEndpointsForSelection(
      const TextSelection.collapsed(offset: 0), // First character's position.
    );
    expect(firstCharEndpoint.length, 1);
    // The first character is now offscreen to the left.
    expect(firstCharEndpoint[0].point.dx, moreOrLessEquals(-310.20, epsilon: 0.25));
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets(
    'long tap after a double tap select is not affected',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      // On iOS/iPadOS, during a tap we select the edge of the word closest to the tap.
      // On macOS, we select the precise position of the tap.
      final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.iOS;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset pPos = textOffsetToPosition(tester, 9); // Index of 'P|eel'
      final Offset ePos = textOffsetToPosition(tester, 6); // Index of 'Atwate|r'

      await tester.tapAt(pPos);
      await tester.pump(const Duration(milliseconds: 50));
      // First tap moved the cursor to the beginning of the second word.
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, isTargetPlatformMobile ? 12 : 9);
      await tester.tapAt(pPos);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.longPressAt(ePos);
      await tester.pumpAndSettle();

      // Plain collapsed selection at the exact tap position.
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 6),
      );

      // Long press toolbar.
      final int toolbarButtons;
      if (isContextMenuProvidedByPlatform) {
        toolbarButtons = 0;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        toolbarButtons = 2;
      } else {
        // MacOS has no 'Select all' button.
        toolbarButtons = 1;
      }
      expect(find.byType(CupertinoButton), findsNWidgets(toolbarButtons));
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets(
    'double tap after a long tap is not affected',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      // On iOS/iPadOS, during a tap we select the edge of the word closest to the tap.
      // On macOS, we select the precise position of the tap.
      final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.iOS;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      // Use a position higher than wPos to avoid tapping the context menu on
      // desktop.
      final Offset pPos = textOffsetToPosition(tester, 9) + const Offset(0.0, -20.0); // Index of 'P|eel'
      final Offset wPos = textOffsetToPosition(tester, 3); // Index of 'Atw|ater'

      await tester.longPressAt(wPos);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, 3);
      if (isContextMenuProvidedByPlatform) {
        expect(find.byType(CupertinoButton), findsNothing);
      } else {
        expect(find.byType(CupertinoButton), isTargetPlatformMobile ? findsNWidgets(2) : findsNWidgets(1));
      }

      await tester.tapAt(pPos);
      await tester.pump(const Duration(milliseconds: 50));

      // First tap moved the cursor.
      expect(find.byType(CupertinoButton), findsNothing);
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, isTargetPlatformMobile ? 12 : 9);

      await tester.tapAt(pPos);
      await tester.pumpAndSettle();

      // Double tap selection.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 8, extentOffset: 12),
      );
      // Shows toolbar.
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(3));
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets(
    'double tap chains work',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'Atwater Peel Sherbrooke Bonaventure',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

      await tester.tapAt(textFieldStart + const Offset(50.0, 5.0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 7, affinity: TextAffinity.upstream),
      );
      await tester.tapAt(textFieldStart + const Offset(50.0, 5.0));
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(3));

      // Double tap selecting the same word somewhere else is fine.
      await tester.tapAt(textFieldStart + const Offset(100.0, 5.0));
      await tester.pump(const Duration(milliseconds: 50));
      // First tap hides the toolbar, and retains the selection.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      expect(find.byType(CupertinoButton), findsNothing);
      // Second tap shows the toolbar, and retains the selection.
      await tester.tapAt(textFieldStart + const Offset(100.0, 5.0));
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(3));

      await tester.tapAt(textFieldStart + const Offset(150.0, 5.0));
      await tester.pump(const Duration(milliseconds: 50));
      // First tap moved the cursor and hides the toolbar.
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 12, affinity: TextAffinity.upstream),
      );
      expect(find.byType(CupertinoButton), findsNothing);
      await tester.tapAt(textFieldStart + const Offset(150.0, 5.0));
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 8, extentOffset: 12),
      );
      expect(find.byType(CupertinoButton), isContextMenuProvidedByPlatform ? findsNothing : findsNWidgets(3));
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS }));

  testWidgets('force press selects word', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    final Offset textFieldStart = tester.getTopLeft(find.byType(CupertinoTextField));

    final int pointerValue = tester.nextPointer;
    final TestGesture gesture = await tester.createGesture();
    await gesture.downWithCustomEvent(
      textFieldStart + const Offset(150.0, 5.0),
      PointerDownEvent(
        pointer: pointerValue,
        position: textFieldStart + const Offset(150.0, 5.0),
        pressure: 3.0,
        pressureMax: 6.0,
        pressureMin: 0.0,
      ),
    );
    // We expect the force press to select a word at the given location.
    expect(
      controller.selection,
      const TextSelection(baseOffset: 8, extentOffset: 12),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    // Shows toolbar.
    final Matcher matchToolbarButtons;
    if (isContextMenuProvidedByPlatform) {
      matchToolbarButtons = findsNothing;
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.macOS:
        case TargetPlatform.iOS:
          matchToolbarButtons = findsNWidgets(3);
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          matchToolbarButtons = findsNWidgets(4);
          break;
      }
    }
    expect(find.byType(CupertinoButton), matchToolbarButtons);
  });

  testWidgets('force press on unsupported devices falls back to tap', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    // On iOS/iPadOS, during a tap we select the edge of the word closest to the tap.
    // On macOS, we select the precise position of the tap.
    final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.iOS;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    final Offset pPos = textOffsetToPosition(tester, 9); // Index of 'P|eel'

    final int pointerValue = tester.nextPointer;
    final TestGesture gesture = await tester.createGesture();
    await gesture.downWithCustomEvent(
      pPos,
      PointerDownEvent(
        pointer: pointerValue,
        position: pPos,
        // iPhone 6 and below report 0 across the board.
        pressure: 0,
        pressureMax: 0,
        pressureMin: 0,
      ),
    );
    await gesture.up();
    // Fall back to a single tap which selects the edge of the word on iOS, and
    // a precise position on macOS.
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, isTargetPlatformMobile ? 12 : 9);

    await tester.pump();
    // Falling back to a single tap doesn't trigger a toolbar.
    expect(find.byType(CupertinoButton), findsNothing);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets('Cannot drag one handle past the other', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'abc def ghi',
    );
    // On iOS/iPadOS, during a tap we select the edge of the word closest to the tap.
    // On macOS, we select the precise position of the tap.
    final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.iOS;

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            dragStartBehavior: DragStartBehavior.down,
            controller: controller,
            style: const TextStyle(
              fontFamily: 'Ahem',
              fontSize: 10.0,
            ),
          ),
        ),
      ),
    );

    // Double tap on 'e' to select 'def'.
    final Offset ePos = textOffsetToPosition(tester, 5);
    await tester.tapAt(ePos, pointer: 7);
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, isTargetPlatformMobile ? 7 : 5);
    await tester.tapAt(ePos, pointer: 7);
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 4);
    expect(controller.selection.extentOffset, 7);

    final RenderEditable renderEditable = findRenderEditable(tester);
    final List<TextSelectionPoint> endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    expect(endpoints.length, 2);

    // On Mac, the toolbar blocks the drag on the right handle, so hide it.
    final EditableTextState editableTextState = tester.state(find.byType(EditableText));
    editableTextState.hideToolbar(false);
    await tester.pumpAndSettle();

    // Drag the right handle until there's only 1 char selected.
    // We use a small offset because the endpoint is on the very corner
    // of the handle.
    final Offset handlePos = endpoints[1].point;
    Offset newHandlePos = textOffsetToPosition(tester, 5); // Position of 'e'.
    final TestGesture gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    expect(controller.selection.baseOffset, 4);
    expect(controller.selection.extentOffset, 5);

    newHandlePos = textOffsetToPosition(tester, 2); // Position of 'c'.
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.selection.baseOffset, 4);
    // The selection doesn't move beyond the left handle. There's always at
    // least 1 char selected.
    expect(controller.selection.extentOffset, 5);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }));

  testWidgets('Dragging between multiple lines keeps the contact point at the same place on the handle on Android', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      // 11 first line, 19 second line, 17 third line = length 49
      text: 'a big house\njumped over a mouse\nOne more line yay',
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            dragStartBehavior: DragStartBehavior.down,
            controller: controller,
            maxLines: 3,
            minLines: 3,
          ),
        ),
      ),
    );

    // Double tap to select 'over'.
    final Offset pos = textOffsetToPosition(tester, controller.text.indexOf('v'));
    // The first tap.
    TestGesture gesture = await tester.startGesture(pos, pointer: 7);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200)); // skip past the frame where the opacity is zero

    // The second tap.
    await gesture.down(pos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final TextSelection selection = controller.selection;
    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 19,
        extentOffset: 23,
      ),
    );

    final RenderEditable renderEditable = findRenderEditable(tester);
    List<TextSelectionPoint> endpoints = globalize(
      renderEditable.getEndpointsForSelection(selection),
      renderEditable,
    );
    expect(endpoints.length, 2);

    // Drag the right handle 4 letters to the right.
    // The adjustment moves the tap from the text position to the handle.
    const Offset endHandleAdjustment = Offset(1.0, 6.0);
    Offset handlePos = endpoints[1].point + endHandleAdjustment;
    Offset newHandlePos = textOffsetToPosition(tester, 27) + endHandleAdjustment;
    await tester.pump();
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 19,
        extentOffset: 27,
      ),
    );

    // Drag the right handle 1 line down.
    endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    handlePos = endpoints[1].point + endHandleAdjustment;
    final Offset toNextLine = Offset(
      0.0,
      findRenderEditable(tester).preferredLineHeight + 3.0,
    );
    newHandlePos = handlePos + toNextLine;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 19,
        extentOffset: 47,
      ),
    );

    // Drag the right handle back up 1 line.
    endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    handlePos = endpoints[1].point + endHandleAdjustment;
    newHandlePos = handlePos - toNextLine;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 19,
        extentOffset: 27,
      ),
    );

    // Drag the left handle 4 letters to the left.
    // The adjustment moves the tap from the text position to the handle.
    const Offset startHandleAdjustment = Offset(-1.0, 6.0);
    endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    handlePos = endpoints[0].point + startHandleAdjustment;
    newHandlePos = textOffsetToPosition(tester, 15) + startHandleAdjustment;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 15,
        extentOffset: 27,
      ),
    );

    // Drag the left handle 1 line up.
    endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    handlePos = endpoints[0].point + startHandleAdjustment;
    newHandlePos = handlePos - toNextLine;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 3,
        extentOffset: 27,
      ),
    );

    // Drag the left handle 1 line back down.
    endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    handlePos = endpoints[0].point + startHandleAdjustment;
    newHandlePos = handlePos + toNextLine;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 15,
        extentOffset: 27,
      ),
    );
  },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.android }),
  );

  testWidgets('Dragging between multiple lines keeps the contact point at the same place on the handle on iOS', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      // 11 first line, 19 second line, 17 third line = length 49
      text: 'a big house\njumped over a mouse\nOne more line yay',
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            dragStartBehavior: DragStartBehavior.down,
            controller: controller,
            maxLines: 3,
            minLines: 3,
          ),
        ),
      ),
    );

    // Double tap to select 'over'.
    final Offset pos = textOffsetToPosition(tester, controller.text.indexOf('v'));
    // The first tap.
    TestGesture gesture = await tester.startGesture(pos, pointer: 7);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200)); // skip past the frame where the opacity is zero

    // The second tap.
    await gesture.down(pos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final TextSelection selection = controller.selection;
    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 19,
        extentOffset: 23,
      ),
    );

    final RenderEditable renderEditable = findRenderEditable(tester);
    List<TextSelectionPoint> endpoints = globalize(
      renderEditable.getEndpointsForSelection(selection),
      renderEditable,
    );
    expect(endpoints.length, 2);

    // Drag the right handle 4 letters to the right.
    // The adjustment moves the tap from the text position to the handle.
    const Offset endHandleAdjustment = Offset(1.0, 6.0);
    Offset handlePos = endpoints[1].point + endHandleAdjustment;
    Offset newHandlePos = textOffsetToPosition(tester, 27) + endHandleAdjustment;
    await tester.pump();
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 19,
        extentOffset: 27,
      ),
    );

    // Drag the right handle 1 line down.
    endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    handlePos = endpoints[1].point + endHandleAdjustment;
    final double lineHeight = findRenderEditable(tester).preferredLineHeight;
    final Offset toNextLine = Offset(0.0, lineHeight + 3.0);
    newHandlePos = handlePos + toNextLine;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 19,
        extentOffset: 47,
      ),
    );

    // Drag the right handle back up 1 line.
    endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    handlePos = endpoints[1].point + endHandleAdjustment;
    newHandlePos = handlePos - toNextLine;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 19,
        extentOffset: 27,
      ),
    );

    // Drag the left handle 4 letters to the left.
    // The adjustment moves the tap from the text position to the handle.
    final Offset startHandleAdjustment = Offset(-1.0, -lineHeight + 6.0);
    endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    handlePos = endpoints[0].point + startHandleAdjustment;
    newHandlePos = textOffsetToPosition(tester, 15) + startHandleAdjustment;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // On Apple platforms, dragging the base handle makes it the extent.
    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 27,
        extentOffset: 15,
      ),
    );

    // Drag the left handle 1 line up.
    endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    handlePos = endpoints[0].point + startHandleAdjustment;
    newHandlePos = handlePos - toNextLine;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 27,
        extentOffset: 3,
      ),
    );

    // Drag the left handle 1 line back down.
    endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    handlePos = endpoints[0].point + startHandleAdjustment;
    newHandlePos = handlePos + toNextLine;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(
        baseOffset: 27,
        extentOffset: 15,
      ),
    );
  },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS }),
  );

  testWidgets('Selection updates on tap down (Desktop platforms)', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(controller: controller),
        ),
      ),
    );

    const String testValue = 'abc def ghi';
    await tester.enterText(find.byType(CupertinoTextField), testValue);
    // Skip past scrolling animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final Offset ePos = textOffsetToPosition(tester, 5);
    final Offset gPos = textOffsetToPosition(tester, 8);

    final TestGesture gesture = await tester.startGesture(ePos, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 5);
    expect(controller.selection.extentOffset, 5);

    await gesture.up();
    await tester.pumpAndSettle(kDoubleTapTimeout);

    await gesture.down(gPos);
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 8);

    // This should do nothing. The selection is set on tap down on desktop platforms.
    await gesture.up();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 8);
  },
      variant: TargetPlatformVariant.desktop(),
  );

  testWidgets('Selection updates on tap up (Mobile platforms)', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    final bool isTargetPlatformApple = defaultTargetPlatform == TargetPlatform.iOS;

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(controller: controller),
        ),
      ),
    );

    const String testValue = 'abc def ghi';
    await tester.enterText(find.byType(CupertinoTextField), testValue);
    // Skip past scrolling animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final Offset ePos = textOffsetToPosition(tester, 5);
    final Offset gPos = textOffsetToPosition(tester, 8);

    final TestGesture gesture = await tester.startGesture(ePos, kind: PointerDeviceKind.mouse);
    await gesture.up();
    await tester.pumpAndSettle(kDoubleTapTimeout);

    await gesture.down(gPos);
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 5);
    expect(controller.selection.extentOffset, 5);

    await gesture.up();
    await tester.pumpAndSettle(kDoubleTapTimeout);
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 8);

    final TestGesture touchGesture = await tester.startGesture(ePos);
    await touchGesture.up();
    await tester.pumpAndSettle(kDoubleTapTimeout);
    // On iOS, a tap to select, selects the word edge instead of the exact tap position.
    expect(controller.selection.baseOffset, isTargetPlatformApple ? 7 : 5);
    expect(controller.selection.extentOffset, isTargetPlatformApple ? 7 : 5);

    // Selection should stay the same since it is set on tap up for mobile platforms.
    await touchGesture.down(gPos);
    await tester.pump();
    expect(controller.selection.baseOffset, isTargetPlatformApple ? 7 : 5);
    expect(controller.selection.extentOffset, isTargetPlatformApple ? 7 : 5);

    await touchGesture.up();
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 8);
  },
      variant: TargetPlatformVariant.mobile(),
  );

  testWidgets('Can select text by dragging with a mouse', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            dragStartBehavior: DragStartBehavior.down,
            controller: controller,
            style: const TextStyle(
              fontFamily: 'Ahem',
              fontSize: 10.0,
            ),
          ),
        ),
      ),
    );

    const String testValue = 'abc def ghi';
    await tester.enterText(find.byType(CupertinoTextField), testValue);
    // Skip past scrolling animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final Offset ePos = textOffsetToPosition(tester, testValue.indexOf('e'));
    final Offset gPos = textOffsetToPosition(tester, testValue.indexOf('g'));

    final TestGesture gesture = await tester.startGesture(ePos, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveTo(gPos);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.selection.baseOffset, testValue.indexOf('e'));
    expect(controller.selection.extentOffset, testValue.indexOf('g'));
  });

  testWidgets('Continuous dragging does not cause flickering', (WidgetTester tester) async {
    int selectionChangedCount = 0;
    const String testValue = 'abc def ghi';
    final TextEditingController controller = TextEditingController(text: testValue);

    controller.addListener(() {
      selectionChangedCount++;
    });

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            dragStartBehavior: DragStartBehavior.down,
            controller: controller,
            style: const TextStyle(
              fontFamily: 'Ahem',
              fontSize: 10.0,
            ),
          ),
        ),
      ),
    );

    final Offset cPos = textOffsetToPosition(tester, 2); // Index of 'c'.
    final Offset gPos = textOffsetToPosition(tester, 8); // Index of 'g'.
    final Offset hPos = textOffsetToPosition(tester, 9); // Index of 'h'.

    // Drag from 'c' to 'g'.
    final TestGesture gesture = await tester.startGesture(cPos, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveTo(gPos);
    await tester.pumpAndSettle();

    expect(selectionChangedCount, isNonZero);
    selectionChangedCount = 0;
    expect(controller.selection.baseOffset, 2);
    expect(controller.selection.extentOffset, 8);

    // Tiny movement shouldn't cause text selection to change.
    await gesture.moveTo(gPos + const Offset(2.0, 0.0));
    await tester.pumpAndSettle();
    expect(selectionChangedCount, 0);

    // Now a text selection change will occur after a significant movement.
    await gesture.moveTo(hPos);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectionChangedCount, 1);
    expect(controller.selection.baseOffset, 2);
    expect(controller.selection.extentOffset, 9);
  });

  testWidgets('Tap does not show handles nor toolbar', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'abc def ghi',
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(controller: controller),
        ),
      ),
    );

    // Tap to trigger the text field.
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();

    final EditableTextState editableText = tester.state(find.byType(EditableText));
    expect(editableText.selectionOverlay!.handlesAreVisible, isFalse);
    expect(editableText.selectionOverlay!.toolbarIsVisible, isFalse);
  });

  testWidgets('Long press shows toolbar but not handles', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'abc def ghi',
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(controller: controller),
        ),
      ),
    );

    // Long press to trigger the text field.
    await tester.longPress(find.byType(CupertinoTextField));
    await tester.pump();
    // A long press in Cupertino should position the cursor without any selection.
    expect(controller.selection.isCollapsed, isTrue);

    final EditableTextState editableText = tester.state(find.byType(EditableText));
    expect(editableText.selectionOverlay!.handlesAreVisible, isFalse);
    expect(editableText.selectionOverlay!.toolbarIsVisible, isContextMenuProvidedByPlatform ? isFalse : isTrue);
  });

  testWidgets(
    'Double tap shows handles and toolbar if selection is not collapsed',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'abc def ghi',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(controller: controller),
          ),
        ),
      );

      final Offset hPos = textOffsetToPosition(tester, 9); // Position of 'h'.

      // Double tap on 'h' to select 'ghi'.
      await tester.tapAt(hPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(hPos);
      await tester.pump();

      final EditableTextState editableText = tester.state(find.byType(EditableText));
      expect(editableText.selectionOverlay!.handlesAreVisible, isTrue);
      expect(editableText.selectionOverlay!.toolbarIsVisible, isContextMenuProvidedByPlatform ? isFalse : isTrue);
    },
  );

  testWidgets(
    'Double tap shows toolbar but not handles if selection is collapsed',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'abc def ghi',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(controller: controller),
          ),
        ),
      );

      final Offset textEndPos = textOffsetToPosition(tester, 11); // Position at the end of text.

      // Double tap to place the cursor at the end.
      await tester.tapAt(textEndPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(textEndPos);
      await tester.pump();

      final EditableTextState editableText = tester.state(find.byType(EditableText));
      expect(editableText.selectionOverlay!.handlesAreVisible, isFalse);
      expect(editableText.selectionOverlay!.toolbarIsVisible, isContextMenuProvidedByPlatform ? isFalse : isTrue);
    },
  );

  testWidgets(
    'Mouse long press does not show handles nor toolbar',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'abc def ghi',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(controller: controller),
          ),
        ),
      );

      // Long press to trigger the text field.
      final Offset textFieldPos = tester.getCenter(find.byType(CupertinoTextField));
      final TestGesture gesture = await tester.startGesture(
        textFieldPos,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pump();

      final EditableTextState editableText = tester.state(find.byType(EditableText));
      expect(editableText.selectionOverlay!.toolbarIsVisible, isFalse);
      expect(editableText.selectionOverlay!.handlesAreVisible, isFalse);
    },
  );

  testWidgets(
    'Mouse double tap does not show handles nor toolbar',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'abc def ghi',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(controller: controller),
          ),
        ),
      );

      final EditableTextState editableText = tester.state(find.byType(EditableText));

      // Double tap at the end of text.
      final Offset textEndPos = textOffsetToPosition(tester, 11); // Position at the end of text.
      final TestGesture gesture = await tester.startGesture(
        textEndPos,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();
      await gesture.down(textEndPos);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(editableText.selectionOverlay!.toolbarIsVisible, isFalse);
      expect(editableText.selectionOverlay!.handlesAreVisible, isFalse);

      final Offset hPos = textOffsetToPosition(tester, 9); // Position of 'h'.

      // Double tap on 'h' to select 'ghi'.
      await gesture.down(hPos);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();
      await gesture.down(hPos);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(editableText.selectionOverlay!.handlesAreVisible, isFalse);
      expect(editableText.selectionOverlay!.toolbarIsVisible, isFalse);
    },
  );

  testWidgets('onTap is called upon tap', (WidgetTester tester) async {
    int tapCount = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            onTap: () => tapCount++,
          ),
        ),
      ),
    );

    expect(tapCount, 0);
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    expect(tapCount, 1);

    // Wait out the double tap interval so the next tap doesn't end up being
    // recognized as a double tap.
    await tester.pump(const Duration(seconds: 1));

    // Double tap count as one single tap.
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    expect(tapCount, 2);
  });

  testWidgets(
    'onTap does not work when the text field is disabled',
    (WidgetTester tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              enabled: false,
              onTap: () => tapCount++,
            ),
          ),
        ),
      );

      expect(tapCount, 0);
      await tester.tap(find.byType(CupertinoTextField), warnIfMissed: false); // disabled
      await tester.pump();
      expect(tapCount, 0);

      // Wait out the double tap interval so the next tap doesn't end up being
      // recognized as a double tap.
      await tester.pump(const Duration(seconds: 1));

      // Enabling the text field, now it should accept taps.
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              onTap: () => tapCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CupertinoTextField));
      expect(tapCount, 1);

      await tester.pump(const Duration(seconds: 1));

      // Disable it again.
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              enabled: false,
              onTap: () => tapCount++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CupertinoTextField), warnIfMissed: false); // disabled
      await tester.pump();
      expect(tapCount, 1);
    },
  );

  testWidgets('Focus test when the text field is disabled', (WidgetTester tester) async {
    final FocusNode focusNode = FocusNode();
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            focusNode: focusNode,
          ),
        ),
      ),
    );

    expect(focusNode.hasFocus, false); // initial status

    // Should accept requestFocus.
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, true);

    // Disable the text field, now it should not accept requestFocus.
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            enabled: false,
            focusNode: focusNode,
          ),
        ),
      ),
    );

    // Should not accept requestFocus.
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, false);
  });

  testWidgets(
    'text field respects theme',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          theme: CupertinoThemeData(
            brightness: Brightness.dark,
          ),
          home: Center(
            child: CupertinoTextField(),
          ),
        ),
      );

      final BoxDecoration decoration = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(CupertinoTextField),
          matching: find.byType(DecoratedBox),
        ),
      ).decoration as BoxDecoration;

      expect(
        decoration.border!.bottom.color.value,
        0x33FFFFFF,
      );

      await tester.enterText(find.byType(CupertinoTextField), 'smoked meat');
      await tester.pump();

      expect(
        tester.renderObject<RenderEditable>(
          find.byElementPredicate((Element element) => element.renderObject is RenderEditable).last,
        ).text!.style!.color,
        isSameColorAs(CupertinoColors.white),
      );
    },
  );

  testWidgets(
    'Check the toolbar appears below the TextField when there is not enough space above the TextField to show it',
    (WidgetTester tester) async {
      // This is a regression test for
      // https://github.com/flutter/flutter/issues/29808
      const String testValue = 'abc def ghi';
      final TextEditingController controller = TextEditingController();

      await tester.pumpWidget(
        CupertinoApp(
          home: Container(
            padding: const EdgeInsets.all(30),
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(CupertinoTextField), testValue);
      // Tap the selection handle to bring up the "paste / select all" menu.
      await tester.tapAt(textOffsetToPosition(tester, testValue.indexOf('e')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200)); // skip past the frame where the opacity is zero
      RenderEditable renderEditable = findRenderEditable(tester);
      List<TextSelectionPoint> endpoints = globalize(
        renderEditable.getEndpointsForSelection(controller.selection),
        renderEditable,
      );
      await tester.tapAt(endpoints[0].point + const Offset(1.0, 1.0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200)); // skip past the frame where the opacity is zero

      // Verify the selection toolbar position
      Offset toolbarTopLeft = tester.getTopLeft(find.text('Paste'));
      Offset textFieldTopLeft = tester.getTopLeft(find.byType(CupertinoTextField));
      expect(textFieldTopLeft.dy, lessThan(toolbarTopLeft.dy));

      await tester.pumpWidget(
        CupertinoApp(
          home: Container(
            padding: const EdgeInsets.all(150),
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(CupertinoTextField), testValue);
      // Tap the selection handle to bring up the "paste / select all" menu.
      await tester.tapAt(textOffsetToPosition(tester, testValue.indexOf('e')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200)); // skip past the frame where the opacity is zero
      renderEditable = findRenderEditable(tester);
      endpoints = globalize(
        renderEditable.getEndpointsForSelection(controller.selection),
        renderEditable,
      );
      await tester.tapAt(endpoints[0].point + const Offset(1.0, 1.0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200)); // skip past the frame where the opacity is zero

      // Verify the selection toolbar position
      toolbarTopLeft = tester.getTopLeft(find.text('Paste'));
      textFieldTopLeft = tester.getTopLeft(find.byType(CupertinoTextField));
      expect(toolbarTopLeft.dy, lessThan(textFieldTopLeft.dy));
    },
    skip: isContextMenuProvidedByPlatform, // [intended] only applies to platforms where we supply the context menu.
  );

  testWidgets('text field respects keyboardAppearance from theme', (WidgetTester tester) async {
    final List<MethodCall> log = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.textInput, (MethodCall methodCall) async {
      log.add(methodCall);
      return null;
    });

    await tester.pumpWidget(
      const CupertinoApp(
        theme: CupertinoThemeData(
          brightness: Brightness.dark,
        ),
        home: Center(
          child: CupertinoTextField(),
        ),
      ),
    );

    await tester.showKeyboard(find.byType(EditableText));
    final MethodCall setClient = log.first;
    expect(setClient.method, 'TextInput.setClient');
    expect(((setClient.arguments as List<dynamic>).last as Map<String, dynamic>)['keyboardAppearance'], 'Brightness.dark');
  });

  testWidgets('text field can override keyboardAppearance from theme', (WidgetTester tester) async {
    final List<MethodCall> log = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.textInput, (MethodCall methodCall) async {
      log.add(methodCall);
      return null;
    });

    await tester.pumpWidget(
      const CupertinoApp(
        theme: CupertinoThemeData(
          brightness: Brightness.dark,
        ),
        home: Center(
          child: CupertinoTextField(
            keyboardAppearance: Brightness.light,
          ),
        ),
      ),
    );

    await tester.showKeyboard(find.byType(EditableText));
    final MethodCall setClient = log.first;
    expect(setClient.method, 'TextInput.setClient');
    expect(((setClient.arguments as List<dynamic>).last as Map<String, dynamic>)['keyboardAppearance'], 'Brightness.light');
  });

  testWidgets('cursorColor respects theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoTextField(),
      ),
    );

    final Finder textFinder = find.byType(CupertinoTextField);
    await tester.tap(textFinder);
    await tester.pump();

    final EditableTextState editableTextState =
    tester.firstState(find.byType(EditableText));
    final RenderEditable renderEditable = editableTextState.renderEditable;

    expect(renderEditable.cursorColor, CupertinoColors.activeBlue.color);

    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoTextField(),
        theme: CupertinoThemeData(
          brightness: Brightness.dark,
        ),
      ),
    );

    await tester.pump();
    expect(renderEditable.cursorColor, CupertinoColors.activeBlue.darkColor);

    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoTextField(),
        theme: CupertinoThemeData(
          primaryColor: Color(0xFFF44336),
        ),
      ),
    );

    await tester.pump();
    expect(renderEditable.cursorColor, const Color(0xFFF44336));
  });

  testWidgets('cursor can override color from theme', (WidgetTester tester) async {
    const CupertinoDynamicColor cursorColor = CupertinoDynamicColor.withBrightness(
      color: Color(0x12345678),
      darkColor: Color(0x87654321),
    );

    await tester.pumpWidget(
      const CupertinoApp(
        theme: CupertinoThemeData(),
        home: Center(
          child: CupertinoTextField(
            cursorColor: cursorColor,
          ),
        ),
      ),
    );

    EditableText editableText = tester.firstWidget(find.byType(EditableText));
    expect(editableText.cursorColor.value, 0x12345678);

    await tester.pumpWidget(
      const CupertinoApp(
        theme: CupertinoThemeData(brightness: Brightness.dark),
        home: Center(
          child: CupertinoTextField(
            cursorColor: cursorColor,
          ),
        ),
      ),
    );

    editableText = tester.firstWidget(find.byType(EditableText));
    expect(editableText.cursorColor.value, 0x87654321);
  });

  testWidgets('shows selection handles', (WidgetTester tester) async {
    const String testText = 'lorem ipsum';
    final TextEditingController controller = TextEditingController(text: testText);

    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(),
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    final RenderEditable renderEditable =
      tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;

    await tester.tapAt(textOffsetToPosition(tester, 5));
    renderEditable.selectWord(cause: SelectionChangedCause.longPress);
    await tester.pumpAndSettle();

    final List<Widget> transitions =
      find.byType(FadeTransition).evaluate().map((Element e) => e.widget).toList();
    expect(transitions.length, 2);
    final FadeTransition left = transitions[0] as FadeTransition;
    final FadeTransition right = transitions[1] as FadeTransition;

    expect(left.opacity.value, equals(1.0));
    expect(right.opacity.value, equals(1.0));
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }));

  testWidgets('when CupertinoTextField would be blocked by keyboard, it is shown with enough space for the selection handle', (WidgetTester tester) async {
    final ScrollController scrollController = ScrollController();
    final TextEditingController controller = TextEditingController();

    await tester.pumpWidget(CupertinoApp(
      theme: const CupertinoThemeData(),
      home: Center(
        child: ListView(
          controller: scrollController,
          children: <Widget>[
            Container(height: 583), // Push field almost off screen.
            CupertinoTextField(controller: controller),
            Container(height: 1000),
          ],
        ),
      ),
    ));

    // Tap the TextField to put the cursor into it and bring it into view.
    expect(scrollController.offset, 0.0);
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pumpAndSettle();

    // The ListView has scrolled to keep the TextField and cursor handle
    // visible.
    expect(scrollController.offset, 25.0);
  });

  testWidgets('disabled state golden', (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
          child: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: RepaintBoundary(
                key: const ValueKey<int>(1),
                child: CupertinoTextField(
                  controller: TextEditingController(text: 'lorem'),
                  enabled: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(const ValueKey<int>(1)),
      matchesGoldenFile('text_field_test.disabled.png'),
    );
  });

  group('Text selection toolbar', () {
    testWidgets('Collapsed selection works', (WidgetTester tester) async {
      EditableText.debugDeterministicCursor = true;
      tester.binding.window.physicalSizeTestValue = const Size(400, 400);
      tester.binding.window.devicePixelRatioTestValue = 1;
      TextEditingController controller;
      EditableTextState state;
      Offset bottomLeftSelectionPosition;

      controller = TextEditingController(text: 'a');
      // Top left collapsed selection. The toolbar should flip vertically, and
      // the arrow should not point exactly to the caret because the caret is
      // too close to the left.
      await tester.pumpWidget(
        CupertinoApp(
          debugShowCheckedModeBanner: false,
          home: CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                height: 200,
                child: CupertinoTextField(
                  controller: controller,
                  maxLines: null,
                ),
              ),
            ),
          ),
        ),
      );

      state = tester.state<EditableTextState>(find.byType(EditableText));
      final double lineHeight = state.renderEditable.preferredLineHeight;

      state.renderEditable.selectPositionAt(from: textOffsetToPosition(tester, 0), cause: SelectionChangedCause.tap);
      expect(state.showToolbar(), true);
      await tester.pumpAndSettle();

      bottomLeftSelectionPosition = textOffsetToBottomLeftPosition(tester, 0);
      expect(
        find.byType(CupertinoTextSelectionToolbar),
        paints..clipPath(
          pathMatcher: PathPointsMatcher(
            excludes: <Offset> [
              // Arrow should not point to the selection handle.
              bottomLeftSelectionPosition.translate(0, 8 + 0.1),
            ],
            includes: <Offset> [
              // Expected center of the arrow.
              Offset(26.0, bottomLeftSelectionPosition.dy + 8 + 0.1),
            ],
          ),
        ),
      );

      expect(
        find.byType(CupertinoTextSelectionToolbar),
        paints..clipPath(
          pathMatcher: PathBoundsMatcher(
            topMatcher: moreOrLessEquals(bottomLeftSelectionPosition.dy + 8, epsilon: 0.01),
            leftMatcher: moreOrLessEquals(8),
            rightMatcher: lessThanOrEqualTo(400 - 8),
            bottomMatcher: moreOrLessEquals(bottomLeftSelectionPosition.dy + 8 + 43, epsilon: 0.01),
          ),
        ),
      );

      // Top Right collapsed selection. The toolbar should flip vertically, and
      // the arrow should not point exactly to the caret because the caret is
      // too close to the right.
      controller = TextEditingController(text: List<String>.filled(200, 'a').join());
      await tester.pumpWidget(
        CupertinoApp(
          debugShowCheckedModeBanner: false,
          home: CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 200,
                height: 200,
                child: CupertinoTextField(
                  controller: controller,
                  maxLines: null,
                ),
              ),
            ),
          ),
        ),
      );

      state = tester.state<EditableTextState>(find.byType(EditableText));
      state.renderEditable.selectPositionAt(
        from: tester.getTopRight(find.byType(CupertinoApp)),
        cause: SelectionChangedCause.tap,
      );
      await tester.pumpAndSettle();

      // -1 because we want to reach the end of the line, not the start of a new line.
      bottomLeftSelectionPosition = textOffsetToBottomLeftPosition(tester, state.renderEditable.selection!.baseOffset - 1);

      expect(
        find.byType(CupertinoTextSelectionToolbar),
        paints..clipPath(
          pathMatcher: PathPointsMatcher(
            excludes: <Offset> [
              // Arrow should not point to the selection handle.
              bottomLeftSelectionPosition.translate(0, 8 + 0.1),
            ],
            includes: <Offset> [
              // Expected center of the arrow.
              Offset(400 - 26.0, bottomLeftSelectionPosition.dy + 8 + 0.1),
            ],
          ),
        ),
      );

      expect(
        find.byType(CupertinoTextSelectionToolbar),
        paints..clipPath(
          pathMatcher: PathBoundsMatcher(
            topMatcher: moreOrLessEquals(bottomLeftSelectionPosition.dy + 8, epsilon: 0.01),
            rightMatcher: moreOrLessEquals(400.0 - 8),
            bottomMatcher: moreOrLessEquals(bottomLeftSelectionPosition.dy + 8 + 43, epsilon: 0.01),
            leftMatcher: greaterThanOrEqualTo(8),
          ),
        ),
      );

      // Normal centered collapsed selection. The toolbar arrow should point down, and
      // it should point exactly to the caret.
      controller = TextEditingController(text: List<String>.filled(200, 'a').join());
      await tester.pumpWidget(
        CupertinoApp(
          debugShowCheckedModeBanner: false,
          home: CupertinoPageScaffold(
            child: Align(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CupertinoTextField(
                  controller: controller,
                  maxLines: null,
                ),
              ),
            ),
          ),
        ),
      );

      state = tester.state<EditableTextState>(find.byType(EditableText));
      state.renderEditable.selectPositionAt(
        from: tester.getCenter(find.byType(EditableText)),
        cause: SelectionChangedCause.tap,
      );
      await tester.pumpAndSettle();

      bottomLeftSelectionPosition = textOffsetToBottomLeftPosition(tester, state.renderEditable.selection!.baseOffset);

      expect(
        find.byType(CupertinoTextSelectionToolbar),
        paints..clipPath(
          pathMatcher: PathPointsMatcher(
            includes: <Offset> [
              // Expected center of the arrow.
              bottomLeftSelectionPosition.translate(0, -lineHeight - 8 - 0.1),
            ],
          ),
        ),
      );

      expect(
        find.byType(CupertinoTextSelectionToolbar),
        paints..clipPath(
          pathMatcher: PathBoundsMatcher(
            bottomMatcher: moreOrLessEquals(bottomLeftSelectionPosition.dy - 8 - lineHeight, epsilon: 0.01),
            topMatcher: moreOrLessEquals(bottomLeftSelectionPosition.dy - 8 - lineHeight - 43, epsilon: 0.01),
            rightMatcher: lessThanOrEqualTo(400 - 8),
            leftMatcher: greaterThanOrEqualTo(8),
          ),
        ),
      );

      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    testWidgets('selecting multiple words works', (WidgetTester tester) async {
      EditableText.debugDeterministicCursor = true;
      tester.binding.window.physicalSizeTestValue = const Size(400, 400);
      tester.binding.window.devicePixelRatioTestValue = 1;
      final TextEditingController controller;
      final EditableTextState state;

      // Normal multiword collapsed selection. The toolbar arrow should point down, and
      // it should point exactly to the caret.
      controller = TextEditingController(text: List<String>.filled(20, 'a').join('  '));
      await tester.pumpWidget(
        CupertinoApp(
          debugShowCheckedModeBanner: false,
          home: CupertinoPageScaffold(
            child: Align(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CupertinoTextField(
                  controller: controller,
                  maxLines: null,
                ),
              ),
            ),
          ),
        ),
      );

      state = tester.state<EditableTextState>(find.byType(EditableText));
      final double lineHeight = state.renderEditable.preferredLineHeight;

      // Select the first 2 words.
      state.renderEditable.selectPositionAt(
        from: textOffsetToPosition(tester, 0),
        to: textOffsetToPosition(tester, 4),
        cause: SelectionChangedCause.tap,
      );
      expect(state.showToolbar(), true);
      await tester.pumpAndSettle();

      final Offset selectionPosition = (textOffsetToBottomLeftPosition(tester, 0) + textOffsetToBottomLeftPosition(tester, 4)) / 2;

      expect(
        find.byType(CupertinoTextSelectionToolbar),
        paints..clipPath(
          pathMatcher: PathPointsMatcher(
            includes: <Offset> [
              // Expected center of the arrow.
              selectionPosition.translate(0, -lineHeight - 8 - 0.1),
            ],
          ),
        ),
      );

      expect(
        find.byType(CupertinoTextSelectionToolbar),
        paints..clipPath(
          pathMatcher: PathBoundsMatcher(
            bottomMatcher: moreOrLessEquals(selectionPosition.dy - 8 - lineHeight, epsilon: 0.01),
            topMatcher: moreOrLessEquals(selectionPosition.dy - 8 - lineHeight - 43, epsilon: 0.01),
            rightMatcher: lessThanOrEqualTo(400 - 8),
            leftMatcher: greaterThanOrEqualTo(8),
          ),
        ),
      );

      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    testWidgets('selecting multiline works', (WidgetTester tester) async {
      EditableText.debugDeterministicCursor = true;
      tester.binding.window.physicalSizeTestValue = const Size(400, 400);
      tester.binding.window.devicePixelRatioTestValue = 1;
      final TextEditingController controller;
      final EditableTextState state;

      // Normal multiline collapsed selection. The toolbar arrow should point down, and
      // it should point exactly to the horizontal center of the text field.
      controller = TextEditingController(text: List<String>.filled(20, 'a  a  ').join('\n'));
      await tester.pumpWidget(
        CupertinoApp(
          debugShowCheckedModeBanner: false,
          home: CupertinoPageScaffold(
            child: Align(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CupertinoTextField(
                  controller: controller,
                  maxLines: null,
                ),
              ),
            ),
          ),
        ),
      );

      state = tester.state<EditableTextState>(find.byType(EditableText));
      final double lineHeight = state.renderEditable.preferredLineHeight;

      // Select the first 2 words.
      state.renderEditable.selectPositionAt(
        from: textOffsetToPosition(tester, 0),
        to: textOffsetToPosition(tester, 10),
        cause: SelectionChangedCause.tap,
      );
      expect(state.showToolbar(), true);
      await tester.pumpAndSettle();

      final Offset selectionPosition = Offset(
        // Toolbar should be centered.
        200,
        textOffsetToBottomLeftPosition(tester, 0).dy,
      );

      expect(
        find.byType(CupertinoTextSelectionToolbar),
        paints..clipPath(
          pathMatcher: PathPointsMatcher(
            includes: <Offset> [
              // Expected center of the arrow.
              selectionPosition.translate(0, -lineHeight - 8 - 0.1),
            ],
          ),
        ),
      );

      expect(
        find.byType(CupertinoTextSelectionToolbar),
        paints..clipPath(
          pathMatcher: PathBoundsMatcher(
            bottomMatcher: moreOrLessEquals(selectionPosition.dy - 8 - lineHeight, epsilon: 0.01),
            topMatcher: moreOrLessEquals(selectionPosition.dy - 8 - lineHeight - 43, epsilon: 0.01),
            rightMatcher: lessThanOrEqualTo(400 - 8),
            leftMatcher: greaterThanOrEqualTo(8),
          ),
        ),
      );

      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    // This is a regression test for
    // https://github.com/flutter/flutter/issues/37046.
    testWidgets('No exceptions when showing selection menu inside of nested Navigators', (WidgetTester tester) async {
      const String testValue = '123456';
      final TextEditingController controller = TextEditingController(
        text: testValue,
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: Column(
                children: <Widget>[
                  Container(
                    height: 100,
                    color: CupertinoColors.black,
                  ),
                  Expanded(
                    child: Navigator(
                      onGenerateRoute: (_) => CupertinoPageRoute<void>(
                        builder: (_) => CupertinoTextField(
                          controller: controller,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // No text selection toolbar.
      expect(find.byType(CupertinoTextSelectionToolbar), findsNothing);

      // Double tap on the text in the input.
      await tester.pumpAndSettle();
      await tester.tapAt(textOffsetToPosition(tester, testValue.length ~/ 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(textOffsetToPosition(tester, testValue.length ~/ 2));
      await tester.pumpAndSettle();

      // Now the text selection toolbar is showing and there were no exceptions.
      expect(find.byType(CupertinoTextSelectionToolbar), findsOneWidget);
      expect(tester.takeException(), null);
    });

    testWidgets('Drag selection hides the selection menu', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'blah1 blah2',
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              controller: controller,
            ),
          ),
        ),
      );

      // Initially, the menu is not shown and there is no selection.
      expect(controller.selection, const TextSelection(baseOffset: -1, extentOffset: -1));
      final Offset midBlah1 = textOffsetToPosition(tester, 2);
      final Offset midBlah2 = textOffsetToPosition(tester, 8);

      // Right click the second word.
      final TestGesture gesture = await tester.startGesture(
        midBlah2,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // The toolbar is shown.
      expect(find.text('Paste'), findsOneWidget);

      // Drag the mouse to the first word.
      final TestGesture gesture2 = await tester.startGesture(
        midBlah1,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture2.moveTo(midBlah2);
      await tester.pump();
      await gesture2.up();
      await tester.pumpAndSettle();

      // The toolbar is hidden.
      expect(find.text('Paste'), findsNothing);
    }, variant: TargetPlatformVariant.desktop());
  }, skip: isContextMenuProvidedByPlatform); // [intended] only applies to platforms where we supply the context menu.

  group('textAlignVertical position', () {
    group('simple case', () {
      testWidgets('align top (default)', (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        const Size size = Size(200.0, 200.0);
        await tester.pumpWidget(
          CupertinoApp(
            debugShowCheckedModeBanner: false,
            home: CupertinoPageScaffold(
              child: Align(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CupertinoTextField(
                    focusNode: focusNode,
                    expands: true,
                    maxLines: null,
                  ),
                ),
              ),
            ),
          ),
        );

        // Fills the whole container since expands is true.
        expect(tester.getSize(find.byType(CupertinoTextField)), size);

        // Tapping anywhere inside focuses it.
        expect(focusNode.hasFocus, false);
        await tester.tapAt(tester.getTopLeft(find.byType(CupertinoTextField)));
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, true);
        focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, false);
        final Offset justInside = tester
          .getBottomLeft(find.byType(CupertinoTextField))
          .translate(0.0, -1.0);
        await tester.tapAt(justInside);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(focusNode.hasFocus, true);

        // The EditableText is at the top.
        expect(tester.getTopLeft(find.byType(CupertinoTextField)).dy, moreOrLessEquals(size.height, epsilon: .0001));
        expect(tester.getTopLeft(find.byType(EditableText)).dy, moreOrLessEquals(207.0, epsilon: .0001));
      });

      testWidgets('align center', (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        const Size size = Size(200.0, 200.0);
        await tester.pumpWidget(
          CupertinoApp(
            debugShowCheckedModeBanner: false,
            home: CupertinoPageScaffold(
              child: Align(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CupertinoTextField(
                    textAlignVertical: TextAlignVertical.center,
                    focusNode: focusNode,
                    expands: true,
                    maxLines: null,
                  ),
                ),
              ),
            ),
          ),
        );

        // Fills the whole container since expands is true.
        expect(tester.getSize(find.byType(CupertinoTextField)), size);

        // Tapping anywhere inside focuses it.
        expect(focusNode.hasFocus, false);
        await tester.tapAt(tester.getTopLeft(find.byType(CupertinoTextField)));
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, true);
        focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, false);
        final Offset justInside = tester
          .getBottomLeft(find.byType(CupertinoTextField))
          .translate(0.0, -1.0);
        await tester.tapAt(justInside);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(focusNode.hasFocus, true);

        // The EditableText is at the center.
        expect(tester.getTopLeft(find.byType(CupertinoTextField)).dy, moreOrLessEquals(size.height, epsilon: .0001));
        expect(tester.getTopLeft(find.byType(EditableText)).dy, moreOrLessEquals(291.5, epsilon: .0001));
      });

      testWidgets('align bottom', (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        const Size size = Size(200.0, 200.0);
        await tester.pumpWidget(
          CupertinoApp(
            debugShowCheckedModeBanner: false,
            home: CupertinoPageScaffold(
              child: Align(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CupertinoTextField(
                    textAlignVertical: TextAlignVertical.bottom,
                    focusNode: focusNode,
                    expands: true,
                    maxLines: null,
                  ),
                ),
              ),
            ),
          ),
        );

        // Fills the whole container since expands is true.
        expect(tester.getSize(find.byType(CupertinoTextField)), size);

        // Tapping anywhere inside focuses it.
        expect(focusNode.hasFocus, false);
        await tester.tapAt(tester.getTopLeft(find.byType(CupertinoTextField)));
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, true);
        focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, false);
        final Offset justInside = tester
          .getBottomLeft(find.byType(CupertinoTextField))
          .translate(0.0, -1.0);
        await tester.tapAt(justInside);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(focusNode.hasFocus, true);

        // The EditableText is at the bottom.
        expect(tester.getTopLeft(find.byType(CupertinoTextField)).dy, moreOrLessEquals(size.height, epsilon: .0001));
        expect(tester.getTopLeft(find.byType(EditableText)).dy, moreOrLessEquals(376.0, epsilon: .0001));
      });

      testWidgets('align as a double', (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        const Size size = Size(200.0, 200.0);
        await tester.pumpWidget(
          CupertinoApp(
            debugShowCheckedModeBanner: false,
            home: CupertinoPageScaffold(
              child: Align(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CupertinoTextField(
                    textAlignVertical: const TextAlignVertical(y: 0.75),
                    focusNode: focusNode,
                    expands: true,
                    maxLines: null,
                  ),
                ),
              ),
            ),
          ),
        );

        // Fills the whole container since expands is true.
        expect(tester.getSize(find.byType(CupertinoTextField)), size);

        // Tapping anywhere inside focuses it.
        expect(focusNode.hasFocus, false);
        await tester.tapAt(tester.getTopLeft(find.byType(CupertinoTextField)));
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, true);
        focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, false);
        final Offset justInside = tester
          .getBottomLeft(find.byType(CupertinoTextField))
          .translate(0.0, -1.0);
        await tester.tapAt(justInside);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(focusNode.hasFocus, true);

        // The EditableText is near the bottom.
        expect(tester.getTopLeft(find.byType(CupertinoTextField)).dy, moreOrLessEquals(size.height, epsilon: .0001));
        expect(tester.getTopLeft(find.byType(EditableText)).dy, moreOrLessEquals(354.875, epsilon: .0001));
      });
    });

    group('tall prefix', () {
      testWidgets('align center (default when prefix)', (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        const Size size = Size(200.0, 200.0);
        await tester.pumpWidget(
          CupertinoApp(
            debugShowCheckedModeBanner: false,
            home: CupertinoPageScaffold(
              child: Align(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CupertinoTextField(
                    focusNode: focusNode,
                    expands: true,
                    maxLines: null,
                    prefix: const SizedBox(
                      height: 100,
                      width: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Fills the whole container since expands is true.
        expect(tester.getSize(find.byType(CupertinoTextField)), size);

        // Tapping anywhere inside focuses it. This includes tapping on the
        // prefix, because in this case it is transparent.
        expect(focusNode.hasFocus, false);
        await tester.tapAt(tester.getTopLeft(find.byType(CupertinoTextField)));
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, true);
        focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, false);
        final Offset justInside = tester
          .getBottomLeft(find.byType(CupertinoTextField))
          .translate(0.0, -1.0);
        await tester.tapAt(justInside);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(focusNode.hasFocus, true);

        // The EditableText is at the center. Same as without prefix.
        expect(tester.getTopLeft(find.byType(CupertinoTextField)).dy, moreOrLessEquals(size.height, epsilon: .0001));
        expect(tester.getTopLeft(find.byType(EditableText)).dy, moreOrLessEquals(291.5, epsilon: .0001));
      });

      testWidgets('align top', (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        const Size size = Size(200.0, 200.0);
        await tester.pumpWidget(
          CupertinoApp(
            debugShowCheckedModeBanner: false,
            home: CupertinoPageScaffold(
              child: Align(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CupertinoTextField(
                    textAlignVertical: TextAlignVertical.top,
                    focusNode: focusNode,
                    expands: true,
                    maxLines: null,
                    prefix: const SizedBox(
                      height: 100,
                      width: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Fills the whole container since expands is true.
        expect(tester.getSize(find.byType(CupertinoTextField)), size);

        // Tapping anywhere inside focuses it. This includes tapping on the
        // prefix, because in this case it is transparent.
        expect(focusNode.hasFocus, false);
        await tester.tapAt(tester.getTopLeft(find.byType(CupertinoTextField)));
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, true);
        focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, false);
        final Offset justInside = tester
          .getBottomLeft(find.byType(CupertinoTextField))
          .translate(0.0, -1.0);
        await tester.tapAt(justInside);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(focusNode.hasFocus, true);

        // The prefix is at the top, and the EditableText is centered within its
        // height.
        expect(tester.getTopLeft(find.byType(CupertinoTextField)).dy, moreOrLessEquals(size.height, epsilon: .0001));
        expect(tester.getTopLeft(find.byType(EditableText)).dy, moreOrLessEquals(241.5, epsilon: .0001));
      });

      testWidgets('align bottom', (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        const Size size = Size(200.0, 200.0);
        await tester.pumpWidget(
          CupertinoApp(
            debugShowCheckedModeBanner: false,
            home: CupertinoPageScaffold(
              child: Align(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CupertinoTextField(
                    textAlignVertical: TextAlignVertical.bottom,
                    focusNode: focusNode,
                    expands: true,
                    maxLines: null,
                    prefix: const SizedBox(
                      height: 100,
                      width: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Fills the whole container since expands is true.
        expect(tester.getSize(find.byType(CupertinoTextField)), size);

        // Tapping anywhere inside focuses it. This includes tapping on the
        // prefix, because in this case it is transparent.
        expect(focusNode.hasFocus, false);
        await tester.tapAt(tester.getTopLeft(find.byType(CupertinoTextField)));
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, true);
        focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, false);
        final Offset justInside = tester
          .getBottomLeft(find.byType(CupertinoTextField))
          .translate(0.0, -1.0);
        await tester.tapAt(justInside);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(focusNode.hasFocus, true);

        // The prefix is at the bottom, and the EditableText is centered within
        // its height.
        expect(tester.getTopLeft(find.byType(CupertinoTextField)).dy, moreOrLessEquals(size.height, epsilon: .0001));
        expect(tester.getTopLeft(find.byType(EditableText)).dy, moreOrLessEquals(341.5, epsilon: .0001));
      });

      testWidgets('align as a double', (WidgetTester tester) async {
        final FocusNode focusNode = FocusNode();
        const Size size = Size(200.0, 200.0);
        await tester.pumpWidget(
          CupertinoApp(
            debugShowCheckedModeBanner: false,
            home: CupertinoPageScaffold(
              child: Align(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CupertinoTextField(
                    textAlignVertical: const TextAlignVertical(y: 0.75),
                    focusNode: focusNode,
                    expands: true,
                    maxLines: null,
                    prefix: const SizedBox(
                      height: 100,
                      width: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Fills the whole container since expands is true.
        expect(tester.getSize(find.byType(CupertinoTextField)), size);

        // Tapping anywhere inside focuses it. This includes tapping on the
        // prefix, because in this case it is transparent.
        expect(focusNode.hasFocus, false);
        await tester.tapAt(tester.getTopLeft(find.byType(CupertinoTextField)));
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, true);
        focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, false);
        final Offset justInside = tester
          .getBottomLeft(find.byType(CupertinoTextField))
          .translate(0.0, -1.0);
        await tester.tapAt(justInside);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(focusNode.hasFocus, true);

        // The EditableText is near the bottom.
        expect(tester.getTopLeft(find.byType(CupertinoTextField)).dy, moreOrLessEquals(size.height, epsilon: .0001));
        expect(tester.getTopLeft(find.byType(EditableText)).dy, moreOrLessEquals(329.0, epsilon: .0001));
      });
    });

    testWidgets(
      'Long press on an autofocused field shows the selection menu',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          CupertinoApp(
            home: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints.loose(const Size(200, 200)),
                child: const CupertinoTextField(
                  autofocus: true,
                ),
              ),
            ),
          ),
        );
        // This extra pump allows the selection set by autofocus to propagate to
        // the RenderEditable.
        await tester.pump();

        // Long press shows the selection menu.
        await tester.longPressAt(textOffsetToPosition(tester, 0));
        await tester.pumpAndSettle();
        expect(find.text('Paste'), isContextMenuProvidedByPlatform ? findsNothing : findsOneWidget);
      },
    );
  });

  testWidgets("Arrow keys don't move input focus", (WidgetTester tester) async {
    final TextEditingController controller1 = TextEditingController();
    final TextEditingController controller2 = TextEditingController();
    final TextEditingController controller3 = TextEditingController();
    final TextEditingController controller4 = TextEditingController();
    final TextEditingController controller5 = TextEditingController();
    final FocusNode focusNode1 = FocusNode(debugLabel: 'Field 1');
    final FocusNode focusNode2 = FocusNode(debugLabel: 'Field 2');
    final FocusNode focusNode3 = FocusNode(debugLabel: 'Field 3');
    final FocusNode focusNode4 = FocusNode(debugLabel: 'Field 4');
    final FocusNode focusNode5 = FocusNode(debugLabel: 'Field 5');

    // Lay out text fields in a "+" formation, and focus the center one.
    await tester.pumpWidget(CupertinoApp(
      home: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 100.0,
                child: CupertinoTextField(
                  controller: controller1,
                  focusNode: focusNode1,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 100.0,
                    child: CupertinoTextField(
                      controller: controller2,
                      focusNode: focusNode2,
                    ),
                  ),
                  SizedBox(
                    width: 100.0,
                    child: CupertinoTextField(
                      controller: controller3,
                      focusNode: focusNode3,
                    ),
                  ),
                  SizedBox(
                    width: 100.0,
                    child: CupertinoTextField(
                      controller: controller4,
                      focusNode: focusNode4,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 100.0,
                child: CupertinoTextField(
                  controller: controller5,
                  focusNode: focusNode5,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    focusNode3.requestFocus();
    await tester.pump();
    expect(focusNode3.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focusNode3.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focusNode3.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(focusNode3.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focusNode3.hasPrimaryFocus, isTrue);
  }, variant: KeySimulatorTransitModeVariant.all());

  testWidgets('Scrolling shortcuts are disabled in text fields', (WidgetTester tester) async {
    bool scrollInvoked = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: Actions(
          actions: <Type, Action<Intent>>{
            ScrollIntent: CallbackAction<ScrollIntent>(onInvoke: (Intent intent) {
              scrollInvoked = true;
              return null;
            }),
          },
          child: ListView(
            children: const <Widget>[
              Padding(padding: EdgeInsets.symmetric(vertical: 200)),
              CupertinoTextField(),
              Padding(padding: EdgeInsets.symmetric(vertical: 800)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(scrollInvoked, isFalse);

    // Set focus on the text field.
    await tester.tapAt(tester.getTopLeft(find.byType(CupertinoTextField)));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(scrollInvoked, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(scrollInvoked, isFalse);
  }, variant: KeySimulatorTransitModeVariant.all());

  testWidgets('Cupertino text field semantics', (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints.loose(const Size(200, 200)),
            child: const CupertinoTextField(),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byType(CupertinoTextField),
          matching: find.byType(Semantics),
        ).first,
      ),
      matchesSemantics(
        isTextField: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('Disabled Cupertino text field semantics', (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints.loose(const Size(200, 200)),
            child: const CupertinoTextField(
              enabled: false,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byType(CupertinoTextField),
          matching: find.byType(Semantics),
        ).first,
      ),
      matchesSemantics(
        hasEnabledState: true,
      ),
    );
  });

  testWidgets('text selection style 1', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure\nhi\nwassssup!',
    );
    await tester.pumpWidget(
       CupertinoApp(
        home: Center(
          child: RepaintBoundary(
            child: Container(
              width: 650.0,
              height: 600.0,
              decoration: const BoxDecoration(
                color: Color(0xff00ff00),
              ),
              child: Column(
                children: <Widget>[
                  CupertinoTextField(
                    key: const Key('field0'),
                    controller: controller,
                    style: const TextStyle(height: 4, color: ui.Color.fromARGB(100, 0, 0, 0)),
                    toolbarOptions: const ToolbarOptions(selectAll: true),
                    selectionHeightStyle: ui.BoxHeightStyle.includeLineSpacingTop,
                    selectionWidthStyle: ui.BoxWidthStyle.max,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final Offset textFieldStart = tester.getTopLeft(find.byKey(const Key('field0')));

    await tester.longPressAt(textFieldStart + const Offset(50.0, 2.0));
    await tester.pump(const Duration(milliseconds: 150));
    // Tap the Select All button.
    await tester.tapAt(textFieldStart + const Offset(20.0, 100.0));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('text_field_golden.TextSelectionStyle.1.png'),
    );
  },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS }),
    skip: kIsWeb, // [intended] the web has its own Select All.
  );

  testWidgets('text selection style 2', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure\nhi\nwassssup!',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: RepaintBoundary(
            child: Container(
              width: 650.0,
              height: 600.0,
              decoration: const BoxDecoration(
                color: Color(0xff00ff00),
              ),
              child: Column(
                children: <Widget>[
                  CupertinoTextField(
                    key: const Key('field0'),
                    controller: controller,
                    style: const TextStyle(height: 4, color: ui.Color.fromARGB(100, 0, 0, 0)),
                    toolbarOptions: const ToolbarOptions(selectAll: true),
                    selectionHeightStyle: ui.BoxHeightStyle.includeLineSpacingBottom,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final Offset textFieldStart = tester.getTopLeft(find.byKey(const Key('field0')));

    await tester.longPressAt(textFieldStart + const Offset(50.0, 2.0));
    await tester.pump(const Duration(milliseconds: 150));
    // Tap the Select All button.
    await tester.tapAt(textFieldStart + const Offset(20.0, 100.0));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('text_field_golden.TextSelectionStyle.2.png'),
    );
  },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS }),
    skip: kIsWeb, // [intended] the web has its own Select All.
  );

  testWidgets('textSelectionControls is passed to EditableText', (WidgetTester tester) async {
    final MockTextSelectionControls selectionControl = MockTextSelectionControls();
    await tester.pumpWidget(
       CupertinoApp(
        home: Center(
          child: CupertinoTextField(
              selectionControls: selectionControl,
            ),
          ),
        ),
      );

    final EditableText widget = tester.widget(find.byType(EditableText));
    expect(widget.selectionControls, equals(selectionControl));
  });

  testWidgets('Do not add LengthLimiting formatter to the user supplied list', (WidgetTester tester) async {
    final List<TextInputFormatter> formatters = <TextInputFormatter>[];

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoTextField(maxLength: 5, inputFormatters: formatters),
      ),
    );

    expect(formatters.isEmpty, isTrue);
  });

  group('MaxLengthEnforcement', () {
    const int maxLength = 5;

    Future<void> setupWidget(
      WidgetTester tester,
      MaxLengthEnforcement? enforcement,
    ) async {

      final Widget widget = CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            maxLength: maxLength,
            maxLengthEnforcement: enforcement,
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
    }

    testWidgets('using none enforcement.', (WidgetTester tester) async {
      const MaxLengthEnforcement enforcement = MaxLengthEnforcement.none;

      await setupWidget(tester, enforcement);

      final EditableTextState state = tester.state(find.byType(EditableText));

      state.updateEditingValue(const TextEditingValue(text: 'abc'));
      expect(state.currentTextEditingValue.text, 'abc');
      expect(state.currentTextEditingValue.composing, TextRange.empty);

      state.updateEditingValue(const TextEditingValue(text: 'abcdef', composing: TextRange(start: 3, end: 6)));
      expect(state.currentTextEditingValue.text, 'abcdef');
      expect(state.currentTextEditingValue.composing, const TextRange(start: 3, end: 6));

      state.updateEditingValue(const TextEditingValue(text: 'abcdef'));
      expect(state.currentTextEditingValue.text, 'abcdef');
      expect(state.currentTextEditingValue.composing, TextRange.empty);
    });

    testWidgets('using enforced.', (WidgetTester tester) async {
      const MaxLengthEnforcement enforcement = MaxLengthEnforcement.enforced;

      await setupWidget(tester, enforcement);

      final EditableTextState state = tester.state(find.byType(EditableText));

      state.updateEditingValue(const TextEditingValue(text: 'abc'));
      expect(state.currentTextEditingValue.text, 'abc');
      expect(state.currentTextEditingValue.composing, TextRange.empty);

      state.updateEditingValue(const TextEditingValue(text: 'abcde', composing: TextRange(start: 3, end: 5)));
      expect(state.currentTextEditingValue.text, 'abcde');
      expect(state.currentTextEditingValue.composing, const TextRange(start: 3, end: 5));

      state.updateEditingValue(const TextEditingValue(text: 'abcdef', composing: TextRange(start: 3, end: 6)));
      expect(state.currentTextEditingValue.text, 'abcde');
      expect(state.currentTextEditingValue.composing, const TextRange(start: 3, end: 5));

      state.updateEditingValue(const TextEditingValue(text: 'abcdef'));
      expect(state.currentTextEditingValue.text, 'abcde');
      expect(state.currentTextEditingValue.composing, const TextRange(start: 3, end: 5));
    });

    testWidgets('using truncateAfterCompositionEnds.', (WidgetTester tester) async {
      const MaxLengthEnforcement enforcement = MaxLengthEnforcement.truncateAfterCompositionEnds;

      await setupWidget(tester, enforcement);

      final EditableTextState state = tester.state(find.byType(EditableText));

      state.updateEditingValue(const TextEditingValue(text: 'abc'));
      expect(state.currentTextEditingValue.text, 'abc');
      expect(state.currentTextEditingValue.composing, TextRange.empty);

      state.updateEditingValue(const TextEditingValue(text: 'abcde', composing: TextRange(start: 3, end: 5)));
      expect(state.currentTextEditingValue.text, 'abcde');
      expect(state.currentTextEditingValue.composing, const TextRange(start: 3, end: 5));

      state.updateEditingValue(const TextEditingValue(text: 'abcdef', composing: TextRange(start: 3, end: 6)));
      expect(state.currentTextEditingValue.text, 'abcdef');
      expect(state.currentTextEditingValue.composing, const TextRange(start: 3, end: 6));

      state.updateEditingValue(const TextEditingValue(text: 'abcdef'));
      expect(state.currentTextEditingValue.text, 'abcde');
      expect(state.currentTextEditingValue.composing, TextRange.empty);
    });

    testWidgets('using default behavior for different platforms.', (WidgetTester tester) async {
      await setupWidget(tester, null);

      final EditableTextState state = tester.state(find.byType(EditableText));

      state.updateEditingValue(const TextEditingValue(text: '侬好啊'));
      expect(state.currentTextEditingValue.text, '侬好啊');
      expect(state.currentTextEditingValue.composing, TextRange.empty);

      state.updateEditingValue(const TextEditingValue(text: '侬好啊旁友', composing: TextRange(start: 3, end: 5)));
      expect(state.currentTextEditingValue.text, '侬好啊旁友');
      expect(state.currentTextEditingValue.composing, const TextRange(start: 3, end: 5));

      state.updateEditingValue(const TextEditingValue(text: '侬好啊旁友们', composing: TextRange(start: 3, end: 6)));
      if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.fuchsia
      ) {
        expect(state.currentTextEditingValue.text, '侬好啊旁友们');
        expect(state.currentTextEditingValue.composing, const TextRange(start: 3, end: 6));
      } else {
        expect(state.currentTextEditingValue.text, '侬好啊旁友');
        expect(state.currentTextEditingValue.composing, const TextRange(start: 3, end: 5));
      }

      state.updateEditingValue(const TextEditingValue(text: '侬好啊旁友'));
      expect(state.currentTextEditingValue.text, '侬好啊旁友');
      expect(state.currentTextEditingValue.composing, TextRange.empty);
    });
  });

  testWidgets('disabled widget changes background color', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            enabled: false,
          ),
        ),
      ),
    );

    BoxDecoration decoration = tester
        .widget<DecoratedBox>(
          find.descendant(
            of: find.byType(CupertinoTextField),
            matching: find.byType(DecoratedBox),
          ),
        )
        .decoration as BoxDecoration;

    expect(
      decoration.color!.value,
      0xFFFAFAFA,
    );

    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            enabled: true,
          ),
        ),
      ),
    );

    decoration = tester
        .widget<DecoratedBox>(
          find.descendant(
            of: find.byType(CupertinoTextField),
            matching: find.byType(DecoratedBox),
          ),
        )
        .decoration as BoxDecoration;

    expect(
      decoration.color!.value,
      CupertinoColors.white.value,
    );

    await tester.pumpWidget(
      const CupertinoApp(
        theme: CupertinoThemeData(
          brightness: Brightness.dark,
        ),
        home: Center(
          child: CupertinoTextField(
            enabled: false,
          ),
        ),
      ),
    );

    decoration = tester
        .widget<DecoratedBox>(
          find.descendant(
            of: find.byType(CupertinoTextField),
            matching: find.byType(DecoratedBox),
          ),
        )
        .decoration as BoxDecoration;

    expect(
      decoration.color!.value,
      0xFF050505,
    );
  });

  // Regression test for https://github.com/flutter/flutter/issues/78097.
  testWidgets(
    'still gets disabled background color when decoration is null',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              decoration: null,
              enabled: false,
            ),
          ),
        ),
      );

      final Color disabledColor = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(CupertinoTextField),
          matching: find.byType(ColoredBox),
        ),
      ).color;
      expect(disabledColor, isSameColorAs(const Color(0xFFFAFAFA)));
    },
  );

  testWidgets('autofill info has placeholder text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoTextField(
          placeholder: 'placeholder text',
        ),
      ),
    );
    await tester.tap(find.byType(CupertinoTextField));

    expect(
      tester.testTextInput.setClientArgs?['autofill'],
      containsPair('hintText', 'placeholder text'),
    );
  });

  testWidgets('textDirection is passed to EditableText', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );

    final EditableText ltrWidget = tester.widget(find.byType(EditableText));
    expect(ltrWidget.textDirection, TextDirection.ltr);

    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );

    final EditableText rtlWidget = tester.widget(find.byType(EditableText));
    expect(rtlWidget.textDirection, TextDirection.rtl);
  });

  testWidgets('clipBehavior has expected defaults', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoTextField(
        ),
      ),
    );

    final CupertinoTextField textField = tester.firstWidget(find.byType(CupertinoTextField));
    expect(textField.clipBehavior, Clip.hardEdge);
  });

  testWidgets('Overflow clipBehavior none golden', (WidgetTester tester) async {
    final Widget widget = CupertinoApp(
      home: RepaintBoundary(
        key: const ValueKey<int>(1),
        child: SizedBox(
          height: 200.0,
          width: 200.0,
          child: Center(
            child: SizedBox(
              // Make sure the input field is not high enough for the WidgetSpan.
              height: 50,
              child: CupertinoTextField(
                controller: OverflowWidgetTextEditingController(),
                clipBehavior: Clip.none,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(widget);

    final CupertinoTextField textField = tester.firstWidget(find.byType(CupertinoTextField));
    expect(textField.clipBehavior, Clip.none);

    final EditableText editableText = tester.firstWidget(find.byType(EditableText));
    expect(editableText.clipBehavior, Clip.none);

    await expectLater(
      find.byKey(const ValueKey<int>(1)),
      matchesGoldenFile('overflow_clipbehavior_none.cupertino.0.png'),
    );
  });

  testWidgets('can shift + tap to select with a keyboard (Apple platforms)', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    await tester.tapAt(textOffsetToPosition(tester, 13));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 13);
    expect(controller.selection.extentOffset, 13);

    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.tapAt(textOffsetToPosition(tester, 20));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 13);
    expect(controller.selection.extentOffset, 20);

    await tester.pump(kDoubleTapTimeout);
    await tester.tapAt(textOffsetToPosition(tester, 23));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 13);
    expect(controller.selection.extentOffset, 23);

    await tester.pump(kDoubleTapTimeout);
    await tester.tapAt(textOffsetToPosition(tester, 4));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 4);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 4);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets('can shift + tap to select with a keyboard (non-Apple platforms)', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    await tester.tapAt(textOffsetToPosition(tester, 13));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 13);
    expect(controller.selection.extentOffset, 13);

    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.tapAt(textOffsetToPosition(tester, 20));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 13);
    expect(controller.selection.extentOffset, 20);

    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.tapAt(textOffsetToPosition(tester, 23));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 13);
    expect(controller.selection.extentOffset, 23);

    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.tapAt(textOffsetToPosition(tester, 4));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 13);
    expect(controller.selection.extentOffset, 4);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    expect(controller.selection.baseOffset, 13);
    expect(controller.selection.extentOffset, 4);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.android, TargetPlatform.fuchsia, TargetPlatform.linux, TargetPlatform.windows }));

  testWidgets('shift tapping an unfocused field', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    final FocusNode focusNode = FocusNode();
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      ),
    );

    expect(focusNode.hasFocus, isFalse);

    // Put the cursor at the end of the field.
    await tester.tapAt(textOffsetToPosition(tester, controller.text.length));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    expect(controller.selection.baseOffset, 35);
    expect(controller.selection.extentOffset, 35);

    // Unfocus the field, but the selection remains.
    focusNode.unfocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
    expect(controller.selection.baseOffset, 35);
    expect(controller.selection.extentOffset, 35);

    // Shift tap in the middle of the field.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.tapAt(textOffsetToPosition(tester, 20));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    switch (defaultTargetPlatform) {
      // Apple platforms start the selection from 0.
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        expect(controller.selection.baseOffset, 0);
        break;

      // Other platforms start from the previous selection.
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        expect(controller.selection.baseOffset, 35);
        break;
    }
    expect(controller.selection.extentOffset, 20);
  }, variant: TargetPlatformVariant.all());

  testWidgets('can shift + tap + drag to select with a keyboard (Apple platforms)', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.iOS;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    await tester.tapAt(textOffsetToPosition(tester, 8));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 8);

    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    final TestGesture gesture =
        await tester.startGesture(
          textOffsetToPosition(tester, 23),
          pointer: 7,
          kind: PointerDeviceKind.mouse,
        );
    if (isTargetPlatformMobile) {
      await gesture.up();
    }
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 23);

    // Expand the selection a bit.
    if (isTargetPlatformMobile) {
      await gesture.down(textOffsetToPosition(tester, 24));
    }
    await gesture.moveTo(textOffsetToPosition(tester, 28));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 28);

    // Move back to the original selection.
    await gesture.moveTo(textOffsetToPosition(tester, 23));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 23);

    // Collapse the selection.
    await gesture.moveTo(textOffsetToPosition(tester, 8));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 8);

    // Invert the selection. The base jumps to the original extent.
    await gesture.moveTo(textOffsetToPosition(tester, 7));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 7);

    // Continuing to move in the inverted direction expands the selection.
    await gesture.moveTo(textOffsetToPosition(tester, 4));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 4);

    // Move back to the original base.
    await gesture.moveTo(textOffsetToPosition(tester, 8));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 8);

    // Continue to move past the original base, which will cause the selection
    // to invert back to the original orientation.
    await gesture.moveTo(textOffsetToPosition(tester, 9));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 9);

    // Continuing to select in this direction selects just like it did
    // originally.
    await gesture.moveTo(textOffsetToPosition(tester, 24));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 24);

    // Releasing the shift key has no effect; the selection continues as the
    // mouse continues to move.
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 24);
    await gesture.moveTo(textOffsetToPosition(tester, 26));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 26);

    await gesture.up();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 26);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets('can shift + tap + drag to select with a keyboard (non-Apple platforms)', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.android
        || defaultTargetPlatform == TargetPlatform.fuchsia;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    await tester.tapAt(textOffsetToPosition(tester, 8));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 8);

    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    final TestGesture gesture =
        await tester.startGesture(
          textOffsetToPosition(tester, 23),
          pointer: 7,
          kind: PointerDeviceKind.mouse,
        );
    if (isTargetPlatformMobile) {
      await gesture.up();
    }
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 23);

    // Expand the selection a bit.
    if (isTargetPlatformMobile) {
      await gesture.down(textOffsetToPosition(tester, 24));
    }
    await gesture.moveTo(textOffsetToPosition(tester, 28));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 28);

    // Move back to the original selection.
    await gesture.moveTo(textOffsetToPosition(tester, 23));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 23);

    // Collapse the selection.
    await gesture.moveTo(textOffsetToPosition(tester, 8));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 8);

    // Invert the selection. The original selection is not restored like on iOS
    // and Mac.
    await gesture.moveTo(textOffsetToPosition(tester, 7));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 7);

    // Continuing to move in the inverted direction expands the selection.
    await gesture.moveTo(textOffsetToPosition(tester, 4));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 4);

    // Move back to the original base.
    await gesture.moveTo(textOffsetToPosition(tester, 8));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 8);

    // Continue to move past the original base.
    await gesture.moveTo(textOffsetToPosition(tester, 9));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 9);

    // Continuing to select in this direction selects just like it did
    // originally.
    await gesture.moveTo(textOffsetToPosition(tester, 24));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 24);

    // Releasing the shift key has no effect; the selection continues as the
    // mouse continues to move.
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 24);
    await gesture.moveTo(textOffsetToPosition(tester, 26));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 26);

    await gesture.up();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 26);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.linux,  TargetPlatform.android, TargetPlatform.fuchsia, TargetPlatform.windows }));

  testWidgets('can shift + tap + drag to select with a keyboard, reversed (Apple platforms)', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.iOS;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    // Make a selection from right to left.
    await tester.tapAt(textOffsetToPosition(tester, 23));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 23);
    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    final TestGesture gesture =
        await tester.startGesture(
          textOffsetToPosition(tester, 8),
          pointer: 7,
          kind: PointerDeviceKind.mouse,
        );
    if (isTargetPlatformMobile) {
      await gesture.up();
    }
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 8);

    // Expand the selection a bit.
    if (isTargetPlatformMobile) {
      await gesture.down(textOffsetToPosition(tester, 7));
    }
    await gesture.moveTo(textOffsetToPosition(tester, 5));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 5);

    // Move back to the original selection.
    await gesture.moveTo(textOffsetToPosition(tester, 8));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 8);

    // Collapse the selection.
    await gesture.moveTo(textOffsetToPosition(tester, 23));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 23);

    // Invert the selection. The base jumps to the original extent.
    await gesture.moveTo(textOffsetToPosition(tester, 24));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 24);

    // Continuing to move in the inverted direction expands the selection.
    await gesture.moveTo(textOffsetToPosition(tester, 27));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 27);

    // Move back to the original base.
    await gesture.moveTo(textOffsetToPosition(tester, 23));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 8);
    expect(controller.selection.extentOffset, 23);

    // Continue to move past the original base, which will cause the selection
    // to invert back to the original orientation.
    await gesture.moveTo(textOffsetToPosition(tester, 22));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 22);

    // Continuing to select in this direction selects just like it did
    // originally.
    await gesture.moveTo(textOffsetToPosition(tester, 16));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 16);

    // Releasing the shift key has no effect; the selection continues as the
    // mouse continues to move.
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 16);
    await gesture.moveTo(textOffsetToPosition(tester, 14));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 14);

    await gesture.up();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 14);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets('can shift + tap + drag to select with a keyboard, reversed (non-Apple platforms)', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'Atwater Peel Sherbrooke Bonaventure',
    );
    final bool isTargetPlatformMobile = defaultTargetPlatform == TargetPlatform.android
        || defaultTargetPlatform == TargetPlatform.fuchsia;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    // Make a selection from right to left.
    await tester.tapAt(textOffsetToPosition(tester, 23));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 23);
    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    final TestGesture gesture =
        await tester.startGesture(
          textOffsetToPosition(tester, 8),
          pointer: 7,
          kind: PointerDeviceKind.mouse,
        );
    if (isTargetPlatformMobile) {
      await gesture.up();
    }
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 8);

    // Expand the selection a bit.
    if (isTargetPlatformMobile) {
      await gesture.down(textOffsetToPosition(tester, 7));
    }
    await gesture.moveTo(textOffsetToPosition(tester, 5));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 5);

    // Move back to the original selection.
    await gesture.moveTo(textOffsetToPosition(tester, 8));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 8);

    // Collapse the selection.
    await gesture.moveTo(textOffsetToPosition(tester, 23));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 23);

    // Invert the selection. The selection is not restored like it would be on
    // iOS and Mac.
    await gesture.moveTo(textOffsetToPosition(tester, 24));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 24);

    // Continuing to move in the inverted direction expands the selection.
    await gesture.moveTo(textOffsetToPosition(tester, 27));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 27);

    // Move back to the original base.
    await gesture.moveTo(textOffsetToPosition(tester, 23));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 23);

    // Continue to move past the original base.
    await gesture.moveTo(textOffsetToPosition(tester, 22));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 22);

    // Continuing to select in this direction selects just like it did
    // originally.
    await gesture.moveTo(textOffsetToPosition(tester, 16));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 16);

    // Releasing the shift key has no effect; the selection continues as the
    // mouse continues to move.
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 16);
    await gesture.moveTo(textOffsetToPosition(tester, 14));
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 14);

    await gesture.up();
    expect(controller.selection.baseOffset, 23);
    expect(controller.selection.extentOffset, 14);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.linux,  TargetPlatform.android, TargetPlatform.fuchsia, TargetPlatform.windows }));

  // Regression test for https://github.com/flutter/flutter/issues/101587.
  testWidgets('Right clicking menu behavior', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(
      text: 'blah1 blah2',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            controller: controller,
          ),
        ),
      ),
    );

    // Initially, the menu is not shown and there is no selection.
    expect(find.byType(CupertinoButton), findsNothing);
    expect(controller.selection, const TextSelection(baseOffset: -1, extentOffset: -1));

    final Offset midBlah1 = textOffsetToPosition(tester, 2);
    final Offset midBlah2 = textOffsetToPosition(tester, 8);

    // Right click the second word.
    final TestGesture gesture = await tester.startGesture(
      midBlah2,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        expect(controller.selection, const TextSelection(baseOffset: 6, extentOffset: 11));
        expect(find.text('Cut'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Paste'), findsOneWidget);
        break;

      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        expect(controller.selection, const TextSelection.collapsed(offset: 8));
        expect(find.text('Cut'), findsNothing);
        expect(find.text('Copy'), findsNothing);
        expect(find.text('Paste'), findsOneWidget);
        break;
    }

    // Right click the first word.
    await gesture.down(midBlah1);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
        expect(find.text('Cut'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Paste'), findsOneWidget);
        break;

      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        expect(controller.selection, const TextSelection.collapsed(offset: 8));
        expect(find.text('Cut'), findsNothing);
        expect(find.text('Copy'), findsNothing);
        expect(find.text('Paste'), findsNothing);
        break;
    }
  },
    variant: TargetPlatformVariant.all(),
    skip: isContextMenuProvidedByPlatform, // [intended] only applies to platforms where we supply the context menu.
  );

  group('Right click focus', () {
    testWidgets('Can right click to focus multiple times', (WidgetTester tester) async {
      // Regression test for https://github.com/flutter/flutter/pull/103228
      final FocusNode focusNode1 = FocusNode();
      final FocusNode focusNode2 = FocusNode();
      final UniqueKey key1 = UniqueKey();
      final UniqueKey key2 = UniqueKey();
      await tester.pumpWidget(
        CupertinoApp(
          home: Column(
            children: <Widget>[
              CupertinoTextField(
                key: key1,
                focusNode: focusNode1,
              ),
              // This spacer prevents the context menu in one field from
              // overlapping with the other field.
              const SizedBox(height: 100.0),
              CupertinoTextField(
                key: key2,
                focusNode: focusNode2,
              ),
            ],
          ),
        ),
      );

      // Interact with the field to establish the input connection.
      await tester.tapAt(
        tester.getCenter(find.byKey(key1)),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(focusNode1.hasFocus, isTrue);
      expect(focusNode2.hasFocus, isFalse);

      await tester.tapAt(
        tester.getCenter(find.byKey(key2)),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(focusNode1.hasFocus, isFalse);
      expect(focusNode2.hasFocus, isTrue);

      await tester.tapAt(
        tester.getCenter(find.byKey(key1)),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(focusNode1.hasFocus, isTrue);
      expect(focusNode2.hasFocus, isFalse);
    });

    testWidgets('Can right click to focus on previously selected word on Apple platforms', (WidgetTester tester) async {
      final FocusNode focusNode1 = FocusNode();
      final FocusNode focusNode2 = FocusNode();
      final TextEditingController controller = TextEditingController(
        text: 'first second',
      );
      final UniqueKey key1 = UniqueKey();
      await tester.pumpWidget(
        CupertinoApp(
          home: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CupertinoTextField(
                key: key1,
                controller: controller,
                focusNode: focusNode1,
              ),
              Focus(
                focusNode: focusNode2,
                child: const Text('focusable'),
              ),
            ],
          ),
        ),
      );

      // Interact with the field to establish the input connection.
      await tester.tapAt(
        tester.getCenter(find.byKey(key1)),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(focusNode1.hasFocus, isTrue);
      expect(focusNode2.hasFocus, isFalse);

      // Select the second word.
      controller.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 12,
      );
      await tester.pump();

      expect(focusNode1.hasFocus, isTrue);
      expect(focusNode2.hasFocus, isFalse);
      expect(controller.selection.isCollapsed, isFalse);
      expect(controller.selection.baseOffset, 6);
      expect(controller.selection.extentOffset, 12);

      // Unfocus the first field.
      focusNode2.requestFocus();
      await tester.pumpAndSettle();

      expect(focusNode1.hasFocus, isFalse);
      expect(focusNode2.hasFocus, isTrue);

      // Right click the second word in the first field, which is still selected
      // even though the selection is not visible.
      await tester.tapAt(
        textOffsetToPosition(tester, 8),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(focusNode1.hasFocus, isTrue);
      expect(focusNode2.hasFocus, isFalse);
      expect(controller.selection.baseOffset, 6);
      expect(controller.selection.extentOffset, 12);

      // Select everything.
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 12,
      );
      await tester.pump();

      expect(focusNode1.hasFocus, isTrue);
      expect(focusNode2.hasFocus, isFalse);
      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, 12);

      // Unfocus the first field.
      focusNode2.requestFocus();
      await tester.pumpAndSettle();

      // Right click the first word in the first field.
      await tester.tapAt(
        textOffsetToPosition(tester, 2),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(focusNode1.hasFocus, isTrue);
      expect(focusNode2.hasFocus, isFalse);
      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, 5);
    }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }));
  });

  group('context menu', () {
    testWidgets('builds CupertinoAdaptiveTextSelectionToolbar by default', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: '');
      await tester.pumpWidget(
        CupertinoApp(
          home: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CupertinoTextField(
                controller: controller,
              ),
            ],
          ),
        ),
      );

      await tester.pump(); // Wait for autofocus to take effect.

      expect(find.byType(CupertinoAdaptiveTextSelectionToolbar), findsNothing);

      // Long-press to bring up the context menu.
      final Finder textFinder = find.byType(EditableText);
      await tester.longPress(textFinder);
      tester.state<EditableTextState>(textFinder).showToolbar();
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAdaptiveTextSelectionToolbar), findsOneWidget);
    },
      skip: kIsWeb, // [intended] on web the browser handles the context menu.
    );

    testWidgets('contextMenuBuilder is used in place of the default text selection toolbar', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      final TextEditingController controller = TextEditingController(text: '');
      await tester.pumpWidget(
        CupertinoApp(
          home: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CupertinoTextField(
                controller: controller,
                contextMenuBuilder: (
                  BuildContext context,
                  EditableTextState editableTextState,
                ) {
                  return Placeholder(key: key);
                },
              ),
            ],
          ),
        ),
      );

      await tester.pump(); // Wait for autofocus to take effect.

      expect(find.byKey(key), findsNothing);

      // Long-press to bring up the context menu.
      final Finder textFinder = find.byType(EditableText);
      await tester.longPress(textFinder);
      tester.state<EditableTextState>(textFinder).showToolbar();
      await tester.pumpAndSettle();

      expect(find.byKey(key), findsOneWidget);
    },
      skip: kIsWeb, // [intended] on web the browser handles the context menu.
    );
  });

  group('magnifier', () {
    late ValueNotifier<MagnifierInfo> magnifierInfo;
    final Widget fakeMagnifier = Container(key: UniqueKey());

    group('magnifier builder', () {
      testWidgets('should build custom magnifier if given', (WidgetTester tester) async {
        final Widget customMagnifier = Container(
          key: UniqueKey(),
        );
        final CupertinoTextField defaultCupertinoTextField = CupertinoTextField(
          magnifierConfiguration: TextMagnifierConfiguration(magnifierBuilder: (_, __, ___) => customMagnifier),
        );

        await tester.pumpWidget(const CupertinoApp(
          home: Placeholder(),
        ));

        final BuildContext context =
            tester.firstElement(find.byType(Placeholder));

        expect(
            defaultCupertinoTextField.magnifierConfiguration!.magnifierBuilder(
                context,
                MagnifierController(),
                ValueNotifier<MagnifierInfo>(MagnifierInfo.empty),
              ),
            isA<Widget>().having((Widget widget) => widget.key, 'key', equals(customMagnifier.key)));
      });

      group('defaults', () {
        testWidgets('should build CupertinoMagnifier on iOS and Android', (WidgetTester tester) async {
          await tester.pumpWidget(const CupertinoApp(
            home: CupertinoTextField(),
          ));

        final BuildContext context = tester.firstElement(find.byType(CupertinoTextField));
        final EditableText editableText = tester.widget(find.byType(EditableText));

          expect(
              editableText.magnifierConfiguration.magnifierBuilder(
                  context,
                  MagnifierController(),
                  ValueNotifier<MagnifierInfo>(MagnifierInfo.empty),
                ),
              isA<CupertinoTextMagnifier>());
        },
            variant: const TargetPlatformVariant(
                <TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));
      });

      testWidgets('should build nothing on all platforms but iOS and Android', (WidgetTester tester) async {
        await tester.pumpWidget(const CupertinoApp(
          home: CupertinoTextField(),
        ));

        final BuildContext context = tester.firstElement(find.byType(CupertinoTextField));
        final EditableText editableText = tester.widget(find.byType(EditableText));

        expect(
            editableText.magnifierConfiguration.magnifierBuilder(
                context,
                MagnifierController(),
                ValueNotifier<MagnifierInfo>(MagnifierInfo.empty),
              ),
            isNull);
      },
          variant: TargetPlatformVariant.all(
              excluding: <TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));
    });

    testWidgets('Can drag handles to show, unshow, and update magnifier',
        (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (BuildContext context) => CupertinoTextField(
                dragStartBehavior: DragStartBehavior.down,
                controller: controller,
                magnifierConfiguration: TextMagnifierConfiguration(
                    magnifierBuilder: (_,
                        MagnifierController controller,
                        ValueNotifier<MagnifierInfo>
                            localMagnifierInfo) {
                  magnifierInfo = localMagnifierInfo;
                  return fakeMagnifier;
                }),
              ),
            ),
          ),
        ),
      );

      const String testValue = 'abc def ghi';
      await tester.enterText(find.byType(CupertinoTextField), testValue);

      // Double tap the 'e' to select 'def'.
      await tester.tapAt(textOffsetToPosition(tester, testValue.indexOf('e')));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tapAt(textOffsetToPosition(tester, testValue.indexOf('e')));
      await tester.pump(const Duration(milliseconds: 30));

      final TextSelection selection = controller.selection;

      final RenderEditable renderEditable = findRenderEditable(tester);
      final List<TextSelectionPoint> endpoints = globalize(
        renderEditable.getEndpointsForSelection(selection),
        renderEditable,
      );

      // Drag the right handle 2 letters to the right.
      final Offset handlePos = endpoints.last.point + const Offset(1.0, 1.0);
      final TestGesture gesture =
          await tester.startGesture(handlePos, pointer: 7);

      Offset? firstDragGesturePosition;

      await gesture.moveTo(textOffsetToPosition(tester, testValue.length - 2));
      await tester.pump();

      expect(find.byKey(fakeMagnifier.key!), findsOneWidget);
      firstDragGesturePosition = magnifierInfo.value.globalGesturePosition;

      await gesture.moveTo(textOffsetToPosition(tester, testValue.length));
      await tester.pump();

      // Expect the position the magnifier gets to have moved.
      expect(firstDragGesturePosition,
          isNot(magnifierInfo.value.globalGesturePosition));

      await gesture.up();
      await tester.pump();

      expect(find.byKey(fakeMagnifier.key!), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Can long press to show, unshow, and update magnifier on non-Apple platforms', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      final bool isTargetPlatformAndroid = defaultTargetPlatform == TargetPlatform.android;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              dragStartBehavior: DragStartBehavior.down,
              controller: controller,
              magnifierConfiguration: TextMagnifierConfiguration(
                magnifierBuilder: (
                    _,
                    MagnifierController controller,
                    ValueNotifier<MagnifierInfo> localMagnifierInfo
                  ) {
                    magnifierInfo = localMagnifierInfo;
                    return fakeMagnifier;
                  },
              ),
            ),
          ),
        ),
      );

      const String testValue = 'abc def ghi';
      await tester.enterText(find.byType(CupertinoTextField), testValue);
      await tester.pumpAndSettle();

      // Tap at 'e' to move the cursor before the 'e'.
      await tester.tapAt(textOffsetToPosition(tester, testValue.indexOf('e')));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(controller.selection.isCollapsed, true);
      expect(controller.selection.baseOffset, isTargetPlatformAndroid ? 5 : 4);
      expect(find.byKey(fakeMagnifier.key!), findsNothing);

      // Long press the 'e' to select 'def' and show the magnifier.
      final TestGesture gesture = await tester.startGesture(textOffsetToPosition(tester, testValue.indexOf('e')));
      await tester.pumpAndSettle(const Duration(milliseconds: 1000));
      expect(controller.selection.baseOffset, 4);
      expect(controller.selection.extentOffset, 7);
      expect(find.byKey(fakeMagnifier.key!), findsOneWidget);

      final Offset firstLongPressGesturePosition = magnifierInfo.value.globalGesturePosition;

      // Move the gesture to 'h' to extend the selection to 'ghi'.
      await gesture.moveTo(textOffsetToPosition(tester, testValue.indexOf('h')));
      await tester.pumpAndSettle();
      expect(controller.selection.baseOffset, 4);
      expect(controller.selection.extentOffset, 11);
      expect(find.byKey(fakeMagnifier.key!), findsOneWidget);
      // Expect the position the magnifier gets to have moved.
      expect(firstLongPressGesturePosition, isNot(magnifierInfo.value.globalGesturePosition));

      // End the long press to hide the magnifier.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(fakeMagnifier.key!), findsNothing);
    }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.android }));

    testWidgets('Can long press to show, unshow, and update magnifier on iOS', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      final bool isTargetPlatformAndroid = defaultTargetPlatform == TargetPlatform.android;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CupertinoTextField(
              dragStartBehavior: DragStartBehavior.down,
              controller: controller,
              magnifierConfiguration: TextMagnifierConfiguration(
                magnifierBuilder: (
                    _,
                    MagnifierController controller,
                    ValueNotifier<MagnifierInfo> localMagnifierInfo
                  ) {
                    magnifierInfo = localMagnifierInfo;
                    return fakeMagnifier;
                  },
              ),
            ),
          ),
        ),
      );

      const String testValue = 'abc def ghi';
      await tester.enterText(find.byType(CupertinoTextField), testValue);
      await tester.pumpAndSettle();

      // Tap at 'e' to set the selection to position 5 on Android.
      // Tap at 'e' to set the selection to the closest word edge, which is position 4 on iOS.
      await tester.tapAt(textOffsetToPosition(tester, testValue.indexOf('e')));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(controller.selection.isCollapsed, true);
      expect(controller.selection.baseOffset, isTargetPlatformAndroid ? 5 : 7);
      expect(find.byKey(fakeMagnifier.key!), findsNothing);

      // Long press the 'e' to move the cursor in front of the 'e' and show the magnifier.
      final TestGesture gesture = await tester.startGesture(textOffsetToPosition(tester, testValue.indexOf('e')));
      await tester.pumpAndSettle(const Duration(milliseconds: 1000));
      expect(controller.selection.baseOffset, 5);
      expect(controller.selection.extentOffset, 5);
      expect(find.byKey(fakeMagnifier.key!), findsOneWidget);

      final Offset firstLongPressGesturePosition = magnifierInfo.value.globalGesturePosition;

      // Move the gesture to 'h' to update the magnifier and move the cursor to 'h'.
      await gesture.moveTo(textOffsetToPosition(tester, testValue.indexOf('h')));
      await tester.pumpAndSettle();
      expect(controller.selection.baseOffset, 9);
      expect(controller.selection.extentOffset, 9);
      expect(find.byKey(fakeMagnifier.key!), findsOneWidget);
      // Expect the position the magnifier gets to have moved.
      expect(firstLongPressGesturePosition, isNot(magnifierInfo.value.globalGesturePosition));

      // End the long press to hide the magnifier.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(fakeMagnifier.key!), findsNothing);
    }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS }));
  });

  group('TapRegion integration', () {
    testWidgets('Tapping outside loses focus on desktop', (WidgetTester tester) async {
      final FocusNode focusNode = FocusNode(debugLabel: 'Test Node');
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: CupertinoTextField(
                autofocus: true,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);

      // Tap outside the border.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();

      expect(focusNode.hasPrimaryFocus, isFalse);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets("Tapping outside doesn't lose focus on mobile", (WidgetTester tester) async {
      final FocusNode focusNode = FocusNode(debugLabel: 'Test Node');
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: CupertinoTextField(
                autofocus: true,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);

      // Tap just outside the border, but not inside the EditableText.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();

      // Focus is lost on mobile browsers, but not mobile apps.
      expect(focusNode.hasPrimaryFocus, kIsWeb ? isFalse : isTrue);
    }, variant: TargetPlatformVariant.mobile());

    testWidgets("tapping on toolbar doesn't lose focus", (WidgetTester tester) async {
      final TextEditingController controller;
      final EditableTextState state;

      controller = TextEditingController(text: 'A B C');
      final FocusNode focusNode = FocusNode(debugLabel: 'Test Node');
      await tester.pumpWidget(
        CupertinoApp(
          debugShowCheckedModeBanner: false,
          home: CupertinoPageScaffold(
            child: Align(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CupertinoTextField(
                  autofocus: true,
                  focusNode: focusNode,
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);

      state = tester.state<EditableTextState>(find.byType(EditableText));

      // Select the first 2 words.
      state.renderEditable.selectPositionAt(
        from: textOffsetToPosition(tester, 0),
        to: textOffsetToPosition(tester, 2),
        cause: SelectionChangedCause.tap,
      );

      final Offset midSelection = textOffsetToPosition(tester, 2);

      // Right click the selection.
      final TestGesture gesture = await tester.startGesture(
        midSelection,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);

      // Copy the first word.
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);
    },
      variant: TargetPlatformVariant.all(),
      skip: kIsWeb, // [intended] The toolbar isn't rendered by Flutter on the web, it's rendered by the browser.
    );

    testWidgets("Tapping on border doesn't lose focus",
        (WidgetTester tester) async {
      final FocusNode focusNode = FocusNode(debugLabel: 'Test Node');
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: CupertinoTextField(
                autofocus: true,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);

      final Rect borderBox = tester.getRect(find.byType(CupertinoTextField));
      // Tap just inside the border, but not inside the EditableText.
      await tester.tapAt(borderBox.topLeft + const Offset(1, 1));
      await tester.pump();

      expect(focusNode.hasPrimaryFocus, isTrue);
    }, variant: TargetPlatformVariant.all());
  });

  testWidgets('Can drag handles to change selection correctly in multiline', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();

    await tester.pumpWidget(
      CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: CupertinoPageScaffold(
          child: CupertinoTextField(
            dragStartBehavior: DragStartBehavior.down,
            controller: controller,
            style: const TextStyle(color: Colors.black, fontSize: 34.0),
            maxLines: 3,
          ),
        ),
      ),
    );

    const String testValue =
        'First line of text is\n'
        'Second line goes until\n'
        'Third line of stuff';

    const String cutValue =
        'First line of text is\n'
        'Second until\n'
        'Third line of stuff';
    await tester.enterText(find.byType(CupertinoTextField), testValue);

    // Skip past scrolling animation.
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // Check that the text spans multiple lines.
    final Offset firstPos = textOffsetToPosition(tester, testValue.indexOf('First'));
    final Offset secondPos = textOffsetToPosition(tester, testValue.indexOf('Second'));
    final Offset thirdPos = textOffsetToPosition(tester, testValue.indexOf('Third'));
    expect(firstPos.dx, secondPos.dx);
    expect(firstPos.dx, thirdPos.dx);
    expect(firstPos.dy, lessThan(secondPos.dy));
    expect(secondPos.dy, lessThan(thirdPos.dy));

    // Double tap on the 'n' in 'until' to select the word.
    final Offset untilPos = textOffsetToPosition(tester, testValue.indexOf('until')+1);
    await tester.tapAt(untilPos);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(untilPos);
    await tester.pumpAndSettle();

    // Skip past the frame where the opacity is zero.
    await tester.pump(const Duration(milliseconds: 200));

    expect(controller.selection.baseOffset, 39);
    expect(controller.selection.extentOffset, 44);

    final RenderEditable renderEditable = findRenderEditable(tester);
    final List<TextSelectionPoint> endpoints = globalize(
      renderEditable.getEndpointsForSelection(controller.selection),
      renderEditable,
    );
    expect(endpoints.length, 2);

    final Offset offsetFromEndPointToMiddlePoint = Offset(0.0, -renderEditable.preferredLineHeight / 2);

    // Drag the left handle to just after 'Second', still on the second line.
    Offset handlePos = endpoints[0].point + offsetFromEndPointToMiddlePoint;
    Offset newHandlePos = textOffsetToPosition(tester, testValue.indexOf('Second') + 6) + offsetFromEndPointToMiddlePoint;
    TestGesture gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.selection.baseOffset, 28);
    expect(controller.selection.extentOffset, 44);

    // Drag the right handle to just after 'goes', still on the second line.
    handlePos = endpoints[1].point + offsetFromEndPointToMiddlePoint;
    newHandlePos = textOffsetToPosition(tester, testValue.indexOf('goes') + 4) + offsetFromEndPointToMiddlePoint;
    gesture = await tester.startGesture(handlePos, pointer: 7);
    await tester.pump();
    await gesture.moveTo(newHandlePos);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.selection.baseOffset, 28);
    expect(controller.selection.extentOffset, 38);

    if (!isContextMenuProvidedByPlatform) {
      await tester.tap(find.text('Cut'));
      await tester.pump();
      expect(controller.selection.isCollapsed, true);
      expect(controller.text, cutValue);
    }
  });

  testWidgets('placeholder style overflow works', (WidgetTester tester) async {
    final String placeholder = 'hint text' * 20;
    const TextStyle placeholderStyle = TextStyle(
      fontFamily: 'Ahem',
      fontSize: 14.0,
      overflow: TextOverflow.fade,
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextField(
            placeholder: placeholder,
            placeholderStyle: placeholderStyle,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Finder placeholderFinder = find.text(placeholder);
    final Text placeholderWidget = tester.widget(placeholderFinder);
    expect(placeholderWidget.overflow, placeholderStyle.overflow);
    expect(placeholderWidget.style!.overflow, placeholderStyle.overflow);
  });
}
