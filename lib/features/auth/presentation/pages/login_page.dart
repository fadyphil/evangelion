import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/auth/presentation/auth_strings.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/auth/presentation/widgets/password_visibility_toggle.dart';
import 'package:evangelion/features/auth/presentation/widgets/social_auth_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the sign-in attempt on `/login` produced.
///
/// ## WHY AN ENUM AND NOT A `bool`
///
/// `avoid_positional_boolean_parameters` is enabled in `analysis_options.yaml`,
/// and the obvious shape — `void Function(bool didLogin)` — is exactly what it
/// forbids. The first attempt satisfied the lint by suppression: this
/// repository's only `// ignore:`, justified against `06-navigation.md` §8's
/// `onResult(true)` spelling and this phase's verification line "resumes on
/// `onResult(true)`".
///
/// That justification does not hold, and the reason is not a matter of taste.
/// AGENTS.md makes `docs/agents/AGENT_CONTEXT.md` the authority which "overrides
/// any conflicting statement anywhere else in this repository, including … anything
/// under `docs/plans/`", and §4 makes zero analyzer issues the objective gate for
/// types, lints and deprecation alike. So a document that does not outrank the
/// linter cannot justify an ignore against it — and because Dart has no
/// `unnecessary_ignore` lint, an ignore nobody needs could not have been
/// *detected* either. It would have sat here looking load-bearing.
///
/// A named parameter would have satisfied the lint while keeping the `bool`:
/// `onResult(didLogin: true)`. It was rejected because the boolean is not the
/// defect. `onResult(didLogin: true)` is the same hazard as `onResult(true)` — the
/// reader still has to work out which of two flags is meant — and it would have
/// spelt the call site in a form neither document uses. An enum removes the
/// hazard and the suppression together:
///
/// ```dart
/// onResult(LoginOutcome.signedIn)   // reads as what it is
/// onResult(LoginOutcome.cancelled)
/// ```
///
/// Hiding the `bool` behind a `ValueChanged<bool>` alias would also have silenced
/// the diagnostic, but that is a rename rather than a change, which is the shape
/// of "a gate that cannot fail".
///
/// ## AND WHY NOT TWO CALLBACKS
///
/// A `onResult` plus, say, an `onCancel` would have sidestepped the lint too and
/// would have been strictly worse. Two callbacks means the reader has to work out
/// *which one resumes*, which is a weaker statement than "this one resumes" — and
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
/// Real. `LoginScreen.tsx:11-99` is transcribed — the seal, the wordmark, the
/// tagline, the glass form with its `28` radius and `24` padding, the email and
/// password fields, "Sign in", the two inert links, the "or" divider and the two
/// social buttons — with prototype defects **#8** (`Input` was `readOnly`, so the
/// form could not be filled in) and **#10** (focus and error were literals) fixed.
/// Every number the layout uses is named below with its `ds.tsx` /
/// `LoginScreen.tsx` line, and `login_geometry_test.dart` compares the rendered
/// geometry against those values rather than against a golden — which is the
/// harness AGENT_CONTEXT §9 decision 8 named this phase as the owner of.
///
/// ## THE SEVEN-ELEMENT DECISION (D3), ELEMENT BY ELEMENT
///
/// The prototype has email, password, a show/hide toggle, "Sign in", "Forgot
/// password?", "New here? Create account", an "or" divider, and Google/Apple. Four
/// of those have **nothing behind them** — no endpoint, no route, no OAuth port —
/// and this app may not add a dependency (AGENT_CONTEXT §8.4). So:
///
/// | element | ships? | what a tap does |
/// | --- | --- | --- |
/// | seal + wordmark + tagline | yes, live | nothing — decorative |
/// | email field | yes, live | types into [AuthBloc] |
/// | password field + show/hide toggle | yes, live | types / flips visibility |
/// | "Sign in" | yes, live | [AuthSubmitted] |
/// | "Forgot password?" | **rendered, disabled** | **nothing** — no tap action, no focus stop |
/// | "New here? Create account" | **rendered, disabled** | **nothing** — same |
/// | "or" divider | yes | nothing — decorative |
/// | Google / Apple | **rendered, disabled** | **nothing** — same |
///
/// **Why rendered rather than dropped.** AGENT_CONTEXT §2's route table says
/// `/login` includes "social buttons", so dropping them is a divergence this file
/// is not entitled to make silently. Rendering them honestly disabled keeps the
/// screen a faithful transcription and tells the reader, in the accessible name,
/// that they are unavailable.
///
/// **Why *disabled* rather than a live control that explains itself.** The
/// alternative — a live button whose `onPressed` showed a snackbar saying there is
/// no account creation here — is a fifth control whose only behaviour is to report
/// its own absence, and it teaches the reader that a button in this app sometimes
/// answers with a message about the app rather than about the task. A disabled
/// control with the reason in its accessible name says the same thing once, in the
/// place a reader looks for it, and cannot mislead anyone who cannot see the
/// dimming.
///
/// **The cost is stated, because it is real:** this screen ships four permanently
/// inert controls, which is visible product debt. When a route or an endpoint
/// exists, the fix is one `onPressed` per button and nothing else changes here.
/// `login_page_test.dart` pins the inertness in the failing direction so the
/// decision cannot quietly become a lie.
///
/// ## THE VARIANT IS `NeuralVariant.login` IN **BOTH** DIRECTIONS
///
/// `LoginScreen.tsx:12` is `<NeuralBackground variant={0} />` — unconditionally.
/// There is no Arabic login screen in `eva/src`, and `ORB_CONFIGS[0]` is named by
/// the *screen*, not by a language. So `/login` picks its orb group from the route
/// and nothing else, and the language only chooses text and direction.
///
/// This is deliberately **not** the pattern the reading screens use, where
/// `NeuralVariant.readingEn` and `readingAr` are separate values because the
/// prototype draws a different orb group per language (`ds.tsx:83-91`).
/// `NeuralScaffold`'s doc warns against re-deriving the variant from anything but
/// the variant, and adding a language switch here would put the same fact in two
/// places. `login_geometry_test.dart` asserts the login orb group renders under an
/// `ar` locale.
///
/// ## [onResult] MAY BE NULL, AND THIS PAGE IS BUILT FOR IT
///
/// `/login` is the one route with **no guard** — a gate in front of it would
/// redirect to itself forever — so `pushPath('/login')` builds this page with
/// `onResult == null`. Measured on `AppRouter` with no session by Phase 4: the push
/// leaves the stack at `[LoginRoute, LoginRoute]` (the redirect's, then the deep
/// link's), the pushed page carries `onResult == null`, and the page that *does*
/// carry the resumable callback is underneath, unreachable behind it. A cold deep
/// push of `/login` — a deep link, a notification tap, a restored navigation state —
/// is the app's own route table, not somebody hand-building a widget.
///
/// So the outcome is reported through a **local no-op** when [onResult] is null,
/// and never through a default parameter on the field: a default there would make
/// the trap invisible, because a page reporting an outcome to nobody would look
/// identical to one reporting it to the guard. `login_page_test.dart` signs in on a
/// page built with no [onResult] and asserts the bloc reaches `signedIn` and the
/// page still comes down.
///
/// ## AND NOTHING HERE NAVIGATES
///
/// On success the page reports the outcome and stops. Resuming the interrupted
/// navigation is the **guard's** job (`auth_guard.dart`), which is what makes the
/// flow re-entrant: the same code path serves a deep link to `/login`, a guard
/// redirect, and the initial route. A `context.router.replace` here would be a
/// second, competing resume path.
///
/// ## §14 IN FULL
///
/// * **No unlabeled interactive node.** Every control on this screen carries a
///   name — the two fields through `EvaTextField`'s own `Semantics(label:)`, the
///   four inert ones through [SocialAuthButton]'s and `TextLink`'s, the toggle
///   through [PasswordVisibilityToggle]. `login_accessibility_test.dart` walks the
///   semantics tree and asserts it.
/// * **The focus ring.** §14's 2px `ember`-at-40% band comes from
///   `EvaFocusRing`, which the button, the links and the toggle all use. The two
///   fields are the documented exception: their own rim *is* the ring, and
///   `EvaTextField` says so.
/// * **Colour-only state is paired with an icon.** The password toggle changes
///   both its glyph and its accessible name; every errored field gets
///   `EvaTextField`'s error icon and its `liveRegion` helper text.
@RoutePage()
class LoginPage extends StatelessWidget {
  /// The sign-in screen.
  const LoginPage({super.key, this.onResult, this.bloc});

