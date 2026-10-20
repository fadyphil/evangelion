import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The confirmation toast the restore action raises.
///
/// `eva/redesign.html:975` — `restored:["↺ nocturne defaults restored","↺
/// استُعيدت الافتراضيات"]` — raised by the reset handler at `:1525` and shown for
/// **1800ms** by `:1393`'s `toast(m)`.
///
/// ## IT DELEGATES TO THE **SHARED** TOAST, AND IT USED TO BE A SECOND COPY
///
/// This file used to carry a **complete second implementation** of the
/// prototype's `.toast` — the same pill, the same mono 10.5px with `.12em` of
/// tracking (`:466-467`), the same gold hairline, the same
/// `Semantics(liveRegion: true)`. So did
/// `features/leaderboard/presentation/widgets/communion_cheer_toast.dart`, and
/// the home page's amen toast was a third thing that did not exist yet.
///
/// **Two implementations of one CSS rule, in two features, is the duplication
/// this repository refuses wherever it finds it** — and §3's rule that **no
/// feature may import another feature** is what made the shared copy the only
/// possible home rather than a preference. So the drawing is
/// `core/design_system/widgets/eva_toast.dart`'s now, and this class is the
/// **screen's** half of it: the message, and the one thing that is genuinely
/// the restore's own — the `↺`'s fallback.
///
/// **The golden is byte-identical**, because the two implementations drew the
/// same pill with the same numbers, and §5.2's rule that the app has **one**
/// spelling of 10.5 was already honoured by both.
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
///
/// **It is a PARAMETER of the shared toast and not a rule inside it**, because
/// the glyph is the **message's** business and not the toast's: the cheer
/// paints a star and the restore carries an arrow, and neither is the toast's
/// to know about.
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
  Widget build(BuildContext context) => EvaToast(
    message: message,
    // The arrow's fallback. See the class doc.
    fontFamilyFallback: const <String>[EvaTypography.uiFamily],
  );
}
