/// The four shapes the aurora curtain can take.
///
/// `eva/redesign.html:654-655` — the segmented control carries four values,
/// `data-s="0"`…`data-s="3"`, and the same four are written as an array at
/// `:1463` — `['top','bottom','sides','shafts'][s]`.
///
/// ## AND THEY ARE ALSO THE **SCRIM'S** SHAPE, WHICH IS WHY THIS IS ONE TYPE
///
/// The prototype's handler sets **two** things from one control (`:1463`):
///
/// ```js
/// el('screen').dataset.shape=['top','bottom','sides','shafts'][s];
/// ```
///
/// `u_shape` — the shader's uniform — and `dataset.shape`, which is what the
/// `.scrim` CSS reads. **So the prototype has ONE attribute with four values,
/// read by two rules**, and this client had two types for it: the design
/// system's three-member `CurtainShape` (the scrim's ramp) and this file's
/// four-member one (the control's choice). Task 5.7 merged them, and the merge
/// is this file's reason to exist:
///
/// * **the scrim paints `top` and `shafts` the same way**, because the CSS has
///   overrides for `bottom` (`:114`) and `sides` (`:115`) only, and a
///   `data-shape="shafts"` element falls through to the base `.scrim` rule
///   (`:112-113`) — which is the `180deg` ramp, the same one `top` gets. The
///   design system's `kNeuralCurtain` has a `shafts` arm that says so.
/// * **the shader reads all four**, as `u_shape` 0-3.
///
/// The design system used to declare its own three-member enum beside
/// `NeuralScaffold`, and the two types' names collided in every file that
/// imported both the barrel and this one. `NeuralScaffold` now takes **this**
/// enum, and the ramps live where they were.
///
/// ## WHY THE **NAMES** ARE THE STORED VALUE AND NOT THE **INDEX**
///
/// The prototype's control speaks in indices (`data-s="0"`) and its handler
/// speaks in names (`:1463`), so both are true of it. This enum stores the
/// **name** and derives the index, because the index is what reaches the
/// shader (`u_shape`, `LumenUniforms.shape` asserts 0-3,
/// `lumen_uniforms.dart:431`) and the name is what a reader poking at the
/// store will read. A stored `3` is a fact about a uniform; a stored
/// `shafts` is a fact about a curtain.
///
/// ## AND WHY IT LIVES HERE, IN `core/domain/`, AND NOT IN THE DESIGN SYSTEM
///
/// `UserSettings` holds it (Task 5.7, `eva.shader.shape`), and
/// `core/domain/` is **pure Dart** — Gate 1 holds that directory Flutter-free,
/// so an enum declared in `core/design_system/widgets/` could not be named from
/// `core/domain/entities/user_settings.dart` at all. This is §3's placement
/// test with two consumers on both sides of the boundary: the design system
/// draws the curtain and the domain holds the preference.
///
/// `CurtainShape` is the third of the three enums Task 5.7 moved or created.
/// The other two, `SkyStarShape` and `SkyStarField`, **moved** out of
/// `core/design_system/widgets/witness_sky.dart` for the same reason.
enum CurtainShape {
  /// The curtain hangs from the top. `eva/redesign.html:655` — `data-s="0"`,
  /// and `:1463` — `['top',…][0]`.
  ///
  /// **The scrim paints the base `180deg` ramp** (`:113`), because there is no
  /// `data-shape="top"` rule — `top` *is* the base.
  top('top'),

  /// The curtain hangs from the bottom. `eva/redesign.html:655` — `data-s="1"`.
  ///
  /// **The scrim paints the mirrored ramp** (`:114`).
  bottom('bottom'),

  /// The curtain closes on both sides. `eva/redesign.html:655` — `data-s="2"`.
  ///
  /// **The scrim paints the `90deg` ramp** (`:115`).
  sides('sides'),

  /// The curtain falls in shafts. `eva/redesign.html:655` — `data-s="3"`.
  ///
  /// **The one shape the prototype gates.** `NeuralTier` disables it above
  /// about 2 Mpx (`neural_background.dart:113-162`), because the shafts
  /// measure **5.04 ns/px** against the bands' 2.98. The client does not
  /// mount the shader at all (Task 5.7's recorded deferral), so the gate has
  /// nothing to act on here — but the preference is stored and the gate will
  /// apply to whichever task mounts the painter.
  ///
  /// **AND THE SCRIM PAINTS IT THE WAY `top` IS PAINTED**, which is the
  /// prototype's own behaviour rather than a choice: the CSS has overrides for
  /// `bottom` and `sides` only, so a `data-shape="shafts"` element falls
  /// through to the base `.scrim` rule (`:112-113`).
  shafts('shafts');

  const CurtainShape(this.storedValue);

  /// What `shared_preferences` holds, and what [fromStored] accepts.
  ///
  /// Spelled out rather than derived from the member name, for
  /// `AppThemeMode`'s reason: `.name` gives `top`/`bottom`/`sides`/`shafts`
  /// here by luck, and a member called `hangsFromTop` would silently stop
  /// being readable.
  final String storedValue;

  /// The prototype's `data-s` index — and therefore `u_shape`'s value.
  ///
  /// **The declaration order IS the index**, and it is not an accident: the
  /// prototype's control is `data-s="0"`…`data-s="3"` in that order and its
  /// handler indexes the same array (`:1463`). `LumenUniforms.shape` asserts
  /// 0-3 (`lumen_uniforms.dart:431`), so this is the number the shader wants.
  int get shaderIndex => index;

  /// The shape [storedValue] names, or `null` when it names none of them.
  ///
  /// ## WHY `null` AND NOT A FALLBACK, ON A **PREFERENCE**
  ///
  /// `AppThemeMode.fromStored` and `ReadingLanguage.fromCode` both return
  /// `null` for the same reason — a wrong answer is worse than no answer. A
  /// hand-edited or version-skewed preference naming a shape this build does
  /// not have must not be silently answered with [top]: a reader who chose
  /// `shafts` and whose preference was mangled would be shown a different
  /// curtain, and nothing on screen would say the preference was not read.
  ///
  /// `SettingsLocalDataSource` turns a `null` into **the default** and no
  /// more, so the failure is visible exactly once — in the state, as a
  /// preference that came back at its default — and never as a wrong shape.
  static CurtainShape? fromStored(String storedValue) => switch (storedValue) {
    'top' => top,
    'bottom' => bottom,
    'sides' => sides,
    'shafts' => shafts,
    _ => null,
  };
}
