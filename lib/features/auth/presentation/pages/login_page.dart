import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the sign-in attempt on `/login` produced.
///
/// ## WHY AN ENUM AND NOT A `bool`
///
/// `avoid_positional_boolean_parameters` is enabled in `analysis_options.yaml`,
/// and the obvious shape — `void Function(bool didLogin)` — is exactly what it
/// forbids. A named `didLogin:` parameter would have satisfied the lint while
/// keeping the hazard: the reader still has to work out which of two flags is
/// meant. An enum removes the hazard outright:
///
/// ```dart
/// onResult(LoginOutcome.signedIn)   // reads as what it is
/// onResult(LoginOutcome.cancelled)
/// ```
///
/// And why not two callbacks: an `onResult` plus an `onCancel` would have
/// sidestepped the lint too and been strictly worse — the reader has to work out
/// *which one resumes*, which is a weaker statement than "this one resumes", and
/// "fires exactly once" is the property the guard's latch is built on (see
/// `auth_guard.dart`). One callback, one call site, one guarantee.
enum LoginOutcome {
  /// The reader signed in. Resume whatever navigation was interrupted.
  signedIn,

  /// The reader gave up. Abandon it and leave them where they are.
  cancelled,
}

/// Reports the outcome of the sign-in attempt to whoever redirected here.
///
/// `signedIn` resumes the navigation the guard interrupted; `cancelled` abandons
/// it. See [LoginOutcome] for why this is a callback carrying an enum rather than
/// one carrying a boolean.
typedef LoginResultCallback = void Function(LoginOutcome outcome);

