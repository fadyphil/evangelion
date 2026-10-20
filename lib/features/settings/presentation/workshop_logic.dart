/// The Workshop's pure derivations, and the prototype's own untranslated literals.
///
/// ## WHY THIS FILE EXISTS, AND WHY IT IS **PURE DART**
///
/// AGENT_CONTEXT §6: "domain logic must not be buried inside a widget". The
/// Workshop's two derivations — the Daylight toggle's narrowing of a **three-state**
/// field to a **two-state** control, and the choice of the preview line's text — are
/// decisions, not layout, and a decision a reader cannot check is a decision nobody
/// made on purpose. They live here so a test can reach them without a widget tree.
///
/// **It is pure Dart on purpose.** Gate 1 holds `lib/core/domain/` and
/// `lib/features/*/domain/` Flutter-free, and this file is neither — it is under
/// `presentation/`, beside the screen that uses it. The purity is not a gate
/// requirement here; it is the reason the file can be read without a Flutter
/// context, and it is why the only import below is a `core/domain/` enum.
///
/// ## AND WHY IT IS **NOT** IN `features/settings/domain/`
///
/// That directory is "`this feature's own **use cases** only" (AGENT_CONTEXT §3), and
/// a use case is a thing a screen calls to do something. A narrowing and a literal
/// are neither, and `settings_clamps.dart`'s presence there is a **recorded
/// precedent** for widening it, not a licence to widen it again. This file stays in
/// `presentation/`, which is where the thing it describes lives.
///
/// ## AND WHY IT IS **NOT** IN `core/domain/`
///
/// §3's placement test: a type consumed by two or more features belongs in the
/// shared kernel. Nothing outside `/settings` reads any of this, so the shared
/// kernel is exactly the wrong home for it.
library;

import 'package:evangelion/core/domain/entities/app_theme_mode.dart';

// ---------------------------------------------------------------------------
// The Daylight toggle's narrowing.
// ---------------------------------------------------------------------------

/// Whether the Daylight switch is **on** for [mode].
///
/// ## THE NARROWING, AND WHY IT IS A NAMED FUNCTION
///
/// `UserSettings.themeMode` is a **three-state** enum — `light`, `dark` and
/// `system` — and the redesign's control is a **two-state** switch
/// (`eva/redesign.html:650`).
///
/// | stored | the switch shows |
/// | --- | --- |
/// | `light` | on |
/// | `dark` | off |
/// | `system` | **off** |
///
/// **`system` renders off, and the stored value is not changed until the reader
/// touches the control.** A reader who stored `system` keeps it — and keeps
/// following the OS — until they touch the switch, and touching it narrows the
/// choice to `light` or `dark` for good. The `system` arm of `AppThemeMode`
/// therefore becomes **unreachable from the UI**, and that product consequence is
/// recorded at the control (`SettingsCubit.setDaylight`'s own doc carries the
/// cubit's half of it).
///
/// **The writer is the cubit's, not this file's.** `SettingsCubit.setDaylight`
/// turns the switch's two positions into `AppThemeMode.light` and
/// `AppThemeMode.dark`; this function only answers the other question — what the
/// switch should *show* — and a second implementation of the write would be two
/// spellings of one mapping.
bool daylightOnFor(AppThemeMode mode) => mode == AppThemeMode.light;

// ---------------------------------------------------------------------------
// The preview line's text.
// ---------------------------------------------------------------------------

/// The preview line's English text. `eva/redesign.html:694` — the `.prevline`
/// element's own literal, and `:996` — the script that swaps it for the Arabic
/// one when the language changes.
const String kPreviewTextEnglish = 'The Lord is my shepherd…';

/// The preview line's Arabic text. `eva/redesign.html:996` —
/// `el('prevLine').textContent=lang==='ar'?'الرب راعي…':'The Lord is my shepherd…'`.
const String kPreviewTextArabic = 'الرب راعي…';

/// The preview line's text for the arm [isArabic] describes.
///
/// The prototype picks the arm's text in its own script at `:996`, and the client
/// does the same: the preview is a **scripture** line, so it is written in the
/// language the reader is reading.
///
/// ## WHY IT IS **NOT** AN ARB KEY
///
/// Because the prototype does not put it in its own `I18N` table — `:996` writes
/// both literals in a script, and the table at `:924-977` carries neither. The
/// seven other untranslated strings on this screen are widget literals for the
/// same reason, and `app_localizations_test.dart`'s `mustBeIdentical` set is the
/// gate that catches an untranslated string: a key whose two arms are identical
/// would have to join that set, and weakening it for a scripture line is a bad
/// trade.
String previewTextFor({required bool isArabic}) =>
    isArabic ? kPreviewTextArabic : kPreviewTextEnglish;

