import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The cheer confirmation toast (`eva/redesign.html:466-468`, `:1393`, D12).
///
/// Centred, bottom-anchored, leading painted [FourPointedStar], and announced with
/// `Semantics(liveRegion: true)`.
///
/// ## THE TYPE IS THE PROTOTYPE'S, AND THE FAMILY FOLLOWS THE ARM
///
/// `eva/redesign.html:467` — `font-family:var(--mono);font-size:10.5px;
/// letter-spacing:.12em` — so the toast is **mono at 10.5px**, not the UI sans
/// at 13.5px. Under RTL the prototype swaps the family for the Arabic UI face
/// (`:134` — `[dir=rtl] .toast{font-family:var(--ui-ar)}`), which is what
/// [arabicAware] over the mono style produces: JetBrainsMono under LTR, Amiri
/// under RTL.
///
/// The `✦` the prototype types at the front of the string (`:947`) is **painted**
/// here, because U+2726 is in no bundled family — the same rule Task 5.4
/// applied to the quiz's score.
class CommunionCheerToast extends StatelessWidget {
  /// Creates the cheer toast.
  const CommunionCheerToast({required this.message, super.key});

  /// The localized message (`cheer sent to {name}`).
  final String message;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(99),
            // The prototype's border is **gold**: `border:1px solid
            // rgba(232,176,75,.5)` (`:466`) — the same hairline the toast's
            // light-mode override keeps (`:109`). It is not a neutral glass
            // border, and the prototype's is the one that says "this is the
            // app speaking".
            border: Border.all(color: colors.ember.withValues(alpha: 0.5)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.ink.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FourPointedStar(size: 12, color: colors.emberInk),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: arabicAware(
                    EvaTypography.monoCaps(colors).copyWith(
                      // `eva/redesign.html:467` — 10.5px with `.12em` of
                      // tracking. The prototype's `.toast` is **not** a `.mono`
                      // run, so it is not upper-cased and its tracking is not
                      // reset under RTL (`:135-136` reset the `.mono` class
                      // only), and this keeps that.
                      fontSize: 10.5,
                      letterSpacing: 1.26,
                      color: colors.ink,
                    ),
                    direction,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