  /// Reports the sign-in outcome back to whoever redirected here.
  ///
  /// Null means nobody redirected here — which the app's own route table can
  /// arrange. See the class doc for the measured case; the short version is that
  /// this page has to tolerate it, and it does.
  final LoginResultCallback? onResult;

  /// The bloc to render.
  ///
  /// `null` means "resolve [AuthBloc] from the locator", which is the production
  /// path and the reason this page is not a `BlocProvider` of its own: a page that
  /// created its bloc would have one session per mount, and the navigation guard
  /// reads the *locator's*.
  ///
  /// A parameter rather than only a lookup because a widget test cannot reach the
  /// locator without configuring the whole graph, and the alternative — registering
  /// a bloc per test — would make every test file responsible for the graph.
  /// `login_page_test.dart` passes its own and asserts against it.
  final AuthBloc? bloc;

  /// `LoginScreen.tsx:11` — the root's `padding: '0 24px'`, as [EvaSpacing.xxl].
  static const double kRootGutter = EvaSpacing.xxl;

  /// `LoginScreen.tsx:14` — `<div style={{ height: 72 … }} />`, the spacer below the
  /// status bar. **Not** `minHeight: 844`: that is prototype defect #9 and it is
  /// gone with the rest of it — this is a spacer inside a scrolling root, not a
  /// height the page imposes.
  static const double kTopSpacer = 72;

