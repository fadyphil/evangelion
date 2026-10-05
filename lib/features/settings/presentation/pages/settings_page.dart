import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:evangelion/features/settings/presentation/settings_l10n.dart';
import 'package:evangelion/features/settings/presentation/widgets/language_sheet.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `/settings` — appearance, reading, about. `SettingsScreen.tsx:33-124`.
///
/// ## IT IS **NOT** A `Scaffold` WITH AN `AppBar`, AND THE STUB IT REPLACED WAS
///
/// The Phase-0 stub was `Scaffold(appBar: AppBar(title: Text(AppRoutes.settings)))`
/// — it drew a **route path** as a screen title, which is the shape of every
/// placeholder this repository has shipped and the reason each was a stub. The real
/// screen draws the prototype's own header instead: `SettingsScreen.tsx:39-43` is a
/// 44×44 chevron button beside a 26px display-serif title, over the same
/// `NeuralScaffold` the other five screens use, and §13.4 puts `/settings` in
/// "everything else → `tint`" — which is every row here, since `SettingsTile` is a
/// `GlassSurface` at [GlassTier.tint] and nothing on this screen blurs.
///
/// **A `NeuralScaffold` and not a bare `Scaffold`**, so the screen inherits
/// `AnnotatedRegion<SystemUiOverlayStyle>` (defect #9's other half: edge-to-edge with
/// light icons on a light palette is an invisible status bar), the ambient background
/// and the `SafeArea`. The stub had none of the three and was visibly not this
/// design.
///
/// ## WHAT IS **CUT** FROM THE PROTOTYPE, AND WHY EACH ONE IS CUT
///
/// | prototype | this screen | why |
/// | --- | --- | --- |
/// | `SettingsScreen.tsx:93-110` — the whole **Account** group | — | §2 decision 1 cut the profile screen, and `Change password` has no endpoint either. Three of its four rows would be dead controls, and `LoginPage`'s recorded reason is that "a live control that reports nothing teaches a reader that a button here sometimes answers with a message about the app rather than about the task" |
/// | `:106` **Notifications** | — | same group, and there is no permission request, no push token and no endpoint |
/// | `:92` **Verse numbers** | — | see the note below |
/// | `:118` **Privacy policy** | — | a legal document with no URL, no screen and no endpoint. An inert row whose name says "unavailable in this build" is *worse* than absent for this particular row: a reader looking for a privacy policy deserves an answer, and "unavailable" is not one |
/// | `:115` **Version** | **kept** | `AppConfig.appVersion`, asserted equal to `pubspec.yaml`'s by `settings_page_test.dart` |
///
/// ### Why Verse numbers is cut rather than shipped — and this one is a **scope**
/// decision, not a product one
///
/// `ReadingCubit`'s doc records the opposite decision for Phase 7, and it is worth
/// quoting the reason rather than paraphrasing it: *"A `bool` with no writer is the
/// dead-branch defect twice over, so `ScriptureBlock` always renders the marker."*
///
/// That reason is now **half** spent: Phase 9 gives it a writer. What it does not give
/// it is room. `ScriptureBlock` has no `showVerseNumbers` parameter, so shipping the
/// toggle means changing a Phase-7 widget's public API, and its marker is load-bearing
/// for **four** gates this phase does not own: `reading_glyph_test.dart`'s declared
/// Arabic-run table, `reading_geometry_test.dart`'s marker assertions, the §14
/// overflow group, and `reading_page_test.dart`'s failing-direction assertion that the
/// marker reaches the tree. AGENT_CONTEXT §2 is not up for renegotiation and §6's
/// protocol is one task at a time.
///
/// **So the honest accounting is: the prototype's Reading group ships one row of
/// two**, and the second is a deliberate scope cut rather than an oversight. It is a
/// one-parameter change plus one ARB key if a later task wants it, and nothing on this
/// screen has to be redesigned to add it.
///
/// ## AND THE BACK TARGET IS `/`, PER THE PHASE PLAN
///
/// `08-build-phases.md`'s scope note: "`AppTopBar`'s avatar tap now opens `/settings`,
/// and settings' back target is `/`." So the chevron is `maybePop`, **not** a push of
/// `AppRoutes.home` — which would put a second `/` on the stack for a reader who
/// arrived from it and press Back twice to get home.
@RoutePage()
class SettingsPage extends StatelessWidget {
  /// The settings screen.
  const SettingsPage({super.key, this.cubit});

