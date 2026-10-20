import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The app's toast — the prototype's `.toast`.
///
/// `eva/redesign.html:466-468`:
///
/// ```css
/// .toast{position:absolute;left:50%;bottom:110px;transform:translate(-50%,16px);
///   z-index:40;background:rgba(12,14,24,.95);border:1px solid rgba(232,176,75,.5);
///   color:var(--ink-0);font-family:var(--mono);font-size:10.5px;letter-spacing:.12em;
///   padding:10px 18px;border-radius:99px;opacity:0;transition:.35s var(--e-spring);
///   pointer-events:none}
/// .toast.show{opacity:1;transform:translate(-50%,0)}
/// ```
///
/// ## WHY IT IS IN THE **DESIGN SYSTEM** AND NOT IN A FEATURE
///
/// AGENT_CONTEXT §3's placement test, and this is a widget **three** features
/// read: the cheer on `/communion`, the restore on `/settings` and the selah's
/// amen on `/`. A feature-local copy is what
/// `communion_cheer_toast.dart` and `workshop_restore_toast.dart` were — two
/// implementations of one CSS rule, in two features, which is the duplication
/// this repository refuses wherever it finds it. §3's other rule — **no feature
/// may import another feature** — is what made the shared copy the only
/// possible home rather than a preference.
///
/// ## AND THE PAGE OWNS THE **CLOCK**, NOT THIS WIDGET
///
/// The prototype's `toast(m)` (`:1393`) shows the message for **1800 ms** and
/// then removes it. The clock is the **screen's** business and not the
/// drawing's: the screen knows when the event happened and when the screen is
/// disposed, and a widget that owned its own timer would have to be told to
/// stop. `settings_page.dart` records the same arrangement as a deliberate
/// departure from an earlier brief, and the reasoning is the one that matters:
/// splitting the message (the screen's) from the clock (the widget's) would
/// put the toast's state in **two owners** and would still leave the screen
/// stateful.
///
/// So this widget draws. The page raises it, times it, and takes it away.
///
/// ## AND THE **PLACEMENT** IS THE PAGE'S TOO
///
/// The prototype anchors the toast to the **screen root** — `:466`'s
/// `position:absolute;left:50%;bottom:110px` — with the element a direct child
/// of the screen (`:738`) and not of the scrolling list. `NeuralScaffold`'s
/// `overlay` slot is the viewport-fixed half of that, and `CommunionPage` and
/// `SettingsPage` place the toast there. A toast inside a page's own column
/// would scroll away with the content and would sit inside the scroll view's
/// box rather than the viewport's — a defect `/communion`'s suite measured and
/// recorded.
///
/// **`pointer-events:none` is the page's `IgnorePointer`, not this widget's.**
/// The prototype's rule ends `pointer-events:none` (`:466`), because a
/// confirmation is a **notice** and never a control: it must not take a tap
/// that belonged to the row under it. The caller wraps this widget in
/// `IgnorePointer` and leaves the semantics tree alone — the `liveRegion`
/// announcement is the point of the toast for a screen-reader user.
///
/// ## THE NUMBERS, AND WHICH OF THEM ARE THE PROTOTYPE'S
///
/// * `padding: 10px 18px` (`:467`) — the pill's own.
/// * `border-radius: 99px` (`:467`) — the pill.
/// * `border: 1px solid rgba(232,176,75,.5)` (`:466`) — the **gold** hairline,
///   which is the prototype's way of saying "this is the app speaking". The
///   gold is `EvaColors.ember`, §5.1's only accent.
/// * `font-family: var(--mono); font-size: 10.5px; letter-spacing: .12em`
///   (`:467`) — the type. **The `.12em` is premultiplied by the 10.5px**,
///   which is `1.26`, because the prototype's `em` is relative to the element's
///   own font and Flutter's `letterSpacing` is a logical-pixel advance. The
///   size is borrowed from [EvaSectionHeader.sectionSize] so the app has **one**
///   spelling of 10.5 and not three.
/// * `background: rgba(12,14,24,.95)` (`:466`) — **substituted**, and this is
///   the one number that is not the prototype's. The prototype's is a literal
///   near-black; this client has no token for it and `no_colour_literals_test`
///   refuses every colour in `lib/` that does not resolve through
///   `EvaColors`, so the fill is `surface` at **90%** — the glass tier's own
///   alpha, one step below the prototype's `.95`. The border, the radius, the
///   type and the size are all the prototype's; this one is recorded here
///   rather than left for a reader to compare against the CSS.
/// * `[dir=rtl] .toast{font-family:var(--ui-ar)}` (`:134`) — the Arabic arm
///   swaps the family, which is what [arabicAware] over the mono style
///   produces: JetBrainsMono under LTR, Amiri under RTL.
class EvaToast extends StatelessWidget {
  /// Creates the toast.
  const EvaToast({
    required this.message,
    this.leading,
    this.fontFamilyFallback,
    super.key,
  });

