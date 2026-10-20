/// Whether it is vespers, and how much the ambient dims when it is.
///
/// PURE DART — Gate 1 holds `core/domain/` Flutter-free.
library;

/// The ambient factor the vespers dim applies.
///
/// `eva/redesign.html:890` — `const vesp=vespersOn&&isNight()?0.78:1;`.
const double kVespersDimFactor = 0.78;

/// Whether [hour] is vespers.
///
/// `eva/redesign.html:886` — `const isNight=()=>{ const h=new Date().getHours();
/// return h>=21||h<5; };`.
bool isVespersHour(int hour) => hour >= 21 || hour < 5;

/// The factor the ambient is multiplied by.
///
/// `eva/redesign.html:890` — `const vesp=vespersOn&&isNight()?0.78:1;`.
///
/// **The switch is checked before the hour, and the order matters only for
/// the reader who turned it off**: an hour test alone would dim the app at
/// 03:00 for a reader who asked for no vespers dim at all, and the prototype's
/// own expression is `vespersOn&&isNight()` — the reader's choice first.
double vespersFactor({required bool enabled, required int hour}) =>
    enabled && isVespersHour(hour) ? kVespersDimFactor : 1;
