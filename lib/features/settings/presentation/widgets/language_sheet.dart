import 'dart:async';

import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/settings/presentation/settings_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Opens the language picker and **changes the app's locale when a choice is made**.
///
/// ## THIS IS DEFECT #7, AND THE FAB IT NAMED **DOES NOT EXIST**
///
/// `01-source-analysis.md`'s row is: "FAB 'Language' item silently does nothing.
/// `screen: null` → closes the dock, navigates nowhere. Dead-end UI. **Phase 9**:
/// `FabDockItem` takes `onPressed`; the Language item opens a real language sheet."
///
/// **Measured before implementing it: there is no FAB.** `rg -i sealfab|fabdock lib
/// test` returns one hit in `lib/` — `home_page.dart:102`'s doc recording that
/// `SealFAB` **is cut** — plus four more that are all prose about the cut
/// (`eva_elevations.dart`, `eva_chip.dart`, `glass_surface.dart`, and two goldens'
/// inventory tables). `04-widget-inventory.md` §3 items 27–28 ("`SealFab` +
/// `FabDockItem` — fixes #7 … The dock is down to 2 items: Settings and Language")
/// were cut with the profile screen under §2 decision 1, and
/// `home_geometry_test.dart:41` asserts the absence.
///
/// So the dead-end control is gone and the defect's *substance* — a Language control
/// that navigates nowhere — is what this function fixes. **Rebuilding a `SealFab` to
/// host it would have re-litigated decision 1** and put a second blur site on `/`,
/// which `glass_blur_budget_test.dart` holds at one. The language control ships on the
/// screen the prototype also puts one on (`SettingsScreen.tsx:76`, "Default
/// language"), which is where a reader looks for it.
///
/// ## IT **CHANGES THE LOCALE**, AND THAT IS THE PART THAT IS EASY TO FORGET
///
/// A picker that closes without writing is the defect restated one layer down. The
/// three things that must be true when a reader picks `العربية`, and each has an
/// assertion:
///
/// 1. `SettingsHandle.setLanguage` wrote it — the round trip through
///    `shared_preferences`, in `settings_repository_test.dart`;
/// 2. `app.dart`'s `MaterialApp.locale` changed — `app_test.dart`, which reads the
///    live `MaterialApp`;
/// 3. **the corpus re-fetched.** `/`, `/reading` and `/quiz` each re-dispatch on a
///    locale change, and each already recorded that as the trigger Phase 9 would
///    cause (`HomePage`'s `_requested`-not-`_started` note, `_ReadingBody`'s
///    `didChangeDependencies` note, `QuizBloc`'s note). A locale change with no
///    re-fetch is English chrome over Arabic scripture, and each of those three
///    suites drives it.
///
/// ## IT IS A **MODAL** SHEET, AND A MODAL IS NOT FREE
///
/// `showModalBottomSheet` is the right kind of thing for this and the cost is
/// recorded rather than discovered: it inserts a route, so the settings page's own
/// `didPopNext`-equivalent does not exist but `SettingsScope` keeps the row's value
/// correct because the cubit — not the page — owns it. That is why this screen has no
/// `State` and no `AutoRouteAware`: **there is nothing per-visit here to remember.**
/// The `textSizePanelOpen` flag on `/reading` is the counter-example, and its doc
/// gives the rule this file exists to satisfy.
///
/// **`useSafeArea: true` and `showDragHandle: false`.** The theme's
/// `bottomSheetTheme` already rounds only the top corners and zeroes the modal
/// elevation (`eva_theme.dart`'s D1 section), so the sheet reads as Eva rather than as
/// a stock Material sheet — but a stock Material sheet also draws a drag handle, and
/// §3's inventory counts no such affordance for this design. Nothing is invented and
/// nothing is borrowed.
Future<void> showLanguageSheet(BuildContext context) {
  final ReadingLanguage selected = selectedLanguageOf(context);

  return showModalBottomSheet<void>(
    context: context,
    // See the class doc: no drag handle, because the design system has none, and
    // safe area because `main.dart` puts the app in `SystemUiMode.edgeToEdge` and a
    // sheet that reaches under the home indicator hides its own bottom row.
    useSafeArea: true,
    showDragHandle: false,
    builder: (BuildContext sheetContext) => _LanguageSheet(selected: selected),
  );
}

/// The language on screen right now, for **a control's own selected value**.
///
/// ## THIS IS NOT THE CUBIT'S ANSWER, AND THE DIFFERENCE IS THE WHOLE OF IT
///
/// `UserSettings.language` is `null` until the reader chooses — `null` meaning
/// "follow the platform". So on a fresh install on an Arabic device the cubit holds
/// `null` while the app renders Arabic, and a row that read `language` directly would
/// show **no selection** on a screen that is entirely in Arabic.
///
/// The resolution is to ask the question the control is actually asking — "which
/// language am I looking at?" — and `MaterialApp.locale` already holds the answer,
/// because `app.dart` resolves it from `UserSettings.language` *or* leaves it null for
/// the platform. So:
///
/// | stored | app renders | this returns |
/// | --- | --- | --- |
/// | `null` | `en` (platform) | `english` |
/// | `null` | `ar` (platform) | `arabic` |
/// | `arabic` | `ar` | `arabic` |
/// | `english` | `en` | `english` |
///
/// `ReadingLanguage.forLocale` is the function, and its own doc names the fallback as
/// the same one `gen_l10n` makes "for a widget pumped outside a `MaterialApp`, which
/// several suites do" — which is exactly the case this function has to survive.
ReadingLanguage selectedLanguageOf(BuildContext context) =>
    ReadingLanguage.forLocale(Localizations.localeOf(context).languageCode);

