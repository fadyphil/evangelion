/// Whether a string may be handed to the text engine at all.
///
/// ## THE THROW IS REAL. IT IS ALSO **CAUGHT**, AND THOSE ARE SEPARATE FACTS
///
/// The defect claim this file exists for is that `RenderParagraph` throws
/// `ArgumentError: string is not well-formed UTF-16` on a `String` holding an
/// unpaired surrogate. **That is correct**, and it is recorded three times in
/// `AGENT_CONTEXT.md` — `:1757`, `:2156`, `:2226` — the last of which is decision
/// 83, the decision that introduced this file.
///
/// An intermediate draft of this doc said the opposite: that a re-measurement on
/// `Flutter 3.47.4` found the throw does not happen. **That draft was wrong.** It
/// is worth recording *how*, because the failure is not about UTF-16.
///
/// ## THE MECHANISM THAT HIDES IT, MEASURED
///
/// The throw happens **during layout**, not during `build`:
///
/// ```text
/// _NativeParagraphBuilder.addText      dart:ui/text.dart:3724   <- throws ArgumentError
/// TextSpan.build                       painting/text_span.dart:298
/// TextPainter._createParagraph         painting/text_painter.dart:1203
/// TextPainter.layout                   painting/text_painter.dart:1264
/// RenderParagraph.performLayout        rendering/paragraph.dart:966
/// ```
///
/// `dart:ui` is the throw site and it is unconditional — `text.dart:3721-3724` is
/// `final String? error = _addText(text); if (error != null) throw
/// ArgumentError(error);`, where `_addText` is the engine's `ParagraphBuilder::addText`
/// returning its own error string. Measured on the pinned toolchain
/// (`Flutter 3.47.4`), for **all three** widget types — `Text`, `SelectableText` and
/// `Text.rich` — `tester.takeException()` is an `ArgumentError` reading
/// `Invalid argument(s): string is not well-formed UTF-16`, from a string holding one
/// trailing lone high surrogate. The frame still paints.
///
/// **So the frame painting is not the absence of a throw.** The painting library
/// catches a layout exception, records it, and lets the frame complete; the test
/// binding surfaces it through `tester.takeException()`. Two consequences, both
/// load-bearing:
///
/// * a probe that prints its own label beside the exception's value can be read as
///   agreeing with the label when it is displaying the opposite. The bad draft above
///   did exactly that;
/// * **an exception that is never taken fails the test.** `AutomatedTestWidgetsFlutterBinding`
///   rethrows a pending one at teardown, so `takeException() == null` — not "a frame
///   appeared" — is the only negative test available.
///
/// This is the third time this phase a probe's output carried the answer and the
/// conclusion ignored it, after Phase 7's `find.textContaining` miss and Phase 8's
/// `excludeSemantics` miss. The rule that generalises: **when a probe can print a
/// verdict, print the verdict as the value being asserted, not as a label beside it.**
///
/// ## SO THE COST OF A MALFORMED PAINTED STRING IS **TWO** THINGS
///
/// A broken glyph where the content should be, **and** a caught `ArgumentError` on
/// every layout of that paragraph — the paragraph whose layout was aborted is laid
/// out again on the next frame that needs it, and throws again. It is not a screen
/// outage: the frame completes and the reader keeps the rest of the screen. That is
/// the accurate version, and it is a real defect worth a mapper rule — "this field
/// cannot be painted" is the same verdict `today_reading_mapper.dart` already gives
/// a verse with no `book_number`, and reusing it is what stops a second "what does a
/// bad row cost" decision existing.
///
/// Decision 80 is the authority for putting the rule here at all, and its wording
/// survives the correction untouched:
///
/// > *"the honest repair is a **mapper** rule answering 'is this verse usable?'
/// alongside the empty-verse question it deliberately does not answer — once, in
/// Phase 8."*
///
/// ## 89. THE RULE REACHES **EVERY** PAINTED STRING, AND THE VERDICT DEPENDS ON
/// ## WHAT THE STRING IS **FOR**
///
/// An earlier draft of this decision excluded `reference` and `translation` on cost
/// grounds, and the cost it quoted was false — it said a malformed label costs only a
/// tofu box and that gating one would "create" an outage. With the throw measured,
/// that column is wrong in both directions, and re-deciding it on the real numbers
/// reverses the exclusion. The rule now reaches **all six** painted fields:
///
/// | field | role | malformed, **blanked** (kept) | malformed, **refused** (rejected) |
/// | --- | --- | --- | --- |
/// | `text`, `text_clean`, `prompt`, `options` | **content** — the reader reads it as the passage or the question | *not applicable: these are refused, see below* | that verse or question is skipped; the screen works |
/// | `reference`, `translation` | **labels over the content** | a blank citation/edition row — a state the server already produces by sending `''` | **the whole reading fails to map** — `/`'s panel, `/reading`'s passage, and both controls |
///
/// **The real trade, stated in both directions.** What the reader loses when a label
/// is malformed and we blank it: the citation, or the edition name. That is not
/// nothing, and it is not invisible to a reader who notices an empty title — but it
/// is the **same thing they already see** when the server sends `reference: ''`, which
/// this mapper has always passed through on purpose and which
/// `today_reading_mapper_test.dart` already carries a test for. What they lose instead
/// of that: a broken glyph **and** a caught `ArgumentError` on every layout of the
/// heading, which no reader was going to benefit from. What the reader loses when the
/// gate **refuses** a malformed label: the entire reading, on both screens, with both
/// controls dead.
///
/// One bad label must not cost the passage. That is decision 40's `text: ''` argument
/// exactly, and it is why the label's verdict is a blank rather than a refusal.
///
/// **Rejected: passing a malformed label through verbatim.** This was the earlier
/// draft's position and it is the one the corrected measurement kills. It preserves
/// the server's bytes, and it pays for them with a per-layout `ArgumentError` and a
/// tofu box in the one line that tells the reader which reading they are in — for a
/// byte sequence no reader can act on and no screen renders. `renderableTextOrEmpty`
/// is the rule; verbatim was the accident.
///
/// **Rejected: refusing the reading.** Not close. A blank title is a cosmetic loss on
/// one line; a refused reading is the loss of the product's only feature on that
/// screen. The two are not the same kind of decision and should not be written as if
/// they were.
///
/// `today_reading_mapper_test.dart` holds both halves as tests: the four content
/// fields are *refused* and the two labels are *blanked with the passage intact*, so
/// the next reader sees a decision rather than a gap.
///
/// ## "USABLE" IS **NOT** "NON-EMPTY", AND THE TWO ARE NOT INTERCHANGEABLE
///
/// Recorded decision 40 fixed `text: ''` as a value that **maps**: the verse text
/// is the one field a reader cannot be shown without, and everything else in that
/// payload is a label *over* content, so refusing it would turn one cosmetic
/// upstream defect into "the reader cannot open today's reading at all".
///
/// A malformed string is the other half. An empty paragraph is a **visible** gap —
/// a reader sees a numbered line with nothing on it — and every control on the
/// screen still works. A malformed string is a louder version of the same thing: a
/// tofu box **and** a caught `ArgumentError` on every layout of that paragraph. So
/// the two verdicts are distinguished by *what the reader loses*, not by whether
/// anything crashes:
///
/// | wire | maps? | reader sees |
/// | --- | --- | --- |
/// | `text: ''` | **yes** — decision 40 | an empty numbered line; the screen works |
/// | `text: '\uD83D…'` | **no** — this rule | the verse is skipped; the screen works |
/// | `text: 42` | **no** — already refused as a type | the verse is skipped; the screen works |
///
/// The third row is the same verdict by a different route, and the fact that two
/// malformed rows and one empty row land differently is the point: the question is
/// not "does this look like text", it is "can this be painted".
///
/// ## WHY A NAMED FUNCTION AND NOT A `try`/`catch` OVER `runes`
///
/// `String.runes` does **not** throw on a malformed string — it yields the unpaired
/// surrogate as a rune of its own, which is why `runes.length == length` is the wrong
/// test and `test/support/utf16.dart` records the measurement. So a `try`/`catch` was
/// never the alternative here; a scan over `codeUnits` is simply the same walk the
/// engine's own check does, has no exception in it at all, and is total.
///
/// The rule itself is the only one in the codebase: `test/support/utf16.dart`
/// carried a copy for Phase 7's tests and now delegates here, so there is one
/// implementation and the tests that already existed are testing it.
///
/// ## AND IT IS **NOT** A SHAPE TEST ON THE SCRIPTURE
///
/// Recorded decision 29 rejects a shape test — "does this look like Arabic?", "does
/// it start with a letter?" — for the drop cap, for a measured reason: a verse can
/// legitimately open with a numeral or a bracket, and `§5`'s live payload opens one
/// behind a `‹Verily`. This is not that. It asks a property of the **encoding**, not
/// of the corpus, and it would be satisfied by a string in any script.
library;

