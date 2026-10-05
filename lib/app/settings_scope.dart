import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/settings_handle.dart';
import 'package:flutter/material.dart';

export 'package:evangelion/app/settings_handle.dart' show SettingsHandle;

/// Publishes a [SettingsHandle] to the subtree.
///
/// An [InheritedNotifier] and not a plain [InheritedWidget], because the whole point
/// is that a change reaches every descendant: `app.dart` rebuilds the app from
/// `SettingsHandle`'s notification through this scope, and `/settings` and `/reading`
/// rebuild through the same one. A plain `InheritedWidget` would need a manual
/// `notifyListeners` pump per reader and there are three readers.
///
/// **Why not an `InheritedNotifier<SettingsCubit>`?** Because the notifier's *type*
/// is what the scope publishes, and publishing the settings feature's cubit would put
/// `features/settings` into every file that reads the app's settings — which is the
/// cross-feature import this file exists to avoid, rebuilt one level up.
class SettingsScope extends StatefulWidget {
  /// Publishes [handle] to [child].
  const SettingsScope({
    required this.handle,
    required super.key,
    required this.child,
  });

  /// The handle every descendant reads.
  final SettingsHandle handle;

  /// The subtree the handle is published to.
  final Widget child;

  /// The handle above [context].
  ///
  /// ## THE LOCATOR FALLBACK IS **DELIBERATE** AND IT IS A TEST SEAM, NOT A
  /// ## PRODUCTION PATH
  ///
  /// `HomePage`'s doc records the measured cost of the opposite decision: the page
  /// suites pump a screen over a bare `MaterialApp`, and `ReadingPage` — which now
  /// reads and writes the font step — is pumped that way by five suites. `ReadingPage`
  /// could resolve from the locator **only** (as it resolves its cubit) and skip the
  /// scope entirely; it does not, because then nothing would rebuild when the settings
  /// change, which is the property this scope exists for.
  ///
  /// So the order is: scope first, locator second. A context under the app's root gets
  /// the live scope and therefore a rebuild on every change. A context with neither —
  /// which in this repository means a widget test that mounted a page bare — gets the
  /// registered singleton, which holds the same value and writes through the same
  /// cubit but is not watched, so nothing rebuilds. **A write through the fallback is
  /// still a real write**, which is what keeps a test that taps `Aa` and asserts the
  /// step honest rather than asserting against a stub.
  ///
  /// There is deliberately **no third fallback**. A silent "return the defaults" would
  /// make a page render in the right palette while writing nowhere, which is
  /// `NeuralScaffold`'s D2 "a guess wearing an API" and the shape of defect this
  /// repository audits.
  ///
  /// **The lookup goes through [_SettingsInherited], not through `SettingsScope` itself,
  /// and that indirection is the cost of the pure-handle split.** A `StatefulWidget` is
  /// not an `InheritedWidget`, so the thing dependents must find is a separate private
  /// notifier widget below it. The alternative — building a fresh
  /// `InheritedNotifier<_SettingsBridge>` in this constructor — needs no extra type and
  /// is wrong: the handle is a locator singleton, so every rebuild of `app.dart` would
  /// subscribe **another** bridge to it and the listener list would grow for the life of
  /// the process. `settings_page_test.dart`'s disposal arm is what holds that honest.
  static SettingsHandle of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SettingsInherited>()
          ?.handle ??
      getIt<SettingsHandle>();

  @override
  State<SettingsScope> createState() => _SettingsScopeState();
}

class _SettingsScopeState extends State<SettingsScope> {
  /// **Created once and reused**, so a rebuild of `app.dart` does not re-subscribe.
  late _SettingsBridge _bridge = _SettingsBridge(widget.handle);

  @override
  void didUpdateWidget(SettingsScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.handle, widget.handle)) {
      // A different handle is a different subscriber, so the old one has to go or the
      // disposed scope keeps answering announcements meant for someone else.
      _bridge.dispose();
      _bridge = _SettingsBridge(widget.handle);
    }
  }

  @override
  void dispose() {
    _bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SettingsInherited(
    notifier: _bridge,
    handle: widget.handle,
    child: widget.child,
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
    // **Before** `super.dispose()`, and unconditionally: the handle outlives the scope
    // (it is a locator singleton), so a scope that goes away without dropping its
    // subscription would keep calling `notifyListeners` on a disposed notifier, and the
    // next theme change would throw from inside Flutter's own assertion.
    handle.removeListener(_forward);
    super.dispose();
  }
}
