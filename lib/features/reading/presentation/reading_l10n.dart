import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';

/// The `/reading` sentences that are **composed** rather than translated, and
/// the two arm-keyed reads that belong beside them.
///
/// ## WHY THIS FILE EXISTS — THE PLURAL IS GONE, AND THAT IS THE EVENT
///
/// Until Phase 5.3 this file existed to wrap **one** method over the ARB's
/// two-placeholder plural `readingCaptionFor`, and that plural was real work:
/// `app_ar.arb` supplied all six ICU classes so a count of `2` rendered
/// `٢ سؤالان` rather than the table's `٢ أسئلة`.
///
/// **Task 5.3 deleted the plural**, because the redesign's CTA does not have a
/// sentence to inflect. `eva/redesign.html:1347` writes the caption as
///
/// ```js
/// el('qctaLabel').textContent = `${tr('quiz')} · ${N(qEff)} ${tr('questions')}`;
/// ```
///
/// — one word for every count, from a table whose `questions` row
/// (`:967`) carries **no** plural forms at all. Adopting the prototype's
/// caption therefore means adopting its table, and the Arabic dual
/// (`سؤالان`) is a piece of grammar the prototype's own UI does not have.
///
/// ## AND THAT IS THE SAME TRADE HOME ALREADY MADE, WHICH IS WHY IT IS A
/// ## PATTERN AND NOT A PRECEDENT I AM SETTING
///
/// `features/home/presentation/home_l10n.dart` already dropped four plural
/// keys for the same reason, with the same recorded trade: `verseCount`,
/// `selahSeconds` and `scrollsOpen` all render one word for every count
/// because the redesign's I18N table (`:925-977`) has one row each and no ICU
/// metadata. **A client that inflects where the prototype does not is
/// translating a design decision nobody made**, and the cost is a table whose
/// values cannot be compared against the prototype's row-by-row — which is
/// what `home_l10n_test.dart` and `app_localizations_test.dart` do compare.
///
/// The loss is real and is written here rather than discovered later: a reader
/// on the Arabic arm sees `اختبار · ٢ أسئلة` where `اختبار · سؤالان` would be
/// correct Arabic. It buys a caption that is byte-comparable with `:1347`.
///
/// ## AND STILL NO ARB PLACEHOLDER — THE LATIN-SCRIPT GATE
///
/// Both composed strings take numbers, and neither number may go into the ARB
/// as a placeholder: a placeholder *name* is Latin (`{count}`), and
/// `app_localizations_test.dart`'s Latin gate fails any Arabic-arm value
/// holding Latin script outside its documented set. So the composition is
/// Dart's, the numerals come from [digits] (`l10n.dart`, which is `:988`'s
/// `N`), and the table keeps whole-literal rows.
///
/// ## AND THE NUMERALS ARE THE ARM'S, IN BOTH DIRECTIONS
///
/// `digits` renders `٠-٩` (U+0660-0669) on the Arabic arm and `0-9` on the
/// Latin one, which is what `N()` does at `:988`. **Those codepoints are
/// Arabic-block**, so a count rendered in the mono face is tofu — the same
/// defect `streak_chip.dart`'s numerals had, fixed by `arabicAware`, and the
/// reason `reading_glyph_test.dart` asserts the family of these two strings.
extension ReadingStringsPhrases on AppLocalizations {
  /// The quiz CTA's caption for [count] questions — `quiz · 3 questions`.
  ///
  /// `redesign.html:1347`, verbatim in shape: the word `quiz`, the middle dot
  /// the prototype writes as ` · ` (U+00B7 with spaces, and **not** this
  /// client's ARABIC COMMA separator — `homeGreetingSeparator` is a different
  /// sentence in a different grammar, and reusing a separator from one screen
  /// for another would couple two unrelated transcriptions), then the count in
  /// this arm's numerals and the plural-free word `questions`.
  ///
  /// **A count of zero is still a caption, not an error.** `TodayReadingMapper`
  /// skips an unreadable question rather than refusing the passage (recorded
  /// decision 40), so `questionCount == 0` is reachable — but the *page* is
  /// what gates the CTA on `questionCount > 0` (`reading_page.dart`'s own
  /// comment records why), so the reader never sees this sentence at zero. The
  /// method is honest either way, which is why it does not special-case it.
  String quizCaption(int count) =>
      '$readingQuiz · ${digits(count)} $readingQuestions';

  /// The sub-bar's meta line —
  /// `poetry · 6 verses · sky 3`.
  ///
  /// `redesign.html:1346`:
  /// `` `${CATS[b.cat][li()]} · ${N(b.en.length)} ${tr('verses')} · ${tr('sky')} ${N(skyN)}` ``
  ///
  /// Three numbers-looking clauses and two of them are **arguments, not strings**:
  ///
  /// * [category] — the reader's arm-keyed category word. The caller passes
  ///   `LibraryCategory.label(strings)`, which `home_l10n.dart` owns, because
  ///   `CATS` is a shared table (`:1036`) and a second transcription of six
  ///   rows here would be two sources for one fact. This method takes the word,
  ///   not the enum, precisely so `/reading` never has to import home's
  ///   extension to say what a book is.
  /// * [verses] — **the passage's real verse count**, and this is a recorded
  ///   divergence from the prototype's `b.en.length`. That expression is the
  ///   *fictional excerpt length* ADR-0022 killed on `/` (the catalogue's
  ///   `verseCount`), while the screen showing the line has the server's
  ///   `ScriptureText.verses` in hand. Rendering the fiction's count above the
  ///   real passage would be the fiction leaking back in through the one line a
  ///   reader uses to check the passage's length.
  /// * [litStars] — `SkyState.count`, fed by the observer that adds a star per
  ///   verse as it crosses `:1219`'s threshold.
  String crumbMeta({
    required String category,
    required int verses,
    required int litStars,
  }) =>
      '$category · ${digits(verses)} $readingVerses · '
      '$readingSky ${digits(litStars)}';

  /// The `listen` control's accessible name while audio is absent.
  ///
  /// ## THE CONTROL IS INERT IN THIS BUILD, AND THE NAME SAYS WHY
  ///
  /// `eva/redesign.html:1399` is the whole of the prototype's listen
  /// behaviour: `el('listen').onclick = … el('pill').classList.toggle('playing')`
  /// plus a 10 ms haptic. **There is no audio anywhere in the prototype** —
  /// `speechSynthesis`, `AudioContext`, `new Audio` and `.play()` all appear
  /// zero times in the file. The button starts nothing; it toggles a CSS class
  /// that reveals four decorative bars (`.wave`, `:197-201`, four `<i>` each
  /// animating its own height 4→14→4 px on a 0.15 s phase offset).
  ///
  /// So this client ships the control **inert**, with the reason in its
  /// accessible name, exactly as `/login`'s two ghost pills and `/`'s SealFab
  /// items do — a reader is told the capability is absent rather than shown an
  /// animation that lies about audio playing. The visible label stays the
  /// prototype's own `listen` word; only the name a screen reader announces
  /// grows the suffix, so the sighted reader is not told about a build detail
  /// on every visit.
  ///
  /// ## AND THE WAVE ITSELF IS NOT BUILT — SEE THE ORPHAN GATE
  ///
  /// An inert control never reaches `.playing`, so a `.wave` widget would be
  /// built, tested and **never reachable from a page** — precisely the defect
  /// `tool/gates/orphan_widget_check.py` exists to catch (recorded decision
  /// 144, and its allowlist is a list of *named* future consumers). If audio
  /// ever lands, the wave arrives with it and the same gate keeps it honest.
  String listeningUnavailable(String suffix) => '$readingListen — $suffix';
}
