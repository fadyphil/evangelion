import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../test/support/reading_harness.dart';
import '../test/support/design_system_harness.dart';
import '../test/support/settings_harness.dart';

/// Every `Opacity` value between the page root and the verse `RichText`, in order.
List<double> opacityChain(Element element) {
  final List<double> out = <double>[];
  element.visitAncestorElements((Element ancestor) {
    final RenderObject? object = ancestor.renderObject;
    if (object is RenderOpacity) out.add(object.opacity);
    if (ancestor.widget is AnimatedOpacity) {
      out.add((ancestor.widget as AnimatedOpacity).opacity);
    }
    return true;
  });
  return out.reversed.toList();
}

void main() {
  testWidgets('probe verse visibility, animated path', (WidgetTester tester) async {
    final ReadingHarness h = readingHarness();
    await pumpReading(tester, cubit: h.cubit, size: const Size(430, 2400));
    final Iterable<Element> rich = find
        .descendant(of: find.byType(VerseLine), matching: find.byType(RichText))
        .evaluate();
    for (int i = 0; i < rich.length; i++) {
      final VerseLine line = tester.widget<VerseLine>(
        find.byType(VerseLine).at(i),
      );
      debugPrint(
        'verse ${line.number} paint=${line.paint} chain=${opacityChain(rich.elementAt(i))}',
      );
    }
    debugPrint('---- all Opacity widgets in the tree ----');
    for (final Opacity o in tester.widgetList<Opacity>(find.byType(Opacity))) {
      debugPrint('  ${o.opacity}');
    }
  });

  testWidgets('probe calm path', (WidgetTester tester) async {
    final ReadingHarness h = readingHarness();
    await pumpReading(
      tester,
      cubit: h.cubit,
      size: const Size(430, 2400),
      disableAnimations: true,
    );
    final Iterable<Element> rich = find
        .descendant(of: find.byType(VerseLine), matching: find.byType(RichText))
        .evaluate();
    for (int i = 0; i < rich.length; i++) {
      final VerseLine line = tester.widget<VerseLine>(
        find.byType(VerseLine).at(i),
      );
      debugPrint(
        'calm verse ${line.number} paint=${line.paint} chain=${opacityChain(rich.elementAt(i))}',
      );
    }
  });

}
