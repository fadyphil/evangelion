/// The single import surface for the Eva design system.
///
/// `07-file-map.md`: "`core/design_system/barrel.dart` is the only import path
/// for design-system widgets." Every screen, widget and token consumer imports
/// this file and nothing beneath it.
///
/// ## WHY A BARREL RATHER THAN DEEP IMPORTS
///
/// Two reasons, one of which is a test.
///
/// **The barrel must not re-export the framework.** `export
/// 'package:flutter/material.dart'` makes Flutter part of this file's own
/// surface, so any pure-Dart file that reached for a spacing token through the
/// barrel would become Flutter-dependent without naming anything but the barrel.
///
/// **What does NOT catch that.** An earlier version of this comment claimed Gate 1
/// would fail on the pure-Dart importer. It would not. Gate 1's pattern is
/// anchored to the directives *in the file it scans*, with no graph resolution,
/// so a `core/domain/*.dart` file importing only this barrel matches nothing
/// forbidden and is reported `ok` — and Gate 1 never scans this file at all, so
/// the offending export here is equally invisible to it. Confirmed by planting
/// `export 'package:flutter/material.dart' show ThemeData;` here: `flutter
/// test`, `dart analyze` and `verify_purity.sh` all stayed green.
///
/// So the guarantee is carried by two checks in
/// `test/core/design_system/barrel_test.dart` instead: the export regex stops at
/// the closing quote rather than the semicolon, so a `show`/`hide` combinator
/// cannot hide the URI from it, and the transitive import-graph walk in
/// `test/support/project_import_graph.dart` proves no pure-Dart directory reaches
/// Flutter through a chain.
///
/// **One place to change.** A token renamed in `tokens/eva_colors.dart` breaks
/// every deep importer at once, which is the argument *for* deep imports. But the
/// design system has eleven files and eleven directories' worth of consumers
/// (six pages, plus widgets, effects and their tests), so the practical cost of
/// the rename is one edit here and the practical cost of a deep import appearing
/// is two import styles coexisting forever. The barrel wins.
///
/// `test/core/design_system/barrel_test.dart` compares this list against the
/// files on disk, so a new token file that nobody exports here is a red rather
/// than a silent second import path.
///
/// **Phase 9 added `tokens/eva_type_scale.dart`**, and the barrel is why it is a
/// *widget* in `tokens/` rather than a private `MediaQuery` spelled three times — see
/// that file's doc for the three sites and the reasoning. Nothing about the export
/// policy changed; the file joined the `tokens/` list because `eva_typography.dart`'s
/// own header has claimed "the Settings font-size scaler" as part of the type system
/// since Phase 1, and this is the widget that installs it.
///
/// ## SCOPE
///
/// Everything under `tokens/`, `theme/`, `effects/` and `widgets/`. Phase 1 shipped
/// the first two; Phase 2 added `effects/` plus the **five** decorative widgets in
/// its commit (`glass_surface`, `passage_drop_cap`, `seal_monogram`,
/// `streak_flame`, `sun_burst` — counted from `git show --stat 81f5034`); and
/// Phase 3 added the Tier-1 primitives in a commit whose subject is literally
/// "the 17 Tier-1 primitive widgets" (`3804939`).
///
/// The previous version of this sentence said Phase 3 "fills in the Tier-1
/// primitives and the Tier-3 composites", which stopped being true the moment
/// Phase 3 landed. It is written down now rather than left, because a phase number
/// in a comment is a claim about the future that nothing checks — the lesson
/// AGENT_CONTEXT §9's recorded decision 21 records, and it applies to this file as
/// much as to the ones that sweep found.
///
/// The directory-listing comparison in `barrel_test.dart` walks all four
/// directories, so every design-system file landing on disk has to be exported
/// here in the same commit. That is the whole point: a new `widgets/*.dart` that
/// nobody exports is invisible until a feature deep-imports it, and from then on
/// two import styles coexist.
library;

export 'package:evangelion/core/design_system/effects/gold_flecks.dart';
export 'package:evangelion/core/design_system/effects/hue_rotate_matrix.dart';
export 'package:evangelion/core/design_system/effects/neural_background.dart';
export 'package:evangelion/core/design_system/effects/neural_motion.dart';
export 'package:evangelion/core/design_system/effects/neural_orbs.dart';
export 'package:evangelion/core/design_system/theme/eva_theme.dart';
export 'package:evangelion/core/design_system/theme/eva_theme_dark.dart';
export 'package:evangelion/core/design_system/theme/eva_theme_light.dart';
export 'package:evangelion/core/design_system/tokens/eva_colors.dart';
export 'package:evangelion/core/design_system/tokens/eva_elevations.dart';
export 'package:evangelion/core/design_system/tokens/eva_motion.dart';
export 'package:evangelion/core/design_system/tokens/eva_radii.dart';
export 'package:evangelion/core/design_system/tokens/eva_spacing.dart';
export 'package:evangelion/core/design_system/tokens/eva_type_scale.dart';
export 'package:evangelion/core/design_system/tokens/eva_typography.dart';
export 'package:evangelion/core/design_system/tokens/sticker_palette.dart';
export 'package:evangelion/core/design_system/widgets/empty_state.dart';
export 'package:evangelion/core/design_system/widgets/error_view.dart';
export 'package:evangelion/core/design_system/widgets/eva_button.dart';
export 'package:evangelion/core/design_system/widgets/eva_chip.dart';
export 'package:evangelion/core/design_system/widgets/eva_section_header.dart';
export 'package:evangelion/core/design_system/widgets/eva_text_field.dart';
export 'package:evangelion/core/design_system/widgets/eva_toggle.dart';
export 'package:evangelion/core/design_system/widgets/focus_ring.dart';
export 'package:evangelion/core/design_system/widgets/font_size_stepper.dart';
export 'package:evangelion/core/design_system/widgets/glass_surface.dart';
export 'package:evangelion/core/design_system/widgets/hairline_divider.dart';
export 'package:evangelion/core/design_system/widgets/icon_action_button.dart';
export 'package:evangelion/core/design_system/widgets/neural_scaffold.dart';
export 'package:evangelion/core/design_system/widgets/passage_drop_cap.dart';
export 'package:evangelion/core/design_system/widgets/progress_beads.dart';
export 'package:evangelion/core/design_system/widgets/seal_monogram.dart';
export 'package:evangelion/core/design_system/widgets/segmented_control.dart';
export 'package:evangelion/core/design_system/widgets/settings_group.dart';
export 'package:evangelion/core/design_system/widgets/settings_tile.dart';
export 'package:evangelion/core/design_system/widgets/stat_tile.dart';
export 'package:evangelion/core/design_system/widgets/streak_flame.dart';
export 'package:evangelion/core/design_system/widgets/sun_burst.dart';
export 'package:evangelion/core/design_system/widgets/text_link.dart';