  /// The cubit to render.
  ///
  /// `null` means "resolve [SettingsCubit] from the locator", which is the production
  /// path — and the reason this page is not a `BlocProvider` of its own: the cubit is
  /// a **singleton** holding the app's palette, locale and text scale, so a page that
  /// created one per mount would render its own copy of all three and then vanish,
  /// taking the reader's toggle with it.
  ///
  /// A parameter rather than only a lookup because a widget test cannot reach the
  /// locator without configuring the whole graph. Same arrangement as `HomePage.bloc`
  /// and `ReadingPage.cubit`, and for the same reason: **substitution, not
  /// initialisation** — `_SettingsBody` reads the cubit's current state and dispatches
  /// nothing on entry, so a passed-in cubit that already holds what the test wants is
  /// not overwritten.
  final SettingsCubit? cubit;

  /// The prototype's content padding. `SettingsScreen.tsx:45` —
  /// `padding: '24px 24px 48px'`.
  ///
  /// **The scaffold takes `EdgeInsets.zero` and this column supplies its own**, for
  /// `ReadingPage`'s reason: the scaffold's `padding` is a uniform gutter, and this
  /// screen's two rows have their own — `SettingsScreen.tsx:39`'s `20px 20px 0` for the
  /// header and `:45`'s 24 for the content.
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(
    EvaSpacing.xxl,
    0,
    EvaSpacing.xxl,
    EvaSpacing.huge,
  );

  /// The gap between the header and the first group, and between groups.
  /// `SettingsScreen.tsx:45` — one `gap: 28` on the content column, which is the gap
  /// between **all** of its children.
  ///
  /// 28, and not a step on the 4px scale: the prototype's number is not on the scale
  /// and the nearest step (32) is 14% further apart. `SettingsScreen.tsx`'s own header
  /// carries 20 + a 26px line above it, so 28 is measured against the composition and
  /// not invented.
  static const double groupGap = EvaSpacing.xxl + EvaSpacing.xs;

  /// The gap between the back control and the title. `SettingsScreen.tsx:43` —
  /// `marginLeft: 8`.
  static const double titleGap = EvaSpacing.sm;

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

/// Everything below the scaffold: the header row and the three groups.
///
/// A `StatelessWidget`, and that is the **opposite** of `HomePage._HomeBody` and
/// `_ReadingBody` — for a measured reason rather than a stylistic one. Both of those
/// are `StatefulWidget`s because they must fire a request **once**, on entry, and
/// `didChangeDependencies` is the only phase that may read `Localizations`. This screen
/// dispatches nothing on entry: its data came from a singleton before the first frame,
/// and a dispatch in `build` would re-apply a reader's settings on every rebuild of
/// the page — which, on a palette change, is every rebuild of the app.
class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    // **Read once, for two callers.** The row's trailing text and the sheet's starting
    // position must agree, and they both want "which language is on screen" — which is
    // `selectedLanguageOf`'s answer and not a value the cubit holds. See its doc.
    final ReadingLanguage onScreen = selectedLanguageOf(context);

