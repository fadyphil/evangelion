import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/l10n/app_localizations.dart';

/// The `/` strings that are **composed** rather than translated.
///
/// Everything here was a method on `HomeStrings` and is not an ARB key, because
/// none of it is a translation decision:
///
/// * [greetingWord] is a `switch` expression over an enum, and §4 forbids an
///   `if`-chain for state branching — a `Map<GreetingPeriod, String>` lookup would
///   return `null` for a member added tomorrow, which a `switch` cannot;
/// * [greetingLead] joins that word to either a separator or a full stop.
///
/// ## WHY IT IS IN `features/home/` AND NOT BESIDE THE ARB
///
/// [greetingWord]'s parameter is `GreetingPeriod`, which §3 puts in
/// `features/home/domain/` because `HomePage` and this file are its only
/// consumers. A file under `lib/l10n/` that reached into a feature for its type
/// would make the shared kernel feature-dependent, and §3's rule is that the
/// dependency points inward — `core` and shared code never import a feature.
extension HomeStringsPhrases on AppLocalizations {
  /// The greeting's first word, for [period].
  String greetingWord(GreetingPeriod period) => switch (period) {
    GreetingPeriod.morning => homeGreetingMorning,
    GreetingPeriod.afternoon => homeGreetingAfternoon,
    GreetingPeriod.evening => homeGreetingEvening,
  };

  /// The greeting's lead-in — the prototype's `…evening, ` / `…evening.` split.
  ///
  /// `HomeScreen.tsx:26-27` renders `<span ink>Good evening, </span>` and then the
  /// name in a second, ember-coloured span. So the lead-in ends in a separator (see
  /// `homeGreetingSeparator`) when a name follows, and the sentence is closed with a
  /// full stop when one does not — which is a case this client makes reachable,
  /// because the name comes from the session and there may not be one.
  ///
  /// The closing mark is `.` on both arms. Arabic uses the same codepoint; what
  /// differs is the *placement* convention for a trailing full stop after a short
  /// phrase, which is a typographic setting no string table carries, so inventing a
  /// different character would have been a guess dressed as a translation.
  String greetingLead(GreetingPeriod period, {required bool hasName}) {
    final String word = greetingWord(period);
    return hasName ? '$word$homeGreetingSeparator' : '$word.';
  }
}
