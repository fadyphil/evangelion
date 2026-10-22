import 'dart:io';

import 'package:evangelion/features/servant/presentation/servant_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../../support/project_import_graph.dart';
import 'servant_harness.dart';

/// The instant the label is read for.
///
/// **A Wednesday**, so the English arm's assertion carries a weekday word
/// that is not every other weekday — a test that asserted "Thursday" would
/// pass against a format that dropped the weekday entirely.
///
/// The same instant `servant_home_page_test.dart` uses, so the two suites
/// are describing the same day.
final DateTime kDay = DateTime(2026, 10, 21);

/// The English arm's label, exactly.
///
/// `EEEE, MMMM d` — the month first, and an ASCII comma.
const String kEnglishLabel = 'Wednesday, October 21';

/// The Arabic arm's label, exactly.
///
/// `EEEE، d MMMM` — the day first, an **Arabic comma** ('،'), and
/// **Arabic-Indic digits** ('٢١'), because the digits come from Flutter's own
/// `ar` table rather than `intl`'s.
const String kArabicLabel = 'الأربعاء، ٢١ أكتوبر';

/// The servant file's own source, with the comments removed.
///
/// The comments go because this file's source gate is about **code**: a doc
/// comment that names `DateFormat` is prose, and a gate that counted prose
/// would count the explanation of the memo as an instance of the thing the
/// memo exists to avoid.
String _l10nSource() => withoutDartComments(
  File('lib/features/servant/presentation/servant_l10n.dart')
      .readAsStringSync(),
);

/// The statement that starts at [signature], up to its `;`.
///
/// ## WHY "UP TO THE FIRST `;`" IS ENOUGH HERE
///
/// Because a Dart member is either an **expression body** (`=> …;`) or a
/// **braced body**. An expression body ends at its first `;`. A braced body
/// ends at its first `;` **too** — the one that terminates its first
/// statement — so a construction of the forbidden thing inside a braced body
/// is *inside* the extracted text, and is seen.
///
/// What the extraction cannot see is a construction in a member **after** the
/// first `;` of this one. That is why the count assertion below is here as
/// well: a file that compiled two formatters would fail it whatever the
/// extraction saw.
String _statementOf(String source, String signature) {
  final int start = source.indexOf(signature);
  if (start < 0) {
    throw StateError('no member declared as "$signature"');
  }
  final int end = source.indexOf(';', start);
  if (end < 0) {
    throw StateError('the member declared as "$signature" has no terminator');
  }
  return source.substring(start, end + 1);
}

/// Pumps the portal's harness with a widget that hands back its context.
Future<BuildContext> _contextIn(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  late BuildContext captured;
  await pumpServant(
    tester,
    Builder(
      builder: (BuildContext context) {
        captured = context;
        return const SizedBox.shrink();
      },
    ),
    locale: locale,
  );
  return captured;
}

void main() {
  group('the day label', () {
    testWidgets('is the locale\'s own, in English', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _contextIn(tester);

      expect(servantDayLabel(context, kDay), kEnglishLabel);
    });

    testWidgets('and in Arabic, with Arabic-Indic digits', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _contextIn(
        tester,
        locale: const Locale('ar'),
      );

      expect(servantDayLabel(context, kDay), kArabicLabel);
    });

    testWidgets('and it is the same string on the second call', (
      WidgetTester tester,
    ) async {
      // The claim the memo has to keep: a `DateFormat` is fixed once
      // constructed, so the formatting result for a given (locale, date) is
      // the same whether the formatter was built a moment ago or earlier.
      final BuildContext context = await _contextIn(tester);

      final String first = servantDayLabel(context, kDay);
      final String second = servantDayLabel(context, kDay);

      expect(second, first);
      expect(second, kEnglishLabel);
    });

    testWidgets('and the same instance answers both calls', (
      WidgetTester tester,
    ) async {
      // ## WHAT THIS WITNESSES, AND WHAT IT DOES NOT
      //
      // It witnesses the **memo**: one `DateFormat` per locale, reused.
      // `debugDayFormatter` is the map's own entry, so two reads of it being
      // the same object means the map did not grow a second formatter
      // between the two calls.
      //
      // It does **not** witness the absence of a construction — a memo that
      // was bypassed would still leave the map holding one entry. The source
      // gate below is what witnesses that.
      final BuildContext context = await _contextIn(tester);

      final String first = servantDayLabel(context, kDay);
      final DateFormat? formatter = debugDayFormatter('en');
      expect(formatter, isNotNull, reason: 'the call memoised a formatter');

      final String second = servantDayLabel(context, kDay);
      expect(
        identical(debugDayFormatter('en'), formatter),
        isTrue,
        reason: 'the second call built a second formatter',
      );
      expect(second, first);
    });

    testWidgets('and a rebuild of the hub does not change it', (
      WidgetTester tester,
    ) async {
      // The app's own path: the label is read **inside `build`**
      // (`servant_home_page.dart:280`), so every rebuild of the hub asks
      // for the day again. The answer must not drift with the rebuild.
      final BuildContext context = await _contextIn(tester);
      final String before = servantDayLabel(context, kDay);

      await tester.pump();
      final BuildContext after = await _contextIn(tester);

      expect(servantDayLabel(after, kDay), before);
    });
  });

  group('the memo itself — the source gate', () {
    test('the file compiles exactly one formatter', () {
      // ## WHY A SOURCE GATE AND NOT A BEHAVIOURAL ONE
      //
      // Because the claim is an **allocation** claim, and no output can
      // witness it: a file that built a `DateFormat` per call and a file
      // that built one produced **the same strings**. A behavioural gate
      // here would be green for the version of the code that allocates — a
      // gate that cannot fail.
      //
      // So the allocation is gated on the source, and the *output* is gated
      // behaviourally above. The two together are the whole claim: the
      // output did not change, and the allocation is gone.
      final String source = _l10nSource();
      final int sites = RegExp('DateFormat\\.MMMMEEEEd\\(')
          .allMatches(source)
          .length;

      expect(
        sites,
        1,
        reason:
            'the file compiles exactly one formatter — the memo builds it '
            'once per locale and the call site reuses it',
      );
    });

    test('and the call site compiles none', () {
      // The count above says "one, somewhere". This says "not here" — so
      // that moving the construction back into `servantDayLabel` is caught
      // even though it would not change the count on its own.
      final String source = _l10nSource();
      final String statement = _statementOf(source, 'String servantDayLabel(');

      expect(
        statement,
        isNot(contains('DateFormat')),
        reason:
            'servantDayLabel builds a formatter again. The formatter is '
            'memoised per locale instead, and a DateFormat is fixed once '
            'constructed — so the label cannot drift with it.',
      );
    });
  });
}
