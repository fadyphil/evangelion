import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/ritual_haptic.dart';
import 'package:evangelion/core/domain/entities/sky_star_field.dart';
import 'package:evangelion/core/domain/entities/sky_star_shape.dart';
// The star count's RANGE and its clamp live in the shared kernel, because the
// sky feature clamps the same number where it becomes a cap and a feature may
// not import another feature — see the file's doc for why the other seven
// Workshop ranges are here instead.
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/domain/settings_clamps.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:evangelion/features/settings/presentation/settings_l10n.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_app_bar.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_restore_toast.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_rows.dart';
import 'package:evangelion/features/settings/presentation/widgets/workshop_segment_row.dart';
import 'package:evangelion/features/settings/presentation/workshop_logic.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `/settings` — **the Workshop** — `eva/redesign.html:638-700`.
///
/// ## THIS SCREEN IS A **REPLACEMENT**, NOT AN ADDITION
///
/// The Phase-9 screen had three groups (Appearance / Reading / About) and five
/// controls. The redesign has **seven groups and thirty-three rows**: twenty-nine
/// interactive controls, one action row, one preview line and two static rows.
/// The prototype's DOM order **is** the order, and every row below carries the
/// line it is transcribed from.
///
/// ## THE SEVEN GROUPS
///
/// | group | prototype | rows |
/// | --- | --- | --- |
/// | `language · اللغة` | `:645` | the 2-segment language control (`:646-648`) |
/// | `theme` | `:649` | the Daylight toggle (`:650`) |
/// | the light workshop | `:651` | ten (`:652-665`) |
/// | witness sky | `:666` | seven (`:667-681`) |
/// | focus & ritual | `:682` | seven (`:683-689`) |
/// | communion | `:690` | two (`:691-692`), the Type size (`:693`), the preview (`:694`), the restore row (`:695`) |
/// | about | `:696` | two static rows (`:697-698`) |
///
/// ## WHAT IS **NOT** ON THIS SCREEN, AND WHY
///
/// | the prototype | why not |
/// | --- | --- |
/// | the **language sheet** (the Phase-9 screen's picker) | the redesign's language control is a 2-segment track (`:646-648`), and `SegmentedControl.labelFamilyOf` — a parameter that names the prototype's `:186` rule and had **no caller** — is what makes its Arabic option draw in Amiri inside a Latin screen. The sheet and its ARB key are gone. |
/// | the **Light / Dark / System** segmented picker | the redesign's theme group holds **one** control, the Daylight toggle (`:650`). The three-state picker is gone — and with it, the `system` arm of `AppThemeMode` becomes unreachable from the UI. See `SettingsCubit.setDaylight`'s doc, which records the cubit's half of that consequence, and [workshop_logic]'s `daylightOnFor`, which records the display half. |
/// | the **16–26px** Type-size slider (`:693`) | `docs/superpowers/plans/2026-10-13-lumen-redesign.md:1172-1173` already decided that the redesign's slider is "a different model" from this client's 1–5 step, and that decision stands. The row is the existing `FontSizeStepper` plus the preview line. |
/// | the **Account** group, the privacy row, the verse-numbers row | the Phase-9 screen's own cuts, and the redesign has no such rows at all. |
/// | the **Version** row | the app's version moved to the app bar's chip (`:642`), which is where the redesign puts it. |
///
/// ## AND THE TWO **RECORDED DIVERGENCES** THE SCREEN CARRIES AS A WHOLE
///
/// 1. **The inter-group gap is the client's.** The redesign says nothing about it:
///    the `.sgroup`'s own `margin:20px 0 6px` (`:422`) is the margin **above** a
///    label, and `SettingsGroup` already owns that as its `topGap`. The page's own
///    [groupGap] is the Phase-9 value — `gap: 28`, the **superseded React
///    prototype's** own column gap — and the prototype's separation between a
///    group's last row and the next group's
///    label is therefore `groupGap + SettingsGroup.topGap` where the prototype's
///    is 20. **Recorded here** because it is the one number on this screen that
///    is the client's rather than the prototype's.
/// 2. **The ten light-workshop controls drive the aurora.** The shader is
///    mounted (Task 5.8) and the ten `eva.shader.*` preferences are its
///    inputs — `LumenPreferences.fromSettings` is the projection and
///    `LumenScene` is what turns them into the shader's sixteen uniforms.
///    **The controls are neither disabled nor hidden**, and the switch beside
///    "Aurora engine" now turns the aurora off, exactly as the prototype's
///    does (`eva/redesign.html:1468`).
///
/// ## AND THE BACK TARGET
///
/// **`maybePop`**, as the Phase-9 screen had it. The prototype's chevron carries
/// `data-back="journey"` (`:640`) and **pushes** `/journey`; this client pops the
/// route stack, so a reader who arrived from the journey goes back to it and a
/// reader who arrived from anywhere else goes back to there. **Recorded as a
/// divergence from `:640`** — and the app bar's own doc repeats it at the
/// control.
@RoutePage()
class SettingsPage extends StatelessWidget {
  /// The settings screen.
  const SettingsPage({super.key, this.cubit});

  /// The cubit to render.
  ///
  /// `null` means "resolve [SettingsCubit] from the locator", which is the
  /// production path — and the reason this page is not a `BlocProvider` of its
  /// own: the cubit is a **singleton** holding the app's palette, locale and text
  /// scale, so a page that created one per mount would render its own copy of all
  /// three and then vanish, taking the reader's toggle with it.
  ///
  /// A parameter rather than only a lookup because a widget test cannot reach the
  /// locator without configuring the whole graph. Same arrangement as `HomePage.bloc`
  /// and `ReadingPage.cubit`, and for the same reason: **substitution, not
  /// initialisation**.
  final SettingsCubit? cubit;

  /// The prototype's content padding.
  ///
  /// **The redesign's `.scroll` declares `padding:6px 14px 118px` (`:157`), and
  /// this is not it.** The horizontal inset is this design system's
  /// [EvaSpacing.xxl] (24) rather than the prototype's 14, and it is the number
  /// the standing 320×568 viewport matrix is measured against — the four-segment
  /// control's arithmetic in `WorkshopSegmentRow`'s doc is `320 − 2×24` because
  /// of it. The bottom inset is [EvaSpacing.huge] (40) rather than the
  /// prototype's 118, because the 118 is the space the redesign's bottom dock
  /// occupies and the dock is Phase 6's.
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(
    EvaSpacing.xxl,
    0,
    EvaSpacing.xxl,
    EvaSpacing.huge,
  );