/// Whether [value] is well-formed UTF-16 and may therefore be painted.
///
/// ```text
/// a high surrogate (U+D800–U+DBFF) is legal only immediately before a low one
/// a low surrogate (U+DC00–U+DFFF) with nothing above it is an orphan
/// everything else is fine, including the empty string
/// ```
///
/// **An empty string is renderable.** See the class doc's table — decision 40's
/// `text: ''` maps, and this function is what keeps that decision and the mapper's
/// on the same page.
bool isRenderableText(String value) {
  final List<int> units = value.codeUnits;
  for (int i = 0; i < units.length; i++) {
    final int unit = units[i];
    if (_isHighSurrogate(unit)) {
      if (i + 1 >= units.length || !_isLowSurrogate(units[i + 1])) {
        return false;
      }
      // Skip the low half; it is legal only as the second unit of this pair.
      i++;
    } else if (_isLowSurrogate(unit)) {
      return false;
    }
  }
  return true;
}

/// [value] if it may be painted, or `null` if it may not.
///
/// The shape a mapper wants for **content** — "the value to use, or `null` for *this
/// row cannot be rendered*" — and the reason it is a separate function rather than a
/// call to [isRenderableText] inside a ternary is that the two spellings of "refuse
/// this row" are easy to confuse when one of them is written inline. See
/// [renderableTextOrEmpty] for the other one.
///
/// **Rejected: returning `''` for a malformed string.** It is the "substitute an
/// empty verse" alternative `today_reading_mapper.dart`'s own table already rejected
/// for a malformed **verse** — a numbered gap with nothing in it and no way to tell
/// it is a gap. Refusing the row is at least visible as a missing number. That
/// rejection is about a verse and it does **not** extend to a label; see
/// [renderableTextOrEmpty].
String? renderableTextOrNull(String value) =>
    isRenderableText(value) ? value : null;

/// [value] if it may be painted, or `''` if it may not.
///
/// The shape a mapper wants for a **label** — `reference`, `translation` — and the
/// decision 95 table is the argument for it: a blank citation costs one line of the
/// screen, a refusal costs the whole reading.
///
/// **Named rather than written inline** for [renderableTextOrNull]'s reason, and more
/// sharply here: `isRenderableText(x) ? x : ''` and `isRenderableText(x) ? x : null`
/// differ by two characters and mean opposite things to a reader. The blank is a
/// deliberate verdict for a field whose absence is already a normal state, so it
/// deserves a name that says "label" rather than one that reads as a general-purpose
/// fallback.
///
/// **Rejected: passing the malformed value through.** That preserves the server's
/// bytes and costs a tofu box plus a caught `ArgumentError` on every layout of the
/// heading. Measured — see the class doc.
String renderableTextOrEmpty(String value) =>
    isRenderableText(value) ? value : '';

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
