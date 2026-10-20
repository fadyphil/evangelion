import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The confirmation toast the restore action raises.
///
/// `eva/redesign.html:975` — `restored:["↺ nocturne defaults restored","↺
/// استُعيدت الافتراضيات"]` — raised by the reset handler at `:1525` and shown for
/// **1800ms** by `:1393`'s `toast(m)`.
///
/// ## IT IS A **FEATURE-LOCAL** WIDGET, AND `/communion`'s IS ITS SIBLING
///
/// `features/leaderboard/presentation/widgets/communion_cheer_toast.dart` is the
/// same shape for the same prototype rule: the same pill, the same mono 10.5px
/// with `.12em` of tracking (`:466-467`), the same gold hairline, and the same
/// `Semantics(liveRegion: true)`.
///
/// **Not a design-system widget**, because it has one caller: §3's placement test
/// puts a widget two features read in the shared kernel, and a widget one feature
/// reads in that feature.
///
/// ## THE `↺` AND ITS `fontFamilyFallback`
///
/// The message carries U+21BA, and that glyph is in **no** bundled mono or
/// scripture face — measured against the twenty shipped `.ttf` files: absent from
/// `JetBrainsMono`, absent from `EBGaramond` and absent from `Amiri`; present in
/// `Inter` and in `IBMPlexSansArabic`.
///
/// So the run carries a `fontFamilyFallback` to `Inter`, and Flutter falls back
/// **per glyph**: the mono face draws the letters and Inter draws the arrow, and
/// the prototype's `font-family:var(--mono)` survives for everything else. The
/// fallback is what makes the row's own `↺` paintable too, and it is the same
/// reason there.
class WorkshopRestoreToast extends StatelessWidget {
  /// Creates the toast.
  const WorkshopRestoreToast({required this.message, super.key});

  /// The localized message.
  final String message;

  /// The toast's tracking, in `em`. `eva/redesign.html:467` —
  /// `letter-spacing:.12em`.
  ///
  /// **A NAMED EM VALUE AND NOT A PIXEL COUNT**, and the reason is the house
  /// rule: the prototype's `em` is relative to the element's own font, and
  /// Flutter's `letterSpacing` is a logical-pixel advance. So the number that
  /// reaches the widget is `sectionSize × trackingEm` — **1.26** at 10.5px —
  /// and the multiplication is written where it happens, so a change to the
  /// size cannot leave the tracking behind.
  ///
  /// **AND THE SIZE ITSELF IS BORROWED**, from
  /// [EvaSectionHeader.sectionSize], so the app has one spelling of 10.5 and
  /// not three: the group headers, the version chip and this toast all take it.
  static const double trackingEm = 0.12;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Container(
          // `:467` — `padding:10px 18px`.
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(99),
            // `:466` — `border:1px solid rgba(232,176,75,.5)`, the same gold
            // hairline `/communion`'s toast carries.
            border: Border.all(color: colors.ember.withValues(alpha: 0.5)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.ink.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: arabicAware(
              EvaTypography.monoCaps(colors).copyWith(
                // `:467` — `font-family:var(--mono);font-size:10.5px;
                // letter-spacing:.12em`. **The `.12em` is premultiplied by the
                // 10.5px**, which is `1.26` — the house rule, and the same number
                // `/communion`'s toast uses.
                //
                // **AND NEITHER NUMBER IS A LITERAL.** The size is borrowed from
                // [EvaSectionHeader.sectionSize] — the same 10.5 this screen's
                // version chip borrows — so the app has **one** spelling of it
                // and not three, and the tracking is the em value multiplied by
                // that size rather than the product written out, so a change to
                // the size cannot leave the tracking behind.
                fontSize: EvaSectionHeader.sectionSize,
                letterSpacing:
                    EvaSectionHeader.sectionSize *
                    WorkshopRestoreToast.trackingEm,
                color: colors.ink,
                // The arrow's fallback. See the class doc.
                fontFamilyFallback: const <String>[EvaTypography.uiFamily],
              ),
              direction,
            ),
          ),
        ),
      ),
    );
  }
}
