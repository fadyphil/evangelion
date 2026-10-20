import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/settings_handle.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:flutter/material.dart';

export 'package:evangelion/app/settings_handle.dart' show SettingsHandle;

/// The reader's **witness sky** preferences — the slice `/reading` reads.
///
/// The seven settings that decide what the sky looks like: whether it is there,
/// whether the constellations are, how bright, which shape, which field, and
/// whether it twinkles.
typedef WitnessSettings = ({
  bool starsOn,
  bool constellationsOn,
  int starBrightness,
  SkyStarShape starShape,
  SkyStarField starField,
  bool twinkle,
});

/// The reader's **ritual** preferences — the slice `/` and `/reading` read.
///
/// The settings that govern a session rather than a surface: how long the
/// silence lasts, how long before the screen dims, whether the breath guide
/// draws, whether the reader asked for stillness, and whether the app answers
/// with a haptic.
typedef RitualSettings = ({
  int focusDelaySec,
  int selahLengthSec,
  bool breathGuide,
  bool reducedMotion,
  bool haptics,
});

/// The reader's **communion** preferences — the slice `/communion` reads.
///
/// Whether the witness names are veiled, and whether the podium is shown.
typedef CommunionSettings = ({bool veilWitnesses, bool showPodium});

/// The reader's **reading** preferences — the slice the type scale reads.
///
/// The font step the app installs into every route, and the language the reader
/// chose (or `null`, which means "follow the platform").
typedef ReadingSettings = ({int fontStep, ReadingLanguage? language});

/// Publishes the reader's settings to the subtree, **in slices**.
///
/// ## WHY IT IS SLICED, AND THE NUMBER THAT PROVED IT
///
/// This was one `InheritedNotifier` over the whole thirty-field
/// `UserSettings`, and it notified on **every** write. A widget that depended on
/// it therefore rebuilt on every write — and a *dependent* lookup registers
/// that dependency.
///
/// **The cost was measured, not assumed.** One hue change on `/settings`
/// rebuilt **1,236 widgets** — every row, every control, every `Text` — and
/// the same write rebuilt the three invisible tab screens the dock keeps
/// alive, because they depend on the same notifier. The measurement is
/// `test/rebuild_isolation_budget_test.dart`, and it is a **budget** there, so
/// the number cannot go back up without a red test.
///
/// ## WHY SLICES AND NOT A NARROWER `UserSettings`
///
/// Because a narrower *record* does not narrow the **notification**. The
/// notifier would still fire on every write, and every dependent would still
/// rebuild. **The granularity has to be in the notifier**, so each slice gets
/// its own notifier, and a notifier only wakes the dependents that registered
/// with *it*.
///
/// And the slices are **records**, because a Dart record compares structurally:
/// `(a: 1, b: 2) == (a: 1, b: 2)` is `true`, so a slice's bridge can ask
/// "did my slice change?" in one comparison, with no `==` to hand-write and no
/// `hashCode` to get wrong.
///
/// ## WHY THE SLICES ARE **DISTINCT TYPES** AND NOT ONE GENERIC BAG
///
/// Because [InheritedWidget]'s granularity is **per type**. Two dependents
/// that both read `InheritedWidget<Object>` share one dependency, and a
/// notification wakes both. [_SliceInherited] is generic over the slice, so
/// `_SliceInherited<WitnessSettings>` and `_SliceInherited<RitualSettings>` are
/// **different runtime types**, and each is a separate dependency.
///
/// ## WHY THE **HANDLE** IS PUBLISHED SEPARATELY
///
/// Because the handle is a **projection of the cubit** and its identity never
/// changes — it is a locator singleton, and `app.dart` registers it once. A
/// dependent lookup for a stable object is a rebuild waiting to happen, so
/// [handleOf] reads it **without** registering a dependency, and a page that
/// needs to *react* to a setting reads the slice instead.
class SettingsScope extends StatefulWidget {
  /// Publishes [handle] and its slices to [child].
  const SettingsScope({
    required this.handle,
    required super.key,
    required this.child,
  });

  /// The handle every descendant reads.
  final SettingsHandle handle;

  /// The subtree the handle is published to.
  final Widget child;