/// The app's pre-auth entry point: onboarding and sign-in.
///
/// ## WHAT THIS SCREEN IS, AND WHAT IT DELIBERATELY IS NOT
///
/// Real. `redesign.html:503-511` is transcribed — the glowing wordmark, the mono
/// tagline, two bare fields each with its own error line, "enter the word", two
/// inert ghost pills and the αω footer — with the behaviour behind it still the
/// app's own [AuthBloc] over `FakeAuthRepository`, which Phase 5.1 leaves
/// unchanged. Every number the layout uses is named below with its
/// `redesign.html` line, and `login_geometry_test.dart` extracts those numbers
/// from the prototype file at test time and compares them against what this page
/// actually rendered.
///
/// The rebuild is **smaller** than what it replaced. The old prototype's login
/// carried a seal, a glass form panel, a forgot-password link, a sign-up row, an
/// "or" divider and two full-width social buttons; the redesign has none of them.
/// The elements that did not survive, and why each is gone rather than hidden:
///
/// | dropped | the redesign's word |
/// | --- | --- |
/// | `SealMonogram` | `:504-505` — the brand block is a wordmark and a tagline. The seal lives on as the design-system widget it was restyled into (Task 4.2 re-rolled its treatment to `.jorb`, `:392-395`) and returns to a page with `/journey` in Task 5.6; `orphan_widget_check`'s allowlist carries that reason until then. |
/// | the glass form | `:506-507` — the fields sit **bare on the aurora**: `background:rgba(255,255,255,.04)`, a 1px `--glass-line` rim, `border-radius:14`. There is no panel, so there is no tier to assert — the old harness's `GlassTier.tint` claim died with the form. |
/// | "Sign in" → "enter the word" | `:508` — `data-i18n="enter"`, one of only three strings on this screen the prototype itself translates. |
/// | forgot / sign-up / divider | absent from `:503-511` entirely. There is no account creation in this product and the redesign stopped pretending otherwise. |
/// | the password show/hide toggle | `:507` is a plain `type="password"` input with no reveal control. **The bloc capability stays** (`AuthPasswordVisibilityToggled` is unchanged and tested) — restoring a reveal is one `trailing:` on the password field. |
/// | full-width social buttons → ghost pills | `:509` — `.ghosts` is a 10px-gapped row of two flex-1 pills. They stay **inert** (no OAuth port exists; AGENT_CONTEXT §2 decision 3) and announce why through `EvaButton.semanticLabel`. |
///
/// ## THE THREE STRINGS THE PROTOTYPE ITSELF TRANSLATES — AND THE FIVE IT DOES NOT
///
/// `applyLang()` (`redesign.html:985`) rewrites **only** `[data-i18n]` elements.
/// On this screen that is the CTA (`:508`), and the two error lines the submit
/// handler fills through `tr('emErr')`/`tr('pwErr')` (`:976`). Everything else is
/// rendered by the prototype's own static markup in both directions:
///
/// * the wordmark `EVANGELION` (`:504`), rebuilt letter-by-letter by
///   `animateLogin()` (`:1298`) from the same literal;
/// * the tagline `the word · illuminated` (`:505`) and the footer
///   `αω · nocturne v1.2` (`:510`) — brand voice in the mono face, the same
///   reasoning that kept `homeWordmark` Latin on the Arabic arm;
/// * the ghost labels `google`/`apple` (`:509`) — brand marks.
///
/// The placeholders are the one split call. `:506-507` writes them lowercase and
/// untranslated, but they are the **only guidance the fields give** — the
/// redesign removed the labels above them — and a reader of the Arabic arm is
/// otherwise told what to type in a language the rest of the screen does not
/// speak. The redesign's own dictionary already carries both nouns (`pwErr` is
/// `كلمة المرور قصيرة`), so the Arabic here is the prototype's vocabulary, not a
/// fresh translation. Recorded as a deliberate divergence from the prototype's
/// literal markup; `arabic_typography_test.dart` enumerates the runs.
///
/// ## THE CTA IS ALWAYS ENABLED, AND FAILURE IS A SHAKE
///
/// The old screen disabled the button until `state.canSubmit`. The redesign's
/// is **always tappable** (`:508` is a bare `<button>` with no `disabled`), and
/// the prototype's submit handler answers an invalid tap with the field messages
/// and a shake: `liCta.onclick` (`:1303-1307`) fills both `.msg` lines, adds
/// `.cta.err`, and removes it after 500 ms. So the CTA here always dispatches
/// [AuthSubmitted] — the bloc's invalid branch already reveals both fields at
/// once (`auth_bloc.dart`, `_onSubmitted`) — and when the tap was made with an
/// invalid form this page plays the shake. The `.cta.err` background swap
/// (`:386`, ember at 45 % scale) is **deliberately not carried**: the failure
/// already has two visible carriers in the same instant (both `.msg` lines turn
/// ember) plus the shake's pulse, and an ink-on-err token for both brightnesses
/// does not exist in the Phase 2 palette — adding one would be a palette change
/// this screen task may not make silently. The temporal half of `.err` is the
/// half the messages cannot carry, and it is carried.
///
/// ## THE WORDMARK'S ENTRANCE IS THE SCREEN'S ONE MOTION
///
/// `animateLogin()` (`:1297-1302`) splits the wordmark into ten `.lm-l` spans:
/// each rises 16px out of a blur over 550 ms, staggered 40 ms, on
/// `--e-light` (`:18`) — [EvaMotion.interactiveCurve]. Two halves of that rule
/// land here and two do not:
///
/// * **the rise and the stagger land** — one controller, each letter on an
///   `Interval`, exactly the prototype's 910 ms total (9 × 40 + 550);
/// * **the blur does not** — `filter:blur(6px)` is `ImageFilter.blur`, and the
///   repository's hard rule is that no `ImageFilter.blur` exists outside
///   `glass_surface.dart`. A radial-gradient approximation of the *glow*
///   (`.lmark::after`, `:371`) is the nearest honest rendering and the entrance
///   loses its 6px blur to the same rule;
/// * **reduced motion jumps to the end state**, not to the prototype's answer.
///   `redesign.html:1301` zeroes the *stagger* under `reduceMotion` and still
///   plays each 550 ms rise; this app's own §14 gate (`09-quality-gates.md`,
///   `MediaQuery.disableAnimationsOf`) is stricter — a disabled animation jumps
///   straight to the end state — and §14 outranks the prototype inside this
///   repository.
///
/// ## [onResult] MAY BE NULL, AND THIS PAGE IS BUILT FOR IT
///
/// `/login` is the one route with **no guard** — a gate in front of it would
/// redirect to itself forever — so `pushPath('/login')` builds this page with
/// `onResult == null`. The outcome is reported through a **local no-op** when
/// [onResult] is null, and never through a default parameter on the field: a
/// default there would make the trap invisible, because a page reporting an
/// outcome to nobody would look identical to one reporting it to the guard.
/// `login_page_test.dart` signs in on a page built with no [onResult] and asserts
/// the bloc reaches `signedIn` and the page still comes down.
///
/// ## AND NOTHING HERE NAVIGATES
///
/// On success the page reports the outcome and stops. Resuming the interrupted
/// navigation is the **guard's** job (`auth_guard.dart`). A `context.router`
/// call here would be a second, competing resume path.
///
/// ## DIVERGENCES RECORDED ONCE, HERE
///
/// * **The prototype pre-fills both fields** (`value="mariam@light.co"`,
///   `value="amenu"`, `:506-507`). That is demo data for a static page, not
///   design: this page starts empty, as it always has.
/// * **The prototype's `haptic([40,60,40])`/`haptic(30)` calls** (`:1307-1308`)
///   have no counterpart — this app ships no haptics anywhere (`grep -r
///   HapticFeedback lib/` is empty), and adding the first one is a product
///   decision, not a transcription.
/// * **The ghost labels paint uppercase** — `:389`'s `text-transform:uppercase`
///   has no `[dir=rtl]` override, so `GOOGLE`/`APPLE` are uppercase literals in
///   both directions, unlike the tagline and footer whose `[dir=rtl] .mono`
///   rule (`:136`) removes the transform on the Arabic arm.
/// * **`.cta.err`'s recolour** — see the shake section above.
/// * **No scroll**: `:369` centres the section (`justify-content:center`) with
///   no overflow of its own, so [NeuralScaffold.scrollable] is `false` here.
///   A `Center` over a `SingleChildScrollView` keeps §14's 1.22× text-scale
///   promise — content centres when it fits and scrolls when it cannot.
@RoutePage()
class LoginPage extends StatelessWidget {
  /// The sign-in screen.
  const LoginPage({super.key, this.onResult, this.bloc});

