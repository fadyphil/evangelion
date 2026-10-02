// Golden-test font hook. Runs once, before any test file in `test/`.
//
// WHY THIS FILE EXISTS. `docs/plans/09-quality-gates.md` §11 and
// `docs/plans/08-build-phases.md` Phase 0 both require it, and both name the
// consequence of leaving it out: every golden is flaky on a cold cache.
//
// The mechanism is a fallback, and the fallback does not fail loudly. With no
// `FontLoader` hook, `TextStyle(fontFamily: 'Amiri')` in a widget test resolves
// to whatever font the test runner has — not to Amiri. Nothing throws. The
// golden is captured from the fallback, it passes against itself, and it is
// re-captured by whoever notices the text looks wrong. So the fonts have to be
// registered into the *test engine's* font collection before the first frame,
// which is the only place a `FontLoader` call has any effect.
//
// `google_fonts` is deliberately not used as the load path: it fetches over
// HTTP at runtime, which is precisely the non-determinism this hook exists to
// remove. The five families are bundled under `assets/fonts/` and declared in
// `pubspec.yaml`, so they resolve offline and byte-identically on every host.
//
// WHY THE FAMILY LIST IS SPELLED OUT HERE. `pubspec.yaml` already declares the
// five families, so this map is a second place the list exists. Reading
// `FontManifest.json` out of the asset bundle instead would couple the hook to a
// generated artifact, and a manifest that silently omits a family would produce
// exactly the quiet-fallback failure described above. Spelling it out makes a
// font that stops being registered a line you can see in a diff.
//
// `test/font_loading_test.dart` is the anti-rot check: it measures real glyph
// advances for a monospaced and a proportional family, which is only true if
// this hook actually ran.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every bundled family and the asset files that make it up.
///
/// Keys are the `family:` names in `pubspec.yaml` — they must match
/// character-for-character, because that string is what a
/// `TextStyle(fontFamily: …)` is matched against. All five weights of a family
/// are added to the same [FontLoader]: the loader registers each file as its own
/// face under one family name and the engine reads the weight out of the font
/// data, so `FontWeight.w700` still resolves to the right file.
const Map<String, List<String>> bundledFontFamilies = <String, List<String>>{
  'CormorantGaramond': <String>[
    'assets/fonts/CormorantGaramond-Regular.ttf',
    'assets/fonts/CormorantGaramond-Medium.ttf',
    'assets/fonts/CormorantGaramond-SemiBold.ttf',
    'assets/fonts/CormorantGaramond-Bold.ttf',
    'assets/fonts/CormorantGaramond-RegularItalic.ttf',
  ],
  'EBGaramond': <String>[
    'assets/fonts/EBGaramond-Regular.ttf',
    'assets/fonts/EBGaramond-Medium.ttf',
    'assets/fonts/EBGaramond-SemiBold.ttf',
    'assets/fonts/EBGaramond-Bold.ttf',
    'assets/fonts/EBGaramond-RegularItalic.ttf',
  ],
  'DMSans': <String>[
    'assets/fonts/DMSans-Regular.ttf',
    'assets/fonts/DMSans-Medium.ttf',
    'assets/fonts/DMSans-SemiBold.ttf',
    'assets/fonts/DMSans-Bold.ttf',
    'assets/fonts/DMSans-ExtraBold.ttf',
  ],
  'Amiri': <String>[
    'assets/fonts/Amiri-Regular.ttf',
    'assets/fonts/Amiri-Bold.ttf',
    'assets/fonts/Amiri-Italic.ttf',
  ],
  'SpaceMono': <String>[
    'assets/fonts/SpaceMono-Regular.ttf',
    'assets/fonts/SpaceMono-Bold.ttf',
  ],
};

/// The flutter_test entry point this file replaces.
///
/// Initialising the binding here is required, not decorative: `rootBundle` needs
/// the asset bundle to exist before it can resolve a key, and the test binding
/// is what installs the bundle.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadBundledFonts();
  await testMain();
}

/// Registers every family in [bundledFontFamilies] with the test engine.
///
/// `rootBundle.load` is used rather than `File(...).readAsBytes`: the bundle is
/// the same asset the built app serves, so a font that is declared in
/// `pubspec.yaml` but missing from disk fails here loudly instead of being
/// silently substituted by a fallback.
///
/// The bytes are passed to [FontLoader] exactly as `load` returns them.
/// `FontLoader.load()` concatenates the futures itself into a single
/// offset-zero `ByteData`, so there is nothing here to normalise — re-wrapping
/// them would hand the engine a window over a *larger* buffer than the font,
/// which is the kind of corruption that shows up as a mysteriously malformed
/// glyph rather than as an error.
Future<void> loadBundledFonts() async {
  for (final MapEntry<String, List<String>> family
      in bundledFontFamilies.entries) {
    final FontLoader loader = FontLoader(family.key);
    for (final String asset in family.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