    return NeuralScaffold(
      variant: NeuralVariant.settings,
      // `SettingsScreen.tsx:36` — `overflowY: 'auto'` on the **root**, so the page
      // scrolls rather than the content. `NeuralScaffold`'s doc names `/settings` as
      // one of the three screens whose root scrolls.
      scrollable: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Header(),
          const SizedBox(height: SettingsPage.groupGap),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (BuildContext context, SettingsState state) => Padding(
              padding: SettingsPage.contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // ## THE ONE PLACE `status` IS READ, AND IT IS THE REASON THIS
                  // PHASE 10 EXISTED FOR THIS SCREEN
                  //
                  // `_SettingsFailureNotice` is rendered **above** the groups and the
                  // groups are rendered regardless — deliberately, and the reasoning is
                  // in its own doc. The short form:
                  //
                  // * `ErrorView` **fills** its box (`Center` → `SingleChildScrollView`),
                  //   so it cannot sit above three groups without nesting two scroll
                  //   views, and this screen's root already scrolls (`scrollable: true`);
                  // * **replacing** the form with it contradicts
                  //   `SettingsStatus.failed`'s own doc — "the defaults are still on
                  //   screen, and the reader's next write may still succeed" — and it is
                  //   worse than a layout objection on the **write** arm, where the
                  //   control the reader just tapped is the thing that vanished;
                  // * its `message` contract is `ApiErrorMapper`'s, and
                  //   `SettingsRepositoryImpl._unreachable` is not a mapper — it
                  //   interpolates the raw Dart exception.
                  //
                  // So the failure is a **notice** carrying the same four §14 properties
                  // `ErrorView` holds: a differently-shaped `err`-coloured icon,
                  // `Semantics(liveRegion:)`, the sentence, and an action.
                  if (state.status == SettingsStatus.failed)
                    _SettingsFailureNotice(strings: strings),
                  SettingsGroup(
                    label: strings.settingsAppearance,
                    children: <Widget>[
                      SettingsTile(
                        title: strings.settingsTheme,
                        trailing: SegmentedControl<AppThemeMode>(
                          values: AppThemeMode.values,
                          selected: state.settings.themeMode,
                          // **The row's own title**, so the track names the control
                          // ("Theme") and the three segments name the options
                          // ("Light", "Dark", "System"). Without it the track's node is
                          // named after the **selected value**, which puts two
                          // activatable nodes on screen with the identical label —
                          // the `readingTextSize` defect, and the whole reason this
                          // parameter exists. See `SegmentedControl.semanticLabel`.
                          semanticLabel: strings.settingsTheme,
                          labelOf: (AppThemeMode mode) => switch (mode) {
                            AppThemeMode.light => strings.settingsThemeLight,
                            AppThemeMode.dark => strings.settingsThemeDark,
                            AppThemeMode.system => strings.settingsThemeSystem,
                          },
                          onChanged: (AppThemeMode mode) =>
                              context.read<SettingsCubit>().setThemeMode(mode),
                        ),
                      ),
                      SettingsTile(
                        title: strings.settingsFontSize,
                        trailing: FontSizeStepper(
                          step: state.settings.fontStep,
                          onChanged: (int step) =>
                              context.read<SettingsCubit>().setFontStep(step),
                          labels: FontSizeStepperLabels(
                            decrease: strings.settingsDecreaseFontSize,
                            increase: strings.settingsIncreaseFontSize,
                            track: strings.settingsFontScale,
                          ),
                        ),
                      ),
                      SettingsTile(
                        title: strings.settingsReduceMotion,
                        trailing: EvaToggle(
                          value: state.settings.reducedMotion,
                          onChanged: (bool reduced) => context
                              .read<SettingsCubit>()
                              .setReducedMotion(reduced: reduced),
                          labels: EvaToggleLabels(
                            on: strings.settingsMotionOn,
                            off: strings.settingsMotionOff,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SettingsPage.groupGap),
                  SettingsGroup(
                    label: strings.settingsReading,
                    children: <Widget>[
                      SettingsTile(
                        title: strings.settingsDefaultLanguage,
                        // `onTap` on the row and a `Text` for the trailing, which is
                        // what `SettingsTile`'s own doc asks for: "a tappable settings
                        // row *contains* a control, and dropping the subtree would
                        // leave a screen reader with a button that does nothing" —
                        // inverted, here the row is the control and the trailing is
                        // its **current value**, which is a fact and not a target.
                        // A second control here would be a second tab stop for one
                        // answer.
                        onTap: () => unawaited(showLanguageSheet(context)),
                        trailing: Text(
                          strings.languageLabelFor(onScreen),
                          style: arabicAware(
                            Theme.of(context).textTheme.bodyMedium!,
                            Directionality.of(context),
                          ).copyWith(color: context.colors.ink2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SettingsPage.groupGap),
                  SettingsGroup(
                    label: strings.settingsAbout,
                    children: <Widget>[
                      SettingsTile(
                        title: strings.settingsVersion,
                        trailing: Text(
                          AppConfig.appVersion,
                          // `SettingsScreen.tsx:115` — `F.mono, 10, 700,
                          // letterSpacing 0.08em, ink3`. A version string is an
                          // identifier and the prototype's own choice is the mono
                          // face; `monoCaps` uppercases, and a version has no cased
                          // letters, so this is the same styling stated rather than
                          // inherited.
                          style: EvaTypography.monoCaps(context.colors)
                              .copyWith(
                                fontSize: EvaSpacing.sm + 2,
                                color: context.colors.ink3,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The prototype's header row: a back chevron and the title.
///
/// `SettingsScreen.tsx:39-43` — `padding: '20px 20px 0'`, then a 44×44
/// borderless button wrapping `<polyline points="15,18 9,12 15,6">` at
/// `strokeWidth: 2` in `ink2`, then the title at `marginLeft: 8`.
///
/// **`Icons.arrow_back_ios_new` and not `Icons.chevron_left`**, because the
/// prototype's is a *chevron* and Material's `arrow_back` is an arrow. The glyph that
/// is actually the prototype's chevron is `arrow_back_ios_new` — `reading_controls.dart`
/// records the mirror half of the same rule, where `Icons.arrow_back` **is** the right
/// answer because that prototype drew a chevron *and* a spine. This one drew only the
/// chevron.
///
/// **The direction mirrors itself for free.** `Icons.arrow_back_ios_new` is declared
/// `matchTextDirection: true` in the SDK, so the ambient RTL from `MaterialApp.locale`
/// points it rightwards — which is `SettingsScreen.tsx:39`'s `<polyline>` under the
/// same `direction: rtl` its root inherits, and no second icon has to be chosen.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;

    return Padding(
      // `SettingsScreen.tsx:39` — `padding: '20px 20px 0'`. `EvaSpacing.xl` is 20
      // and is the token the prototype's own number maps to.
      padding: const EdgeInsets.only(
        top: EvaSpacing.xl,
        left: EvaSpacing.xl,
        right: EvaSpacing.xl,
      ),
      child: Row(
        children: <Widget>[
          IconActionButton(
            icon: Icons.arrow_back_ios_new,
            tooltip: strings.settingsBack,
            // The title row is app chrome, not a reading passage, so it takes the
            // ambient family exactly as `_StreakSubtitle` on `/` does — and the
            // tooltip is Arabic on the Arabic arm, which is defect #2's mechanism if
            // it does not.
            tooltipFamily: arabicAwareFamily(
              Directionality.of(context),
              EvaTypography.uiFamily,
            ),
            // `maybePop`, not a push of `/` — see the page's doc. `unawaited` because
            // §4 forbids dropping a `Future` as a bare expression statement.
            onPressed: () => unawaited(context.router.maybePop()),
          ),
          const SizedBox(width: SettingsPage.titleGap),
          Expanded(
            child: Text(
              strings.settingsTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  arabicAware(
                    Theme.of(context).textTheme.headlineMedium!,
                    Directionality.of(context),
                  ).copyWith(
                    // `SettingsScreen.tsx:43` — `F.display 26 / 600 / ink /
                    // letterSpacing -0.01em`. `headlineMedium` is 28sp in Material 3 and
                    // `headlineSmall` is 24sp (which is what `AppTopBar`'s wordmark
                    // uses); 26 is between them, so the size is transcribed on the slot
                    // that carries the display serif, and the difference from 28 is well
                    // under a pixel per character — the honest size of a number this
                    // design system has no slot for.
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.01,
                    color: context.colors.ink,
                  ),
            ),
          ),
        ],
      ),
    );
  }
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
///    `SettingsScreen.tsx:36`'s `overflowY: 'auto'` on the root). Nesting the two
///    gives two scroll views fighting over one gesture.
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
      // peer of the three groups, not one of their rows, so it takes the same
      // separation from its neighbours that they take from each other.
      padding: const EdgeInsets.only(
        top: EvaSpacing.sm,
        bottom: SettingsPage.groupGap,
      ),
      child: GlassSurface(
        tier: GlassTier.tint,
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
                      color: context.colors.err,
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