  /// Reports the sign-in outcome back to whoever redirected here.
  ///
  /// Null means nobody redirected here — which the app's own route table can
  /// arrange. See the class doc; the short version is that this page has to
  /// tolerate it, and it does.
  final LoginResultCallback? onResult;

  /// The bloc to render.
  ///
  /// `null` means "resolve [AuthBloc] from the locator", which is the production
  /// path and the reason this page is not a `BlocProvider` of its own: a page that
  /// created its bloc would have one session per mount, and the navigation guard
  /// reads the *locator's*.
  ///
  /// A parameter rather than only a lookup because a widget test cannot reach the
  /// locator without configuring the whole graph. `login_page_test.dart` passes
  /// its own and asserts against it.
  final AuthBloc? bloc;

  /// `redesign.html:504` — the wordmark's content. `.lmark` declares no
  /// `text-transform`, so the markup is uppercase and stays uppercase in both
  /// directions.
  static const String kWordmarkText = 'EVANGELION';

  /// `redesign.html:505` — the tagline, untranslated in the prototype's own
  /// markup (no `data-i18n`); see the class doc's language section.
  static const String kTaglineText = 'the word · illuminated';

  /// `redesign.html:510` — the footer. A brand line: αω, the first and last
  /// letters, and the build's name. `JetBrainsMono` carries Greek — verified
  /// against the bundled TTF's cmap before this literal shipped.
  static const String kFooterText = 'αω · nocturne v1.2';

  /// `redesign.html:509` — the ghost labels. `:389` uppercases them and has no
  /// `[dir=rtl]` override, so the uppercase form is the rendered form in both
  /// directions and the literal carries it.
  static const String kGhostGoogle = 'GOOGLE';
  static const String kGhostApple = 'APPLE';

  /// `redesign.html:369` — `.login`'s `padding: 0 34px`, the horizontal half.
  static const double kRootGutter = 34;

  /// `redesign.html:370` — `.lmark`'s `font-size: 26px`.
  static const double kWordmarkSize = 26;

  /// `redesign.html:370` — `letter-spacing: .3em` **of 26px**, so `7.8`. Flutter
  /// tracks in px, CSS in em of the element's own size; the conversion is the
  /// whole content of this constant.
  static const double kWordmarkTracking = 7.8;

  /// `redesign.html:370` — `.lmark`'s `margin-bottom: 6px`.
  static const double kMarkToTagGap = 6;

  /// `redesign.html:374` — `.ltag`'s `margin-bottom: 34px`.
  static const double kTagToFieldsGap = 34;

  /// `redesign.html:375` — `.field`'s `margin-bottom: 14px`.
  static const double kFieldGap = 14;

  /// The gap between the password field and the CTA.
  ///
  /// `redesign.html:375` gives every `.field` a `margin-bottom: 14` **and**
  /// `:381` gives `.cta` a `margin-top: 8`, and `.login` is a flex column
  /// (`:128`) — flexbox does not collapse margins, so the rendered gap is the
  /// **sum**, 22. The two contributing numbers stay separate in
  /// `login_geometry_test.dart`, which extracts both from the prototype file and
  /// asserts the sum here.
  static const double kCtaTopGap = 22;

