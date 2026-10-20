import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the widgets the framework **rebuilt** during one frame, by type.
///
/// ## WHY THIS EXISTS
///
/// The question this repository's performance work is actually asking is *"when a
/// piece of state changes, how much of the tree rebuilds with it?"* — and Flutter
/// answers it in exactly one place: [Element.update].
///
/// A rebuild **stops descending** the moment it re-encounters the *same widget
/// instance*. A `const` widget is canonicalised, so it is always the same instance
/// and always short-circuits. A widget constructed fresh inside a `build` is a new
/// instance every time, and its whole subtree rebuilds with it.
///
/// **That is the mechanism, and this file is the instrument that measures it.**
/// `debugOnRebuildDirtyWidget` is the framework's own hook: it fires for every
/// dirty element the framework rebuilds, with a `builtOnce` flag that separates a
/// first build from a rebuild. It is the same hook the DevTools inspector's
/// `trackRebuildDirtyWidgets` service extension uses.
///
/// ## WHY IT IS A **DELTA** AND NOT A COUNT
///
/// Two of the pages this instrument is used against (`/reading` and `/`) mount
/// **ambient animation**: the shared float clock and the LUMEN shader clock both
/// `repeat()`, so a pump rebuilds the witness sky's stars and the dock's ripple
/// **whether or not anything the test did caused it**.
///
/// A raw count would therefore measure the *ambient*, not the *action* — which is
/// the number nobody wants. So the instrument counts one pump on its own (the
/// baseline) and one pump after the action, and the difference is what the action
/// cost. [RebuildCounter.delta] does that subtraction.
///
/// ## WHY IT IS A TEST-SUPPORT FILE AND NOT A GATE
///
/// Because the gate is a *budget*, and the budget is a policy decision, not a
/// measurement. This file measures; the gate asserts. Splitting them means the
/// measurement can be printed, diffed and re-used by any number of gates, and it
/// means a gate that fails says *"this many widgets rebuilt"* rather than
/// *"something rebuilt"*.
final class RebuildCounter {
  const RebuildCounter(this._counts);

  /// The count of rebuilds, by the widget's runtime type.
  final Map<Type, int> _counts;

  /// The number of widgets rebuilt, in total.
  int get total =>
      _counts.values.fold<int>(0, (int sum, int count) => sum + count);

  /// The number of widgets rebuilt, by the widget's runtime type.
  Map<Type, int> get byType => Map<Type, int>.unmodifiable(_counts);

  /// The number of widgets of [type] that rebuilt.
  int countOf(Type type) => _counts[type] ?? 0;

  /// The widgets rebuilt, as a readable `Type × count` list.
  ///
  /// **Sorted by count, descending, then by type name** — so the output is stable
  /// between runs and the biggest contributor is the first line. A gate that
  /// prints an unordered map reads as noise, and a diff of two runs of an
  /// unordered map is a diff of noise.
  String describe() {
    if (_counts.isEmpty) return 'nothing rebuilt';
    final List<MapEntry<Type, int>> entries = _counts.entries.toList()
      ..sort((MapEntry<Type, int> a, MapEntry<Type, int> b) {
        final int byCount = b.value.compareTo(a.value);
        return byCount != 0
            ? byCount
            : a.key.toString().compareTo(b.key.toString());
      });
    return entries
        .map((MapEntry<Type, int> e) => '${e.key} × ${e.value}')
        .join(', ');
  }

  /// The widgets [baseline] did not rebuild that this one did — the action's own
  /// cost.
  ///
  /// **By type, and by the excess over the baseline's count for that type.** A
  /// type the action rebuilt that the baseline did not contributes its whole
  /// count; a type both rebuilt contributes the difference. Subtracting the two
  /// counts wholesale would go negative for a type the ambient happened to
  /// rebuild more of on the baseline frame, and a negative count of rebuilds is
  /// not a quantity.
  RebuildCounter delta(RebuildCounter baseline) {
    final Map<Type, int> extra = <Type, int>{};
    for (final MapEntry<Type, int> entry in _counts.entries) {
      final int baselineCount = baseline._counts[entry.key] ?? 0;
      final int extraCount = entry.value - baselineCount;
      if (extraCount > 0) extra[entry.key] = extraCount;
    }
    return RebuildCounter(extra);
  }
}

/// Counts the widgets rebuilt by one pump, with [action] running before it.
///
/// The hook is installed for the duration of the pump and removed afterwards, and
/// the elements it collected are filtered to those the framework reported as
/// **rebuilding** rather than building for the first time — a first build is not
/// a rebuild, and counting one would make every baseline look like a full tree.
Future<RebuildCounter> countRebuilds(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  final Map<Type, int> counts = <Type, int>{};
  final RebuildDirtyWidgetCallback? previous = debugOnRebuildDirtyWidget;
  debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
    if (builtOnce) return;
    final Type type = element.widget.runtimeType;
    counts[type] = (counts[type] ?? 0) + 1;
  };
  try {
    await action();
    await tester.pump();
  } finally {
    debugOnRebuildDirtyWidget = previous;
  }
  return RebuildCounter(counts);
}
