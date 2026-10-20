import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The cheer confirmation toast (`eva/redesign.html:466-468`, `:1393`, D12).
///
/// Centred, bottom-anchored, leading painted [FourPointedStar], and announced with
/// `Semantics(liveRegion: true)`.
///
/// ## IT IS THE **SHARED** TOAST, WITH A MARK IN FRONT OF IT
///
/// The prototype's `.toast` is one CSS rule, and this client now has **one**
/// implementation of it: `EvaToast` in the design system, which is where §3's
/// placement test puts a widget three features read — the cheer here, the
/// restore on `/settings` and the selah's amen on `/`.
///
/// This class is what is left of the feature-local copy: the **mark** in front
/// of the message, which is this toast's own business and the shared widget's
/// `leading` slot. Everything else — the pill, the type, the hairline, the
/// announcement — is `EvaToast`'s, and the two goldens in
/// `test/features/leaderboard/presentation/goldens/` are what prove the
/// delegation changed no pixel.
///
/// ## THE TYPE IS THE PROTOTYPE'S, AND THE FAMILY FOLLOWS THE ARM
///
/// `eva/redesign.html:467` — `font-family:var(--mono);font-size:10.5px;
/// letter-spacing:.12em` — so the toast is **mono at 10.5px**, not the UI sans
/// at 13.5px. Under RTL the prototype swaps the family for the Arabic UI face
/// (`:134` — `[dir=rtl] .toast{font-family:var(--ui-ar)}`), which is what the
/// shared widget's `arabicAware` over the mono style produces: JetBrainsMono
/// under LTR, Amiri under RTL.
///
/// The `✦` the prototype types at the front of the string (`:947`) is **painted**
/// here, because U+2726 is in no bundled family — the same rule Task 5.4
/// applied to the quiz's score. It is the one thing this class still owns.
class CommunionCheerToast extends StatelessWidget {
  /// Creates the cheer toast.
  const CommunionCheerToast({required this.message, super.key});

  /// The localized message (`cheer sent to {name}`).
  final String message;

  /// The painted mark's size.
  ///
  /// The prototype types the `✦` into the message, so it has no size of its
  /// own — it is a character in a 10.5px run. Painted, it needs one, and this
  /// is the one the golden recorded.
  static const double markSize = 12;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;

    return EvaToast(
      message: message,
      leading: FourPointedStar(size: markSize, color: colors.emberInk),
    );
  }
}