  /// `redesign.html:387` — `.ghosts`'s `gap: 10px`.
  static const double kGhostsGap = 10;

  /// `redesign.html:387` — `.ghosts`'s `margin-top: 14px`.
  static const double kGhostsTopGap = 14;

  /// `redesign.html:391` — `.lfoot`'s `bottom: 26px`.
  static const double kFooterBottomGap = 26;

  /// The CTA label's family, for [language].
  ///
  /// `EvaButton.labelFamily` is required because the script varies: the label is
  /// `AppLocalizations.authEnterTheWord`, which is `ادخل الكلمة` on the Arabic
  /// arm, and the fallback family — DM Sans — carries no Arabic glyphs at all. A
  /// per-arm family and not `EvaTypography.uiFamily`, because answering the knob
  /// with the Latin face on the Arabic arm asserts the defect. Keyed on
  /// [ReadingLanguage] and not on the locale, for `ReadingLanguage.forLocale`'s
  /// reason: a `Locale` at the presentation edge, the enum everywhere below, one
  /// conversion rather than two.
  static String ctaFamilyFor(ReadingLanguage language) => switch (language) {
    ReadingLanguage.english => EvaTypography.uiFamily,
    ReadingLanguage.arabic => EvaTypography.arabicFamily,
  };

  @override
  Widget build(BuildContext context) {
    // Two sources for one bloc, one provider either way. See [bloc]'s doc: with a
    // bloc the caller owns it, and without one this page resolves the app's from
    // the locator — a page that *created* its own would have one session per mount,
    // and the navigation guard reads the locator's.
    //
    // `BlocProvider.value` in both branches rather than the shorthand
    // `BlocProvider(create:)`: the shorthand **closes** the bloc it creates, and a
    // bloc owned by the locator must outlive this page — the guard is still reading
    // `AuthBloc.state` when the form comes down.
    final AuthBloc resolved =
        bloc ?? (getIt<AuthBloc>()..add(const AuthStarted()));
    final Widget form = BlocProvider<AuthBloc>.value(
      value: resolved,
      child: _LoginForm(onResult: onResult),
    );

    return NeuralScaffold(
      // The prototype passes `variant={0}` unconditionally, and there is no
      // Arabic login screen to inherit a different one from.
      // `redesign.html:369` — `.login` centres its column and declares no
      // overflow of its own; the old prototype's scrolling root is gone with the
      // form panel, so `scrollable` stays its default `false`. The
      // centre-or-scroll pattern lives in [_LoginForm] so the content still
      // survives §14's 1.22×.
      padding: const EdgeInsets.symmetric(horizontal: kRootGutter),
      // `redesign.html:391` — `.lfoot` is `position:absolute; bottom:26px`,
      // outside the centred column's flow. [NeuralScaffold.overlay] is the
      // viewport-fixed layer for exactly that shape.
      overlay: const _Footer(),
      child: form,
    );
  }
}

/// The centred form, and the only widget that reads [AuthBloc].
///
/// Split from [LoginPage] because it must be rebuilt by the bloc while the page's
/// own inputs — the two controllers and the shake clock — do not change.
class _LoginForm extends StatefulWidget {
  const _LoginForm({required this.onResult});

  /// Threaded down rather than found with
  /// `findAncestorWidgetOfExactType<LoginPage>()`: the ancestor search would work
  /// today and would break the day the page is wrapped in anything.
  final LoginResultCallback? onResult;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm>
    with SingleTickerProviderStateMixin {
  // §6 and `EvaTextField`'s own doc: the controller is the **caller's**. This
  // widget never creates one from the bloc's text, so a rebuild of the state does
  // not overwrite a character the reader is in the middle of typing.
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  /// The listeners added to the two controllers, so [dispose] can remove exactly
  /// those and not whatever is there.
  final List<VoidCallback> _controllerListeners = <VoidCallback>[];

  /// The failed-submit shake. `redesign.html:360` — `.cta.err` runs `shake .45s`;
  /// `:360`'s keyframes are −8 / 8 / −5 / 5 px at 20/40/60/80 %. The curve is the
  /// design system's [EvaShake] — `.opt.wrong` shares the same keyframes, and a
  /// second private copy would have been exactly that.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: EvaShake.duration,
  );

