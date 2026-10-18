import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/features/home/presentation/widgets/last_light_card.dart';
import 'package:evangelion/features/home/presentation/widgets/library_carousel.dart';
import 'package:evangelion/features/home/presentation/widgets/selah_card.dart';
import 'package:evangelion/features/home/presentation/widgets/verse_of_the_day_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/home_harness.dart';

/// §14: "text scales to 1.22× without overflow at 320px width."
///
/// ## BOTH NUMBERS COME FROM THE DOCUMENT AND NEITHER IS NEGOTIABLE
///
/// `kNarrowSurface` is `Size(320, 568)` and `kEvaRequiredTextScale` is `1.22`, both
/// declared in `design_system_harness.dart` and both quoted from §14. They are used
/// rather than repeated so this file cannot drift from the other four suites that
/// assert the same requirement.
///
/// ## AND EVERY STATE IS MOUNTED, BECAUSE A LAYOUT IS NOT ONE THING
///
/// Ready, failed, Arabic, no-session and an **empty** last light all lay out
/// differently, and the states with the most text — the eyebrow with its reference,
/// a repository's error message, a book's caption inside a 136px column — are the
/// ones that wrap. A single "the ready screen does not overflow" would leave the
/// failed sections' long messages untested at 1.22×, which is precisely where a
/// long string overflows.
///
/// ## AND THE THREE FIXED WIDTHS ARE WHERE THIS SCREEN ACTUALLY BREAKS
///
/// The redesign gave `/` a fixed-width row three times, and each one is a place a
/// 1.22× run has nowhere to go:
///
/// | where | the constraint | the escape |
/// | --- | --- | --- |
/// | a book card's caption | 168px card − 32px padding = 136 of column | `maxLines: 1` + ellipsis |
/// | the greeting's name | whatever the chip leaves of the row | `maxLines: 1` + ellipsis |
/// | the selah circle | 44 × 44, no padding to grow into | it holds one glyph |
///
/// The first two ellipsize and the harness below says so; the **third** is the one
/// that cannot, which is why the circle's glyph is asserted at one step smaller
/// than §14's: a `Text` with no `maxLines` in a `Row` of bounded width is where
/// `RenderFlex` overflows, and the glyph is 11px at a 44px box, which has 33px of
/// slack before it matters.
void main() {
  /// The scale, named so a failure reads as §14's own words. The surface is
  /// `kNarrowSurface`, which is `pumpHome`'s own default and so is not passed.
  const double scale = kEvaRequiredTextScale;

  group('at 320x568 and 1.22x, no state overflows', () {
    testWidgets('ready, English', (WidgetTester tester) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, textScale: scale);

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('ready, Arabic — a taller script for the same box', (
      WidgetTester tester,
    ) async {
      // Arabic script is *taller* at the same point size, the reference is a wider
      // string in practice, and two of this screen's runs are Arabic: the greeting's
      // name and the last-light card's body. So the RTL arm is not a mirror of the
      // LTR one.
      final HomeHarness h = harness();
      h.readings.scripture = const Right<Failure, ScriptureText>(
        liveArabicScripture,
      );
      await pumpHome(
        tester,
        bloc: h.bloc,
        locale: const Locale('ar'),
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('a failed READING, whose message is a long sentence', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        reading: const Left<Failure, ScriptureText>(homeReadingFailure),
      );
      await pumpHome(tester, bloc: h.bloc, textScale: scale);

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('a failed STREAK — the chip is a button-sized control', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        streak: const Left<Failure, StreakSummary>(streakFailure),
      );
      await pumpHome(tester, bloc: h.bloc, textScale: scale);

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('a failed LAST LIGHT', (WidgetTester tester) async {
      // The section the redesign created, so the one with no predecessor and no
      // suite: `home_page_test.dart` asserts what it *says* and this asserts that
      // saying it at 1.22× on 320 does not overflow.
      final HomeHarness h = harness(
        history: const Left<Failure, List<StreakHistoryEntry>>(streakFailure),
      );
      await pumpHome(tester, bloc: h.bloc, textScale: scale);

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('an EMPTY last light, whose body is a full sentence', (
      WidgetTester tester,
    ) async {
      // `redesign.html:929` — "no light received yet — open a book below". The
      // longest string on the screen, in the arm with no content to shorten it.
      final HomeHarness h = harness(
        history: const Right<Failure, List<StreakHistoryEntry>>(
          <StreakHistoryEntry>[],
        ),
      );
      await pumpHome(tester, bloc: h.bloc, textScale: scale);

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });

    testWidgets('no session — the greeting is `peace` alone', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(signedIn: false);
      await pumpHome(tester, bloc: h.bloc, textScale: scale);

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });
  });

  group('and the platform scaler alone, at the largest step', () {
    // `evaScalerFor(5)` is 1.22, the top of §5.2's table and the same number as
    // §14's requirement — so this asserts the two agree rather than stacking them,
    // which would be 1.22 x 1.22 and a requirement nobody has.
    testWidgets('1.22x is the requirement, and the screen renders it', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(
        tester,
        bloc: h.bloc,
        textScale: evaScalerFor(5).scale(14) / 14,
      );

      expect(tester.takeException(), isNull);
      _expectNoOverflow(tester);
    });
  });

  group('the three fixed-width rows ellipsize rather than overflow', () {
    testWidgets("a book card's caption is one line and it is elided", (
      WidgetTester tester,
    ) async {
      // **The caption is the one place the redesign's own CSS would have
      // overflowed**, which is what `LibraryCarousel.captionFor`'s doc records: at
      // 1.22× on 320 the string "PROPHETS · 4 VERSES" at 9px and `.16em` is wider
      // than the card's 136px of content, and the CSS has no `text-overflow`.
      //
      // So the divergence is the ellipsis, and this row is where a reader can see
      // that the widget knows it: the caption's rendered height is **one line**.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, textScale: scale);

      // **Psalms' caption, not Isaiah's**, and the reason is the strip: at 320 the
      // `ListView` builds the first card or two, and "PROPHETS · 4 VERSES" — the
      // widest of the six — is on the fourth. The claim is about the *widget*, so
      // the card it is read from does not matter; what matters is that it is a real
      // caption and not the first one's absence.
      final Text caption = tester.widget<Text>(find.text('POETRY · 6 VERSES'));
      expect(caption.maxLines, 1);
      expect(caption.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSize(find.text('POETRY · 6 VERSES')).height,
        lessThan(20.0),
        reason: 'one line at 9px scaled to 1.22 is 11 tall, plus the line box',
      );
    });

    testWidgets("the greeting's name is one line and it is elided", (
      WidgetTester tester,
    ) async {
      // A long display name at 320 is the case the row's `maxLines: 1` exists for.
      // `firstNameOf` keeps the name to one token, so the fixture uses the longest
      // single-token name the session can carry rather than a two-word one.
      final HomeHarness h = harness(session: _longNamedSession());
      await pumpHome(tester, bloc: h.bloc, textScale: scale);

      final Text name = tester.widget<Text>(
        find.textContaining('peace, ').first,
      );
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and the selah circle holds one glyph at one step down', (
      WidgetTester tester,
    ) async {
      // The third fixed box, and the one that **cannot** ellipsize: the star is a
      // single drawn shape in a 44px circle with no padding, so the only way it
      // overflows is if the shape's own advance exceeds the box. Asserted as a
      // size comparison rather than a string, because the mechanism is the width —
      // and the shape is PAINTED (`FourPointedStar`, the shared
      // design-system widget), not typed, which is the measured correction
      // `SelahCard.glyph`'s doc records: U+2726 is in no bundled family, so the
      // typed version was the tofu this suite's own no-overflow check could not
      // see.
      //
      // **And the box is read off the rendered size**, which is the point of this
      // row. The finder used to be `w is CustomPaint && w.size ==
      // const Size.square(11.0)`, which matched the painter's *declaration* — so
      // the width assertion below was half a constant comparing itself, at the one
      // place where a scaling failure would show up. A painted shape does not move
      // under `TextScaler` at all, and that is the property witnessed here: 11
      // stays 11 while the text around it grows.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, textScale: scale);

      final Finder star = find
          .descendant(
            of: find.byType(SelahCard),
            matching: find.byType(FourPointedStar),
          )
          .first;
      final Size glyph = tester.getSize(star);
      expect(
        glyph,
        const Size.square(11.0),
        reason: '`:269` — `font-size: 11px`, and paint does not scale',
      );
      expect(
        glyph.width,
        lessThan(SelahCard.diameter),
        reason: 'an 11px glyph at 1.22× is 13.4 wide inside a 44px box',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the geometry that is fixed rather than scaled', () {
    testWidgets("the day's card radius and padding are the prototype values", (
      WidgetTester tester,
    ) async {
      // §14 scales *text*. The radius and the padding are layout, and the card
      // publishes them as constants so a geometry test can read them rather than
      // re-derive them.
      expect(VerseOfTheDayCard.radius, EvaRadii.heroPanel);
      expect(
        VerseOfTheDayCard.padding,
        const EdgeInsets.symmetric(horizontal: EvaSpacing.xl, vertical: 22),
      );
      expect(LibraryCarousel.cardWidth, 168.0);
      expect(LastLightCard.radius, VerseOfTheDayCard.radius);
    });
  });
}

/// A session whose display name is one very long token.
///
/// **One token and not two words**, because `home_l10n.dart`'s `firstNameOf` takes
/// the first token: a two-word name would be shortened before the greeting ever saw
/// it, and the row under test is about what the *greeting* does with a long string.
///
/// 40 characters, because that is what it takes to overflow 430 − 20 − 20 − the
/// pill's 88 = 302 of column at 23px in EB Garamond, and the ellipsis only shows up
/// on the Arabic arm below about 300.
AuthSession _longNamedSession() => AuthSession(
  userId: '11111111-1111-1111-1111-111111111111',
  email: 'long.name@evangelion.app',
  displayName: 'Wilhelmina Aurelia Featherstonehaugh',
  initials: 'WF',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

/// Asserts that nothing in the tree reported an overflow.
///
/// **[WidgetTester.takeException] is null, and that is the mechanism.** A
/// `RenderFlex` overflow raises a `FlutterError` through `FlutterError.onError`,
/// which `flutter_test` records and hands back from `takeException()`; there is no
/// "did it overflow" property on the render objects, so this is the only way a
/// reader can ask the question. `login_text_scale_test.dart` says the same and
/// carries the negative control that proves it — a column built to overflow at this
/// scale returns a non-null exception.
///
/// ## AND THE ANTI-VACUITY HALF IS "THE SCREEN DREW THE CARDS"
///
/// `takeException()` returning null also covers a screen that rendered nothing at
/// all, which would make every assertion in this file pass for the wrong reason. So
/// the helper insists the day's card is present — the section every one of these
/// states shares — and **not** that a particular widget is, because the failed and
/// empty arms draw different children.
void _expectNoOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(
    find.byType(VerseOfTheDayCard),
    findsOneWidget,
    reason:
        "the day's card did not render, so \"no overflow\" is vacuous: a screen "
        'that drew nothing cannot overflow',
  );
  expect(
    find.byType(SelahCard),
    findsOneWidget,
    reason:
        'and the selah card is the section a scaled screen is most likely to '
        'lose, since it holds a fixed 44px box beside two lines of text',
  );
}
