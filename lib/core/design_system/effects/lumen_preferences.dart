import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:flutter/widgets.dart';

/// The reader's ten light-workshop choices, as the aurora's inputs.
///
/// ## WHY THIS IS A **NARROW** TYPE AND NOT A `UserSettings`
///
/// `UserSettings` has thirty fields; ten of them are the aurora's. The scope
/// that publishes these ([LumenPreferencesScope]) sits above every screen, so
/// what it publishes decides whether every screen rebuilds. Publishing the
/// whole aggregate would rebuild all of them when the reader changes their
/// font size — a change the aurora does not care about.
///
/// Ten fields, compared over ten fields, means the scope notifies only when
/// the aurora's own inputs change.
///
/// ## WHY IT LIVES BESIDE THE LUMEN FILES AND NOT IN `core/domain/`
///
/// Because it is the **design system's** input, and `core/domain/` is the
/// shared kernel of the app's domain. The value it carries is a projection of
/// a preference onto a shader, and the shader is a design-system concern.
/// `LumenUniforms` — the thing this becomes — lives in the same directory for
/// the same reason, and `core/domain/` may not name the design system.
///
/// The one thing this file reaches *outward* for is `UserSettings`, and that
/// is inward: the design system may read the domain, never the reverse.
class LumenPreferences {
  /// The ten choices, each defaulting to the prototype's own default.
  ///
  /// The defaults are the prototype's control defaults at
  /// `eva/redesign.html:658-665` — the same values `UserSettings` carries, and
  /// `lumen_preferences_test.dart` asserts the two agree field by field,
  /// because a drift between them would show the aurora a colour the reader
  /// never chose.
  const LumenPreferences({
    this.enabled = true,
    this.shape = CurtainShape.top,
    this.reach = 42,
    this.glow = 100,
    this.touchGlow = 55,
    this.hue = 312,
    this.melt = false,
    this.rayCombing = true,
    this.whiteCores = true,
    this.dotVeil = false,
  });

  /// The ten choices, read out of [settings].
  ///
  /// The projection is by hand rather than by reflection, because Dart has no
  /// reflection and a generated projection would be a second place to forget a
  /// field.
  factory LumenPreferences.fromSettings(UserSettings settings) =>
      LumenPreferences(
        enabled: settings.shaderEnabled,
        shape: settings.curtainShape,
        reach: settings.reach,
        glow: settings.glow,
        touchGlow: settings.touchGlow,
        hue: settings.hue,
        melt: settings.multichromeMelt,
        rayCombing: settings.rayCombing,
        whiteCores: settings.whiteCores,
        dotVeil: settings.dotVeil,
      );

  /// Whether the aurora paints at all — `eva/redesign.html:1468`.
  ///
  /// The prototype hides the canvas (`cvs.style.display='none'`), so "off" is
  /// the fallback background rather than a shader with no uniforms.
  final bool enabled;

  /// Which curtain the aurora draws — `eva/redesign.html:1462-1463`.
  ///
  /// The **same** attribute the scrim's CSS reads (`:114`, `:115`), which is
  /// why there is one type for it: `CurtainShape`'s own doc says so.
  final CurtainShape shape;

  /// How far the band reaches, as the slider's own value — `:658`, `:1469`.
  ///
  /// The raw slider value, not the uniform: [spreadFromReach] is the
  /// conversion and it belongs to the conversion.
  final int reach;

  /// The ambient brightness, as the slider's own value — `:659`, `:1470`.
  ///
  /// **Not a uniform.** The prototype folds it into the ambient target
  /// (`:891`) and never sends it to the GPU — see [brightnessFromGlow].
  final int glow;

  /// The touch glow's gain, as the slider's own value — `:660`, `:1471`.
  final int touchGlow;

  /// The band's hue in degrees — `:661`, `:1472`.
  final int hue;

  /// Whether the three hues melt together — `:662`, `:1473-1474`.
  ///
  /// And whether the hue **drifts**: `:893` cycles `autoH` at 8° a second
  /// while the melt is on, so this is an animation and not only a flag.
  final bool melt;

  /// Whether the rays are combed by noise — `:663`, `:1475`.
  final bool rayCombing;

  /// Whether the band carries a white-hot core — `:664`, `:1476`.
  final bool whiteCores;

  /// Whether the 6px scanline veil is on — `:665`, `:1477`.
  final bool dotVeil;

  /// All ten fields decide equality.
  ///
  /// Hand-written for the reason `LumenUniforms`' is: `equatable` is gone from
  /// this package (AGENT_CONTEXT decision 131) and `==` over a `List` payload
  /// is identity in every implementation there was.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LumenPreferences &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          shape == other.shape &&
          reach == other.reach &&
          glow == other.glow &&
          touchGlow == other.touchGlow &&
          hue == other.hue &&
          melt == other.melt &&
          rayCombing == other.rayCombing &&
          whiteCores == other.whiteCores &&
          dotVeil == other.dotVeil;

  @override
  int get hashCode => Object.hash(
    enabled,
    shape,
    reach,
    glow,
    touchGlow,
    hue,
    melt,
    rayCombing,
    whiteCores,
    dotVeil,
  );

  @override
  String toString() =>
      'LumenPreferences(enabled: $enabled, shape: ${shape.storedValue}, '
      'reach: $reach, glow: $glow, touchGlow: $touchGlow, hue: $hue, '
      'melt: $melt, rayCombing: $rayCombing, whiteCores: $whiteCores, '
      'dotVeil: $dotVeil)';
}

/// Publishes the reader's light-workshop choices to the subtree.
///
/// ## WHY A SCOPE AND NOT A PARAMETER ON EVERY SCREEN
///
/// Because the aurora is an **ambient** layer, and an ambient layer belongs to
/// the app rather than to a screen. The prototype's canvas is a child of
/// `.screen` (`eva/redesign.html:46`) but there is only ever one `.screen`,
/// and it is the app.
///
/// The alternative — every page reading `SettingsScope` and passing the
/// preferences down to the scaffold — would put the app's settings dependency
/// into eight pages for a background that is one layer below all of them.
///
/// ## WHY IT IS PUBLISHED **ABOVE** THE ROUTER
///
/// `lib/app/app.dart` publishes it beside `SettingsScope` and `SkyScope`,
/// above `MaterialApp.router`. Every route is therefore inside it, including
/// the ones Phase 6's `AutoTabsRouter` added.
///
/// ## WHY A MISSING SCOPE MEANS "NO AURORA" AND NOT "DEFAULT AURORA"
///
/// Because the scope carries the reader's **choices**, and a layer painted
/// with choices nobody made is a guess wearing an API — the same objection
/// `SettingsScope`'s doc raises about a third fallback. A subtree with no
/// scope paints the fallback background, which is a thing the design already
/// has.
class LumenPreferencesScope extends InheritedWidget {
  /// Publishes [preferences] to [child].
  const LumenPreferencesScope({
    required this.preferences,
    required super.child,
    super.key,
  });

  /// The reader's choices.
  final LumenPreferences preferences;

  /// The preferences above [context], or null when there are none.
  ///
  /// A **dependent** lookup: the caller rebuilds when the choices change,
  /// which is what makes a hue slider move the aurora.
  static LumenPreferences? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LumenPreferencesScope>()
      ?.preferences;

  /// Notifies only when the aurora's own inputs change.
  ///
  /// [LumenPreferences] compares over the ten fields and nothing else, so a
  /// font-size change does not rebuild a single screen.
  @override
  bool updateShouldNotify(LumenPreferencesScope oldWidget) =>
      oldWidget.preferences != preferences;
}
