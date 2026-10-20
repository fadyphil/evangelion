import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_restore_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

/// `workshop_restore_toast.dart` — the restore confirmation.
///
/// ## WHY THE **TRACKING** IS THE SUBJECT OF ONE OF THESE
///
/// `eva/redesign.html:467` — `font-size:10.5px;letter-spacing:.12em` — and the
/// `.12em` is **premultiplied by the 10.5px**, which is **1.26**. The prototype's
/// `em` is relative to the element's own font and Flutter's `letterSpacing` is a
/// logical-pixel advance, and a raw 0.12 would be more than **ten times** too
/// small.
/// The message the ARB key holds.
const String _message = '↺ nocturne defaults restored';

void main() {
  group('the toast', () {
    // ## IT IS **ANNOUNCED**
    //
    // `:1393`'s `toast(m)` is a confirmation, and `/communion`'s toast is the
    // precedent: `Semantics(liveRegion: true)`.
    testWidgets('it is a live region carrying the message', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final Iterable<SemanticsData> live = semanticsTree(tester)
          .where((SemanticsData data) => data.flagsCollection.isLiveRegion);
      expect(live, hasLength(1));
      expect(live.single.label, contains(_message));
    });

    // ## AND IT IS **PAINTED**
    testWidgets('the message is painted', (WidgetTester tester) async {
      await _pump(tester);

      expect(find.text(_message), findsOneWidget);
    });

    // ## AND IT IS **MONO AT 10.5px**, WITH **1.26px** OF TRACKING
    testWidgets('it wears the prototype\'s mono type', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final TextStyle style = tester.widget<Text>(find.text(_message)).style!;
      expect(style.fontSize, 10.5);
      expect(style.letterSpacing, closeTo(1.26, 0.0001));
      expect(style.fontFamily, EvaTypography.monoFamily);
    });

    // ## AND THE `↺` CARRIES AN **INTER** FALLBACK
    //
    // U+21BA is in **no** bundled mono or scripture face — measured against the
    // twenty shipped `.ttf` files: absent from `JetBrainsMono`, absent from
    // `EBGaramond` and absent from `Amiri`; present in `Inter` and in
    // `IBMPlexSansArabic`. Flutter falls back **per glyph**, so the mono face
    // draws the letters and Inter draws the arrow.
    testWidgets('the arrow has an Inter fallback', (WidgetTester tester) async {
      await _pump(tester);

      final TextStyle style = tester.widget<Text>(find.text(_message)).style!;
      expect(style.fontFamilyFallback, contains(EvaTypography.uiFamily));
    });

    // ## AND IT IS A **PILL** WITH A **GOLD HAIRLINE**
    //
    // `:466-467` — `border-radius:99px` and `border:1px solid
    // rgba(232,176,75,.5)`.
    testWidgets('it is a pill with a gold hairline', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final Container pill = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(WorkshopRestoreToast),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = pill.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(99));
      final Border border = decoration.border! as Border;
      expect(
        border.top.color,
        EvaThemeDark.theme.extension<EvaColors>()!.ember.withValues(alpha: 0.5),
      );
    });

    // ## AND IT IS **CENTRED**
    //
    // `:466` — `.toast{left:50%;transform:translate(-50%,…)}`. The pill is as
    // wide as its message and it sits in the middle of the screen, and a
    // confirmation that hangs off one side reads as something else.
    testWidgets('the pill is centred', (WidgetTester tester) async {
      await _pump(tester);

      final Rect pill = tester.getRect(
        find
            .descendant(
              of: find.byType(WorkshopRestoreToast),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(pill.center.dx, closeTo(kAmbientSurface.width / 2, 0.5));
    });
  });
}

/// Pumps the toast on the ambient surface.
Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = kAmbientSurface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    evaPrimitiveHarness(child: const WorkshopRestoreToast(message: _message)),
  );
  await tester.pump();
}
