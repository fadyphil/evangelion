/// The four prototype colours `/journey` draws that **no token in this client
/// carries**, transcribed from `eva/redesign.html`.
///
/// ## WHY THIS FILE EXISTS, AND WHY IT IS **NOT** A LEAK
///
/// `eva/redesign.html` writes the journey's three ring strokes and its four medal
/// blooms as **inline `style` attributes**, not as rules:
///
/// | line | what it writes |
/// | --- | --- |
/// | `:592` | `style="stroke:#3EC9B0;filter:drop-shadow(0 0 6px rgba(62,201,176,.7))"` — ring 1's stroke |
/// | `:593` | `style="stroke:#E457D6;…"` — ring 2's stroke |
/// | `:594` | `style="stroke:#4F74FF;…"` — ring 3's stroke |
/// | `:599` | `style="--bh:rgba(244,227,178,.5)"` — medal 1's bloom |
/// | `:600` | `style="--bh:rgba(228,87,214,.5)"` — medal 2's bloom |
/// | `:601` | `style="--bh:rgba(217,142,50,.5)"` — medal 3's bloom |
/// | `:602` | `style="--bh:rgba(79,116,255,.5)"` — medal 4's bloom |
///
/// §5.1 publishes fourteen colour tokens per brightness and **none** of them
/// is the teal, the blue, the cream or the amber. Promoting four values into
/// `EvaColors` would put screen-specific colours into the file that claims to
/// be the spec's token table — the same reasoning that exempts
/// `neural_orbs.dart`, `eva_toggle.dart` and
/// `features/home/presentation/widgets/card_washes.dart`, and the same
/// discipline: **one colour construction, pinned by count**, and a written
/// reason where the colour gate can see it.
///
/// ## THE MAGENTA IS **NOT** IN HERE, AND THAT IS THE POINT
///
/// `EvaColors.bloom` is `0x8CE457D6` — the prototype's magenta **at 55%** — so
/// `colors.bloom.withValues(alpha: 1.0)` is `#E457D6`, **exactly** the prototype's
/// stroke. Where a token reproduces the hue exactly, the token is used and the
/// transcription is not made. That is decision 63's rule in order, and it is why
/// this file carries **four** values and not five.
///
/// The one difference the token cannot express: the prototype's medal bloom is
/// `rgba(228,87,214,**.5**)` and the token is at **.55**. The wash is 55% in dark
/// and 55% × 0.55 ≈ 30% in light, against the prototype's 50% and 50% × 0.55 ≈
/// 27.5%. The difference is recorded at the medal tile, which is where it is
/// painted.
///
/// ## AND THE THREE RING HUES ARE THE PROTOTYPE'S **READER** HUES
///
/// `eva/redesign.html:1056`, `:1057` and `:1060` are the `hx` fields of the
/// communion board's readers — the same teal, the same magenta and the same blue
/// the journey's rings are drawn in. The redesign reuses its **avatar** palette
/// for its **progress** rings, and the medal blooms are the same idea again: the
/// cream is `:1063`'s `hx` and the amber is `:1058`'s. So these four values are
/// not decorations invented for a screen; they are the board's own reader
/// colours, and the reader on the board is the gold `:1059`.
///
/// ## THE CONTRAST FINDING, WHICH IS **RECORDED** AND NOT FIXED
///
/// The ring strokes are **non-text UI components**, so WCAG 1.4.11 wants 3:1
/// against the surface they sit on. Measured against this client's own palettes
/// (the numbers are reproduced, and asserted, by
/// `test/features/journey/journey_contrast_test.dart`):
///
/// | stroke | dark / canvas | dark / surface | light / canvas | light / surface |
/// | --- | --- | --- | --- | --- |
/// | teal `#3EC9B0` | 9.65 | 9.02 | **1.80** | **2.06** |
/// | magenta `#E457D6` | 6.28 | 5.87 | **2.77** | 3.17 |
/// | blue `#4F74FF` | 4.99 | 4.67 | 3.48 | 3.98 |
///
/// **The light theme's teal and magenta fail 3:1, and the prototype fails them
/// too**: the redesign has **no light-mode override for the strokes** — only the
/// track is overridden (`:79`). And **substitution does not fix it**: every
/// candidate token fails as well — sticker teal 1.76, sticker sky 1.67, sticker
/// lavender 2.04 and sticker pink 1.91 on the light canvas.
///
/// So the hue is **not** changed to make a number pass. The information is not
/// colour-only in any case: the ring's own **value** is painted in `ink` and its
/// **label** in `ink2`, and both are text. The finding is a recorded non-goal
/// with its numbers attached, and the assertion that keeps it honest lives in
/// this feature's own suite rather than in a silent pass.
library;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The teal — `eva/redesign.html:592`'s `stroke:#3EC9B0`.
///
/// **Ring 1's stroke, and the reader hue at `:1056`.** The prototype writes it as
/// an inline `style` on the `.fgc` circle, so it is part of that circle's
/// identity and not a rule anything else can inherit.
const int journeyTealArgb = 0xFF3EC9B0;

