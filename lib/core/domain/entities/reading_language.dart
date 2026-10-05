/// Which arm of the bilingual corpus a payload is in.
///
/// ## WHY THIS IS IN `core/domain/` AND NOT IN ONE FEATURE
///
/// Three screens read it — `home` asks the API for *today's reading* in the
/// reader's language, `reading` renders that arm's scripture, and `settings`
/// names the language a reader picks — so it fails §3's placement test for a
/// single feature and belongs in the shared kernel. A copy inside `features/home`
/// would force `reading` and `settings` to import `home`, which §3 forbids with
/// no exceptions and `tool/verify_purity.sh` Gate 2 fails on the line.
///
/// ## WHY IT IS PURE DART AND NOT A `Locale`
///
/// `Locale` is a `dart:ui` type. Gate 1 holds `core/domain/` — and
/// `core/common/` and `core/navigation/` — Flutter-free, and a `Locale` here
/// would put `dart:ui` inside the shared kernel and out of every use case that
/// composes with it. The alternative — a bridge file mapping `Locale` to this
/// enum — was rejected: it would be a second declaration of the same two-value
/// set in a layer whose only job is to convert a string, and there is exactly
/// one conversion to make, which is what [fromCode] is.
///
/// Screens therefore read it as
/// `ReadingLanguage.forLocale(Localizations.localeOf(context).languageCode)` —
/// a `Locale` at the presentation edge, this enum everywhere below.
///
/// PURE DART — `core/domain/` is held to no Flutter, Dio or http by Gate 1.
enum ReadingLanguage {
  /// NKJV. `ds.tsx` / `ReadingEnScreen.tsx`; `GET /readings/today/en`.
  english('en'),

  /// Smith & Van Dyck (فانديك). `ReadingArScreen.tsx`;
  /// `GET /readings/today/ar`.
  arabic('ar');

  const ReadingLanguage(this.code);

  /// The wire value: the `{lang}` path segment and the response's own
  /// `language` field. Spelled out rather than derived from the member name
  /// because `.name` would give `english` / `arabic`, and the server's value is
  /// `en` / `ar` — §4 forbids `describeEnum` for exactly this reason.
  final String code;

  /// The language [code] names, or `null` if it names none of them.
  ///
  /// ## WHY IT IS NULLABLE, AND WHY [forLocale] IS NOT
  ///
  /// This is the **wire** direction, and its answer to "what if the server sends
  /// something else?" must be *no answer*. A mapper that defaulted an
  /// unrecognised `language` to [english] would build an entity that claims to be
  /// English scripture and is not, and every layer above it would behave
  /// correctly about a lie. So it returns `null` and
  /// `features/reading/data/` turns that into
  /// `FailureKind.serialization` — which is what `failure.dart` already documents
  /// that kind for: "a 2xx response body could not be parsed into a domain
  /// entity."
  ///
  /// The case-sensitivity is deliberate and asserted in the test: `'EN'` is not
  /// `'en'`, and a locale code that arrives capitalised is a bug somewhere else.
  static ReadingLanguage? fromCode(String code) => switch (code) {
    'en' => english,
    'ar' => arabic,
    _ => null,
  };

  /// The language a **locale**'s code names, defaulting to [english].
  ///
  /// ## WHY THE DEFAULT IS SAFE HERE AND NOT IN [fromCode]
  ///
  /// `app.dart` declares `supportedLocales: [Locale('en'), Locale('ar')]` and
  /// nothing else, so a code reaching this function is one of those two unless
  /// the app has been misconfigured — and `MaterialApp` resolves an unlisted
  /// locale back to the first supported one before a screen ever reads it. The
  /// fallback is therefore the same one `gen_l10n` already makes, for the
  /// same reason, with the same wording in its doc: it exists for a widget pumped
  /// outside a `MaterialApp`, which several suites do.
  ///
  /// What it is **not** is a licence to guess from a payload. A response's
  /// `language` field goes through [fromCode] and a `null` there is an error.
  static ReadingLanguage forLocale(String code) => fromCode(code) ?? english;
}