  /// The handle above [context] — **without** registering a dependency.
  ///
  /// ## WHY THIS IS NOT [of]
  ///
  /// Because [of] is a **dependent** lookup, and a page that only needs the
  /// handle — to *write* a setting — has no business rebuilding when a setting
  /// changes. `/settings` writes the two communion settings through the handle
  /// and reads every other value from its own cubit, so a dependent lookup
  /// there rebuilt the whole thirty-three-row form for a hue change.
  ///
  /// **The locator fallback is deliberate** and is the same one [of] has always
  /// had: a context with no scope above it — a widget test that mounted a page
  /// bare — gets the registered singleton, which holds the same value and
  /// writes through the same cubit but is **not watched**, so nothing rebuilds.
  /// A write through the fallback is still a real write, which is what keeps a
  /// test that taps `Aa` and asserts the step honest rather than asserting
  /// against a stub.
  static SettingsHandle handleOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SettingsInherited>()?.handle ??
      getIt<SettingsHandle>();

  /// The handle above [context], **as a dependent lookup**.
  ///
  /// ## WHY IT STILL EXISTS
  ///
  /// Because it is the **only** accessor that hands back the whole record, and
  /// a caller that reads the whole record has to rebuild when the whole record
  /// changes. **A caller that reads one slice should read that slice** — the
  /// slice accessors below are narrower, and the difference is the 1,236.
  ///
  /// ## THE LOCATOR FALLBACK IS **DELIBERATE** AND IT IS A TEST SEAM, NOT A
  /// ## PRODUCTION PATH
  ///
  /// `HomePage`'s doc records the measured cost of the opposite decision: the
  /// page suites pump a screen over a bare `MaterialApp`, and `ReadingPage` —
  /// which now reads and writes the font step — is pumped that way by five
  /// suites. `ReadingPage` could resolve from the locator **only** (as it
  /// resolves its cubit) and skip the scope entirely; it does not, because then
  /// nothing would rebuild when the settings change, which is the property this
  /// scope exists for.
  ///
  /// So the order is: scope first, locator second. A context under the app's
  /// root gets the live scope and therefore a rebuild on every change. A
  /// context with neither — which in this repository means a widget test that
  /// mounted a page bare — gets the registered singleton, which holds the same
  /// value and writes through the same cubit but is not watched, so nothing
  /// rebuilds. **A write through the fallback is still a real write**, which is
  /// what keeps a test that taps `Aa` and asserts the step honest rather than
  /// asserting against a stub.
  ///
  /// There is deliberately **no third fallback**. A silent "return the defaults"
  /// would make a page render in the right palette while writing nowhere, which
  /// is `NeuralScaffold`'s D2 "a guess wearing an API" and the shape of defect
  /// this repository audits.
  static SettingsHandle of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SettingsInherited>()
          ?.handle ??
      getIt<SettingsHandle>();

  /// The reader's **witness sky** preferences, as a dependent lookup.
  ///
  /// A dependent lookup, and deliberately: the sky's appearance is this slice,
  /// and a reader who changes a sky setting in `/settings` must see the sky
  /// change. **And only this slice** — a change to the selah's length does not
  /// redraw a single star.
  static WitnessSettings witnessOf(BuildContext context) =>
      _sliceOf<WitnessSettings>(context, _witnessProjection);

  /// The reader's **ritual** preferences, as a dependent lookup.
  static RitualSettings ritualOf(BuildContext context) =>
      _sliceOf<RitualSettings>(context, _ritualProjection);

  /// The reader's **communion** preferences, as a dependent lookup.
  static CommunionSettings communionOf(BuildContext context) =>
      _sliceOf<CommunionSettings>(context, _communionProjection);

  /// The reader's **reading** preferences, as a dependent lookup.
  static ReadingSettings readingOf(BuildContext context) =>
      _sliceOf<ReadingSettings>(context, _readingProjection);

  /// The slice of type [T] above [context].
  ///
  /// [fallback] projects the slice out of the whole record for the case where
  /// there is no scope above [context] — the locator's registered handle holds
  /// the same value and writes through the same cubit, but it is **not watched**,
  /// so nothing rebuilds. That is the same bargain [of] makes, and it is
  /// deliberate: a page pumped bare must still render the right value and still
  /// write somewhere real.
  static T _sliceOf<T>(
    BuildContext context,
    T Function(UserSettings settings) fallback,
  ) {
    final _SliceInherited<T>? slice = context
        .dependOnInheritedWidgetOfExactType<_SliceInherited<T>>();
    if (slice != null) return slice.slice;
    return fallback(getIt<SettingsHandle>().settings);
  }