/// The blue — `eva/redesign.html:594`'s `stroke:#4F74FF`.
///
/// **Ring 3's stroke, and the reader hue at `:1060`.** It is also medal 4's
/// bloom (`:602`), which is why one value covers two uses.
const int journeyBlueArgb = 0xFF4F74FF;

/// The cream — `eva/redesign.html:599`'s `--bh:rgba(244,227,178,.5)`.
///
/// **Medal 1's bloom**, and the reader hue at `:1063`.
const int journeyCreamArgb = 0xFFF4E3B2;

/// The amber — `eva/redesign.html:601`'s `--bh:rgba(217,142,50,.5)`.
///
/// **Medal 3's bloom**, and the reader hue at `:1058`.
const int journeyAmberArgb = 0xFFD98E32;

/// The blooms' alpha — the prototype's `rgba(…, .5)` at `:599-602`.
///
/// **`.5`, and not the `.55` the `bloom` token carries.** The prototype's four
/// medal washes are all at 50%; the token is at 55% because the *token* is
/// `:254`'s own gradient stop, which is a different wash. This is the number the
/// transcribed blooms are painted at.
const double journeyBloomAlpha = 0.5;

/// The one colour construction in this file.
///
/// **One, and pinned by count** the way `card_washes.dart`'s is: the exemption
/// this file needs is a licence to construct colour, so the licence has to be
/// bounded to a number a reader can check. Every value above is a **packed
/// int** and every colour below is built through here, so a second construction
/// in this file means a colour nobody transcribed.
Color _journeyColour(int argb, double alpha) =>
    Color(argb).withValues(alpha: alpha);

/// The teal, at full strength — ring 1's stroke.
///
/// `eva/redesign.html:592`.
Color get journeyRingTeal => _journeyColour(journeyTealArgb, 1);

/// The blue, at full strength — ring 3's stroke.
///
/// `eva/redesign.html:594`.
Color get journeyRingBlue => _journeyColour(journeyBlueArgb, 1);

/// The cream — medal 1's bloom.
///
/// `eva/redesign.html:599`, at the prototype's `.5`.
Color get journeyBloomCream =>
    _journeyColour(journeyCreamArgb, journeyBloomAlpha);

/// The amber — medal 3's bloom.
///
/// `eva/redesign.html:601`, at the prototype's `.5`.
Color get journeyBloomAmber =>
    _journeyColour(journeyAmberArgb, journeyBloomAlpha);

/// The blue — medal 4's bloom.
///
/// `eva/redesign.html:602`, at the prototype's `.5`.
Color get journeyBloomBlue =>
    _journeyColour(journeyBlueArgb, journeyBloomAlpha);

/// The three ring strokes, in the prototype's order: teal, magenta, blue.
///
/// `eva/redesign.html:592`, `:593` and `:594`.
///
/// **The magenta is the token, not a transcription**: `EvaColors.bloom` is
/// `0x8CE457D6`, and at full alpha that is `#E457D6` — the prototype's stroke
/// exactly. Reading it here rather than in the ring row keeps the one place
/// that knows about the token's 55% alpha in the file that records it.
List<Color> journeyRingStrokes(EvaColors colors) => <Color>[
  journeyRingTeal,
  colors.bloom.withValues(alpha: 1),
  journeyRingBlue,
];
