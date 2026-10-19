import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/features/journey/presentation/journey_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// The journey's strings, and the one transform the shared table does not
/// carry.
void main() {
  group('the medal names', () {
    test('come from the table, in the prototype\'s order', () {
      final AppLocalizations en = AppLocalizationsEn();
      final AppLocalizations ar = AppLocalizationsAr();

      // `eva/redesign.html:937`'s four i18n rows — `m1`, `m2`, `m3` and `m4` —
      // and the enum's declaration order is `:599-602`'s draw order.
      expect(Medal.firstLight.label(en), 'first light');
      expect(Medal.psalmist.label(en), 'psalmist');
      expect(Medal.streakSeven.label(en), 'streak ×7');
      expect(Medal.john.label(en), 'john');

      expect(Medal.firstLight.label(ar), 'أول نور');
      expect(Medal.psalmist.label(ar), 'مرنّمة');
      expect(Medal.streakSeven.label(ar), '٧ أيام');
      expect(Medal.john.label(ar), 'يوحنا');
    });
  });

  group('the percentage', () {
    test('is a whole number with the Latin sign on the Latin arm', () {
      // `eva/redesign.html:592` — `data-v="83%"`, and `:981`'s `N()` maps the
      // digits and the sign.
      final AppLocalizations en = AppLocalizationsEn();
      expect(journeyPercent(en, 0.83), '83%');
      expect(journeyPercent(en, 0.92), '92%');
      expect(journeyPercent(en, 0), '0%');
      expect(journeyPercent(en, 1), '100%');
    });

    test('is Arabic-Indic with the Arabic sign on the Arabic arm', () {
      final AppLocalizations ar = AppLocalizationsAr();
      expect(journeyPercent(ar, 0.83), '٨٣٪');
      expect(journeyPercent(ar, 0.92), '٩٢٪');

      // **U+066A and not U+0025.** The prototype's `N()` (`:981`) is
      // `.replace(/%/g, '٪')`, and a Latin percent sign on an Arabic arm is a
      // translation defect rather than a note.
      expect(journeyPercent(ar, 0.83).codeUnitAt(2), 0x066A);
    });

    test('rounds, because the prototype\'s own values are whole', () {
      final AppLocalizations en = AppLocalizationsEn();
      expect(journeyPercent(en, 0.8333), '83%');
      expect(journeyPercent(en, 0.836), '84%');
    });
  });
}
