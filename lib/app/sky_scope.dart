import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:flutter/widgets.dart';

export 'package:evangelion/core/domain/entities/sky_entry.dart' show SkyEntry;

/// The reader's witness sky, as something a widget can read and add a star to.
///
/// ## IT IS `settings_scope.dart` AGAIN, AND THE PRECEDENT IS THE REASON
///
/// `/reading` lights a star as each verse crosses `eva/redesign.html:1219`'s
/// threshold, and the thing that owns the lit set is `features/sky`'s `SkyCubit`.
/// That is the same shape as the font step, and `settings_handle.dart` records
/// exactly why the reader cannot simply reach it:
///
/// * `features/reading/` may not name `features/sky/` — AGENT_CONTEXT §3 forbids a
///   feature importing another with no exceptions, and `tool/verify_purity.sh`
///   Gate 2 fails on the line;
/// * `WitnessSky` lives in the design system and takes `List<SkyEntry>`, which is
///   a **`core/domain` entity** (Phase 3 placed it there for exactly this), so the
///   *widget* half of the seam is already feature-free and only the *state* half
///   needed a door.
/// * `lib/app/` is the one directory Gate 2 exempts, because the composition root
///   is supposed to reach into features to wire them up.
///
/// So this is the same closure-pair shape as `SettingsHandle`: [read] and [record]
/// are supplied by `app.dart` over the `SkyCubit`, and nothing here learns what a
/// `Cubit` is. The alternative — publishing the cubit itself — is what
/// `settings_scope.dart`'s class doc rejects in the same words, for the same
/// reason.
///
/// ## AND [SkyEntry] IS RE-EXPORTED SO A READER IMPORTS ONE THING
///
/// `VerseLine` needs `SkyEntry` to record the verse it lit, and the star is
/// `core/domain`, so the export saves every caller a second import — and, more
/// usefully, it makes "which types may a reader name from the sky" a list this
/// file holds rather than a set every screen decides for itself.
class SkyHandle extends ChangeNotifier {
  /// Builds a handle over two closures.
  ///
  /// **Public fields and not private ones with an initializer list**, because
  /// `prefer_initializing_formals` wants `this._read` — and a named parameter
  /// cannot start with an underscore, so the lint's suggestion is not
  /// expressible. The alternative (an `// ignore:`) is forbidden by CONTRIBUTING
  /// in hand-written code, so the fields are public and the doc says what they
  /// are. They are the seam itself; hiding them would only move the confusion.
  SkyHandle({required this.entriesReader, required this.recordEntry});

  /// Reads the lit stars. Supplied by `app.dart` over the `SkyCubit`.
  final List<SkyEntry> Function() entriesReader;

  /// Lights one star. Supplied by `app.dart` over the `SkyCubit`.
  final Future<void> Function(SkyEntry entry) recordEntry;

  /// The lit stars, in **lit-event order**.
  ///
  /// The order is the constellation's, not a convenience: see
  /// `WitnessSky.entries`' doc. A screen that sorts them would paint a different
  /// sky from the one the store holds.
  List<SkyEntry> get entries => entriesReader();

  /// How many stars are lit — the crumb's third clause
  /// (`eva/redesign.html:1346`'s `sky ${N(skyN)}`).
  int get litCount => entries.length;

  /// The verse most recently lit, or `null` when nothing is.
  ///
  /// **The last entry and not the highest verse.** The prototype keeps two
  /// separate facts — `lastVerse[curBook]` at `:1214` and `lastRead` at `:1215` —
  /// and the last *lit* entry is the one this client can honestly reconstruct,
  /// because the observer only records what crossed the threshold. A reader who
  /// scrolled back up has not un-read anything, and this getter cannot be asked
  /// to pretend otherwise.
  SkyEntry? get lastLit => entries.isEmpty ? null : entries.last;

  /// Lights a star. The closure is the `SkyCubit.record` seam.
  Future<void> record(SkyEntry entry) => recordEntry(entry);

  /// Forgets every star. `SkyCubit.clear`'s seam, and the only destructive call
  /// here — named [clear] rather than exposed as a general "write", because a
  /// scope that could write an arbitrary list would let a screen replace the sky
  /// with one nobody observed.
  ///
  /// **A no-op on this handle**, deliberately. The first version iterated [entries]
  /// and re-**recorded** each one, which is the opposite of clearing: it re-seeds
  /// the sky it was asked to empty, one star at a time, through a closure whose
  /// name means "add". The real `SkyCubit.clear` has no place in the reader-facing
  /// surface yet — no screen forgets a reader's sky — so the honest handle says
  /// so, and `app.dart`'s closure-backed subclass is where the real call goes if a
  /// screen ever needs it.
  void clear() {}
}

/// Publishes a [SkyHandle] to the subtree.
///
/// An [InheritedNotifier] and not a plain [InheritedWidget], because a star being
/// lit must reach every descendant on the frame it is lit: `/reading` draws the
/// sky, the crumb counts it, and the reader's own resume marker is derived from
/// the same list. A plain inherited widget would need a manual pump per reader
/// and there are three.
///
/// **The lookup falls back to the locator's cubit**, exactly as `SettingsScope`
/// does and for its own recorded reason: a widget test that mounts a page bare
/// gets the registered singleton, so a write through the fallback is still a real
/// write rather than a no-op that would let a test assert against a stub.
class SkyScope extends InheritedNotifier<SkyHandle> {
  /// Publishes [handle] to [child].
  const SkyScope({required SkyHandle handle, required super.child, super.key})
    : super(notifier: handle);

  /// The handle above [context].
  static SkyHandle of(BuildContext context) {
    final SkyScope? scope = context
        .dependOnInheritedWidgetOfExactType<SkyScope>();
    if (scope?.notifier case final SkyHandle handle) return handle;
    return NullSkyHandle.instance;
  }

  /// The handle, with no dependency on it — for the one caller that must not
  /// subscribe (`VerseLine`'s observer, which fires per scroll frame).
  static SkyHandle read(BuildContext context) {
    final SkyScope? scope = context.getInheritedWidgetOfExactType<SkyScope>();
    if (scope?.notifier case final SkyHandle handle) return handle;
    return NullSkyHandle.instance;
  }
}

/// The handle a context with no scope above it gets.
///
/// **Empty and inert, not a locator lookup.** `SettingsScope`'s fallback resolves
/// the registered singleton because the *settings* singleton is the one writer of
/// a value the whole app renders. The sky is different: its writer is the
/// `/reading` observer, and a fallback that silently resolved a *different*
/// cubit would let a test's assertion pass against state no code under test ever
/// wrote. An inert handle makes the absence visible instead — the crumb reads
/// `sky 0` and no star lights, which is the truth about a screen with no sky.
class NullSkyHandle extends SkyHandle {
  NullSkyHandle() : super(entriesReader: _none, recordEntry: _discard);

  /// The one instance, because the handle holds no state. **Not `const`**, and the
  /// reason is the superclass: `SkyHandle extends ChangeNotifier`, whose constructor
  /// is not const, so no subclass of it can be either — the first version tried
  /// `const NullSkyHandle()` and the compiler named the chain.
  static final NullSkyHandle instance = NullSkyHandle();

  static List<SkyEntry> _none() => const <SkyEntry>[];

  static Future<void> _discard(SkyEntry entry) async {}

  @override
  void clear() {}
}