  /// `LoginScreen.tsx:99` — `<div style={{ height: 40 }} />`.
  static const double kBottomSpacer = 40;

  /// `LoginScreen.tsx:17` — the seal-to-wordmark column's `gap: 14`.
  static const double kBrandGap = 14;

  /// `LoginScreen.tsx:17` — the same column's `marginBottom: 48`.
  static const double kBrandBottomGap = 48;

  /// `LoginScreen.tsx:28` — the wordmark's `lineHeight: 1`.
  static const double kWordmarkLineHeight = 1;

  /// `LoginScreen.tsx:32` — the tagline's `marginTop: 6`.
  static const double kTaglineTopGap = 6;

  /// `LoginScreen.tsx:43` — the glass form's `gap: 16`. [EvaSpacing.lg].
  static const double kFormGap = EvaSpacing.lg;

  /// `LoginScreen.tsx:42` — the glass form's `padding: 24`. [EvaSpacing.xxl].
  static const EdgeInsets kFormPadding = EdgeInsets.all(EvaSpacing.xxl);

  /// `LoginScreen.tsx:42` — the glass form's `borderRadius: 28`.
  /// [EvaRadii.glassForm], which `03-design-system.md` §5.3 names for exactly this
  /// surface.
  static const double kFormRadius = EvaRadii.glassForm;

  /// `LoginScreen.tsx:68` — the sign-up row's `gap: 6`, between "New here?" and the
  /// link.
  static const double kSignUpRowGap = 6;

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
    final Widget page = BlocProvider<AuthBloc>.value(
      value: resolved,
      child: _LoginForm(onResult: onResult),
    );