  /// The gap between the header and the first group, and between groups.
  ///
  /// **The Phase-9 value, and the redesign does not replace it.** The prototype's
  /// `.scroll` declares no gap between its children, and the only margin in that
  /// neighbourhood is the `.sgroup`'s own 20px (`:422`), which `SettingsGroup`
  /// already owns. So the separation between two groups on this screen is
  /// [groupGap] **plus** `SettingsGroup.topGap` — the client's number, and it is
  /// recorded here rather than smoothed.
  static const double groupGap = EvaSpacing.xxl + EvaSpacing.xs;

  @override
  Widget build(BuildContext context) {
    // Two sources for one cubit, one provider either way — see [cubit].
    final SettingsCubit? passed = cubit;
    final SettingsCubit resolved = passed ?? getIt<SettingsCubit>();

    return BlocProvider<SettingsCubit>.value(
      value: resolved,
      child: const _SettingsBody(),
    );
  }
}

/// Everything below the app bar: the seven groups and the restore toast.
///
/// ## WHY IT IS A **`StatefulWidget`** NOW, AND WHAT DID NOT CHANGE
///
/// It was a `StatelessWidget` through Phase 9, and the reason it gave was
/// measured: "this screen dispatches nothing on entry: its data came from a
/// singleton before the first frame, and a dispatch in `build` would re-apply a
/// reader's settings on every rebuild of the page".
///
/// **That reason still holds and the dispatch is still absent.** What changed is
/// that the screen now owns a **piece of local state** — the restore toast's
/// message and the timer that takes it away again — and a `StatelessWidget` has
/// nowhere to put either. The state is *not* the reader's preferences: those live
/// in the cubit, and every row writes through it.
///
/// ## AND WHY THE TOAST IS **NOT** IN THE CUBIT
///
/// Because it is not a preference. It is a message with a lifetime, it is
/// announced rather than stored, and nothing reads it back — a field on
/// `UserSettings` would be a value the reader could not change and could not
/// clear.
///
/// ## AND WHY **THE PAGE** OWNS THE CLOCK, WHICH IS A **DEPARTURE** FROM THE
/// ## TASK'S OWN BRIEF
///
/// The brief said: "**The 1800ms timer belongs to a widget, not to the
/// page.** … So the toast is a feature-local widget that owns its own
/// lifetime — a `StatefulWidget` that shows for 1800ms and then hides, with the
/// timer disposed on unmount. **The page tells it to show; the page does not
/// own the clock.**"
///
/// **The implementation is the other way round, and the reason is that the
/// brief's own reason does not hold.** The brief's reason was that "a timer is
/// state" and "the page's body is a `StatelessWidget` today" — but the body
/// is stateful *because* it holds the toast's **message**, and the message has
/// to be somewhere the page can clear.
///
/// **Splitting them would have put the toast's state in two owners**: the
/// message in the page and the clock in the widget, which would then need a
/// `show` flag, a `hide` and a callback for the page to learn that the toast
/// had gone — **and the page would still be stateful**, because it still held
/// the message. So the split would have bought a callback and a flag and lost
/// nothing.
///
/// **The page owns the message and the clock; `WorkshopRestoreToast` paints
/// the message.** The timer is disposed in [dispose] ✓, so a reader who
/// navigates away mid-toast does not leave a timer running.
///
/// This is a **recorded departure from the brief**, and the rule the brief
/// itself states is the rule it breaks: "Every divergence … is recorded at its
/// site."
class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  /// The toast's message, or `null` when no toast is up.
  String? _toastMessage;

  /// The timer that takes the toast away.
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  /// Raises the toast for [message] and takes it away again after
  /// [kRestoreToastDuration].
  ///
  /// **The timer is cancelled first**, because the prototype's own `toast(m)`
  /// does exactly that (`:1393` — `clearTimeout(t._x)` before the new timeout),
  /// and a second restore while the first toast is up must not leave two timers
  /// racing to clear the same message.
  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(kRestoreToastDuration, () {
      // `mounted` because the timer outlives a route pop: a screen that has been
      // disposed must not call `setState` on the way out.
      if (!mounted) return;
      setState(() => _toastMessage = null);
    });
  }

  /// The restore action.
  ///
  /// ## WHAT IT DOES, IN WHICH ORDER
  ///
  /// The write first, the toast second. The write is **optimistic** — the cubit
  /// emits before it persists — so the reader sees the restored values on the
  /// frame the row is pressed.
  ///
  /// ## AND THE TOAST IS RAISED **ONLY WHEN THE WRITE IS CONFIRMED**
  ///
  /// The prototype raises it unconditionally (`:1525`), because the prototype's
  /// reset is local JavaScript and **cannot fail**. **This client's can**:
  /// `SettingsCubit.apply` rolls back and records the failure, and this screen
  /// says so in its own **failure notice** above the groups.
  ///
  /// **So a toast that said "nocturne defaults restored" over a screen that was
  /// simultaneously saying "your preferences could not be saved" would be two
  /// sentences about one event, and they would contradict each other.** The
  /// toast is therefore raised after the write is confirmed, and it is **not**
  /// raised at all when the write failed — the failure notice speaks, and it
  /// says why.
  ///
  /// `SettingsCubit.apply` emits optimistically and `_persist` emits again with
  /// the store's answer, so the status **after** the `await` is the outcome.
  /// The `await` is what makes the difference, and the method is therefore
  /// `async` rather than the fire-and-forget it could have been.
  Future<void> _restore() async {
    final SettingsCubit cubit = context.read<SettingsCubit>();
    await cubit.restoreDefaults();
    // `mounted` first: the reader may have left the screen while the write was
    // in flight, and `setState` on an unmounted widget throws.
    if (!mounted) return;
    if (cubit.state.status == SettingsStatus.failed) return;
    _showToast(context.l10n.settingsRestored);
  }

  /// The toast, **anchored to the viewport** and **transparent to taps**.
  ///
  /// `NeuralScaffold.overlay` is the viewport-fixed slot, and the reason a toast
  /// in the page's own column would be wrong is `/communion`'s: it would scroll
  /// away with the content and it would sit inside the scroll view's box rather
  /// than the viewport's.
  Widget? _toastOverlay() {
    final String? message = _toastMessage;
    if (message == null) return null;
    return Stack(
      children: <Widget>[
        Positioned(
          left: 20,
          right: 20,
          // The prototype's `bottom: 110px` (`:466`).
          bottom: 110,
          // `:466` ends `pointer-events:none` — a confirmation is a **notice**,
          // not a control, and it must never take a tap that belonged to the row
          // under it. `IgnorePointer` leaves the semantics tree alone, and the
          // live-region announcement is the point of the toast.
          child: IgnorePointer(child: WorkshopRestoreToast(message: message)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;

    return NeuralScaffold(
      // `eva/redesign.html:644`'s `.scroll` container is the page's own scroll, and
      // `NeuralScaffold`'s doc names `/settings` as one of the three screens whose
      // root scrolls. **The page does not fit at 320×568** and that is the
      // standing gate's assertion, not an accident.
      scrollable: true,
      padding: EdgeInsets.zero,
      // The viewport-fixed slot — see [_toastOverlay].
      overlay: _toastOverlay(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const WorkshopAppBar(),
          const SizedBox(height: SettingsPage.groupGap),
          Padding(
            padding: SettingsPage.contentPadding,
            child: _groups(context, strings),
          ),
        ],
      ),
    );
  }

  /// The seven groups, in the prototype's DOM order.
  ///
  /// ## WHY IT IS A **METHOD** AND NOT A BUILD-TIME LIST
  ///
  /// Because the groups read the **state**, and the state changes: a reader who
  /// drags the Hue slider has to see the swatch move, and a reader who flips the
  /// Daylight switch has to see the whole screen repaint. A list built once would
  /// be a list built from the first frame's state.
  ///
  /// ## AND WHY IT NO LONGER TAKES THE STATE
  ///
  /// **Because each row reads its own setting, through its own
  /// [BlocSelector].** This method used to take the whole `SettingsState` and
  /// hand it to thirty-three rows, and the cost of that was measured rather than
  /// assumed: **one hue change rebuilt 1,236 widgets** — every row, every
  /// control, every `SettingsTile` — because a single `BlocBuilder` over the
  /// whole form re-ran this method and every row was a fresh widget instance.
  ///
  /// A reader who drags the Hue slider changes **one number**, and the screen
  /// now rebuilds **one row**. The rows that read nothing are not rebuilt at
  /// all, because they are not under a selector.
  ///
  /// The measurement is `test/rebuild_isolation_budget_test.dart`, and the
  /// budget is asserted there — which is the only kind of claim about a number
  /// this repository accepts.
  Widget _groups(BuildContext context, AppLocalizations strings) {
    final SettingsCubit cubit = context.read<SettingsCubit>();
    // The **handle**, and only for the two communion rows.
    //
    // `SettingsCubit` has no `setVeilWitnesses` and no `setShowPodium` — the two
    // `/communion` fields were given their writers on the **handle**, which is the
    // widget-facing projection of the cubit (`settings_handle.dart:142,149`). The
    // handle's `write` is the same cubit's `apply`, so the write is the same write.
    //
    // **And it is read WITHOUT a dependency** — `SettingsScope.handleOf`, not
    // `SettingsScope.of`. The handle is a locator singleton whose identity never
    // changes, so a dependent lookup here would rebuild this whole thirty-three-row
    // form on **every** settings write, which is what it used to do: one hue
    // change rebuilt **1,236 widgets**. The rows read their own values through
    // their own `_SettingRow`, so nothing here needs the whole record.
    final SettingsHandle handle = SettingsScope.handleOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ## THE FAILURE NOTICE, ABOVE THE GROUPS
        //
        // `_SettingsFailureNotice` is rendered **above** the groups and the
        // groups are rendered regardless — deliberately, and the reasoning is in
        // its own doc, which has not changed.
        //
        // **And it reads the status through its own selector**, so a write that
        // succeeds does not rebuild it — and a write that fails rebuilds it
        // without rebuilding the thirty-two rows below.
        BlocSelector<SettingsCubit, SettingsState, SettingsStatus>(
          selector: (SettingsState state) => state.status,
          builder: (BuildContext context, SettingsStatus status) =>
              status == SettingsStatus.failed
              ? _SettingsFailureNotice(strings: strings)
              : const SizedBox.shrink(),
        ),

        // --- 1. the language group (`:645-648`) ---------------------------
        SettingsGroup(
          label: strings.settingsWsLang,
          children: <Widget>[
            // The full-width 2-segment control. **Not** a `SettingsTile`: the
            // prototype's `:646-648` is a bare `.segp.wide` in the scroll
            // container, with no `.srow` around it.
            SegmentedControl<ReadingLanguage>(
              values: ReadingLanguage.values,
              // The language **on screen**, and not the stored one: the stored
              // value is `null` for "follow the platform", so a control that read
              // it would show no selection at all on a screen that is entirely in
              // Arabic. `selectedLanguageOf` is the derivation for exactly that
              // question.
              selected: selectedLanguageOf(context),
              // The client's own-script names — `settings_l10n.dart`'s rule, "a
              // language names itself in its own script". **A divergence from
              // `:647`**, which writes the raw `English` and `العربية`.
              labelOf: strings.languageLabelFor,
              // `:186` — `.segp button[data-l=ar]{font-family:var(--ar);…}`.
              // The rule is keyed on the **option**, not on the direction, and
              // `SegmentedControl.labelFamilyOf`'s own doc says so in as many
              // words: "on the **English** arm the Arabic option is still Amiri,
              // because the selector is `data-l=ar`". Under RTL `arabicAware`
              // resolves the whole control to Amiri anyway, which is what `:190`
              // asks for.
              //
              // **The English option is given the control's own family** — which is
              // what it would have had anyway — because `labelFamilyOf` is a
              // `String Function(T)` and a function that returns nothing is not
              // one.
              //
              // ## AND THE **THREE** DIVERGENCES THIS ONE CALL SITE CARRIES
              //
              // 1. **The labels are the client's own-script names**, not `:647`'s
              //    raw `English` / `العربية` — the `settings_l10n.dart` rule, and
              //    the divergence the brief records.
              // 2. **So the Arabic-named option carries the Arabic face on the
              //    English arm too**, where its own text is the Latin word
              //    "Arabic". That is a direct consequence of (1) and of `:186`
              //    being keyed on the option; it is recorded here rather than
              //    "fixed", because the prototype's own rule is the one being
              //    transcribed.
              // 3. **The Arabic option is 13px in the prototype** (`:186`) and
              //    the client draws every wide segment at 11px (`:189`). The
              //    control has no per-option size, and the wide mode's 11px is
              //    what makes four segments fit at 320px.
              labelFamilyOf: (ReadingLanguage language) =>
                  language == ReadingLanguage.arabic
                  ? EvaTypography.arabicFamily
                  : EvaTypography.monoFamily,
              // The control's own name. **Not** the group's header: the header is
              // the prototype's bilingual label (`language · اللغة`), and a name
              // that reads "language · language" aloud is not a name.
              semanticLabel: strings.settingsLanguageLabel,
              wide: true,
              onChanged: (ReadingLanguage language) =>
                  unawaited(cubit.setLanguage(language)),
            ),
          ],
        ),
        const SizedBox(height: SettingsPage.groupGap),

        // --- 2. the theme group (`:649-650`) ------------------------------
        SettingsGroup(
          label: strings.settingsThemeGroup,
          children: <Widget>[
            // ## IT READS **TWO** SETTINGS, AND THAT IS WHY IT IS A **RECORD**
            //
            // The switch's own value is the theme, and the haptic it fires reads
            // the haptics setting — so a change to **either** must rebuild this
            // row, or the switch and the tick would disagree.
            //
            // A Dart **record** compares structurally, so `(bool, bool)` is
            // compared field by field and rebuilds exactly when one of the two
            // moves. Two separate selectors would not do: the second would
            // rebuild the row on its own, and the first would have to be told
            // about the second.
            _SettingRow<(bool, bool)>(
              read: (UserSettings s) => (daylightOnFor(s.themeMode), s.haptics),
              builder: (BuildContext context, (bool, bool) value) => WorkshopToggleRow(
                title: strings.settingsDaylight,
                // ## THE NARROWING, AND THE PRODUCT CONSEQUENCE IT HAS
                //
                // A stored `system` renders the switch **off**, and the stored
                // value is **not** changed until the reader touches the control —
                // so a reader who stored `system` keeps following the OS until
                // they touch it.
                //
                // **And touching it narrows the choice for good.** The only
                // writer of the theme on this screen is
                // `SettingsCubit.setDaylight`, and it writes `light` or `dark`
                // and never `system` — so the `system` arm of `AppThemeMode`, a
                // shipped capability since Phase 0 ("the reader asked to follow
                // the OS"), becomes **unreachable from the UI**. The cubit's own
                // doc carries that half of the record; this is the control's
                // half.
                value: value.$1,
                onChanged: (bool daylight) {
                  // `eva/redesign.html:1482` — `el('setDaylight').onchange=e=>{…
                  // if(V)V.spike=.4; haptic(15); }`. The tick is on the change,
                  // and it is the **reader's own** switch being answered.
                  fireRitualHaptic(
                    RitualHaptic.daylightToggled,
                    enabled: value.$2,
                  );
                  unawaited(cubit.setDaylight(daylight: daylight));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: SettingsPage.groupGap),

        // --- 3. the light workshop (`:651-665`) ---------------------------
        //
        // ## THE TEN CONTROLS BELOW DRIVE THE AURORA
        //
        // Task 5.8 mounted `LumenCanvas` in the screen root, and these ten
        // preferences are its inputs: `LumenPreferences.fromSettings` is the
        // projection, and `LumenScene` is what turns them into the shader's
        // sixteen uniforms. The plan's deferral ("Wiring constraint for
        // whoever mounts the painter (Phase 5) … Hoist one `LumenCanvas`
        // above the rebuild boundary",
        // `docs/superpowers/plans/2026-10-13-lumen-redesign.md:805-811`) is
        // discharged.
        //
        // **So the switch beside "Aurora engine" now turns the aurora off**
        // — the prototype's `cvs.style.display='none'` (`:1468`) — and the
        // screen falls back to the legacy background while it is off.
        SettingsGroup(
          label: strings.settingsWsLight,
          children: <Widget>[
            _SettingRow<bool>(
              read: (UserSettings s) => s.shaderEnabled,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsShaderEngine,
                value: value,
                onChanged: (bool enabled) =>
                    unawaited(cubit.setShaderEnabled(enabled: enabled)),
              ),
            ),
            _SettingRow<CurtainShape>(
              read: (UserSettings s) => s.curtainShape,
              builder: (BuildContext context, CurtainShape value) =>
                  WorkshopSegmentRow<CurtainShape>(
                    title: strings.settingsCurtainShape,
                    values: CurtainShape.values,
                    selected: value,
                    labelOf: (CurtainShape shape) => switch (shape) {
                      CurtainShape.top => strings.settingsCurtainTop,
                      CurtainShape.bottom => strings.settingsCurtainBottom,
                      CurtainShape.sides => strings.settingsCurtainSides,
                      CurtainShape.shafts => strings.settingsCurtainShafts,
                    },
                    onChanged: (CurtainShape shape) =>
                        unawaited(cubit.setCurtainShape(shape)),
                  ),
            ),
            _SettingRow<int>(
              read: (UserSettings s) => s.reach,
              builder: (BuildContext context, int value) => WorkshopSliderRow(
                title: strings.settingsReach,
                value: value,
                min: kReachMin,
                max: kReachMax,
                onChanged: (int reach) => unawaited(cubit.setReach(reach)),
              ),
            ),
            _SettingRow<int>(
              read: (UserSettings s) => s.glow,
              builder: (BuildContext context, int value) => WorkshopSliderRow(
                title: strings.settingsBrightness,
                value: value,
                min: kGlowMin,
                max: kGlowMax,
                onChanged: (int glow) => unawaited(cubit.setGlow(glow)),
              ),
            ),
            _SettingRow<int>(
              read: (UserSettings s) => s.touchGlow,
              builder: (BuildContext context, int value) => WorkshopSliderRow(
                title: strings.settingsTouchGlow,
                value: value,
                min: kTouchGlowMin,
                max: kTouchGlowMax,
                onChanged: (int touchGlow) =>
                    unawaited(cubit.setTouchGlow(touchGlow)),
              ),
            ),
            _SettingRow<int>(
              read: (UserSettings s) => s.hue,
              builder: (BuildContext context, int value) => WorkshopSliderRow(
                title: strings.settingsHue,
                value: value,
                min: kHueMin,
                max: kHueMax,
                onChanged: (int hue) => unawaited(cubit.setHue(hue)),
                // `:661` — the swatch sits **after** the range input.
                after: HueSwatch(hue: value),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.multichromeMelt,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsMultichromeMelt,
                value: value,
                onChanged: (bool melting) =>
                    unawaited(cubit.setMultichromeMelt(melting: melting)),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.rayCombing,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsRayCombing,
                value: value,
                onChanged: (bool combing) =>
                    unawaited(cubit.setRayCombing(combing: combing)),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.whiteCores,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsWhiteCores,
                value: value,
                onChanged: (bool white) =>
                    unawaited(cubit.setWhiteCores(white: white)),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.dotVeil,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsDotVeil,
                value: value,
                onChanged: (bool veiled) =>
                    unawaited(cubit.setDotVeil(veiled: veiled)),
              ),
            ),
          ],
        ),
        const SizedBox(height: SettingsPage.groupGap),

        // --- 4. the witness sky (`:666-681`) -------------------------------
        //
        // **This is the one group whose switches change what is on screen today.**
        // The seven `eva.sky.pref.*` preferences are consumed by `/reading`'s sky.
        SettingsGroup(
          label: strings.settingsSkyGroup,
          children: <Widget>[
            _SettingRow<bool>(
              read: (UserSettings s) => s.starsOn,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsStars,
                value: value,
                // **Stars-off HIDES the sky; it does not delete it.** The
                // prototype's Stars-off calls `clearStars()` (`:1483`), but the
                // prototype has no persistence — its stars are DOM elements — while
                // this client's sky is a reader's own record of what they have
                // read. **A divergence from `:1483`, and a decision.**
                onChanged: (bool on) => unawaited(cubit.setStarsOn(on: on)),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.constellationsOn,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsConstellations,
                value: value,
                onChanged: (bool on) =>
                    unawaited(cubit.setConstellationsOn(on: on)),
              ),
            ),
            _SettingRow<int>(
              read: (UserSettings s) => s.starCount,
              builder: (BuildContext context, int value) => WorkshopSliderRow(
                title: strings.settingsStarCount,
                value: value,
                min: kStarCountMin,
                max: kStarCountMax,
                onChanged: (int count) => unawaited(cubit.setStarCount(count)),
              ),
            ),
            _SettingRow<int>(
              read: (UserSettings s) => s.starBrightness,
              builder: (BuildContext context, int value) => WorkshopSliderRow(
                title: strings.settingsStarBrightness,
                value: value,
                min: kStarBrightnessMin,
                max: kStarBrightnessMax,
                onChanged: (int brightness) =>
                    unawaited(cubit.setStarBrightness(brightness)),
              ),
            ),
            _SettingRow<SkyStarShape>(
              read: (UserSettings s) => s.starShape,
              builder: (BuildContext context, SkyStarShape value) =>
                  WorkshopSegmentRow<SkyStarShape>(
                    title: strings.settingsStarShape,
                    values: SkyStarShape.values,
                    selected: value,
                    // ## THE PROTOTYPE'S OWN UNTRANSLATED ENGLISH
                    //
                    // `:673` carries **no `data-i18n`** on any of its four buttons, so
                    // these are the prototype's own words and they stay that way. They
                    // are **widget literals, not ARB keys** — an ARB key whose two arms
                    // are identical would have to join `app_localizations_test.dart`'s
                    // `mustBeIdentical` set, and that set is the gate that catches an
                    // untranslated string.
                    //
                    // **The fourth is `gem`, not `diamond`**: the prototype's class name
                    // is `s-diamond` and its label is `gem`, and the two answer
                    // different questions — the class name reaches the geometry and the
                    // label reaches the reader.
                    labelOf: (SkyStarShape shape) => switch (shape) {
                      SkyStarShape.dot => kStarShapeDot,
                      SkyStarShape.star => kStarShapeStar,
                      SkyStarShape.cross => kStarShapeCross,
                      SkyStarShape.diamond => kStarShapeGem,
                    },
                    onChanged: (SkyStarShape shape) =>
                        unawaited(cubit.setStarShape(shape)),
                  ),
            ),
            _SettingRow<SkyStarField>(
              read: (UserSettings s) => s.starField,
              builder: (BuildContext context, SkyStarField value) =>
                  WorkshopSegmentRow<SkyStarField>(
                    title: strings.settingsStarField,
                    values: SkyStarField.values,
                    selected: value,
                    // The prototype's own untranslated English, for the Star shape
                    // segment's reason: `:678` carries no `data-i18n` either.
                    labelOf: (SkyStarField field) => switch (field) {
                      SkyStarField.crown => kStarFieldCrown,
                      SkyStarField.high => kStarFieldHigh,
                      SkyStarField.full => kStarFieldFull,
                    },
                    onChanged: (SkyStarField field) =>
                        unawaited(cubit.setStarField(field)),
                  ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.twinkle,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsTwinkle,
                value: value,
                // **Combined with the reduce-motion signal, never instead of it** —
                // the prototype's handler sets `notwinkle` when the switch is off
                // **or** reduce motion is on (`:1489`), and the client's sky does
                // the same.
                onChanged: (bool twinkling) =>
                    unawaited(cubit.setTwinkle(twinkling: twinkling)),
              ),
            ),
          ],
        ),
        const SizedBox(height: SettingsPage.groupGap),

        // --- 5. focus & ritual (`:682-689`) --------------------------------
        //
        // **SIX of the seven are read today, and this comment used to say the
        // opposite.** It read "SIX of the seven persist and are read by nothing
        // yet", naming the selah timer, the focus mode, the breath guide, the
        // vespers auto-dim, the calm motion and the haptics as "Phase 7's" —
        // and the Lumen redesign's Phase 7 has since shipped all but one of
        // them. The claim was **stale in the direction that flatters the tree**:
        // it said six controls were inert when five of them are live.
        //
        // | control | read by |
        // | --- | --- |
        // | Focus delay | `features/reading/presentation/pages/reading_page.dart` — the focus dim's idle observer |
        // | Selah length | `features/home/presentation/widgets/selah_card.dart` — the silence's length |
        // | Breath guide | `features/reading/presentation/pages/reading_page.dart:782` — the anchor it draws under |
        // | Vespers auto-dim | `core/design_system/effects/lumen_preferences.dart:82` → `lumen_scene.dart:287` — the ambient's `0.78` factor |
        // | Reduce motion | `app.dart` and `/reading` |
        // | Haptics | `core/design_system/effects/ritual_haptics.dart` — nine call sites |
        // | **Calm motion** | **nothing.** It persists and nothing reads it. |
        //
        // **So the count is ONE, and it is `calmMotion`.** The prototype's own
        // `CALM` flag (`eva/redesign.html:913`) is never read by its `loop`
        // either, and its Workshop deliberately preserves it across a restore
        // (`settings_cubit.dart`'s own table says so) — so this is the
        // prototype's behaviour, transcribed, rather than a gap.
        SettingsGroup(
          label: strings.settingsRitualGroup,
          children: <Widget>[
            _SettingRow<int>(
              read: (UserSettings s) => s.focusDelaySec,
              builder: (BuildContext context, int value) => WorkshopSliderRow(
                title: strings.settingsFocusDelay,
                value: value,
                min: kFocusDelaySecMin,
                max: kFocusDelaySecMax,
                onChanged: (int seconds) =>
                    unawaited(cubit.setFocusDelaySec(seconds)),
              ),
            ),
            _SettingRow<int>(
              read: (UserSettings s) => s.selahLengthSec,
              builder: (BuildContext context, int value) => WorkshopSliderRow(
                title: strings.settingsSelahLength,
                value: value,
                min: kSelahLengthSecMin,
                max: kSelahLengthSecMax,
                // `:684` — `step="5"`, the prototype's **only** stepped slider.
                step: kSelahLengthSecStep,
                onChanged: (int seconds) =>
                    unawaited(cubit.setSelahLengthSec(seconds)),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.breathGuide,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsBreathGuide,
                value: value,
                onChanged: (bool on) => unawaited(cubit.setBreathGuide(on: on)),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.vespersAutoDim,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsVespersAutoDim,
                value: value,
                onChanged: (bool on) =>
                    unawaited(cubit.setVespersAutoDim(on: on)),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.reducedMotion,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsReduceMotion,
                value: value,
                // An **existing** field, and the prototype's own switch.
                onChanged: (bool reduced) =>
                    unawaited(cubit.setReducedMotion(reduced: reduced)),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.calmMotion,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsCalmMotion,
                value: value,
                onChanged: (bool calm) =>
                    unawaited(cubit.setCalmMotion(calm: calm)),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.haptics,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsHaptics,
                value: value,
                // `eva/redesign.html:1498` — `el('setHap').onchange=e=>{
                // HAPTICS=e.target.checked; if(HAPTICS)haptic(15); }`.
                //
                // **The tick is on the way UP only** — the prototype's own `if`
                // says so, and it is the only sensible reading: a reader who has
                // just turned haptics **off** must not be answered with one.
                onChanged: (bool on) {
                  if (on) {
                    // ## THE TICK IS GATED ON THE **NEW** VALUE
                    //
                    // The prototype's handler sets `HAPTICS` **first** and then
                    // asks (`:1498` — `HAPTICS=e.target.checked; if(HAPTICS)
                    // haptic(15);`), so the tick is the answer to the switch
                    // being **on** — not to the value it held before the tap.
                    //
                    // That matters for the one moment a reader most wants to
                    // know it worked: **the tap that turns haptics on**. A
                    // client that read the old value would stay silent on that
                    // very tap, because the old value is `false` — and the
                    // reader would be left not knowing whether the switch did
                    // anything.
                    fireRitualHaptic(RitualHaptic.hapticsEnabled, enabled: on);
                  }
                  unawaited(cubit.setHaptics(on: on));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: SettingsPage.groupGap),

        // --- 6. communion (`:690-695`) -------------------------------------
        SettingsGroup(
          label: strings.settingsCommunionGroup,
          children: <Widget>[
            _SettingRow<bool>(
              read: (UserSettings s) => s.veilWitnesses,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsVeilWitnesses,
                value: value,
                // **Through the handle, not the cubit** — see the note where the
                // handle is resolved. The two `/communion` fields are the only ones
                // on this screen whose writer lives there.
                onChanged: (bool veiled) =>
                    unawaited(handle.setVeilWitnesses(veiled: veiled)),
              ),
            ),
            _SettingRow<bool>(
              read: (UserSettings s) => s.showPodium,
              builder: (BuildContext context, bool value) => WorkshopToggleRow(
                title: strings.settingsShowPodium,
                value: value,
                onChanged: (bool shown) =>
                    unawaited(handle.setShowPodium(shown: shown)),
              ),
            ),
            _SettingRow<int>(
              read: (UserSettings s) => s.fontStep,
              builder: (BuildContext context, int value) => SettingsTile(
                title: strings.settingsTypeSize,
                // ## THE EXISTING STEPPER, AND THE DIVERGENCE FROM `:693`
                //
                // The prototype's Type-size row is a 16–26px range input
                // (`docs/superpowers/plans/2026-10-13-lumen-redesign.md:1172-1173`
                // calls it "a different model") and this client keeps its 1–5 step.
                // **The slider is not transcribed**, and the divergence is
                // recorded here.
                trailing: FontSizeStepper(
                  step: value,
                  onChanged: (int step) => unawaited(cubit.setFontStep(step)),
                  labels: FontSizeStepperLabels(
                    decrease: strings.settingsDecreaseFontSize,
                    increase: strings.settingsIncreaseFontSize,
                    // The **track's** slider label, and it is deliberately a
                    // different string from the row's title: the two name the
                    // control from two positions — a row title and a slider.
                    track: strings.settingsFontScale,
                  ),
                ),
              ),
            ),
            // The preview line (`:694`, CSS `:431`).
            //
            // **The widget owns the margin** — `:431`'s `margin:10px 2px 2px` —
            // so nothing is wrapped around it here. The prototype's 10px above
            // the line is the `.prevline`'s own; the **group's** 10px row gap
            // (`SettingsGroup.rowGap`) is the client's, and the two together put
            // the preview 20px below the Type size row where the prototype has
            // 10. That is the same +10 the client puts between every pair of
            // rows, and it is the client's own number.
            PreviewLine(
              // The prototype's own two literals, in its own scripts (`:996`).
              // **Not an ARB key** — the prototype does not put them in its
              // `I18N` table, and a key whose two arms differ by script rather
              // than by language would be a translation decision nobody made.
              text: previewTextFor(isArabic: strings.isArabicArm),
            ),
            WorkshopRestoreRow(
              title: strings.settingsRestoreDefaults,
              onTap: () => unawaited(_restore()),
            ),
          ],
        ),
        const SizedBox(height: SettingsPage.groupGap),

        // --- 7. about (`:696-698`) ----------------------------------------
        SettingsGroup(
          label: strings.settingsAbout,
          children: <Widget>[
            // The prototype's **own** literals, and they name the **design
            // system's** versions rather than this client's — the client's shader
            // program is `kLumenShaderAsset` and it **is** mounted (Task 5.8).
            // **The row still reports the prototype's version, because that is
            // what the row transcribes. Recorded as such at the row.**
            WorkshopValueRow(
              title: strings.settingsShaders,
              value: kShadersVersion,
            ),
            WorkshopValueRow(
              title: strings.settingsTokens,
              value: kTokensVersion,
            ),
          ],
        ),
      ],
    );
  }
}

/// One Workshop row, rebuilt **only** when the setting it reads changes.
///
/// ## WHY THIS EXISTS, AND THE NUMBER THAT PROVED IT
///
/// `/settings` is the largest form in the app: seven groups, thirty-three rows.
/// It used to read them all from **one** `BlocBuilder` over the whole
/// `SettingsState`, which meant a reader who dragged the Hue slider rebuilt
/// **every row on the screen**.
///
/// **That number is measured, not asserted.** One `cubit.setHue(300)` rebuilt
/// **1,236 widgets** — thirty-one `SettingsTile`s, sixteen `EvaToggle`s, eight
/// `EvaRangeSlider`s, four `SegmentedControl`s and every `Text` under them —
/// for a change to **one number**. The measurement is
/// `test/rebuild_isolation_budget_test.dart`, and it is a **budget** there, so
/// the number cannot go back up without a red test.
///
/// ## WHY A **`BlocSelector`** AND NOT A `buildWhen`
///
/// Because `buildWhen` is all-or-nothing. Every write to the settings changes
/// `state.settings`, so a `buildWhen` on that would never say no — and the
/// question is not *whether* the page rebuilds but *which row* does. A
/// `BlocSelector` narrows the question to one field and rebuilds only when that
/// field's value changes.
///
/// ## AND WHY THE VALUE IS **PROJECTED** RATHER THAN THE WHOLE STATE
///
/// `BlocSelector` compares the selected value with `==`. `UserSettings` is a
/// freezed record, so selecting the whole thing would compare **all thirty
/// fields** and rebuild on any of them — which is the defect in miniature.
/// Selecting one `bool`, one `int` or one enum is a comparison of one value.
///
/// **A `List` or a `Set` would be a trap**: Dart gives both **identity**
/// equality, so a selector returning one would rebuild on every emit. No
/// setting here is a collection, and the type parameter is what keeps that
/// true.
class _SettingRow<T> extends StatelessWidget {
  /// A row that reads the one setting [read] names.
  const _SettingRow({required this.read, required this.builder});

  /// The one setting this row shows, projected out of the whole record.
  final T Function(UserSettings settings) read;

  /// The row, given the value [read] produced.
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<SettingsCubit, SettingsState, T>(
        selector: (SettingsState state) => read(state.settings),
        // A **tearoff**, and not a closure: `builder` already has the shape
        // `BlocSelector` wants, and a closure that only forwards its arguments
        // is a closure the analyzer asks to be removed.
        builder: builder,
      );
}

/// The notice `/settings` shows when `SettingsState.status` is
/// [SettingsStatus.failed].
///
/// ## WHY THIS IS **NOT** `ErrorView`, AND WHY THAT IS THE WHOLE ARGUMENT
///
/// `08-build-phases.md`'s Phase 10 line is "`EmptyState`/`ErrorView` wired into every
/// async page". This screen is the one async page that had a failure state and
/// nothing on screen for it, so the bullet reaches here — and the honest answer is
/// that `ErrorView` is the wrong widget for this position. Three measured reasons,
/// in order of how much they would have cost a reader:
///
/// 1. **The write arm erases the cause.** `SettingsCubit._persist` answers a
///    `FailureResult` by emitting `status: failed, settings: _confirmed` — the
///    control the reader just tapped springs back. An `ErrorView` *in place of* the
///    groups would replace the screen with an error at the exact moment the reader
///    is looking for the control they used, so the screen would stop making sense
///    without saying why. A notice above the groups puts the failure next to the
///    controls it is about.
/// 2. **`ErrorView` fills its box.** `Center` → `SingleChildScrollView` → `Padding`
///    → `Column`, and this screen's root **already scrolls** (`scrollable: true`,
///    `eva/redesign.html:644`'s `.scroll`). Nesting the two gives two scroll views
///    fighting over one gesture.
/// 3. **Its message is not this failure's message.** `ErrorView.message` is required
///    and undocumented-as-optional precisely because `ApiErrorMapper` is the single
///    source of a displayable failure message in this app, and that claim is true of
///    `/`, `/reading` and `/quiz`. `SettingsRepositoryImpl._unreachable` builds
///    `'The preferences could not be reached: $error'`, interpolating the raw Dart
///    exception — a real one on a real device is `MissingPluginException(No
///    implementation found for method … on channel …)`. This widget therefore renders
///    **`settingsPreferencesUnavailable`**, the app's own localised sentence, and
///    deliberately not `state.failure!.message`. See that key's ARB description.
///
/// ## WHAT IT CARRIES, AND IT IS THE SAME FOUR THINGS `ErrorView` CARRIES
///
/// | §14 requirement | here |
/// | --- | --- |
/// | not colour alone | `Icons.error_outline` — the same glyph `ErrorView` uses, which is a shape that differs from `EmptyState`'s — beside the sentence, so `err` is never the only signal |
/// | announced when it arrives | `Semantics(liveRegion: true)`, as `ErrorView` sets |
/// | a retry | [EvaButton] running `SettingsCubit.load()` |
/// | a localised name | `arabicAwareFamily` on the label, because `EvaButton.labelFamily` is required (decision 66) and the label is this app's own string |
///
/// The surface is `GlassTier.tint`, which is §13.4's row for `/settings` — "everything
/// else → `.tint`" — and nothing on this screen blurs, so this adds no `saveLayer`
/// and `glass_blur_budget_test.dart`'s `lib/features/` ceiling of 1 is untouched.
///
/// **One notice for both arms, and it is the same sentence.** The cubit reports a
/// failed read and a failed write through one status, and the reader cannot tell from
/// the screen which happened — "your preferences could not be saved" is true of both,
/// because a failed read means what is on screen is not what is stored, which is the
/// same fact from the other side. Two sentences would be a guess about a state this
/// widget cannot see.
class _SettingsFailureNotice extends StatelessWidget {
  const _SettingsFailureNotice({required this.strings});

  /// The ambient arm's strings. Read once so both the sentence and the retry label
  /// come from the same lookup — the Arabic test asserts they are both Arabic.
  final AppLocalizations strings;

  /// The notice's padding. `SettingsTile.padding` is `0 16px` because a tile's
  /// content is a centred row; this holds a sentence that wraps, so it is
  /// [SettingsTile]'s horizontal inset with [EvaSpacing.lg] vertically.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: EvaSpacing.lg,
    vertical: EvaSpacing.lg,
  );

  /// The gap between the icon and the sentence, and between the sentence and the
  /// retry. `EvaSpacing.md` for both — the icon box is 24 and the button is 40, so
  /// the same step reads correctly at each junction.
  static const double gap = EvaSpacing.md;

  @override
  Widget build(BuildContext context) {
    // `unawaited` because §4 forbids dropping a `Future` as a bare expression
    // statement, and `load()` is the one operation that clears this status without
    // asking the reader to change something else first. A local **function**, not a
    // `VoidCallback` variable, because `prefer_function_declarations_over_variables`
    // is enabled.
    void retry() => unawaited(context.read<SettingsCubit>().load());

    return Padding(
      // `EvaSpacing.sm` above and `SettingsPage.groupGap` below: the notice is a
      // peer of the seven groups, not one of their rows, so it takes the same
      // separation from its neighbours that they take from each other.
      padding: const EdgeInsets.only(
        top: EvaSpacing.sm,
        bottom: SettingsPage.groupGap,
      ),
      child: GlassSurface(
        // `GlassTier.tint` is `GlassSurface`'s own default, so no `tier:` is
        // passed — which is the same decision this class's doc records: §13.4 rows
        // `/settings` under `tint`, and the screen had to be *chosen*, not left.
        radius: SettingsTile.radius,
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ## THE `liveRegion` WRAPS **ONLY** THE SENTENCE, AND THAT IS LOAD-BEARING
            //
            // The first version put the action **inside** the `Semantics(
            // liveRegion: true)`, and it fused the two into one node. Measured on the
            // pumped tree, not reasoned about:
            //
            // ```text
            // live=true  btn=true  label="Your preferences could not be saved on this device.|Try again"
            // ```
            //
            // One node that is at once the error, the sentence and a button — the
            // retry control has **no node of its own**, so a screen reader announces
            // a sentence as a button and the reader cannot tell what pressing it
            // would do. `Semantics` with `container: false` merges its subtree into
            // one node, and putting a labelled `EvaButton` under it is enough.
            //
            // `ErrorView` does not have this problem and the reason is worth naming,
            // because it is the opposite construction: measured on `/reading`'s
            // failed state, its live region is a **container** whose two children are
            // the message and the button —
            //
            // ```text
            // live=true  label=""
            //   ├─ "Could not reach the server."
            //   └─ "Try again"  (isButton, tap)
            // ```
            //
            // — which is the shape this now takes too, with the difference that the
            // container here is also given `label:`, so the region is not empty.
            Semantics(
              liveRegion: true,
              label: strings.settingsPreferencesUnavailable,
              child: ExcludeSemantics(
                // The sentence is drawn by the `Text` below, and the icon is
                // decorative — §14 has no use for a glyph announced on its own. The
                // label on the node above carries the sentence instead, so nothing
                // is said twice.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      // The same glyph `ErrorView` draws, and for its reason: a shape
                      // that differs from an empty state's, so the two states are told
                      // apart without colour.
                      Icons.error_outline,
                      size: ErrorView.iconSize,
                      color: context.colors.errInk,
                    ),
                    const SizedBox(width: gap),
                    // `Expanded`, and this is not decoration: the sentence wraps to
                    // several lines on the Arabic arm and at 1.22×, and an
                    // unconstrained `Text` in a `Row` is a horizontal overflow —
                    // measured at 94 pixels on the right with a bare `Text` here. The
                    // `*_text_scale_test.dart` for this screen is what holds it.
                    Expanded(
                      child: Text(
                        strings.settingsPreferencesUnavailable,
                        style: arabicAware(
                          Theme.of(context).textTheme.bodyMedium!,
                          Directionality.of(context),
                        ).copyWith(color: context.colors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: gap),
            // `Align` rather than `crossAxisAlignment: start`, which is what puts
            // `EvaButton` at its natural width in a stretched `Column`. The same
            // shape `ErrorView`'s retry takes, for the same reason: a full-width
            // "Try again" on a screen whose only other button is full-width reads
            // as two primaries.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: EvaButton(
                label: strings.settingsRetry,
                // Required since decision 66, and this label is the app's own
                // localised string — so on the Arabic arm it is Arabic text going
                // into a button that names its family explicitly. `ErrorView`'s
                // `retryFamily` is the precedent.
                labelFamily: arabicAwareFamily(
                  Directionality.of(context),
                  EvaTypography.uiFamily,
                ),
                onPressed: retry,
                expanded: false,
                variant: EvaButtonVariant.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
