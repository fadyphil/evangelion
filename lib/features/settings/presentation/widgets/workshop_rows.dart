/// The Workshop's row vocabulary — the shapes a row on `/settings` takes.
///
/// `eva/redesign.html:638-700` is the screen, and its rows are all
/// `<div class="srow">` elements (`:419`). The client's row is `SettingsTile`,
/// which is that element's Phase-4 transcription, and this file holds the
/// **trailing controls** the redesign draws in them.
///
/// The **segmented** row is in a file of its own
/// (`workshop_segment_row.dart`), because it is the only one whose *layout*
/// differs — the label goes above the control — and the measurement that forces
/// that belongs next to the one widget it governs.
///
/// ## WHY THEY ARE WIDGETS AND NOT INLINE IN THE PAGE
///
/// Because there are **29 interactive rows** and four shapes among them, and a
/// screen that spelled out `SettingsTile(title: …, trailing: EvaToggle(…))`
/// twenty-nine times would put the row's own transcription in twenty-nine places
/// — which is the shape of thing that drifts. Each widget owns one shape, and
/// the page owns the composition.
///
/// ## AND WHY THEY ARE **NOT** IN `core/design_system/`
///
/// A design-system widget is one with more than one caller, and each of these has
/// exactly one: `/settings`. `SettingsGroup`'s own doc records the same deferral
/// for the same reason — "there is still nowhere to put the result".
library;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/settings/presentation/workshop_logic.dart';
import 'package:flutter/material.dart';

/// A row whose trailing control is a **switch**.
///
/// `eva/redesign.html:650`, `:652`, `:662-665`, `:667-668`, `:681`, `:685-689`,
/// `:691-692` — the workshop's **sixteen** switch rows.
///
/// **`:650` IS IN THE LIST, AND IT IS THE ONE THAT MATTERS MOST.** It is the
/// Daylight toggle, the theme group's only control, and the one the client's
/// **two-state switch against a three-state field** is about: on means the
/// light palette, off means the dark one, and a stored `system` renders it off
/// without changing the stored value until the reader touches it. The
/// divergence is recorded at the control.
class WorkshopToggleRow extends StatelessWidget {
  /// A row titled [title] with a switch on [value].
  const WorkshopToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The row's label, and **the switch's own accessible name**.
  ///
  /// ## WHY THE NAME IS THE **ROW'S TITLE** AND NOT A STATE WORD
  ///
  /// `EvaToggle` publishes `Semantics(label: labels.on / labels.off, toggled:
  /// value, excludeSemantics: true)`, so the two strings it is given **are** the
  /// node's name — and the name changes with the switch's position. A name that
  /// changes with the state is a **state** name, not a **control** name: a screen
  /// reader reaching the node hears "On, switch" and learns nothing about what
  /// the switch is for.
  ///
  /// The state is not lost by naming the control: `EvaToggle` already sets
  /// `toggled`, so the node announces "Reduce motion, switch, on" — the control
  /// and its state, in that order.
  ///
  /// **And the row's title cannot supply the name itself.** `SettingsTile` wraps
  /// its title in `ExcludeSemantics` (`settings_tile.dart:268`) precisely so the
  /// trailing control's node does not repeat it, and the effect is that a
  /// non-interactive row's title reaches **no** node at all. The trailing control
  /// is therefore the only thing that can name the row, and it names it with the
  /// row's own words.
  final String title;

  /// Whether the switch is on.
  final bool value;

  /// Reports the new position.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SettingsTile(
    title: title,
    trailing: EvaToggle(
      value: value,
      onChanged: onChanged,
      // The control's name in **both** arms. See [title].
      labels: EvaToggleLabels(on: title, off: title),
    ),
  );
}

