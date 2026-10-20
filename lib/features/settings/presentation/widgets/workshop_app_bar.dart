/// The Workshop's app bar — `eva/redesign.html:639-643`.
///
/// ```html
/// <div class="appbar"><div class="abrow">
///   <button class="chev" data-back="journey">‹</button>
///   <span class="ttl" data-i18n="workshop">The Workshop</span>
///   <span class="mono">v1.2</span>
/// </div></div>
/// ```
///
/// ## THE THREE PARTS, AND WHERE EACH ONE'S NUMBERS COME FROM
///
/// | part | prototype | here |
/// | --- | --- | --- |
/// | the bar's padding | `46px 18px 4px` (`:142`) | the same three numbers |
/// | the row | `min-height:34px`, `gap:10px` (`:143`) | the chevron and the chip at its two ends |
/// | the title | absolutely centred, `max-width:52%`, 15px/600/`-.01em` (`:144-145`) | a `Stack` with the title in the middle |
/// | the chevron | 16px, `--ink-1`, `--ink-0` on hover (`:149-150`) | `IconActionButton` with `iconSize: 16` |
/// | the version chip | `.mono` (`:642`, `:30`) | the app's **real** version |
///
/// ## THE TITLE IS **CENTRED**, AND IT IS A **15px UI-SANS** TITLE
///
/// This is a real change to the header the Phase-9 screen shipped, and both halves
/// of it come from the prototype: `:144-145` positions the title absolutely at
/// `left:50%` with `transform:translate(-50%,-50%)` and caps it at `52%` of the
/// bar's width, and the title inherits `body`'s `--ui` face (`:22`) at 15px.
///
/// The Phase-9 header drew a 26px display-serif title beside the chevron, which
/// is the superseded React prototype's header and **not this one**: the
/// redesign's title is the centred 15px UI-sans `.ttl`
/// (`eva/redesign.html:144-145`), and the 26px display-serif beside the chevron
/// has no counterpart there.
///
/// ## AND THE CHEVRON **MIRRORS FOR FREE**
///
/// `eva/redesign.html:139` is `[dir=rtl] .chev{transform:scaleX(-1)}`, and
/// `Icons.arrow_back_ios_new` is declared `matchTextDirection: true` in the SDK,
/// so the ambient RTL points it rightwards — which is the prototype's `<button>`
/// under the same `direction: rtl` its root inherits, and no second icon has to
/// be chosen.
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The Workshop's app bar.
class WorkshopAppBar extends StatelessWidget {
  /// Creates the app bar.
  const WorkshopAppBar({super.key});

  /// The bar's padding. `eva/redesign.html:142` — `padding:46px 18px 4px`.
  ///
  /// **The three numbers are the prototype's**, and none of them is a token: 46 is
  /// not on the 4px scale, 18 is not either, and 4 is [EvaSpacing.xs]. They are
  /// transcribed rather than rounded, because this bar's top padding is what
  /// clears the status bar and a rounded 48 would move the whole screen down by
  /// two pixels for no reason a reader could name.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 46, 18, 4);

  /// The row's minimum height. `eva/redesign.html:143` — `min-height:34px`.
  ///
  /// **The row is taller than this in practice**, and the reason is the tap
  /// target: `IconActionButton` is a 44×44 box (§14's floor), so the row is 44
  /// tall rather than the prototype's 34. Recorded here rather than shrunk, for
  /// the reason `EvaToggle`'s own doc gives: a control that looks 26 wide and
  /// answers to 44 is correct, and one that answers to 26 is not.
  static const double minHeight = 34;

  /// The row's gap. `eva/redesign.html:143` — `gap:10px`.
  ///
  /// **Not load-bearing here**, and it is named anyway: the title is positioned
  /// absolutely and the row holds the chevron and the chip at its two ends, so
  /// the two are already 44 and about 60 pixels apart. The number is the
  /// prototype's, and a reader comparing the two bars should find it here.
  static const double gap = 10;

  /// The title's maximum width, as a fraction of the bar's. `eva/redesign.html:145`
  /// — `max-width:52%`.
  ///
  /// **A fraction and not a pixel number**, because the prototype's is a
  /// percentage of the bar and the bar is the viewport's width. The arithmetic
  /// that depends on it is in `WorkshopSegmentRow`'s doc.
  static const double titleWidthFactor = 0.52;

  /// The title's size. `eva/redesign.html:145` — `font-size:15px`.
  static const double titleSize = 15;

  /// The title's tracking. `eva/redesign.html:145` — `letter-spacing:-.01em`.
  ///
  /// **The em value premultiplied by the size**, which is the house rule: Flutter's
  /// `letterSpacing` is a logical-pixel advance and CSS's is relative to the
  /// element's own font. `-0.01em` at 15px is **-0.15**.
  static const double titleTracking = -0.01;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final TextDirection direction = Directionality.of(context);

