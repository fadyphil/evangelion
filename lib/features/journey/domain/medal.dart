/// The medal vocabulary, and the two design facts each medal carries.
///
/// ## AND WHY IT DOES **NOT** RE-EXPORT THE **PORT**
///
/// It did, and the review called it: `medal.dart` re-exported
/// `MedalRepository`, `medal_repository.dart` imports `medal.dart` for
/// `Medal`, and the **generated** `injection.config.dart` resolved the port
/// *through* `medal.dart` — so the two files formed an import cycle with a
/// third, generated consumer that this file's own doc did not name, and the
/// re-export made `journey_module.dart`'s import of this file **dead** in
/// exactly the way nothing can see.
///
/// **The port is declared in `medal_repository.dart`**, which is where the
/// placement argument lives, and the two DI files import **that** file for it.
/// One file, one thing: the vocabulary here, the port there, and no cycle
/// between them.
library;

/// One of the four medals the redesign draws (`eva/redesign.html:599-602`).
///
/// ## WHY AN ENUM AND NOT A LIST OF NAMES
///
/// Because a medal is a **thing with a name and an emblem**, and both of those
/// are design facts that belong together: the prototype's four are "first light"
/// with a star, "psalmist" with a fleuron, "streak ×7" with a cross and "john"
/// with a cross. A `List<String>` would hold the names and lose the emblems;
/// a freezed entity would hold both and invite a fifth medal that no prototype
/// line has.
///
/// The same argument is `LibraryCategory`'s, and the same reason it is an
/// enum rather than six strings: **a `switch` over an enum is exhaustive**, so a
/// fifth medal arriving tomorrow is a compile error in every consumer rather
/// than a missing translation discovered on the Arabic arm.
///
/// ## THE NAMES ARE COPY, AND COPY IS AN ARB KEY
///
/// The four labels — `journeyMedalFirstLight`, `journeyMedalPsalmist`,
/// `journeyMedalStreakSeven` and `journeyMedalJohn` — are the prototype's own
/// i18n rows (`eva/redesign.html:937`), so they are **not** fields here. This is
/// `LibraryCategory`'s rule and `LibraryBook`'s too: a translated string
/// does not arrive as data.
///
/// **And the strings themselves are not written here either**, in either arm.
/// The Arabic for the fourth medal is the ARB's to hold, and a domain file
/// that repeated it would be a second home for copy that the ARB can change
/// without anybody reading this file.
///
/// ## AND THE EMBLEM AND THE BLOOM ARE **DESIGN FACTS**, SO THEY ARE HERE
///
/// Two more things hang off a medal, and neither of them is data: the emblem it
/// is drawn with and the colour it washes behind. Both are per-entry facts the
/// prototype states once, at `:599-602`, and both belong with the identity they
/// belong to — a `Medal` that could not say which bloom it is would send the
/// widget back to the prototype to look it up.
///
/// **They are named here and valued elsewhere.** [MedalEmblem] is the name of a
/// character the bundled fonts do not carry, and [MedalBloom] is the name of a
/// colour the token tables do not publish. Neither enum holds a `Color`, a
/// codepoint or a packed ARGB int, and the reasons are in their own docs: a
/// `Color` would put `package:flutter` into a pure-Dart directory, and a
/// packed int would put the colour in the domain — which is the same "two homes
/// for one table" defect the design system's colour gate exists to catch.
///
/// ## THE ORDER IS THE PROTOTYPE'S DRAW ORDER, AND IT IS ALSO THE ENUM'S
///
/// `:599-602` draws first light, psalmist, streak ×7 and john, in that order,
/// and the declaration order is that order. The shelf is read in it, the strip
/// draws in it, and the ARB keys are listed in it — so "the fourth medal" names
/// the same medal in every layer, and a fifth entry is an edit to this file
/// rather than an accident in a list literal somewhere.
enum Medal {
  /// `eva/redesign.html:599` — the four-pointed star, "first light".
  firstLight(MedalEmblem.fourPointedStar, MedalBloom.cream),

  /// `eva/redesign.html:600` — the fleuron, "psalmist".
  psalmist(MedalEmblem.fleuron, MedalBloom.magenta),

  /// `eva/redesign.html:601` — the maltese cross, "streak ×7".
  streakSeven(MedalEmblem.malteseCross, MedalBloom.amber),

