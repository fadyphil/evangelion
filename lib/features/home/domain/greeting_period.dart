/// Which part of the day it is, for the greeting's mono caption.
///
/// ## WHY IT IS A DOMAIN FUNCTION AND NOT A `switch` IN A WIDGET
///
/// AGENT_CONTEXT §6: "if a widget needs a conditional or calculation, extract it
/// to a cubit or a pure function and TDD that." A time-of-day bucket is both, and
/// it is also the one calculation on `/` whose **result has to be testable**: a
/// widget calling `DateTime.now()` directly gives a test no way to reach the
/// afternoon branch, so the middle third of the day would ship untested.
///
/// The clock itself is the bloc's, not this function's — `HomeBloc` takes a
/// `DateTime Function()` and puts the answer in its state, so the widget renders
/// a value it did not compute and a test can pin any hour it likes.
///
/// ## AND WHY THE FOUR **BOUNDARIES** ARE NOW THE PROTOTYPE'S
///
/// The first version of this function had three buckets at 05:00, 12:00 and 18:00,
/// and said in this file that no prototype source existed for them — "they are this
/// function's decision". `redesign.html:983-984` does have one, and Phase 5.2 took
/// it:
///
/// ```js
/// function hourKey(){ const h=new Date().getHours();
///   return (h>=5&&h<12)?'morn':(h>=12&&h<18)?'noon':(h>=18&&h<24)?'eve':'vigil'; }
/// ```
///
/// Same three boundaries, **and a fourth bucket for the small hours** — `vigil`,
/// "night vigil" (`:926`) — which the three-bucket clock used to call evening. The
/// word is not a synonym: `:984`'s `_ => 'vigil'` covers 00:00–04:59 and the I18N
/// gives it its own Arabic, `سهر الليل`. `GreetingPeriod.vigil` is that bucket.
library;

/// The parts of the day a greeting has words for.
///
/// An enum and not four `String`s because a `switch` over it is exhaustive: a
/// fifth bucket — "good night", say — becomes a compile error in every consumer
/// rather than a missing translation discovered in Arabic.
enum GreetingPeriod {
  /// 05:00–11:59. `redesign.html:984` — `h>=5&&h<12` → `morn`.
  morning,

  /// 12:00–17:59. `redesign.html:984` — `h>=12&&h<18` → `noon`.
  afternoon,

  /// 18:00–23:59. `redesign.html:984` — `h>=18&&h<24` → `eve`.
  evening,

  /// 00:00–04:59. `redesign.html:984` — the `_ =>` arm → `vigil`.
  ///
  /// **The bucket the old three-arm clock did not have**, where 00:00–04:59 read as
  /// evening because 18:00 and everything after it was one bucket. The prototype's
  /// word for it is `night vigil` and its Arabic is `سهر الليل`; see this file's
  /// class doc for where the boundaries come from.
  vigil,
}

/// The bucket [at] falls into, by its local hour.
///
/// **The prototype's own rule, transcribed.** `redesign.html:983-984` — `morn` for
/// 5 ≤ h < 12, `noon` for 12 ≤ h < 18, `eve` for 18 ≤ h < 24 and `vigil` for
/// everything else — so the last two arms are `_` and not a fifth and sixth
/// comparison. That is also why `vigil` reads only 0, 1, 2, 3 and 4: the
/// prototype's clock is 24-hour local, exactly as this one is.
///
/// Only [DateTime.hour] is read. A `DateTime` carries no zone information of its
/// own — `DateTime.now()` is local and `DateTime.utc()` is UTC — so the function
/// answers "what hour does this instant read as", and **the caller** owns the
/// zone decision. That is the same separation `AuthSession.createdAt` documents
/// and the reason nothing here calls `toLocal()`: a function that silently
/// converted would make `DateTime.utc()` and `DateTime.now()` of the same instant
/// disagree with no way for a reader to tell which one it read.
GreetingPeriod greetingPeriodFor(DateTime at) => switch (at.hour) {
  >= 5 && < 12 => GreetingPeriod.morning,
  >= 12 && < 18 => GreetingPeriod.afternoon,
  >= 18 => GreetingPeriod.evening,
  _ => GreetingPeriod.vigil,
};