// ---------------------------------------------------------------------------
// The Star shape segment's labels — the prototype's own untranslated English.
// ---------------------------------------------------------------------------

/// The Star shape segment's first label. `eva/redesign.html:673` — `dot`.
const String kStarShapeDot = 'dot';

/// The Star shape segment's second label. `eva/redesign.html:673` — `star`.
const String kStarShapeStar = 'star';

/// The Star shape segment's third label. `eva/redesign.html:673` — `cross`.
const String kStarShapeCross = 'cross';

/// The Star shape segment's fourth label. `eva/redesign.html:673` — `gem`.
///
/// **The prototype's class name is `s-diamond` and its label is `gem`.** The class
/// name reaches the geometry — `SkyStarShape` is the geometry's name — and the
/// label reaches the reader, and the two are allowed to differ because they answer
/// different questions.
const String kStarShapeGem = 'gem';

/// The four Star shape labels, in `SkyStarShape`'s order.
///
/// **A widget literal list, and NOT an ARB key.** `eva/redesign.html:673` carries
/// **no `data-i18n`** on any of its four buttons, so the prototype's own strings
/// are untranslated English and the orchestrator's decision keeps them that way.
/// Putting them in the ARB would force them into `app_localizations_test.dart`'s
/// `mustBeIdentical` set, and that set is the gate that catches an untranslated
/// string — weakening it for seven words is a bad trade.
///
/// **This list is what the Arabic typography gate declares**, as the runs they
/// render: the seven are the four above and the three below.
const List<String> kStarShapeLabels = <String>[
  kStarShapeDot,
  kStarShapeStar,
  kStarShapeCross,
  kStarShapeGem,
];

// ---------------------------------------------------------------------------
// The Star field segment's labels — the prototype's own untranslated English.
// ---------------------------------------------------------------------------

/// The Star field segment's first label. `eva/redesign.html:678` — `crown`.
const String kStarFieldCrown = 'crown';

/// The Star field segment's second label. `eva/redesign.html:678` — `high`.
const String kStarFieldHigh = 'high';

/// The Star field segment's third label. `eva/redesign.html:678` — `full`.
const String kStarFieldFull = 'full';

/// The three Star field labels, in `SkyStarField`'s order.
///
/// Widget literals, for [kStarShapeLabels]' reason: `eva/redesign.html:678`
/// carries no `data-i18n` either.
const List<String> kStarFieldLabels = <String>[
  kStarFieldCrown,
  kStarFieldHigh,
  kStarFieldFull,
];

// ---------------------------------------------------------------------------
// The restore action.
// ---------------------------------------------------------------------------

/// The restore row's glyph. `eva/redesign.html:695` — `<span class="ar">↺</span>`.
///
/// **U+21BA, and it is in NO bundled mono or scripture face.** Measured against the
/// twenty shipped `.ttf` files: absent from `JetBrainsMono` (the `--mono` face),
/// absent from `EBGaramond` (the `--scr` face) and absent from `Amiri`; present
/// in `Inter` (the `--ui` face) and in `IBMPlexSansArabic` (the `--ui-ar` face).
/// It is therefore painted with a `fontFamilyFallback` to `Inter`, and Flutter
/// falls back **per glyph** — so the mono face draws the letters and Inter draws
/// the arrow, and the prototype's `font-family:var(--mono)` survives for everything
/// else.
///
/// **Not a Material icon.** The glyph exists in a bundled face, and painting it
/// as an icon would be a second answer to a question that already has one.
const String kRestoreGlyph = '↺';

/// How long the restore confirmation stays up. `eva/redesign.html:1393` —
/// `setTimeout(()=>t.classList.remove('show'),1800)`.
const Duration kRestoreToastDuration = Duration(milliseconds: 1800);

// ---------------------------------------------------------------------------
// The About group's two values.
// ---------------------------------------------------------------------------

/// The Shaders row's value. `eva/redesign.html:697` — `aurora.frag v8`.
///
/// **The prototype's own literal, and it names the design system's shader asset
/// rather than this client's.** The client's shader program is `kLumenShaderAsset`
/// (`lumen_program.dart`) and it is **not mounted** (the ten light-workshop
/// controls persist their choices and the client renders none of them), so the row
/// reports the prototype's version and the screen's own group header says so.
const String kShadersVersion = 'aurora.frag v8';

/// The Tokens row's value. `eva/redesign.html:698` — `lumen v1.2`.
///
/// The design system's version, for [kShadersVersion]'s reason.
const String kTokensVersion = 'lumen v1.2';