    return NeuralScaffold(
      // See the class doc: the prototype passes `variant={0}` unconditionally, and
      // there is no Arabic login screen to inherit a different one from.
      variant: NeuralVariant.login,
      // `LoginScreen.tsx:11` — `overflowY: 'auto'` on the **root**. The other five
      // screens that scroll differ, and `NeuralScaffold.scrollable`'s doc names the
      // three that do not; `/login` is one of the three that do.
      scrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: kRootGutter),
      child: page,
    );
  }
}

/// The form, and the only widget that reads [LoginBloc].
///
/// Split from [LoginPage] because it must be rebuilt by the bloc while the page's
/// own inputs — the two controllers and the resolved strings — do not change. It
/// is `const`-constructible so the bloc's own rebuilds do not rebuild the two
/// `TextField`s' controllers.
class _LoginForm extends StatefulWidget {
  const _LoginForm({required this.onResult});

  /// Threaded down rather than found with
  /// `findAncestorWidgetOfExactType<LoginPage>()`: the ancestor search would work
  /// today and would break the day the page is wrapped in anything, and it makes a
  /// dependency on a widget three levels up implicit.
  final LoginResultCallback? onResult;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  // §6 and `EvaTextField`'s own doc: the controller is the **caller's**. This
  // widget never creates one from the bloc's text, so a rebuild of the state does
  // not overwrite a character the reader is in the middle of typing.
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  /// The listeners added to the two controllers, so [dispose] can remove exactly
  /// those and not whatever is there.
  final List<VoidCallback> _controllerListeners = <VoidCallback>[];

  /// WHY LISTENERS RATHER THAN AN `onChanged` PARAMETER
  ///
  /// `EvaTextField` has no `onChanged`, and that is its documented contract
  /// rather than an omission: "the controller is the caller's … the `onChanged`
  /// side is [controller]: a caller adds a listener". So the wiring lives here, in
  /// the page that owns the controller, and the design system is untouched.
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
    // the *email* field touched and put "This field is required" under a field the
    // reader had never reached. `login_accessibility_test.dart` caught it by
    // asserting the error icon's count, which is the kind of claim that only fails
    // if the count is exact.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LoginStrings strings = LoginStrings.of(
      Localizations.localeOf(context),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: LoginPage.kTopSpacer),
            _Brand(strings: strings),
            const SizedBox(height: LoginPage.kBrandBottomGap),
            GlassSurface(
              // `GlassTier.tint`, **not** `.blur`. §13.4 is explicit: "Login:
              // `.tint` — it is a full-screen field cluster, so a blur buys
              // nothing", and the prototype's `backdropFilter: blur(24px)` at
              // `LoginScreen.tsx:40` is one of the eight sites the budget refuses.
              // Spending one here would also break
              // `glass_blur_budget_test.dart`'s two-site ceiling, which names
              // Home's panel and Home's top bar as the only two.
              tier: GlassTier.tint,
              radius: LoginPage.kFormRadius,
              padding: LoginPage.kFormPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  EvaTextField(
                    label: strings.emailLabel,
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    errorText: state.emailError,
                    onSubmitted: (String _) =>
                        context.read<AuthBloc>().add(const AuthSubmitted()),
                  ),
                  const SizedBox(height: LoginPage.kFormGap),
                  EvaTextField(
                    label: strings.passwordLabel,
                    controller: _password,
                    obscureText: !state.isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    errorText: state.passwordError,
                    onSubmitted: (String _) =>
                        context.read<AuthBloc>().add(const AuthSubmitted()),
                    // The **widget**, not a callback, for the reason
                    // `EvaTextField.trailing` documents: a focusable nested inside
                    // the field's own focus scope would be a second tab stop for one
                    // field.
                    trailing: PasswordVisibilityToggle(
                      visible: state.isPasswordVisible,
                      showLabel: strings.showPassword,
                      hideLabel: strings.hidePassword,
                      onPressed: () => context.read<AuthBloc>().add(
                        const AuthPasswordVisibilityToggled(),
                      ),
                    ),
                  ),
                  const SizedBox(height: LoginPage.kFormGap),
                  EvaButton(
                    label: strings.signIn,
                    // The only live control on this screen. `null` when the form is
                    // incomplete or wrong — and the errors are already on screen, so
                    // a reader is never left guessing why.
                    onPressed: state.canSubmit
                        ? () => context.read<AuthBloc>().add(
                            const AuthSubmitted(),
                          )
                        : null,
                  ),
                  const SizedBox(height: LoginPage.kFormGap),
                  Center(
                    child: TextLink(
                      label: strings.forgotPassword,
                      // Inert. See the class doc's element table.
                      onPressed: null,
                    ),
                  ),
                  const SizedBox(height: LoginPage.kFormGap),
                  _SignUpRow(strings: strings),
                  const SizedBox(height: LoginPage.kFormGap),
                  HairlineDivider(label: strings.divider),
                  const SizedBox(height: LoginPage.kFormGap),
                  SocialAuthButton(
                    label: strings.continueWithGoogle,
                    semanticLabel:
                        '${strings.continueWithGoogle} — '
                        '${strings.unavailableSuffix}',
                  ),
                  const SizedBox(height: LoginPage.kFormGap),
                  SocialAuthButton(
                    label: strings.continueWithApple,
                    semanticLabel:
                        '${strings.continueWithApple} — '
                        '${strings.unavailableSuffix}',
                  ),
                  if (state.formError case final String message) ...<Widget>[
                    const SizedBox(height: LoginPage.kFormGap),
                    _FormError(message: message),
                  ],
                ],
              ),
            ),
            // `LoginScreen.tsx:99` — the last child of the column, so the canvas
            // does not end flush against the form. The tagline is **not** repeated
            // here: it belongs to the brand block above, and an earlier draft of
            // this file rendered it twice, which the element-counting test in
            // `login_page_test.dart` was the only thing that noticed.
            const SizedBox(height: LoginPage.kBottomSpacer),
          ],
        );
      },
    );
  }
}