/// The sheet's own two rows, and nothing else.
///
/// A [GlassSurface] at [GlassTier.tint] for the panel and one `SettingsTile` per
/// language, because those are the two design-system widgets the prototype's
/// language row is made of (`SettingsScreen.tsx:77` writes the pills inside a
/// `SettingsTile`, and `:76` is the tile). **No `GlassTier.blur`** — §13.4 puts
/// `/settings` in "everything else → `tint`", and `glass_blur_budget_test.dart` holds
/// `lib/features/` at **one** blur site, which `/`'s today's-reading panel spends.
///
/// ## WHY A `SettingsTile` PER LANGUAGE AND NOT A `SegmentedControl`
///
/// The plan's verification line is "`SettingsGroup` and the settings screen share the
/// identical `SegmentedControl` instance type", and it is satisfied by the **theme**
/// row on `SettingsPage`. The language control is a different prototype control and
/// stays one: `SettingsScreen.tsx:78-88` writes two **separate pills**
/// (`borderRadius: 999`, a 1.5px rim, an ember tint), not a joined track — which is
/// `SegmentedControl`'s own doc's reason for transcribing the track form on the theme
/// picker and no other: "a segmented control with no track is two buttons."
///
/// Each row is a `ListTile`-shaped tap target inside a `SettingsTile`-shaped glass row,
/// and each is `Semantics(button: true, selected: …)` — `EvaChip`'s §14 prescription,
/// which is what makes "which one is current" announceable rather than merely visible.
class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.selected});

  final ReadingLanguage selected;

  /// The sheet's own padding. `SettingsScreen.tsx:45`'s `24px`, narrowed to the
  /// sheet's vertical axis by `EvaSpacing.lg` — a sheet at 24 vertical would be a
  /// quarter of its own height of padding.
  static const EdgeInsets padding = EdgeInsets.all(EvaSpacing.lg);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final SettingsHandle settings = SettingsScope.of(context);
    final EvaColors colors = context.colors;

    return GlassSurface(
      tier: GlassTier.tint,
      radius: EvaRadii.heroPanel,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            strings.settingsLanguageSheetTitle,
            // `arabicAware`, because the Arabic typography gate reported this exact run
            // in `DMSans`: the sheet's title was the one Arabic string on `/settings`
            // that no other widget had already fixed. Every other run on the screen —
            // the page's header, group labels, tile titles, theme options, the two
            // language rows — was already in Amiri, which is why the failure named one
            // string rather than the screen.
            style: arabicAware(
              Theme.of(context).textTheme.titleMedium!
                  .copyWith(color: colors.ink, fontWeight: FontWeight.w600),
              Directionality.of(context),
            ),
          ),
          const SizedBox(height: kLanguageRowGap),
          for (final ReadingLanguage language
              in ReadingLanguage.values) ...<Widget>[
            if (language != ReadingLanguage.values.first)
              const SizedBox(height: kLanguageRowGap),
            _LanguageRow(
              language: language,
              selected: language == selected,
              onTap: () {
                // **The write, then the close — in that order, and both.** A `pop`
                // before the write would close the sheet over an app that had not
                // changed, which is the defect restated; a write after the `pop` would
                // use a `BuildContext` whose sheet is already gone. So the write is
                // fired, the sheet is closed, and `app.dart`'s rebuild is what the
                // reader sees behind it.
                //
                // `unawaited` and not `await`: awaiting would delay the dismissal by
                // a platform-channel round trip, and the optimistic emit in
                // `SettingsCubit.apply` has already put the new locale on screen by
                // then. See that method's doc for why the emit comes first.
                unawaited(settings.setLanguage(language));
                // **Not `unawaited(Navigator.of(context).pop())`.** `pop` is
                // `Future<bool?>`, which is not a `Future<void>` and cannot be handed
                // to `unawaited`; the analyzer rejects it as `use_of_void_result`.
                // So the dismissal is a bare call and the rule that would object is
                // satisfied by *there being no future to drop* — which is true, and is
                // the reason `use_of_void_result` fires here at all.
                Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The sheet's row gap.
///
/// **`SettingsGroup.rowGap` (10) and not a second number.** The two are the same
/// measurement at the same scale — `SettingsScreen.tsx:49,75,100,114` writes `gap: 10`
/// between settings rows and `:78` writes `gap: 6` between the language pills — and
/// the pills' 6 is inside a control rather than between rows. One row-gap constant, and
/// this file reads it rather than restating it.
///
/// Named here rather than reusing `SettingsGroup.rowGap` at the four call sites so the
/// dependency is visible in one identifier.
const double kLanguageRowGap = SettingsGroup.rowGap;

/// One language, as a tappable row that says whether it is the current one.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final ReadingLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final EvaColors colors = context.colors;
    final String label = strings.languageLabelFor(language);

    return Semantics(
      button: true,
      // §14's prescription for a selectable control — `EvaChip`'s row, and the same
      // reason `SegmentedControl`'s segments each carry one: without `selected`, a
      // screen-reader user cannot tell which of the two languages is current, and
      // "the Arabic row is a button" does not say it is the answer.
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: EvaFocusRing(
        enabled: true,
        radius: EvaRadii.button,
        child: EvaInk(
          onPressed: onTap,
          borderRadius: BorderRadius.circular(EvaRadii.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: EvaSpacing.md,
              vertical: EvaSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style:
                        arabicAware(
                          Theme.of(context).textTheme.bodyLarge!,
                          Directionality.of(context),
                        ).copyWith(
                          color: selected ? colors.ember : colors.ink2,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                  ),
                ),
                // The check is the **non-colour** half of "selected", per `EvaChip`'s
                // §14 argument: the ember alone is the colour-only state §14 bans, and
                // a check glyph survives greyscale and announces through the
                // `selected` flag above.
                if (selected) Icon(Icons.check, color: colors.ember),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
