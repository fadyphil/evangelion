# Source Analysis & Defects

What the prototype actually is, what is broken in it, and how each defect gets fixed.

**Contains §1 §2 §12** of the original plan. Section numbers are preserved so existing cross-references keep resolving.

> [Index](README.md) · [Architecture](02-architecture.md) · [Widget inventory](04-widget-inventory.md) · [Authority](../agents/AGENT_CONTEXT.md)

---

> **What this file describes, and what it does not.** The React prototype in `eva/` **still exists and is unchanged**, so every observation below is accurate and stays as written. This file describes the prototype **as built** — it is a record of what was shipped in React, not a statement of what the Flutter app should contain. Current scope is six screens with Library and Profile cut, against a live API, and that lives in [AGENT_CONTEXT](../agents/AGENT_CONTEXT.md), which overrides this file. Where a defect below was **resolved by cut** rather than by a fix, its row and its Phase cell say so.

---

## 1. Source analysis

`eva/` is a **Figma Make React prototype** — a design reference, not portable source. Structure:

| File | Role |
| --- | --- |
| `src/main.tsx` | Entrypoint, wraps app in `ThemeProvider` |
| `src/App.tsx` | 390×844 phone frame + dev-only screen switcher (8 chips) + theme toggle |
| `src/contexts/theme.tsx` | `isDark: bool` + `toggle()`, writes `data-theme` on `<html>` |
| `src/components/ds.tsx` | 570 lines — "Evangelion DS": tokens + 13 widgets + 5 helpers |
| `src/screens/*.tsx` | 8 screens, 1:1 with the 8 Figma frames |
| `src/index.css` | CSS vars for both themes, 6 keyframe animations, Google Fonts import |

### 1.1 The prototype ships 13 widgets, and 6 more declared inside screens

> **Cut.** One of the 13 — `PassageCard` — has no successor in the app. The library was cut ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, decision 1), and with it `PassageCard`'s grid, `CategoryFilterBar`, the 7-category chip row, `ContinueReadingPanel`, and `EvaProgressBar`. `CategoryChip` survives, but as the theme toggle, the route chips, and the FAB dock items — its category-filtering role is gone. `JourneyTimeline` and `JourneyRow` went with the profile screen. The prototype itself is unchanged, so all of them still count as duplication the port had to face; they simply never ship.

`ds.tsx` exports **13** widgets — `NeuralBackground`, `ButtonPrimary`, `ButtonSecondary`, `ButtonText`, `Input`, `CategoryChip`, `ProgressBeads`, **`PassageCard` (cut)**, `QuizOption`, `StatTile`, `SettingsTile`, `TopBar`, `SealFAB` — plus 5 non-widget exports: `T` (token strings), `HEX`, `useHex()`, `rgba()`, `F` (font map). `ORB_CONFIGS` is module-private.

Screens declare **6** more components locally, none of them exported:

| Component | Declared at |
| --- | --- |
| `GoogleIcon` | `screens/LoginScreen.tsx:104` |
| `AppleIcon` | `screens/LoginScreen.tsx:115` |
| `GoldFleck` | `screens/QuizScreen.tsx:12` |
| `SunBurst` | `screens/ResultScreen.tsx:4` |
| `Toggle` | `screens/SettingsScreen.tsx:14` |
| `SectionLabel` | `screens/SettingsScreen.tsx:28` |

