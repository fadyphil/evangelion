import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/features/settings/presentation/workshop_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// `workshop_logic.dart` — the Workshop's pure derivations and the prototype's own
/// untranslated literals.
///
/// ## WHY THESE ARE **PURE** TESTS
///
/// AGENT_CONTEXT §6's rule — "domain logic must not be buried inside a widget" —
/// is only enforceable if the logic is somewhere a test can reach without a widget
/// tree. These are the assertions that do that, and they are the reason the
/// derivations live in their own file rather than in a `build` method.
void main() {
  group('`daylightOnFor` — the narrowing of a three-state field', () {
    // ## THE TABLE, AND IT IS THE WHOLE OF THE NARROWING
    //
    // `UserSettings.themeMode` is `light` / `dark` / `system`, and the redesign's
    // control is a two-state switch (`eva/redesign.html:650`).
    test('light is on', () {
      expect(daylightOnFor(AppThemeMode.light), isTrue);
    });

    test('dark is off', () {
      expect(daylightOnFor(AppThemeMode.dark), isFalse);
    });

    // ## THE ARM THAT IS **NOT** IN THE PROTOTYPE
    //
    // `system` is this client's third state and the prototype has no word for it.
    // It renders **off**, and the stored value is **not** changed until the reader
    // touches the control — so a reader who stored `system` keeps following the OS
    // until they touch the switch.
    test('system renders off, and the narrowing is not a write', () {
      expect(daylightOnFor(AppThemeMode.system), isFalse);
    });

    // ## AND THE CONSEQUENCE, WHICH IS THE POINT OF THE TEST
    //
    // The `system` arm of `AppThemeMode` becomes **unreachable from the UI**:
    // the only writer of the theme on this screen is `SettingsCubit.setDaylight`,
    // and it writes `light` or `dark` and never `system`. A reader who stored
    // `system` keeps it until they touch the control and can never select it
    // again.
    //
    // **This test cannot see the write** — the cubit's doc carries that half — but
    // it can see that the *display* treats `system` as off, and that is the half
    // this function owns. A future change that made `system` render **on** would
    // be a different product, and it would go red here.
    test('no stored mode renders the switch on except `light`', () {
      for (final AppThemeMode mode in AppThemeMode.values) {
        expect(
          daylightOnFor(mode),
          mode == AppThemeMode.light,
          reason: 'AppThemeMode.$mode',
        );
      }
    });
  });

  group('`previewTextFor` — the preview line', () {
    // The prototype's own two literals, in its own scripts (`eva/redesign.html:996`).
    test('the English arm reads the English line', () {
      expect(previewTextFor(isArabic: false), 'The Lord is my shepherd…');
    });

    test('the Arabic arm reads the Arabic line', () {
      expect(previewTextFor(isArabic: true), 'الرب راعي…');
    });

    // ## AND THE TWO ARMS ARE **DIFFERENT**
    //
    // A derivation that returned the same string for both arms would render a
    // Latin sentence on the Arabic arm, and the assertion above would still pass
    // for the English side. This is the one that would catch it.
    test('the two arms are not the same string', () {
      expect(
        previewTextFor(isArabic: false),
        isNot(previewTextFor(isArabic: true)),
      );
    });
  });

  group('the untranslated segment labels', () {
    // ## WHY THESE ARE **WIDGET LITERALS** AND NOT ARB KEYS
    //
    // `eva/redesign.html:673` and `:678` carry **no `data-i18n`**, so the
    // prototype's own English is what a reader of the Arabic arm sees. Putting
    // them in the ARB would force them into `app_localizations_test.dart`'s
    // `mustBeIdentical` set — the gate that catches an untranslated string — and
    // weakening that set for seven words is a bad trade.
    //
    // The list is what the **Arabic typography gate declares**, as the runs they
    // render, so its contents are a claim about the screen and not a private
    // detail.
    test('the Star shape labels are the prototype\'s four', () {
      expect(kStarShapeLabels, <String>['dot', 'star', 'cross', 'gem']);
    });

    test('the Star field labels are the prototype\'s three', () {
      expect(kStarFieldLabels, <String>['crown', 'high', 'full']);
    });

    // ## AND THE FOURTH STAR-SHAPE LABEL IS `gem`, NOT `diamond`
    //
    // The prototype's class name is `s-diamond` and its **label** is `gem`: the
    // class name reaches the geometry and the label reaches the reader.
    test('the fourth Star shape label is `gem`', () {
      expect(kStarShapeGem, 'gem');
      expect(kStarShapeLabels, isNot(contains('diamond')));
    });

    // ## AND THE TWO LISTS ARE **SEVEN** WORDS BETWEEN THEM
    //
    // The count is the claim the orchestrator's Arabic-gate wave needs, and it is
    // asserted here so a label added to one list and not the other is visible.
    test('the seven labels are seven distinct words', () {
      final List<String> all = <String>[
        ...kStarShapeLabels,
        ...kStarFieldLabels,
      ];
      expect(all, hasLength(7));
      expect(all.toSet(), hasLength(7));
    });
  });

  group('the restore action', () {
    // ## THE GLYPH
    //
    // U+21BA, and the measurement behind the `fontFamilyFallback` is in
    // `workshop_rows.dart`'s doc: the glyph is in no bundled mono or scripture
    // face, and it is in `Inter`.
    test('the glyph is U+21BA', () {
      expect(kRestoreGlyph, '↺');
      expect(kRestoreGlyph.runes.single, 0x21BA);
    });

    // ## AND THE DURATION
    //
    // `eva/redesign.html:1393` — `setTimeout(…, 1800)`.
    test('the toast lives for 1800ms', () {
      expect(kRestoreToastDuration, const Duration(milliseconds: 1800));
    });
  });

  group('the About group\'s values', () {
    // ## THE PROTOTYPE'S OWN LITERALS
    //
    // `eva/redesign.html:697-698` — `aurora.frag v8` and `lumen v1.2`. They name
    // the **design system's** versions, not this client's, and the row says so.
    test('the Shaders row carries the prototype\'s literal', () {
      expect(kShadersVersion, 'aurora.frag v8');
    });

    test('the Tokens row carries the prototype\'s literal', () {
      expect(kTokensVersion, 'lumen v1.2');
    });
  });
}