/// The sign-up row: "New here?" beside an inert "Create account".
///
/// `LoginScreen.tsx:68-73`. The row is **not** wrapped in a button and the link is
/// disabled, so a reader who tabs past it lands on nothing rather than on a
/// control that goes nowhere.
class _SignUpRow extends StatelessWidget {
  const _SignUpRow({required this.strings});

  final LoginStrings strings;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      Text(
        strings.newHere,
        style: Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: context.colors.ink2),
      ),
      const SizedBox(width: LoginPage.kSignUpRowGap),
      TextLink(label: strings.createAccount, onPressed: null),
    ],
  );
}

/// The seal, the wordmark and the tagline. `LoginScreen.tsx:17-35`.
class _Brand extends StatelessWidget {
  const _Brand({required this.strings});

  final LoginStrings strings;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    return Column(
      children: <Widget>[
        SealMonogram(semanticLabel: strings.sealLabel),
        const SizedBox(height: LoginPage.kBrandGap),
        Text(
          strings.wordmark,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall!.copyWith(
            color: colors.ink,
            fontWeight: FontWeight.w600,
            height: LoginPage.kWordmarkLineHeight,
          ),
        ),
        const SizedBox(height: LoginPage.kTaglineTopGap),
        Text(
          strings.tagline,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge!
              .copyWith(color: colors.ink2),
        ),
      ],
    );
  }
}

/// The repository's refusal, announced once.
///
/// §14's live-region row: it belongs to no single field, so `EvaTextField`'s helper
/// text is the wrong carrier — that is per-field and would be cleared by the next
/// keystroke, taking the answer with it. An error icon carries the state for a
/// reader who cannot see the red.
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
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: context.colors.err),
          ),
        ),
      ],
    ),
  );
}

/// A callback that does nothing.
///
/// Named rather than inlined as `(LoginOutcome _) {}` so the class doc's claim — that
/// a null `onResult` is reported to *this* rather than being skipped — has a name a
/// reader can find. See the class doc.
void _nothing(LoginOutcome outcome) {}
