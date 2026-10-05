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
                  SettingsGroup(
                    label: strings.settingsAppearance,
                    children: <Widget>[
                      SettingsTile(
                        title: strings.settingsTheme,
                        trailing: SegmentedControl<AppThemeMode>(
                          values: AppThemeMode.values,
                          selected: state.settings.themeMode,
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
