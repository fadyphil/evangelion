import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The role the reader signs in as, chosen on `/login`.
///
/// ## THIS IS **WRITTEN, NOT TRANSCRIBED**, AND HERE IS WHY
///
/// `eva/redesign.html` draws **no role picker**. The redesign's login
/// (`:503-511`) is a wordmark, a tagline, two bare fields, a CTA and two inert
/// ghost pills — and every one of those has a prototype line this client
/// transcribes. **This control has none**, and the reason is structural rather
/// than a gap in the reference:
///
/// * **There is no auth endpoint** (AGENT_CONTEXT §2, decision 3). The backend
///   has no `/auth`, no `/me` and no `/login`; identity is three headers the
///   client sets and nothing validates. So the client cannot ask who anyone is,
///   and the role is the **reader's own choice** on this screen.
/// * The prototype was a **reader's** app, with no second audience to offer the
///   choice to. The servant portal adds one, and the control that offers it is
///   therefore new surface rather than a transcription.
///
/// **So there is no `redesign.html:NNN` to cite here, and the citation gate
/// gets no new claim to resolve.** Anything in this file that quoted the
/// prototype would be quoting a control the prototype does not have.
///
/// ## AND THE ROLE IS **ADVISORY**, NEVER A BOUNDARY
///
/// The backend parses `X-User-Role` at `src/middleware/identity.middleware.ts:24`,
/// assigns it at `:31`, and never reads it again — `rg 'user\??\.role' src/` and
/// `rg '403' src/` both return **no matches**. So this control decides what the
/// *client* believes and what the client puts on the wire, and nothing else. It
/// prevents **accidents**: a child is not dropped onto a scheduling screen, and
/// a viewer servant is not shown a control that reports nothing. It prevents
/// **nothing** an attacker would have to defeat. See
/// `core/domain/entities/user_role.dart` for the whole measurement.
///
/// ## IT IS **CONTROLLED**, AND THAT IS WHY IT HOLDS NO STATE
///
/// [selected] is the value and [onChanged] is the report; the parent owns
/// both. **No `setState` here** — and not only because this widget is
/// stateless: `test/setstate_budget_test.dart` is a gate, and a control that
/// kept its own copy of the selection would be a **second source of truth**
/// beside the bloc's `AuthState.role`, free to disagree with it in exactly the
/// way this repository has recorded twice (decisions 5 and 68).
///
/// ## AND THE TRACK IS NAMED **DIFFERENTLY** FROM ITS OPTIONS
///
/// `SegmentedControl`'s track is an activatable node of its own — it is the one
/// thing binding the control's focus node into the focus tree — so naming it
/// after the selected option would put two activatable nodes on screen with the
/// identical label. That is recorded decision 129's defect, and the reason
/// `SegmentedControl.semanticLabel` exists at all. So this widget always
/// passes one, and it is the app's own word for the thing the control offers
/// (`authRoleLabel`), not one of the option labels.
/// ## AND IT IS THE **WIDE** MODE, FOR A MEASURED REASON
///
/// `SegmentedControl` has two geometries, and the wide one is not a style
/// choice — it is the answer to a control whose labels do not fit the default's
/// per-segment padding at the narrowest supported surface.
///
/// The arithmetic, at **320px** and **1.22×** (§14's own numbers):
///
/// * the login screen's content column is `320 − 2×34` (`kRootGutter`) =
///   **252px**;
/// * the track's own padding and rim take 8 of it → **244px**;
/// * three segments share that equally → **81.3px** each;
/// * the default mode's `segmentPadding` takes `12` a side → **57.3px** of text
///   per segment, and "SERVANT" at 12sp mono wants **64.9px** at 1.22×.
///
/// So the default mode **ellipsises** "SERVANT" on the narrowest phone at the
/// largest text scale, and a clipped label is §14's "the reader's words
/// deleted" failure. The wide mode's own numbers fix it: an 11px label
/// (`wideLabelSize`) and **zero** horizontal padding, which brings "SERVANT" to
/// **62.5px** against the same 81.3px — and the Arabic arm's three labels to
/// 21 / 23 / 31px.
///
/// **Measured, not reasoned**: `login_text_scale_test.dart` asserts each
/// label's rendered width against the width it wants, in both arms, so the
/// claim is a failing assertion rather than a paragraph.
///
/// ## THE LABELS ARE **SHORT** FOR THE SAME REASON
///
/// "Kid", "Servant" and "Admin" rather than "Kid", "Viewer servant" and
/// "Admin servant": the three options share one row, and the two servant roles
/// are told apart in a church by **what they do** — one reads the report, one
/// administers — not by the word "servant".
class RolePicker extends StatelessWidget {
  /// A picker over the three roles, showing [selected].
  const RolePicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The role now chosen.
  final UserRole selected;

  /// Reports the role the reader picked.
  final ValueChanged<UserRole> onChanged;

  /// The label for [role], in the app's own words.
  ///
  /// **An exhaustive `switch` with no `default` arm**, because a fourth
  /// [UserRole] must be a compile error here rather than a label nobody
  /// thought of. The same rule `landing_route_for` follows for the same reason
  /// — see `core/navigation/landing_route.dart`'s doc.
  static String labelFor(AppLocalizations strings, UserRole role) =>
      switch (role) {
        UserRole.kid => strings.authRoleKid,
        UserRole.viewerServant => strings.authRoleServant,
        UserRole.adminServant => strings.authRoleAdmin,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    return SegmentedControl<UserRole>(
      // `UserRole.values` — the enum's own three, in its declaration order, so
      // the order the reader sees is the order the role union declares. A
      // hand-written list here would be a second copy of the enum.
      values: UserRole.values,
      selected: selected,
      labelOf: (UserRole role) => labelFor(strings, role),
      // **Distinct from every option label** — see the class doc.
      semanticLabel: strings.authRoleLabel,
      // **The wide geometry**, for the measured reason in the class doc: the
      // default mode's per-segment padding ellipsises "SERVANT" at 320px and
      // 1.22×, and a clipped label is §14's "the reader's words deleted".
      wide: true,
      onChanged: onChanged,
    );
  }
}