  /// The localized message.
  final String message;

  /// A painted mark **before** the message, or `null` for the message alone.
  ///
  /// The prototype types the `✦` into the cheer's own string (`:947`), and
  /// this client **paints** it instead, because U+2726 is in no bundled family
  /// — the same rule the quiz's score and the selah's glyph follow. So the
  /// cheer passes a [FourPointedStar] here and the string stays a string.
  ///
  /// The **gap** is the prototype's own: the painted star and the text are
  /// separated by the space character the prototype wrote, which is 8px here.
  final Widget? leading;

  /// The families to fall back to for glyphs the mono face does not carry.
  ///
  /// **The message's own business, and not the toast's**: the restore's `↺`
  /// (U+21BA) is in no bundled mono or scripture face, so that run carries a
  /// fallback and the toast does not know about it. `null` — the default — is
  /// the ordinary case, where the mono face carries every glyph.
  final List<String>? fontFamilyFallback;

  /// The gap between [leading] and the message.
  ///
  /// The prototype's own space character, at the toast's own 10.5px type.
  static const double leadingGap = 8;

  /// The toast's tracking, in `em`. `eva/redesign.html:467` —
  /// `letter-spacing:.12em`.
  ///
  /// **A NAMED EM VALUE AND NOT A PIXEL COUNT**, and the reason is the house
  /// rule: the prototype's `em` is relative to the element's own font, and
  /// Flutter's `letterSpacing` is a logical-pixel advance. So the number that
  /// reaches the widget is `size × trackingEm` — **1.26** at 10.5px — and the
  /// multiplication is written where it happens, so a change to the size
  /// cannot leave the tracking behind.
  static const double trackingEm = 0.12;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);
    final Widget? mark = leading;

    return Semantics(
      liveRegion: true,
      label: message,
      // **AND THE CHILD'S OWN SEMANTICS ARE EXCLUDED, because the message is
      // ALREADY THE LABEL.**
      //
      // A `Semantics(label: message)` wrapping a `Text(message)` announces the
      // message **twice** — once as the label and once as the text's own
      // semantics — and a screen-reader user is told the same sentence two
      // times. The fix is one flag, and it is the difference between a
      // confirmation and an echo.
      //
      // **This changed the migrated `/communion` toast's announcement**, and
      // that is the point: the migration was told to preserve the toast's
      // *appearance* and its *behaviour*, and a double announcement is a
      // **defect** in the announcement rather than a behaviour to preserve.
      // `/communion`'s two goldens are byte-identical through the change,
      // because semantics are not painted.
      excludeSemantics: true,
      child: Center(
        child: Container(
          // `:467` — `padding:10px 18px`.
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
          // **A ROW ONLY WHEN THERE IS A MARK.** The prototype's `.toast` is
          // one text node, and the cheer's `✦` is typed into its own string —
          // so the mark is a separate painted child here, and a toast with no
          // mark is the text alone. The two shapes are not interchangeable:
          // the row is what lets the mark and the message sit side by side
          // without the text taking the mark's width.
          child: mark == null
              ? _message(colors, direction)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    mark,
                    const SizedBox(width: leadingGap),
                    Flexible(child: _message(colors, direction)),
                  ],
                ),
        ),
      ),
    );
  }

  /// The message, in the prototype's own type.
  Widget _message(EvaColors colors, TextDirection direction) => Text(
    message,
    style: arabicAware(
      EvaTypography.monoCaps(colors).copyWith(
        // `:467` — `font-family:var(--mono);font-size:10.5px;
        // letter-spacing:.12em`. **The `.12em` is premultiplied by the
        // 10.5px**, which is `1.26` — the house rule, and the number is
        // written where it happens.
        //
        // **AND THE PROTOTYPE'S `.toast` IS NOT A `.mono` RUN**, so it is
        // not upper-cased and its tracking is not reset under RTL — the
        // `:135-136` rules reset the `.mono` **class** only, and the
        // prototype's toast is not written with it.
        //
        // **AND NEITHER NUMBER IS A LITERAL.** The size is borrowed from
        // [EvaSectionHeader.sectionSize] — the same 10.5 the group headers
        // and the version chip borrow — so the app has **one** spelling of
        // it, and the tracking is the em value multiplied by that size
        // rather than the product written out.
        fontSize: EvaSectionHeader.sectionSize,
        letterSpacing: EvaSectionHeader.sectionSize * EvaToast.trackingEm,
        color: colors.ink,
        fontFamilyFallback: fontFamilyFallback,
      ),
      direction,
    ),
  );
}
