import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The shared fixture for every servant-portal test.
///
/// ## WHY IT IS HERE AND NOT IN EACH SUITE
///
/// `login_harness.dart` records the reason: one copy of a fixture, so the
/// copies cannot drift, and a fixture that drifts is how a screen ends up
/// tested in two arrangements at once.
///
/// ## AND WHY THE **LOCALISATION DELEGATE** IS INSTALLED HERE
///
/// `evaPrimitiveHarness` installs Material's own delegates and **not** the
/// app's — so `context.l10n` would find no `AppLocalizations` and every
/// servant string would be a null lookup. The app's delegate and the pair of
/// locales the app ships are therefore installed here, and the Arabic arm is
/// reachable by passing `locale: Locale('ar')`.
///
/// ## AND WHY THE DIRECTION IS **DERIVED** from the locale
///
/// `evaPrimitiveHarness` wraps its child in an explicit `Directionality`, which
/// wins over the one `MaterialApp` installs from the resolved locale. So an
/// `ar` locale with the harness's `ltr` default would render Arabic
/// left-to-right, and the failure would read as "the page ignores RTL" rather
/// than as "the harness forced a direction".
TextDirection servantDirectionFor(Locale locale) =>
    locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

/// The delegates the app's own strings need.
const List<LocalizationsDelegate<dynamic>> kServantLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      // **The plural list**, because the singular one leaves the Cupertino
      // delegate out and the Arabic arm then fails on a missing
      // `CupertinoLocalizations` — a failure about the harness and not about
      // the screen.
      ...GlobalMaterialLocalizations.delegates,
    ];

/// The locales the app ships.
const List<Locale> kServantSupportedLocales = <Locale>[
  Locale('en'),
  Locale('ar'),
];

/// Pumps [child] on a phone-sized surface with the app's strings installed.
Future<void> pumpServant(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1.0,
  bool disableAnimations = false,
  ThemeData? theme,
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
      disableAnimations: disableAnimations,
      textDirection: servantDirectionFor(locale),
      localizationsDelegates: kServantLocalizationsDelegates,
      supportedLocales: kServantSupportedLocales,
      child: child,
    ),
  );
}
