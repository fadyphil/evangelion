import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/presentation/widgets/selah_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

void main() {
  testWidgets('a RepaintBoundary is an ancestor of the selah ring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      evaPrimitiveHarness(
        theme: EvaThemeDark.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        child: const SelahCard(
          seconds: 60,
          beginLabel: 'Begin the selah',
          endLabel: 'End the selah',
          hapticsEnabled: true,
        ),
      ),
    );
    await tester.pump();

    final Finder star = find.descendant(
      of: find.byType(SelahCard),
      matching: find.byType(FourPointedStar),
    );
    expect(star, findsOneWidget);

    final List<Element> boundaries = find
        .ancestor(of: star, matching: find.byType(RepaintBoundary))
        .evaluate()
        .toList();
    final bool hasRingSizedBoundary = boundaries.any((Element e) {
      final RenderObject? ro = e.renderObject;
      return ro is RenderRepaintBoundary &&
          ro.size == const Size(SelahCard.diameter, SelahCard.diameter);
    });
    expect(
      hasRingSizedBoundary,
      isTrue,
      reason:
          'the selah ring (FourPointedStar) must have a RepaintBoundary '
          'ancestor sized to the ring (${SelahCard.diameter}x'
          '${SelahCard.diameter}) — the one wrapping '
          '_BreathingButton.build. Without it the ring\'s every-frame '
          'repaints dirty the page layer. Found ${boundaries.length} '
          'RepaintBoundary ancestor(s).',
    );
  });
}