That accounts for 19 named components. The larger duplication is *unnamed* — repeated inline style blocks with no component boundary at all: the 44px back buttons, the sticky CTA, the Home hero, the category filter bar, the feedback banner, the journey rows. Those are the 13 patterns inventoried in [[04-widget-inventory.md](04-widget-inventory.md) §3](04-widget-inventory.md#3-duplication-inventory), which is where most of the extraction work is.

### 1.2 Brief vs. built code diverge sharply

The brief mandates warm paper `#FBF7EF`, **Nunito** for UI, flat hairline cards, and bans gradients, blur/glass, and glows outright. The generated code went dark glassmorphic: canvas `#05081A`, **DM Sans**, 10 copies of `backdropFilter`, `0 0 80px` glows, and a full `NeuralBackground` (aurora gradients, hue-rotate orbs, noise grain) that appears nowhere in the brief.

This plan ports the built code. Two consequences to carry forward:

- The `NeuralBackground` is **load-bearing**, not decoration to be deleted. It is the app's identity and must be ported faithfully — but it is also the single worst performance offender ([09-quality-gates.md](09-quality-gates.md) §13).
- The prototype's Arabic `Space Mono` bug (#2) is a direct consequence of the token table not matching the actual rendered text. The port must validate font/glyph coverage per script.

### 1.3 Two source-of-truth problems in the token system

`HEX` (`ds.tsx:32-43`) and the CSS vars (`index.css:6-37`) hold the same 24 values, maintained twice. `T` returns `var(--x)` strings, so the only way to derive an alpha variant is `useHex()` + `rgba(hex, a)` string concatenation. Every primitive therefore calls `useTheme()` *and* `useHex()` — two context lookups per widget, and consumers must remember which accessor to use.

**Resolution:** one `ThemeExtension<EvaColors>` per theme. `context.colors.ember` is a real `Color`, so `.withValues(alpha: 0.14)` replaces the `rgba()` hack outright. One lookup, compile-time safety, no string parsing.

---

## 2. Verified defects and their fixes

Every row below was confirmed by reading the source or by grep against `eva/src`. Defect, evidence, impact, **and** the phase that resolves it are kept in one table on purpose — an earlier draft of this plan split them across two sections, which meant reading one to learn a defect existed and the other to learn what to do about it.

| # | Defect | Evidence | Impact | Phase | Concrete fix |
| --- | --- | --- | --- | --- | --- |
| 1 | **Category filter is a no-op.** `cat` state only drives chip highlight; the 4 grid cards are hardcoded literals. | `HomeScreen.tsx:12,86,93-96` | Core feature appears to work, does nothing | — | **Resolved by cut, not by fix.** The filter, its chip row, and the card grid all went with the library; there is no filter left to make work. |
| 2 | **Arabic rendered in Space Mono.** Space Mono has no Arabic glyphs → tofu boxes. | `ReadingArScreen.tsx:35,49,51,56,58,63,68,70,86` — **nine** sites, not two: the metadata row (`:35`), the CTA caption (`:86`) and the seven `<sup>` verse markers (`:49`–`:70`). **That is the floor, not the ceiling:** the prototype's four top controls carry **no label at all**, so §14's accessible-name requirement added **three more** Arabic sites that exist only in this client. | Broken RTL screen | 7 | `ScriptureLanguage.ar` maps to `EvaTypography.arabic` everywhere, so every one of the nine renders in Amiri. The three invented tooltip strings were the ones this missed: `IconActionButton`'s `Tooltip` carried **no `textStyle`**, so Flutter resolved it to `bodyMedium` — **DM Sans** — and thirty tofu boxes shipped. It has a required `tooltipFamily` now, and `reading_glyph_test.dart` **paints** each tooltip before it enumerates, so the gate's claim is narrower than it was: it asserts every character **in the tree it walks, which now includes the tooltips**, and `renderedRuns` is `Future`-returning because a `Tooltip` paints nothing until a gesture. `ds.tsx:298` and `:341` are the two `F.mono` sites in `ds.tsx`; `:341` writes `letterSpacing: '0.10em'` — the **Arabic** tracking value — so calling it "English-only" was an assumption, and `EvaChip` still takes no language parameter, so neither is asserted as safe. |
| 3 | **`NeuralBackground` calls `setMouse` every frame** via a `requestAnimationFrame` loop that never idles. | `ds.tsx:143-148` | Permanent 60fps React re-render of the whole background subtree | 2 | `NeuralBackground` is a `CustomPaint` driven by `AnimationController`s inside a `RepaintBoundary`; zero `setState` |
| 4 | **7 of 12 design tokens are dead.** `T.surface`, `T.raised`, `T.line`, `T.ember`, `T.emberDeep`, `T.onEmber`, `T.ok` all have **0** usages; everything reads `HEX.*` instead. | grep: `T.surface:0 T.raised:0 T.line:0 T.ember:0 T.emberDeep:0 T.onEmber:0 T.ok:0` | Token drift; `T` is half-vestigial | 1 | All 12 tokens defined and every one consumed by at least one widget |
| 5 | **Dual source of truth** for 24 hex values. | `ds.tsx:32-43` vs `index.css:6-37` | Silent divergence risk | 1 | Single `EvaColors` definition; delete `HEX`, `useHex`, `rgba`, and the `T` map |
| 6 | **`--orb-opacity` / `--aurora-opacity` declared then ignored.** | `index.css:18-19,35-36` vs `ds.tsx:159` | Dead config | 1–2 | Read both from `EvaColors`; remove the hardcoded `0.55 / 0.16` |
| 7 | **FAB "Language" item silently does nothing.** `screen: null` → closes the dock, navigates nowhere. | `ds.tsx:540,546` | Dead-end UI | 9 | `FabDockItem` takes `onPressed`; the Language item opens a real language sheet |
| 8 | **`Input` is `readOnly` and uncontrolled** — no `value`, `onChanged`, or `onSubmitted`. | `ds.tsx:303` | Login form is non-functional | 5 | `EvaTextField` is a real `TextField` with a `TextEditingController` |
| 9 | **`minHeight: 844` hardcoded in 9 places.** | 9 occurrences across 8 screens | Breaks on every real device (SE, foldables, tablets) | 5–6 | `NeuralScaffold` uses `SafeArea` + `LayoutBuilder`; no fixed height anywhere. The app is also edge-to-edge — `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` in `main()`, with `AnnotatedRegion<SystemUiOverlayStyle>` per `NeuralScaffold` so status-bar icons invert with the theme. The prototype's immersive full-bleed background depends on this. |
| 10 | **Login states are baked in.** Email focus and password error are literals, not state. | `LoginScreen.tsx:49-52` | Error handling unreachable | 5 | Email focus and password error are `LoginBloc` state, not literals |
| 11 | **`TopBar` hardcodes** streak `12`, avatar `MK`, wordmark `Evangelion`. | `ds.tsx:507,516,525` | Not data-driven | 6 | `AppTopBar` takes wordmark, streak, and initials as required params |
| 12 | **Dev scaffolding ships as UI.** `App.tsx` screen switcher + `QuizScreen` "Frame A/B" toggle exist only to let the Figma agent preview states. | `App.tsx:70-84`, `QuizScreen.tsx:56-63` | Must not be ported | 8–9 | Do not port `App.tsx`'s switcher or `QuizScreen`'s Frame A/B toggle. If a debug overlay is wanted, gate it behind `kDebugMode` |

**Root causes, not 12 independent bugs.** Defects 8, 10, and 11 are all one cause — the prototype has no state layer, so anything with state is a literal. (Defect 1 was a fourth member of this cluster and no longer needs fixing; it was cut.) The BLoC layer fixes the survivors by construction. Defects 3, 4, 5, and 6 are likewise one cause: no design-system layer, so tokens are duplicated and derivations are ad hoc. The `ThemeExtension` fixes all four. That is why Phase 1 and Phase 5 are load-bearing, and why jumping straight to screens would reintroduce the whole list.

> **Cut.** Only defect **#1** is resolved by cut. The constructs behind it — `CategoryFilterBar`, `PassageCard`, the category chip row, `ContinueReadingPanel`, `EvaProgressBar` — and the profile screen's `JourneyTimeline` never had defect rows of their own; they were duplication, not breakage. Every other row describes something that still ships, and every other Phase number still resolves in [08-build-phases.md](08-build-phases.md): the phase numbers are pre-cut and were deliberately not renumbered.

**Phase numbers** refer to [08-build-phases.md](08-build-phases.md).
