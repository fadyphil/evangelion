import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'design_system_harness.dart';

/// The shared fixture for every `/login` test.
///
/// ## WHY IT IS HERE AND NOT IN EACH SUITE
///
/// Three suites now mount this screen — behaviour, accessibility, and the
/// 1.22×/320px geometry gate — and each of them needs the same arrangement: an
/// `AuthBloc` over a **fake** repository, the page in a `MaterialApp` with the Eva
/// theme and the bundled fonts, and a `Locale`. The reasoning is
/// `test/support/app_harness.dart`'s: one copy of a fixture, so the copies cannot
/// drift, and a fixture that drifts is how a screen ends up tested in two
/// arrangements at once.
///
/// ## WHY THE BLOC IS A PARAMETER
///
/// `LoginPage` resolves its bloc from the locator when none is given, which is the
/// production path — but a widget test cannot reach the locator without configuring
/// the whole graph, and registering a bloc per test would make every test file
/// responsible for the composition root. So the page takes one and the harness
/// builds it.
///
/// **AND THE PARAMETER IS **NULLABLE**, BECAUSE THE PRODUCTION BRANCH IS A
/// BRANCH.** A harness that always passed a bloc would never mount the page the
/// way production mounts it — and the production branch is where the page
/// dispatches `AuthStarted` on the locator's bloc, which is the dispatch that
/// can take the reader's chosen role away from them. So `bloc: null` means
/// "the page resolves its own", and the suite that wants the production branch
/// registers a bloc in the locator and asks for it.
///
/// ## AND WHY `pumpWidget`, NOT `pumpAndSettle`
///
/// This page has no ambient animation of its own — `evaPrimitiveHarness` mounts it
/// with `animationsEnabled: false`, so the three shared clocks never tick over it —
/// and `pumpAndSettle` **is** therefore safe here. The prohibition is on the app
/// root, where `NeuralMotionScope` runs three `repeat()`ing controllers and settle
/// never arrives. A test that mounts `EvangelionApp` must use `pumpUntilFound`
/// instead; see `app_harness.dart`.
/// The direction [locale] lays out in, per the framework's own resolution.
TextDirection directionFor(Locale locale) =>
    locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

Future<void> pumpLogin(
  WidgetTester tester, {
  // **NULLABLE**, and `null` means "the page resolves its own from the
  // locator" — the production path. See the header's own paragraph.
  AuthBloc? bloc,
  // [child] replaces the page entirely, for the negative control in
  // `login_text_scale_test.dart`, which needs a widget that provably overflows.
  LoginResultCallback? onResult,
  Locale locale = const Locale('en'),
  Size size = const Size(320, 568),
  double textScale = 1.0,
  ThemeData? theme,
  TextDirection? textDirection,
  Widget? child,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: theme,
      locale: locale,
      textScale: textScale,
      // §14's reduced-motion switch, passed through for the tests that assert
      // the disabled branch itself (`login_page_test.dart`'s entrance and
      // shake groups read `MediaQuery.disableAnimationsOf` through the page).
      disableAnimations: disableAnimations,
      // Derived from [locale], and **not** a parameter.
      //
      // `evaPrimitiveHarness` wraps its child in an explicit
      // `Directionality(textDirection:)`, which sits *inside* `MaterialApp.home`
      // and therefore wins over the `Directionality` Material installs from the
      // resolved locale. So an `ar` locale with the harness's `ltr` default renders
      // Arabic left-to-right — the strings are right and the layout is wrong, and
      // the failure reads as "the page ignores RTL" rather than as "the harness
      // forced a direction". Deriving it from the locale is what a real device
      // does, and it keeps `pumpLogin`'s inputs (`locale` and the surface) all
      // describing the same thing.
      textDirection: textDirection ?? directionFor(locale),
      // The app's own delegate trio, so an `ar` locale is actually honoured here
      // rather than resolving back to English — see `evaPrimitiveHarness`'s note.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // The app's own declared pair (`app.dart`) — `ar` has to be *listed* or
      // MaterialApp resolves it back to `en_US`.
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: child ?? LoginPage(onResult: onResult, bloc: bloc),
    ),
  );
  await tester.pump();
}

/// The email field's inner [TextField], by order.
///
/// By **index** rather than by label because `EvaTextField` renders its label as
/// upper-case text — `Email` is painted `EMAIL` — and a label-based finder would
/// have to know the design system's case transform to find the control. The order
/// is the form's, and it is stated in the assertion that depends on it.
TextField textFieldIn(WidgetTester tester, int index) =>
    tester.widgetList<TextField>(find.byType(TextField)).elementAt(index);

/// The email field's [TextField]. `redesign.html:506`.
TextField emailTextField(WidgetTester tester) => textFieldIn(tester, 0);

/// The password field's [TextField]. `redesign.html:507`.
TextField passwordTextField(WidgetTester tester) => textFieldIn(tester, 1);