  /// The shake's easing, applied to the controller's value in the
  /// `AnimatedBuilder` below.
  ///
  /// ## WHY NOT `CurveTween`, WHICH IS WHAT THIS LOOKS LIKE IT WANTS TO BE
  ///
  /// Because `CurveTween.transform` **asserts its curve is the identity at both
  /// ends** — `tween.dart:567`, `curve.transform(t).round() == t` — and a shake
  /// is not: it ends where it began, `transform(1.0) == 0`, which is the whole
  /// point of a shake. Measured, not guessed: driven through a `CurveTween`,
  /// the completion build threw that assertion, the frame died, and the button
  /// froze at the second-to-last keyframe (+3.89px) while the controller
  /// reported `completed` and its own listeners saw `1.0` — a resting-looking
  /// button that was actually three pixels off, for exactly one frame, forever.
  /// The curve is therefore applied **directly** — the same one line the tween
  /// would have run, minus the assertion a shake can never satisfy.
  final EvaShake _shakeCurve = const EvaShake();

  /// WHY LISTENERS RATHER THAN AN `onChanged` PARAMETER
  ///
  /// `EvaTextField` has no `onChanged`, and that is its documented contract
  /// rather than an omission: "the controller is the caller's … the `onChanged`
  /// side is [controller]: a caller adds a listener". So the wiring lives here,
  /// in the page that owns the controller, and the design system is untouched.
  ///
  /// `didChangeDependencies` rather than `initState`, because it is the first
  /// point at which `context.read<AuthBloc>()` is legal — a `BlocProvider` above
  /// this widget is a dependency. It can run more than once if the bloc itself
  /// changes, so the listener bodies are named and removed before being re-added;
  /// adding them twice would dispatch every keystroke twice.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AuthBloc bloc = context.read<AuthBloc>();

    for (final VoidCallback listener in _controllerListeners) {
      _email.removeListener(listener);
      _password.removeListener(listener);
    }
    _controllerListeners
      ..clear()
      ..add(() => bloc.add(AuthEmailChanged(_email.text)))
      ..add(() => bloc.add(AuthPasswordChanged(_password.text)));