  @override
  State<SettingsScope> createState() => _SettingsScopeState();
}

/// The witness slice's fields, out of the whole record.
WitnessSettings _witnessProjection(UserSettings settings) => (
  starsOn: settings.starsOn,
  constellationsOn: settings.constellationsOn,
  starBrightness: settings.starBrightness,
  starShape: settings.starShape,
  starField: settings.starField,
  twinkle: settings.twinkle,
);

/// The ritual slice's fields, out of the whole record.
RitualSettings _ritualProjection(UserSettings settings) => (
  focusDelaySec: settings.focusDelaySec,
  selahLengthSec: settings.selahLengthSec,
  breathGuide: settings.breathGuide,
  reducedMotion: settings.reducedMotion,
  haptics: settings.haptics,
);

/// The communion slice's fields, out of the whole record.
CommunionSettings _communionProjection(UserSettings settings) =>
    (veilWitnesses: settings.veilWitnesses, showPodium: settings.showPodium);

/// The reading slice's fields, out of the whole record.
ReadingSettings _readingProjection(UserSettings settings) =>
    (fontStep: settings.fontStep, language: settings.language);

class _SettingsScopeState extends State<SettingsScope> {
  /// **Created once and reused**, so a rebuild of `app.dart` does not re-subscribe.
  late _SettingsBridge _bridge = _SettingsBridge(widget.handle);

  /// The four slice bridges, and the same "created once" rule.
  late _SliceBridge<WitnessSettings> _witness = _SliceBridge<WitnessSettings>(
    widget.handle,
    _witnessProjection,
  );
  late _SliceBridge<RitualSettings> _ritual = _SliceBridge<RitualSettings>(
    widget.handle,
    _ritualProjection,
  );
  late _SliceBridge<CommunionSettings> _communion =
      _SliceBridge<CommunionSettings>(widget.handle, _communionProjection);
  late _SliceBridge<ReadingSettings> _reading = _SliceBridge<ReadingSettings>(
    widget.handle,
    _readingProjection,
  );

  @override
  void didUpdateWidget(SettingsScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.handle, widget.handle)) {
      // A different handle is a different subscriber, so the old one has to go or the
      // disposed scope keeps answering announcements meant for someone else.
      _bridge.dispose();
      _bridge = _SettingsBridge(widget.handle);
      // **The old bridges go, and four new ones take their place over the new
      // handle.** The old ones subscribed to the old handle, and a bridge
      // that outlived its subscription would answer announcements meant for
      // somebody else.
      _witness.dispose();
      _ritual.dispose();
      _communion.dispose();
      _reading.dispose();
      _witness = _SliceBridge<WitnessSettings>(
        widget.handle,
        _witnessProjection,
      );
      _ritual = _SliceBridge<RitualSettings>(widget.handle, _ritualProjection);
      _communion = _SliceBridge<CommunionSettings>(
        widget.handle,
        _communionProjection,
      );
      _reading = _SliceBridge<ReadingSettings>(
        widget.handle,
        _readingProjection,
      );
    }
  }

  @override
  void dispose() {
    _bridge.dispose();
    _witness.dispose();
    _ritual.dispose();
    _communion.dispose();
    _reading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SettingsInherited(
    notifier: _bridge,
    handle: widget.handle,
    child: _publishSlices(widget.child),
  );

  /// Publishes the four slices around [child].
  ///
  /// **Nested, and written out rather than looped**, for two reasons. Each
  /// slice has to be an [InheritedWidget] in the tree for a dependent lookup to
  /// find it, and nesting is the only way to publish four of them over one
  /// subtree. And a loop cannot spell four *different* type arguments without
  /// a `dynamic` cast — and the type argument is the mechanism, because
  /// [InheritedWidget]'s dependency granularity is per type.
  Widget _publishSlices(Widget child) => _SliceInherited<WitnessSettings>(
    notifier: _witness,
    child: _SliceInherited<RitualSettings>(
      notifier: _ritual,
      child: _SliceInherited<CommunionSettings>(
        notifier: _communion,
        child: _SliceInherited<ReadingSettings>(
          notifier: _reading,
          child: child,
        ),
      ),
    ),
  );
}