/// A row whose trailing control is a **slider**.
///
/// `eva/redesign.html:658-661`, `:669-670`, `:683-684` — the workshop's eight
/// slider rows.
class WorkshopSliderRow extends StatelessWidget {
  /// A row titled [title] with a slider over `min…max` on [value].
  const WorkshopSliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.after,
    super.key,
  });

  /// The row's label, and the slider's own accessible name.
  ///
  /// ## WHY IT IS THE **ROW'S TITLE**
  ///
  /// For [WorkshopToggleRow]'s reason: `SettingsTile` excludes its title from the
  /// semantics tree, so the trailing control is the only thing that can name the
  /// row, and `EvaRangeSlider.semanticLabel` is **required** for exactly this
  /// reason (§14's first row — a control with no name in the reader's own
  /// language).
  final String title;

  /// The slider's value.
  final int value;

  /// The slider's lower bound.
  final int min;

  /// The slider's upper bound.
  final int max;

  /// Reports the new value, already clamped and already stepped.
  final ValueChanged<int> onChanged;

  /// The slider's granularity.
  ///
  /// `1` for seven of the eight rows. The eighth is the prototype's own stepped
  /// slider, `eva/redesign.html:684` — `step="5"` on a range of 15–120.
  final int step;

  /// A widget drawn **after** the slider, with the prototype's 8px gap.
  ///
  /// `null` for seven of the eight rows. The eighth is the Hue row, whose
  /// trailing is the slider **and** the swatch: `eva/redesign.html:661` puts
  /// `<span class="huesw">` after the range input, and `:432` gives the swatch
  /// `margin-left:8px` — which is the gap this parameter's row draws.
  final Widget? after;

  @override
  Widget build(BuildContext context) {
    final Widget slider = EvaRangeSlider(
      value: value,
      min: min,
      max: max,
      step: step,
      onChanged: onChanged,
      semanticLabel: title,
      // **No `valueLabel`.** The prototype paints no number at all
      // (`eva/redesign.html:429-430` declare no content), so the client paints
      // none either, and the announced value is the raw number — which is what
      // `EvaRangeSlider` falls back to. The unit is the caller's, and the
      // prototype's own `secs` (`:970`) is a **phrase** ("seconds of silence"),
      // not a unit, so using it would turn a slider's value into a sentence.
    );
    final Widget? trailing = after;
    if (trailing == null) {
      return SettingsTile(title: title, trailing: slider);
    }
    return SettingsTile(
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          slider,
          // `:432` — `margin-left:8px` on the swatch.
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

/// A row whose trailing is a **static value** — the About group's two rows.
///
/// `eva/redesign.html:697-698` — `<div class="srow" style="cursor:default"><span
/// data-i18n="shaders">Shaders</span> <span class="ar">aurora.frag v8</span></div>`.
///
/// ## WHY THE VALUE IS **NAMED**
///
/// `SettingsTile` excludes its title from the semantics tree, and this row has no
/// trailing **control** to carry the name — so without a name of its own the row
/// would announce "aurora.frag v8" and nothing else, which is a value with no
/// subject. The node therefore carries both, and the value's own text is excluded
/// from it so the two are not said twice.
///
/// ## AND IT IS **NOT** MIRRORED UNDER RTL
///
/// `eva/redesign.html:138` mirrors **every** `.srow .ar` span under RTL, and this
/// value is in a `.srow .ar` span — so a literal transcription would render
/// `aurora.frag v8` **backwards**. The rule's subject is the arrow on the
/// restore row (`:695`), and a version string is not an arrow. The mirror is
/// applied there and not here, and that narrowing is recorded at the restore row
/// too.
class WorkshopValueRow extends StatelessWidget {
  /// A row titled [title] showing [value].
  const WorkshopValueRow({required this.title, required this.value, super.key});

  /// The row's label.
  final String title;

  /// The value the row shows.
  final String value;

  @override
  Widget build(BuildContext context) => SettingsTile(
    title: title,
    trailing: Semantics(
      container: true,
      label: '$title: $value',
      excludeSemantics: true,
      child: Text(value, style: _arValueStyle(context)),
    ),
  );
}

/// The restore action row — a **tappable** row whose trailing is the `↺`.
///
/// `eva/redesign.html:695` — `<div class="srow" id="resetLight"><span
/// data-i18n="restore">Restore nocturne defaults</span> <span class="ar">↺</span></div>`.
///
/// ## WHY IT IS **TAPPABLE**, AND EVERY OTHER ROW IS NOT
///
/// Every other `.srow` in the markup carries `style="cursor:default"` and this one
/// does not. The prototype's own handler is bound to the row (`:1499`), so the row
/// is the control, and `SettingsTile` with an `onTap` is the client's shape for
/// that: it brings the row's own `EvaInk`, its own `EvaFocusRing` and its own
/// `Semantics(button: true)`.
///
/// ## AND WHY THE `↺` IS **MIRRORED** UNDER RTL
///
/// `eva/redesign.html:138` — `[dir=rtl] .srow .ar{display:inline-block;
/// transform:scaleX(-1)}` — mirrors the row's `.ar` span, and the restore row's
/// `.ar` span is the arrow.
///
/// **The mirror is explicit, and it has to be.** U+21BA has no `Bidi_Mirrored`
/// property, so no text engine mirrors it by itself — `matchTextDirection` is an
/// `IconData` property and this is a glyph, not an icon. The transform is
/// therefore painted here.
///
/// **And the prototype's blanket rule is narrowed to the arrow.** `:138` mirrors
/// **every** `.srow .ar` span, which would also mirror the About rows' version
/// strings and render `aurora.frag v8` backwards. The rule's subject is the
/// arrow, and the client mirrors the arrow only. Recorded at the About rows.
///
/// ## AND WHAT THE ROW **DOES**, AND WHAT IT **DOES NOT**
///
/// The prototype's handler is `:1499-1525`, and the client's reset is the same
/// set: the light, the sky, the ritual and the communion preferences go back to
/// the prototype's literals, and **nothing else does**.
///
/// **The three deliberate departures from the prototype, each with its line:**
///
/// 1. **`themeMode` is not reset.** The prototype resets the daylight to dark
///    (`:1501`) and this client does not: `themeMode` is a **three-state** enum
///    whose `system` arm the prototype has no word for, and the orchestrator's
///    decision protects the stored value as an existing reader choice.
/// 2. **`calmMotion` is not reset**, although it is a new field. The prototype's
///    handler touches neither `setCalm` nor `setHap` (`:1499-1525`), because it
///    is a comfort choice.
/// 3. **`haptics` is not reset**, for the same reason.
///
/// **And the hue**: the prototype's reset restores the **current book's** hue
/// (`:1523`) and this client has no per-book hue, so the reset uses the declared
/// control default of `312` (`:661`).
///
/// The per-field tables are in the Task 5.7 plan block and in
/// `SettingsCubit.restoreDefaults`'s own doc, which is where the *writer* is.
class WorkshopRestoreRow extends StatelessWidget {
  /// A row titled [title] that runs [onTap] when it is pressed.
  const WorkshopRestoreRow({
    required this.title,
    required this.onTap,
    super.key,
  });

  /// The row's label.
  final String title;

  /// What to run when the row is pressed.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextDirection direction = Directionality.of(context);
    final Text arrow = Text(kRestoreGlyph, style: _arValueStyle(context));

    return SettingsTile(
      title: title,
      onTap: onTap,
      trailing: direction == TextDirection.rtl
          // The mirror. See the class doc.
          ? Transform(
              transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
              child: arrow,
            )
          : arrow,
    );
  }
}

/// The `.ar` style — `eva/redesign.html:421`.
///
/// ```css
/// .srow .ar{color:var(--ink-1);font-family:var(--mono);font-size:11px}
/// ```
///
/// ## THE THREE NUMBERS, AND WHAT EACH ONE IS
///
/// * the **11px** is the prototype's own, and it is **not** the `.mono` class's
///   10.5px (`:30`) — the `.ar` span is a different rule with a different size;
/// * the **tracking is none**, because `:421` declares no `letter-spacing` — and
///   it is written out as `0` rather than left inherited, because
///   `EvaTypography.monoCaps` carries `labelMedium`'s 0.5 and the prototype's rule
///   is not that one;
/// * the ink is `--ink-1`, which this design system has no token for: `EvaColors`
///   publishes `ink`, `ink2` and `ink3`, and the **middle** ink of the prototype's
///   three stands as `ink2` — `stat_tile.dart`'s own doc gives the argument, and
///   `eva_button.dart` and `icon_action_button.dart` make the same substitution.
///
/// ## AND THE `fontFamilyFallback`
///
/// `Inter`, and only because of the **arrow**: U+21BA is in no bundled mono or
/// scripture face. Flutter falls back **per glyph**, so the mono face draws the
/// letters and Inter draws the arrow. The About rows' values carry it too
/// because they share this one style, and it is inert for them — every character
/// they use is in the mono face.
TextStyle _arValueStyle(BuildContext context) {
  final EvaColors colors = context.colors;
  return arabicAware(
    EvaTypography.monoCaps(colors).copyWith(
      fontSize: 11,
      letterSpacing: 0,
      color: colors.ink2,
      fontFamilyFallback: const <String>[EvaTypography.uiFamily],
    ),
    Directionality.of(context),
  );
}