    // One listener per controller, **by index**. An earlier version added both to
    // both, so typing in the password also fired `AuthEmailChanged` — which marked
    // the *email* field touched and put an error under a field the reader had
    // never reached. `login_accessibility_test.dart` catches it by asserting the
    // error icon's count, which is the kind of claim that only fails if the count
    // is exact.
    _email.addListener(_controllerListeners[0]);
    _password.addListener(_controllerListeners[1]);
  }

  @override
  void dispose() {
    for (final VoidCallback listener in _controllerListeners) {
      _email.removeListener(listener);
      _password.removeListener(listener);
    }
    _email.dispose();
    _password.dispose();
    _shake.dispose();
    super.dispose();
  }

  /// One submit path for the CTA and both fields' action keys.
  ///
  /// The prototype shakes only when the *tap* carried an invalid form
  /// (`redesign.html:1303-1307`), and the bloc's invalid branch reveals both
  /// fields' messages either way — so the shake is decided here, from the
  /// tap-time verdict, and the dispatch happens regardless. A disabled-then-
  /// dispatch split would need two call sites to answer one question.
  void _submit(AuthBloc bloc, {required bool formIsValid}) {
    if (!formIsValid) {
      _playShake();
    }
    bloc.add(const AuthSubmitted());
  }

  /// `.cta.err`'s shake, §14-aware.
  ///
  /// `redesign.html:1301` answers reduced motion by zeroing the *stagger* and
  /// still playing the rise; this app's §14 gate is stricter — a disabled
  /// animation jumps straight to its end state — and the end state of a shake is
  /// the rest position, so reduced motion means it does not run at all.
  void _playShake() {
    if (MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _shake
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final Locale locale = Localizations.localeOf(context);
    final AppLocalizations strings = context.l10n;
    // **A getter, not a field**: `Localizations.localeOf` is an inherited-widget
    // lookup, and `ReadingLanguage.forLocale` is the one conversion of it in the
    // app. See [LoginPage.ctaFamilyFor].
    final ReadingLanguage language = ReadingLanguage.forLocale(
      locale.languageCode,
    );

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (AuthState previous, AuthState current) =>
          previous.status != current.status,
      listener: (BuildContext context, AuthState state) {
        if (!state.isSignedIn) {
          return;
        }
        // The one place the outcome is reported, and it reports to a **local**
        // no-op when nobody is listening. See the class doc: a default parameter
        // on `LoginPage.onResult` would make the null case invisible.
        final LoginResultCallback? report = widget.onResult;
        (report ?? _nothing)(LoginOutcome.signedIn);
      },
      builder: (BuildContext context, AuthState state) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Centre when the content fits, scroll when it cannot — §14's 1.22×
            // text-scale row is a hard gate, and a fixed centre would clip
            // before it scrolled. The prototype's `justify-content:center`
            // (`redesign.html:369`) is the fits case of exactly this.
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _Wordmark(),
                      const SizedBox(height: LoginPage.kMarkToTagGap),
                      Center(
                        child: Text(
                          // `[dir=rtl] .mono` (`redesign.html:136`) removes the
                          // transform on the Arabic arm, so the uppercase is
                          // LTR-only — applied here, to the literal, not in the
                          // style. The FAMILY does not swap: the prototype
                          // keeps `var(--mono)` on this run in both directions,
                          // and `arabicAware` would send it to Amiri — which
                          // carries no Greek glyph at all (`αω`'s tofu, caught
                          // by the arm's own gate on the first run). The swap
                          // exists for runs whose script varies; this one never
                          // does.
                          monoCapsText(
                            LoginPage.kTaglineText,
                            Directionality.of(context),
                          ),
                          style: EvaTypography.monoCaps(context.colors)
                              .copyWith(color: context.colors.ink2),
                        ),
                      ),
                      const SizedBox(height: LoginPage.kTagToFieldsGap),
                      EvaTextField(
                        label: strings.authEmailLabel,
                        // `redesign.html:506` — a bare `<input
                        // placeholder="email">`; the redesign removed the label
                        // row this widget kept from the React prototype.
                        showLabel: false,
                        controller: _email,
                        hintText: strings.authEmailHint,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        // **By presence, never by matching**: the domain's
                        // message is the log-canonical copy, this page renders
                        // the localized sentence whenever the verdict is
                        // non-null. See `authEmailInvalid`'s arb description.
                        errorText: state.emailError == null
                            ? null
                            : strings.authEmailInvalid,
                        onSubmitted: (String _) => _submit(
                          context.read<AuthBloc>(),
                          formIsValid: state.canSubmit,
                        ),
                      ),
                      const SizedBox(height: LoginPage.kFieldGap),
                      EvaTextField(
                        label: strings.authPasswordLabel,
                        showLabel: false,
                        controller: _password,
                        hintText: strings.authPasswordHint,
                        // The reveal control is gone with the redesign's plain
                        // `type="password"` input (`redesign.html:507`); the
                        // bloc's capability stays, so restoring a toggle is one
                        // `trailing:` here.
                        obscureText: !state.isPasswordVisible,
                        textInputAction: TextInputAction.done,
                        errorText: state.passwordError == null
                            ? null
                            : strings.authPasswordTooShort,
                        onSubmitted: (String _) => _submit(
                          context.read<AuthBloc>(),
                          formIsValid: state.canSubmit,
                        ),
                      ),
                      const SizedBox(height: LoginPage.kCtaTopGap),
                      // The CTA is **always tappable** (`redesign.html:508` has
                      // no `disabled`); an invalid tap is answered with the two
                      // field messages and the shake, not with a dimmed button.
                      // See the class doc.
                      AnimatedBuilder(
                        animation: _shake,
                        builder: (BuildContext context, Widget? _) {
                          return Transform.translate(
                            offset: Offset(
                              _shakeCurve.transform(_shake.value),
                              0,
                            ),
                            child: EvaButton(
                              label: strings.authEnterTheWord,
                              labelFamily: LoginPage.ctaFamilyFor(language),
                              onPressed: () => _submit(
                                context.read<AuthBloc>(),
                                formIsValid: state.canSubmit,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: LoginPage.kGhostsTopGap),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _GhostPill(
                              label: LoginPage.kGhostGoogle,
                              suffix: strings.authUnavailableSuffix,
                            ),
                          ),
                          const SizedBox(width: LoginPage.kGhostsGap),
                          Expanded(
                            child: _GhostPill(
                              label: LoginPage.kGhostApple,
                              suffix: strings.authUnavailableSuffix,
                            ),
                          ),
                        ],
                      ),
                      if (state.formError
                          case final String message) ...<Widget>[
                        const SizedBox(height: LoginPage.kFieldGap),
                        _FormError(message: message),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// One inert ghost pill.
///
/// `redesign.html:509` — `<button>google</button><button>apple</button>`, restyled
/// by `.ghosts button` (`:388-390`). There is no OAuth port, no social SDK and no
/// endpoint (AGENT_CONTEXT §2 decision 3), so the control renders **genuinely
/// inert**: [EvaButton] with a null [EvaButton.onPressed] is 45 % opacity, has no
/// ink and no focus stop, carries `Semantics(enabled: false)` and **no tap
/// action**, and [EvaButton.semanticLabel] appends [suffix] so the announcement
/// says *why* rather than only that it cannot be pressed.
class _GhostPill extends StatelessWidget {
  const _GhostPill({required this.label, required this.suffix});

  /// The painted label — an uppercase brand mark in both directions.
  final String label;

  /// The unavailable sentence appended to the accessible name, never to what is
  /// painted.
  final String suffix;

  @override
  Widget build(BuildContext context) => EvaButton(
    label: label,
    // `onPressed` stays its default `null` — the inertness this class exists to
    // document. See the class doc.
    variant: EvaButtonVariant.ghost,
    // `.ghosts button` is the mono face (`redesign.html:389` —
    // `font-family:var(--mono)`); the design system's ghost role keeps the old
    // prototype's label size for the mechanical reasons `EvaButton` records, and
    // the family is the part this screen can answer.
    labelFamily: EvaTypography.monoFamily,
    semanticLabel: '$label — $suffix',
  );
}

/// The wordmark, its glow, and the ten letters' entrance.
///
/// `redesign.html:504` for the content, `:370` for the type,
/// `:371` for the glow, `:372-373` for the per-letter entrance, `:1297-1302` for
/// the stagger. See [LoginPage]'s class doc for which halves of the blur land
/// here (none — `ImageFilter.blur` may not exist outside `glass_surface.dart`)
/// and which do (the rise, the stagger, the `--e-light` curve).
class _Wordmark extends StatefulWidget {
  const _Wordmark();

  @override
  State<_Wordmark> createState() => _WordmarkState();
}

class _WordmarkState extends State<_Wordmark>
    with SingleTickerProviderStateMixin {
  /// Nine 40 ms staggers plus one 550 ms rise — `redesign.html:1301`'s
  /// `i*40` over ten letters against `:373`'s `.55s`.
  static const Duration _entrance = Duration(milliseconds: 910);

  /// One per-letter rise. `redesign.html:373` — 16px of travel.
  static const double _rise = 16;

  /// The stagger. `redesign.html:1301` — `i*40`ms.
  static const Duration _stagger = Duration(milliseconds: 40);

  /// One rise's duration. `redesign.html:373` — `.55s`.
  static const Duration _letter = Duration(milliseconds: 550);

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _entrance,
  );

  /// Set once in [didChangeDependencies] — the first point at which
  /// `MediaQuery` is legal to read.
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    // §14, not the prototype: `redesign.html:1301` zeroes only the stagger under
    // reduced motion; this app's gate jumps a disabled animation to its end
    // state. See [LoginPage]'s class doc.
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Text> letters = <Text>[
      for (final String character in LoginPage.kWordmarkText.split(''))
        Text(
          character,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            // `.lmark` has no `font-family` of its own (`redesign.html:370`),
            // so the UI face renders it — and the UI face is where the
            // Arabic-aware swap below would send an Arabic run, which cannot
            // happen: the wordmark is a fixed Latin brand mark.
            fontFamily: EvaTypography.uiFamily,
            fontSize: LoginPage.kWordmarkSize,
            fontWeight: FontWeight.w800,
            letterSpacing: LoginPage.kWordmarkTracking,
            color: context.colors.ink,
          ),
        ),
    ];

    return ListenableBuilder(
      listenable: _clock,
      builder: (BuildContext context, Widget? _) {
        return Stack(
          // The glow box is larger than the text by the `.lmark::after` insets
          // and must not be clipped for it.
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            // `redesign.html:371` — `.lmark::after`, `inset:-18px -26px`,
            // `radial-gradient(ellipse, rgba(232,176,75,.28), transparent 70%)`,
            // `filter:blur(10px)`. The blur is untranslatable outside
            // `glass_surface.dart`, so the falloff is the softness: a radial
            // gradient that holds its alpha and then falls is what a 10px blur
            // of this shape looks like, minus the blur's own edge. Recorded in
            // [LoginPage]'s class doc rather than approximated with a forbidden
            // filter.
            Positioned(
              left: -26,
              right: -26,
              top: -18,
              bottom: -18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: <Color>[
                      context.colors.ember.withValues(alpha: 0.28),
                      context.colors.ember.withValues(alpha: 0.10),
                      context.colors.ember.withValues(alpha: 0),
                    ],
                    stops: const <double>[0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            // The mark is one brand line and does not wrap. `FittedBox` with
            // `scaleDown` is what keeps that sentence true at §14's 1.22× on a
            // 320px phone: ten 26px letters at 7.8px of tracking want ~330px,
            // the gutter leaves 252, and the alternatives are a clipped glyph,
            // a wrapped mark, or a smaller type. Scaling the mark to the box
            // keeps every letter whole and costs nothing at 1.0× on any
            // surface wide enough — where `scaleDown` is the identity.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < letters.length; i++)
                    _EntranceLetter(
                      clock: _clock,
                      index: i,
                      letter: letters[i],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One letter's share of the entrance.
///
/// Its window is [index] × 40 ms to that plus 550 ms, on `--e-light` —
/// [EvaMotion.interactiveCurve]. Translate only: layout never moves, which is
/// why ten transforms cost nothing between frames that matter.
class _EntranceLetter extends StatelessWidget {
  const _EntranceLetter({
    required this.clock,
    required this.index,
    required this.letter,
  });

  final AnimationController clock;
  final int index;
  final Text letter;

  @override
  Widget build(BuildContext context) {
    final int startMs = index * _WordmarkState._stagger.inMilliseconds;
    final int totalMs = _WordmarkState._entrance.inMilliseconds;
    final Animation<double> progress = clock.drive(
      CurveTween(
        curve: Interval(
          startMs / totalMs,
          (startMs + _WordmarkState._letter.inMilliseconds) / totalMs,
          curve: EvaMotion.interactiveCurve,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: clock,
      builder: (BuildContext context, Widget? _) => Transform.translate(
        offset: Offset(0, _WordmarkState._rise * (1 - progress.value)),
        child: Opacity(opacity: progress.value, child: letter),
      ),
    );
  }
}

/// The repository's refusal, announced once.
///
/// §14's live-region row: it belongs to no single field, so `EvaTextField`'s
/// error line is the wrong carrier — that is per-field and would be cleared by
/// the next keystroke, taking the answer with it.
///
/// The redesign's login declares no repository-failure state (its submit handler
/// can only fail client-side), so this row is **written, not transcribed** — the
/// same standing reason `homeRetry` and every other error surface in this app
/// carries. It renders only when the repository rejects, which the redesigned
/// prototype cannot express.
class _FormError extends StatelessWidget {
  const _FormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.error_outline,
          size: EvaSpacing.lg,
          color: context.colors.err,
        ),
        const SizedBox(width: EvaSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: arabicAware(
              Theme.of(context).textTheme.bodySmall!,
              Directionality.of(context),
            ).copyWith(color: context.colors.errInk),
          ),
        ),
      ],
    ),
  );
}

/// `redesign.html:510` — the footer, pinned `bottom: 26px` through
/// [NeuralScaffold.overlay].
///
/// [NeuralScaffold.overlay] hands its child `Positioned.fill`'s **tight**
/// constraints, and a `Padding` under tight constraints deflates them into more
/// tight constraints — so a bare `Text` here would be stretched to the full
/// viewport, a box wide enough to sit over the CTA and take its tap. `Align`
/// is the widget that turns tight into loose: the text shrink-wraps and the
/// box is the footer's, not the screen's. Measured by the probe that found the
/// CTA's tap landing on this widget's paragraph.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.only(bottom: LoginPage.kFooterBottomGap),
      child: Text(
        monoCapsText(LoginPage.kFooterText, Directionality.of(context)),
        textAlign: TextAlign.center,
        // The mono face in BOTH directions, for the tagline's reason: the run
        // is Greek-plus-Latin and never varies its script, so the Arabic-aware
        // swap would only take it to a face with no Greek in it.
        style: EvaTypography.monoCaps(context.colors)
            .copyWith(color: context.colors.ink2),
      ),
    ),
  );
}

/// A callback that does nothing.
///
/// Named rather than inlined as `(LoginOutcome _) {}` so the claim — that a null
/// `onResult` is reported to *this* rather than being skipped — has a name a
/// reader can find.
void _nothing(LoginOutcome outcome) {}
