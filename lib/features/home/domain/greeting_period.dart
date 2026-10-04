/// Which third of the day it is, for the greeting's first word.
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
/// ## WHY THE THREE BOUNDARIES ARE THE ONES BELOW AND NOT OTHERS
///
/// They are stated as local time on the hour, which is the only reading a
/// "Good morning" greeting can have. There is no prototype source for them
/// (`HomeScreen.tsx:26` writes the literal `Good evening, `), so they are this
/// function's decision and it says so — including the two that are arbitrary:
/// 05:00 and 18:00 rather than 06:00 and 18:00.
library;

/// The three parts of a day a greeting has words for.
///
/// An enum and not three `String`s because a `switch` over it is exhaustive: a
/// fourth bucket — "good night", say — becomes a compile error in every consumer
/// rather than a missing translation discovered in Arabic.
enum GreetingPeriod {
  /// 05:00–11:59.
  morning,

  /// 12:00–17:59.
  afternoon,

  /// 18:00–04:59.
  evening,
}

/// The bucket [at] falls into, by its local hour.
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
  _ => GreetingPeriod.evening,
};
