import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

// The hook itself, imported rather than duplicated: this file exists to prove the
// hook ran, and re-listing the families here would let the two disagree.
import 'flutter_test_config.dart';

/// Two runs of glyphs whose advances differ in every real proportional font and
/// are identical in every monospaced one.
///
/// A lowercase `i` and an uppercase `W` are the widest possible contrast in
/// Latin text. Chosen because the assertion below has to hold for the *shipped*
/// files, not for a hand-picked case: if `SpaceMono` were substituted, or a
/// weight swapped for a proportional cut, this pair stops agreeing.
const String _narrowRun = 'iiiiii';
const String _wideRun = 'WWWWWW';

/// The advance width of [text] set in [family] at a size where a monospaced face
/// measures [wideRun] and a proportional one does not.
///
/// Measured through `ui.ParagraphBuilder` rather than by pumping a widget: no
/// element tree, no `Directionality`, and the number returned is the font's own
/// metrics with no layout rounding in the way.
double advanceOf(String family, String text) {
  final ui.Paragraph paragraph = (ui.ParagraphBuilder(
    ui.ParagraphStyle(fontFamily: family, fontSize: 100),
  )..addText(text)).build();
  addTearDown(paragraph.dispose);
  paragraph.layout(const ui.ParagraphConstraints(width: 100000));
  return paragraph.maxIntrinsicWidth;
}

void main() {
  group('the golden font hook', () {
    test('covers the five families the design system uses', () {
      // The loop in the test below iterates this map, so a family dropped from it
      // would shrink the check silently. Spelled out here so dropping one is a
      // visible edit to a test rather than a silent reduction in coverage.
      expect(bundledFontFamilies.keys.toSet(), <String>{
        'CormorantGaramond',
        'EBGaramond',
        'DMSans',
        'Amiri',
        'SpaceMono',
      }, reason: 'the five families declared in pubspec.yaml under `fonts:`');
      expect(
        bundledFontFamilies.values.every(
          (List<String> files) => files.isNotEmpty,
        ),
        isTrue,
        reason:
            'a family with no files would load nothing and resolve to nothing',
      );
    });

    test('makes every declared family resolve to a real font', () {
      // WHY THIS TEST EXISTS. `flutter_test_config.dart` is a hook, and a hook
      // that silently stops running is the failure mode with the worst ratio of
      // damage to visibility: no test fails, no gate reports anything, and the
      // first golden written afterwards bakes whatever fallback the runner has.
      // It is then re-baked by whoever notices the text looks wrong. So the hook
      // is asserted, not trusted.
      //
      // WHAT IT MEASURES. A family that is NOT registered resolves to the test
      // runner's fallback face, which is fixed-advance — every glyph the same
      // width. A family that IS registered measures its own metrics. So "this
      // family does not measure like the fallback" is exactly "this family
      // resolved", and it is a statement about the engine's font collection
      // rather than about a widget.
      //
      // WHY A DIFFERENCE RATHER THAN A LITERAL WIDTH. The fallback's advance is
      // an implementation detail of the runner. Asserting "not the fallback" pins
      // the property that matters and survives a change to it; asserting a
      // specific number would make this a golden test about the host.
      final double fallback = advanceOf('NoSuchFamilyIsRegistered', _wideRun);

      for (final String family in bundledFontFamilies.keys) {
        expect(
          advanceOf(family, _wideRun),
          isNot(fallback),
          reason:
              '$family is not resolving — `flutter_test_config.dart` did not '
              'load it, so text in this family renders in the test fallback and '
              'every golden of it is baked from the wrong font',
        );
      }
    });

    test(
      'resolves a monospaced family and a proportional one as themselves',
      () {
        // Guards against the subtler version of the same rot: all five families
        // resolving to one face would satisfy the test above. `SpaceMono` really is
        // monospaced and `Amiri` really is proportional, so this pair distinguishes
        // "the five registered fonts" from "one font registered five times".
        expect(
          advanceOf('SpaceMono', _narrowRun),
          advanceOf('SpaceMono', _wideRun),
          reason: 'SpaceMono is monospaced, so both runs must measure the same',
        );
        expect(
          advanceOf('Amiri', _narrowRun),
          isNot(advanceOf('Amiri', _wideRun)),
          reason: 'Amiri is proportional, so the two runs must differ',
        );
      },
    );
  });
}