  /// `eva/redesign.html:602` — the cross of Saint John, "john".
  john(MedalEmblem.crossOfSaintJohn, MedalBloom.blue);

  /// A medal, with the two design facts the prototype attaches to it.
  const Medal(this.emblem, this.bloom);

  /// The emblem this medal is drawn with.
  ///
  /// **A name and not a character** — see [MedalEmblem], which says why the
  /// prototype's four glyphs cannot be typed.
  final MedalEmblem emblem;

  /// The bloom this medal's wash is painted in.
  ///
  /// **A name and not a colour** — see [MedalBloom], which says where the four
  /// values live and why they are not here.
  final MedalBloom bloom;
}

/// The emblems `/journey`'s medals carry — the prototype's four, named.
///
/// ## WHY THE CHARACTER IS **NOT** IN THIS FILE
///
/// `eva/redesign.html:599-602` writes each medal's emblem as a character, and
/// **three of the four are in no bundled family**: the four-pointed star
/// (U+2726), the maltese cross (U+2720) and the cross of Saint John (U+2629)
/// are in none of the five families `pubspec.yaml` declares, and the fleuron
/// (U+2767) is in EB Garamond alone. A character in no family renders as tofu,
/// and a character in one family renders only where that family is asked for.
///
/// So the emblem is a **name** here and a **rendering decision** in the
/// presentation layer: what the widget paints, and in which face, is recorded
/// there — and it is recorded there because three of the four cannot be typed
/// at all.
///
/// **And the codepoint is written here and not typed**, because typing one is
/// how a tofu gets into a build. The numbers are in this file's doc and in the
/// suite that reads them back out of the prototype, which is the only place
/// that file is read from.
enum MedalEmblem {
  /// The four-pointed star — `eva/redesign.html:599`, U+2726.
  fourPointedStar,

  /// The fleuron — `eva/redesign.html:600`, U+2767.
  fleuron,

  /// The maltese cross — `eva/redesign.html:601`, U+2720.
  malteseCross,

  /// The cross of Saint John — `eva/redesign.html:602`, U+2629.
  crossOfSaintJohn,
}

/// The four blooms `/journey`'s medals wash behind — the prototype's four,
/// named.
///
/// ## WHY A BLOOM IS A **NAME** HERE AND A COLOUR IN THE PRESENTATION LAYER
///
/// `eva/redesign.html:599-602` writes each medal's wash as an inline `--bh`
/// custom property — the prototype's own per-element colour, the same shape
/// `/`'s glass cards use — and **none of the four values is in a token table**.
/// So the **value** lives in the journey feature's own transcription table, on
/// the design system's colour-exemption list, and this enum is the key that
/// table is indexed by.
///
/// **Which is the whole arrangement:** the domain says *which bloom* a medal
/// is, the table says *what colour* that bloom is, and no colour literal
/// exists above the table. A `Medal` that carried a `Color` would put
/// `package:flutter` into a pure-Dart directory; a `Medal` that carried a
/// packed ARGB `int` would put the colour in the domain, which is the "two
/// homes for one table" defect the design system's colour gate exists to
/// catch.
///
/// ## AND ONE OF THE FOUR IS THE DESIGN SYSTEM'S OWN BLOOM HUE
///
/// The magenta is not a transcription: `EvaColors.bloom` publishes the same
/// RGB as the prototype's `:600` wash, at 55% rather than the prototype's 50%,
/// so that line resolves through the token and the five-point alpha difference
/// is recorded in the table. **The other three have no token** — the nearest
/// published values are near-misses, and recorded decision 63
/// (`docs/agents/AGENT_CONTEXT.md:1768-1790`) records the rule this enum
/// follows: a hue the token table does not carry is **substituted with a token
/// that exists on both themes, and the divergence is recorded** — never added
/// as a new colour token. The four values' own table is the one place a
/// reader can check that, and it is deliberately not here.
enum MedalBloom {
  /// The `:599` wash — a warm cream.
  cream,

  /// The `:600` wash — the magenta, and the one `EvaColors.bloom` reproduces.
  magenta,

  /// The `:601` wash — an amber.
  amber,

  /// The `:602` wash — a blue.
  blue,
}