/// The [InheritedNotifier] dependents actually find.
///
/// Carries [handle] as a field so [SettingsScope.of] can hand back the handle rather
/// than the bridge, and because the bridge is private to this library.
class _SettingsInherited extends InheritedNotifier<_SettingsBridge> {
  /// Publishes [notifier] and [handle] to [child].
  const _SettingsInherited({
    required _SettingsBridge notifier,
    required this.handle,
    required super.child,
  }) : super(notifier: notifier);

  /// The handle [SettingsScope.of] returns.
  final SettingsHandle handle;
}

/// A slice of the reader's settings, published to the subtree.
///
/// **Generic over the slice, and that is the whole mechanism**: the slice's
/// type argument makes this an `InheritedWidget` of a **different runtime
/// type** per slice, and [InheritedWidget]'s dependency granularity is per
/// type. Two dependents reading two different slices are two dependencies, and
/// a notification wakes only the one whose bridge fired.
class _SliceInherited<T> extends InheritedNotifier<_SliceBridge<T>> {
  /// Publishes [notifier] to [child].
  const _SliceInherited({
    required _SliceBridge<T> notifier,
    required super.child,
  }) : super(notifier: notifier);

  /// The slice, for the accessor's hand-back.
  ///
  /// **The bang is load-bearing and safe**: [InheritedNotifier.notifier] is
  /// declared nullable because the base class allows a null, and this
  /// constructor never passes one — it takes a [_SliceBridge] and hands it
  /// straight to `super`.
  T get slice => notifier!.slice;
}

/// Turns [SettingsHandle]'s pure listener list into a Flutter [Listenable].
///
/// ## THE WHOLE OF THE ADAPTER, AND WHY IT IS A CLASS RATHER THAN A CLOSURE
///
/// `InheritedNotifier<T extends Listenable>` publishes a `Listenable`, and
/// `SettingsHandle` is pure Dart — it cannot implement one without importing Flutter,
/// which is the thing the split exists to prevent. So this bridges: it registers itself
/// with the handle and republishes [ChangeNotifier.notifyListeners].
///
/// A closure pair would be four lines shorter and would hide two facts worth having in
/// types: that the subscription has an **owner** with a disposal order, and that a
/// notification after disposal must be dropped rather than thrown. Both are asserted by
/// `settings_page_test.dart`'s disposal arm and by the fact that `MaterialApp` rebuilds
/// its subtree on every theme change.
class _SettingsBridge extends ChangeNotifier {
  /// Bridges [handle].
  _SettingsBridge(this.handle) {
    handle.addListener(_forward);
  }

  /// The handle being bridged.
  final SettingsHandle handle;

  /// Set by [dispose] so a late [SettingsHandle.announce] is dropped instead of throwing.
  bool _disposed = false;

  void _forward() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // **Before `super.dispose()`, and unconditionally**: the handle outlives the scope
    // (it is a locator singleton), so a scope that goes away without dropping its
    // subscription would keep calling `notifyListeners` on a disposed notifier, and the
    // next theme change would throw from inside Flutter's own assertion.
    handle.removeListener(_forward);
    super.dispose();
  }
}

/// One slice's bridge — the notifier that wakes only the dependents of that slice.
///
/// ## WHY IT FILTERS
///
/// Because a slice's notifier that fired on every write would be no narrower
/// than the one it replaced. **The bridge compares the slice before and after**
/// and stays silent when the slice did not change — so a hue write does not
/// wake the sky's dependents, and a sky write does not wake the ritual's.
class _SliceBridge<T> extends ChangeNotifier {
  /// Bridges [handle]'s [project]ion of the settings.
  _SliceBridge(this.handle, this._project) {
    handle.addListener(_forward);
    _slice = _project(handle.settings);
  }

  /// The handle being bridged.
  final SettingsHandle handle;

  /// How the whole record becomes this slice.
  final T Function(UserSettings settings) _project;

  /// The slice as it was the last time this bridge spoke.
  late T _slice;

  /// The slice, for the accessor's hand-back.
  T get slice => _slice;

  /// Set by [dispose] so a late [SettingsHandle.announce] is dropped.
  bool _disposed = false;

  void _forward() {
    if (_disposed) return;
    final T next = _project(handle.settings);
    // **The comparison that is the whole point.** A record compares
    // structurally, so this is "did any of my fields change?" in one step.
    if (next == _slice) return;
    _slice = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    handle.removeListener(_forward);
    super.dispose();
  }
}