    return Padding(
      padding: WorkshopAppBar.padding,
      child: Stack(
        children: <Widget>[
          // ## THE ROW IS THE **FIRST** CHILD, AND THE ORDER IS THE PAINT ORDER
          //
          // The prototype's `.ttl` is `position:absolute`, so it paints above the
          // two in-flow siblings whatever the DOM order. A `Stack` paints its
          // children in list order, last on top, so the title has to come second.
          // ## THE ROW'S **MINIMUM HEIGHT** IS THE PROTOTYPE'S
          //
          // `:143` — `.abrow{…;min-height:34px}`. The row's content is the
          // chevron (a 44×44 `IconActionButton` tap target) and the chip, so
          // the floor is never the binding constraint in practice — **which is
          // exactly why it is named and used rather than published and
          // unread.** A published constant with no reader is the token-table
          // bloat `settings_tile.dart:219-227` declines, and a constant that
          // is read once to check a number is worth a name and a citation.
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: WorkshopAppBar.minHeight,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // `:143` — `gap:10px`. Flutter's `Row` has carried `spacing` since
              // 3.27 and it is CSS's `gap` exactly: the **minimum** space between
              // the flex items, which is what `space-between` leaves to the
              // container's own slack.
              //
              // **AND THE CONSTANT IS NAMED FOR IT.** `gap` was published and
              // unread, which is the token-table bloat `settings_tile.dart:219-227`
              // declines; naming it and then not using it would have been the same
              // thing twice.
              spacing: WorkshopAppBar.gap,
              children: <Widget>[
                IconActionButton(
                  // **`Icons.arrow_back_ios_new` and not `Icons.chevron_left`**,
                  // for the reason the Phase-9 header gave: the prototype's is a
                  // *chevron* and Material's `arrow_back` is an arrow.
                  icon: Icons.arrow_back_ios_new,
                  // `:149` — `font-size:16px`.
                  iconSize: 16,
                  tooltip: strings.settingsBack,
                  // The tooltip is Arabic on the Arabic arm, which is
                  // `IconActionButton.tooltipFamily`'s reason for being required.
                  tooltipFamily: arabicAwareFamily(
                    direction,
                    EvaTypography.uiFamily,
                  ),
                  // **`maybePop`, not a push of `/journey`.** The prototype's
                  // chevron carries `data-back="journey"` (`:640`) and pushes the
                  // journey; this client pops the route stack, so the reader goes
                  // back to wherever they came from. **Recorded as a divergence
                  // from `:640`.**
                  onPressed: () => unawaited(context.router.maybePop()),
                ),
                const _VersionChip(),
              ],
            ),
          ),
          // ## THE TITLE, ABSOLUTELY CENTRED
          //
          // `Positioned.fill` + `Center` + `FractionallySizedBox` is the Flutter
          // spelling of `position:absolute;left:50%;transform:translate(-50%,-50%)`
          // with a `max-width`, and the three together are what make the title
          // **centred on the bar** rather than centred on the space between the
          // chevron and the chip — which is a different centre, and a visibly
          // wrong one, because the chip is wider than the chevron.
          Positioned.fill(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: WorkshopAppBar.titleWidthFactor,
                child: Text(
                  strings.settingsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: arabicAware(
                    // The **UI sans**, and not the display serif: the prototype's
                    // `.ttl` declares no family, so it inherits `body`'s `--ui`
                    // (`:22`).
                    Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: WorkshopAppBar.titleSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing:
                          WorkshopAppBar.titleSize *
                          WorkshopAppBar.titleTracking,
                      color: context.colors.ink,
                    ),
                    direction,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app bar's version chip.
///
/// `eva/redesign.html:642` — `<span class="mono">v1.2</span>`.
///
/// ## IT CARRIES THE APP'S **REAL** VERSION, AND THAT IS THE DIVERGENCE
///
/// The prototype's chip states the **design system's** version — `v1.2`, the same
/// string the About group's "Tokens" row carries (`:698`). This client states the
/// **app's** version, which is `AppConfig.appVersion` (`pubspec.yaml`'s own
/// `version:` with a build suffix).
///
/// **Why:** a reader looking at a version chip wants the version of the app they
/// are holding. A chip that named the design system's release would answer a
/// question nobody asked.
///
/// **And it is `AppConfig.appVersion` and not an ARB key**, because it is not
/// prose: it is a build number, and putting it in `app_en.arb` would make it a
/// number a translator could edit and nothing would check. The settings suite
/// parses `pubspec.yaml` and asserts that the two agree.
class _VersionChip extends StatelessWidget {
  const _VersionChip();

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final TextDirection direction = Directionality.of(context);

    return Semantics(
      // `settingsVersion` is **the chip's accessible name** — the ARB key's own
      // description says so.
      label: context.l10n.settingsVersion,
      excludeSemantics: true,
      child: Text(
        AppConfig.appVersion,
        style: arabicAware(
          EvaTypography.monoCaps(colors).copyWith(
            // ## THE `.mono` GEOMETRY, AND WHY THE NUMBERS ARE BORROWED
            //
            // `eva/redesign.html:642` puts the chip in the `.mono` class, and
            // `:30` is that class: `font-size:10.5px;letter-spacing:.16em`.
            // `EvaSectionHeader` already names those two numbers for the very
            // same class — its own `section` variant is a `.mono` run — so
            // borrowing them keeps **one** spelling of 10.5 and of 0.16 in the
            // app instead of two.
            fontSize: EvaSectionHeader.sectionSize,
            // ## THE `em` IS **PREMULTIPLIED**, AND THAT IS THE HOUSE RULE
            //
            // `.16em` at 10.5px is **1.68** — not 0.16. Flutter's `letterSpacing`
            // is a logical-pixel advance and CSS's is relative to the element's
            // own font, and `stat_tile.dart` and `eva_section_header.dart` both
            // spell the rule out. A raw 0.16 would be eight to twelve times too
            // small, and it is the single most likely defect on a screen with
            // three tracked mono runs.
            letterSpacing: direction == TextDirection.rtl
                ? 0
                : EvaSectionHeader.sectionSize *
                      EvaSectionHeader.sectionTracking,
            // `:30` — `color:var(--ink-2)`.
            color: colors.ink2,
          ),
          direction,
        ),
      ),
    );
  }
}
