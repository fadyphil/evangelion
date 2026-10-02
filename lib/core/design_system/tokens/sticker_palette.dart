import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// The seven decorative colour slots of the Eva sticker palette.
///
/// DECORATIVE ONLY, AND THE TYPE SAYS SO BY CONSTRUCTION. The palette was
/// originally keyed to a passage-category enum (sky / lavender / pink / coral /
/// teal / leaf / sun). That enum belonged to the library screen, which was cut
/// (AGENT_CONTEXT §2, decision 1) because the backend has no category endpoint.
/// So the slots survive as a closed vocabulary with no domain meaning
/// whatsoever: nothing under `core/domain/` may reference this type, and adding
/// a slot cannot smuggle a new category back in.
///
/// Consumers are chips, dots, and the celebration burst — the three places
/// `docs/plans/04-widget-inventory.md` reaches for colour that carries no
/// information. A slot must never be the *only* signal in a UI: an answer that
/// is "correct" is announced by the `ok` token plus an icon and a semantics
/// label (`09-quality-gates.md` §14, colour-only state).
enum StickerSlot {
  /// `sky` — `#7CC4F0`.
  sky,

  /// `lavender` — `#B79CF0`.
  lavender,

  /// `pink` — `#F58FC4`.
  pink,

  /// `coral` — `#F4836B`.
  coral,

  /// `teal` — `#4EC9BD`.
  teal,

  /// `leaf` — `#7FC96B`.
  leaf,

  /// `sun` — `#F5C84C`.
  sun,
}

/// The single source of truth for the sticker palette.
///
/// One palette, not two. `docs/plans/03-design-system.md` §5.1 gives the seven
/// hexes once, outside the dark/light tables, and gives no light variant — so
/// both [EvaColors.dark] and [EvaColors.light] point at these same colours
/// rather than at two near-identical maps that would drift. This is also why
/// this file exists separately from `eva_colors.dart`: it is the only part of
/// the colour system that is *not* per-brightness, and hiding that inside the
/// extension would invite a future author to "fix" it by forking the map.
@immutable
abstract final class EvaStickerPalette {
  /// Every slot mapped to its colour, keyed by the slot so a slot → colour read
  /// is a type-checked lookup rather than a free-floating hex.
  ///
  /// Unmodifiable. Both themes hold this one map, so a `copyWith` or a `lerp`
  /// that mutated it in place would repaint every surface in the app for the
  /// rest of the process — and the corruption would be invisible in a golden,
  /// which would merely be re-captured.
  static const Map<StickerSlot, Color> colors = <StickerSlot, Color>{
    StickerSlot.sky: Color(0xFF7CC4F0),
    StickerSlot.lavender: Color(0xFFB79CF0),
    StickerSlot.pink: Color(0xFFF58FC4),
    StickerSlot.coral: Color(0xFFF4836B),
    StickerSlot.teal: Color(0xFF4EC9BD),
    StickerSlot.leaf: Color(0xFF7FC96B),
    StickerSlot.sun: Color(0xFFF5C84C),
  };

  /// The colour for [slot], through an exhaustive switch.
  ///
  /// ## WHY THE SWITCH AND NOT `colors[slot]!`
  ///
  /// `colors[slot]!` is shorter and returns the same value for all seven slots
  /// today. The switch is what keeps returning the right value when there are
  /// eight: a new `StickerSlot` case is a **compile error** here until it names a
  /// colour, which is the only form of "every slot has a colour" the compiler can
  /// enforce. An index into a map can only be checked at run time, and only by
  /// whoever remembers to.
  ///
  /// ## WHY IT IS CALLED BY THE PRODUCTION CODE
  ///
  /// `EvaColors.lerp` reads its own endpoint through this method. That is the
  /// only caller, and it is what makes the completeness claim real: a wrong arm —
  /// `pink` returning `colors[StickerSlot.coral]` — is invisible to
  /// "every slot resolves to a distinct value", because the map is untouched and
  /// the duplicate it would create lives in the switch. It is caught only by a
  /// test that walks every slot through `of` and compares against the map, which
  /// is exactly what `sticker_palette_test.dart` does. With no caller and no such
  /// test, a wrong arm would have survived silently; the review that found this
  /// also measured 0/8 coverage on this method.
  static Color of(StickerSlot slot) => switch (slot) {
    StickerSlot.sky => colors[StickerSlot.sky]!,
    StickerSlot.lavender => colors[StickerSlot.lavender]!,
    StickerSlot.pink => colors[StickerSlot.pink]!,
    StickerSlot.coral => colors[StickerSlot.coral]!,
    StickerSlot.teal => colors[StickerSlot.teal]!,
    StickerSlot.leaf => colors[StickerSlot.leaf]!,
    StickerSlot.sun => colors[StickerSlot.sun]!,
  };
}
