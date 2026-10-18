import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/reading_l10n.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/arabic_typography_gate.dart';
import '../../../../support/reading_harness.dart';

/// The Arabic arm of `/reading`, through the shared instrument.
///
/// ## WHY THIS FILE IS SHORT NOW, AND WHAT IT LOST
///
/// It used to be the *original* of the instrument — `reading_glyph_test.dart`
/// built the run-walker and applied it to one screen, and its promotion to
/// `test/support/arabic_typography_gate.dart` left this file as the example. The
/// redesigned reader's own typography claims moved to
/// `test/arabic_typography_test.dart`'s `/reading` group, where they are one entry
/// in the **all-screens** gate — the whole point of the promotion, and the reason
/// a defect found here is a defect found everywhere.
///
/// What stays here is the screen's own derivation: the list below is **built from
/// the fixture and `AppLocalizationsAr()`**, never typed, so a change to either
/// side is a failure in the comparison rather than a silent drift. And the two
/// rows the all-screens gate cannot carry — the *exact* set on the English arm,
/// and the numerals' family, which the design-system fix this screen caused made
/// load-bearing — live here because they are about this screen.
void main() {
  final AppLocalizations ar = AppLocalizationsAr();

  /// Every Arabic run the reader renders, derived from the fixture and the table.
  ///
  /// The two eyebrows are `Text.rich`, and the gate reads **one run per span**, so
  /// each contributes the label-with-separator and the reference separately. The
  /// verse numerals carry the single space `:1362` puts after them
  /// (`<i>${…}</i> ${t}`), because the numeral is its own `TextSpan`.
  List<String> arabicRuns() => <String>[
    // The title — the passage's own reference, `eva/redesign.html:1345`.
    liveArabicPassage.reference,
    // The crumb, composed — `:1346`'s three clauses, with the recorded divergence
    // that the first clause is the book number and not a category word.
    ar.crumbMeta(
      category: '${liveArabicPassage.verses.first.bookNumber}',
      verses: liveArabicPassage.verses.length,
      litStars: 0,
    ),
    // The five verse numerals, each with the single space `:1362` puts after it
    // (`<i>${…}</i> ${t}`), because the numeral is its own `TextSpan` and the gate
    // reads one run per span.
    for (final Verse verse in liveArabicPassage.verses)
      '${ar.digits(verse.number)} ',
    // The five verse paragraphs — `Verse.text`, the diacritised wire string
    // (recorded decision 51; `displayText` is the *preview* projection and the
    // sanctuary shows scripture whole).
    for (final Verse verse in liveArabicPassage.verses) verse.text,
    // The CTA's composed caption — `:1347`, one word for every count.
    ar.quizCaption(liveArabicPassage.questionCount),
    // The dial's Arabic option and the pill's `listen` label — the two Arabic runs
    // the *controls* carry. The dial's is Amiri in both directions (`:186`), which
    // `SegmentedControl.labelFamilyOf` exists to express.
    ReadingPill.languageLabelArabic,
    ar.readingListen,
  ];

  testWidgets(
    'the Arabic arm renders every run it declares, in the Arabic face',
    (WidgetTester tester) async {
      final ReadingHarness h = readingHarness(
        scripture: const Right<Failure, ScriptureText>(liveArabicPassage),
      );
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/reading',
        expectedArabic: arabicRuns(),
      );
      await expectNoTofuInAnyRun(tester, screen: '/reading');
    },
  );

  testWidgets('and the English arm renders Arabic in exactly one run', (
    WidgetTester tester,
  ) async {
    // The dial's own `ع` — `eva/redesign.html:554` shows the reader the other
    // arm's option on both arms, and `:186` keys its face on the option. The
    // all-screens gate carries the same row; this one is where the *exact* set is
    // the claim.
    final ReadingHarness h = readingHarness();
    await pumpReading(tester, cubit: h.cubit);

    await expectArabicTypography(
      tester,
      screen: '/reading',
      expectedArabic: <String>[ReadingPill.languageLabelArabic],
    );
  });
}
