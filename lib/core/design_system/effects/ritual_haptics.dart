import 'dart:async';

import 'package:evangelion/core/domain/entities/ritual_haptic.dart';
import 'package:flutter/services.dart';

/// Fires the ritual's haptics, if the reader has asked for them.
///
/// ## WHY THIS FILE EXISTS AND NOT A CALL AT EVERY SITE
///
/// The prototype's `haptic(p)` is one helper (`eva/redesign.html:914`) and
/// `HAPTICS` is one flag (`:913`) that every call site reads. This client has
/// the same shape: the reader's `UserSettings.haptics` is the flag, and the
/// mapping from the prototype's durations to Flutter's four named impulses is
/// `core/domain/entities/ritual_haptic.dart`'s.
///
/// **What lives here is only the platform call**, because `HapticFeedback` is
/// Flutter and `core/domain/` may not be.
///
/// ## AND WHY `enabled` IS A PARAMETER AND NOT A FIELD
///
/// Because the reader's choice is a **stored preference**, and a stored
/// preference is read where it is used. A helper that held the flag would hold
/// a *copy* of it, and the copy would be a second source of truth for a
/// preference the Workshop writes.
///
/// ## AND WHY THE CALL IS **FIRE-AND-FORGET**
///
/// `HapticFeedback`'s methods return a `Future<void>` that completes when the
/// platform has been asked — and the platform's answer is not something a
/// reader sees. AGENT_CONTEXT §4 requires `unawaited()` rather than a bare
/// future, and that is what this does.
void fireRitualHaptic(RitualHaptic haptic, {required bool enabled}) {
  if (!enabled) return;
  unawaited(switch (hapticImpactFor(haptic)) {
    HapticImpact.selection => HapticFeedback.selectionClick(),
    HapticImpact.light => HapticFeedback.lightImpact(),
    HapticImpact.medium => HapticFeedback.mediumImpact(),
    HapticImpact.heavy => HapticFeedback.heavyImpact(),
  });
}
