/// The washes `/`'s glass cards paint, transcribed from the prototype's own
/// `style` attributes — the third of this client's three colour homes.
///
/// ## WHY THIS FILE EXISTS, AND WHY IT IS **NOT** A LEAK
///
/// `eva/redesign.html` writes each card's wash as an inline custom property and
/// not as a rule: `:519` is `style="--bh:rgba(228,87,214,.55)"` on `#votdCard`
/// and `:524` is `style="--bh:rgba(232,176,75,.35)"` on `#lastCard`. `--bh` is
/// what `.hcard::before`'s bloom reads (`:250`), so the value is part of the
/// **card's identity** — the day's card is magenta and the last light is gold at
/// `.35`, and no token table carries either fact.
///
/// §5.1 publishes fourteen colour tokens per brightness and none of them is a
/// per-card wash; the design system's bloom token is the `var(--bh, …)` **fallback**, not the
/// value. Promoting these two into `EvaColors` would put card-specific values
/// into the file that claims to be the spec's token table, which is the same
/// reasoning that exempts `neural_orbs.dart` and the toggle knob — and
/// `no_colour_literals_test.dart` is what makes those bullets decisions rather
/// than leaks, so this file is registered there with the same discipline: one
/// colour construction, pinned by count.
///
/// ## AND THE CATALOGUE'S WASHES COME THROUGH HERE TOO
///
/// `LibraryBook.bloomArgb` is packed `0xAARRGGBB` for the reason
/// `library_catalogue_local_data_source.dart` records — a data layer without
/// `material.dart` — and the carousel's card wash is built from that packed int
/// with the seal dimmer applied as **caller state** (`:285`,
/// `.bcard.sealed .bloom{opacity:.35}`). Routing that construction through
/// [homeCardWash] gives the whole screen one line where a colour is built from a
/// transcription, which is the line this file's exemption is pinned to.
library;

import 'package:flutter/material.dart';

/// The day's card's wash. `eva/redesign.html:519` — `rgba(228,87,214,.55)`,
/// packed `0xAARRGGBB`: `.55 → 140 = 0x8C`.
///
/// **A packed int and not a `Color`**, so this file's one construction is the
/// function below and the constants stay material-free data a test can read
/// beside the CSS it came from.
const int homeVotdWashArgb = 0x8CE457D6;

/// The last-light card's wash. `eva/redesign.html:524` —
/// `rgba(232,176,75,.35)`, packed: `.35 → 89 = 0x59`. The same hue
/// the design system's ember token publishes for `--gold`, at this card's own alpha.
const int homeLastLightWashArgb = 0x59E8B04B;

/// Builds the [Color] a `GlassSurface.bloomColor` paints.
///
/// The **one** colour construction in this file — `no_colour_literals_test.dart`
/// pins the count at exactly one, so a second wash added here has to arrive as a
/// decision in that test rather than as a line nobody read.
Color homeCardWash(int argb) => Color(argb);
