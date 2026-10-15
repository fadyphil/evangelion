import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter_test/flutter_test.dart';

/// RED-FIRST — the part of `EvaTextField` that is a calculation rather than a
/// widget: which border, which fill, and how strong the focus glow, for each of
/// the three states `ds.tsx`'s `Input` fakes.
///
/// ## WHY THIS IS THE TDD-ABLE PART OF A DEFECT
///
/// Prototype defect #8 says `Input` is `readOnly` with no `value`/`onChanged`,
/// and #10 says Login's focus and error are literals (`LoginScreen.tsx:49-52`
/// hardcodes `focused` on email and an error string on password). Both defects
/// are one missing thing: there is no state layer, so the states were never
/// computed, only typed. Naming the three states and resolving them is what
/// makes the field real; the widget around them is layout.
void main() {
  group('resolveTextFieldStyle — idle', () {
    test('is a 1px rim on the neutral glass fill', () {
      // `redesign.html:376` — `border: 1px solid var(--glass-line)`,
      // `background: rgba(255,255,255,.04)`.
      //
      // **1px, where this asserted `1.5px` against `ds.tsx:307`** until the
      // Task 4.2 restyle re-pointed the box. The width is now
      // [kEvaTextFieldRimWidth] rather than a literal, because the widget's
      // `Border.all` cannot spell it — it *is* `Border.all`'s default, so
      // naming it there would have been a redundant argument
      // (`avoid_redundant_argument_values`) — and a constant with no reader is
      // a constant with nothing keeping it honest. This is the reader.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        final EvaTextFieldStyle style = resolveTextFieldStyle(
          colors: colors,
          focused: false,
          hasError: false,
          enabled: true,
        );
        expect(style.border.top.width, kEvaTextFieldRimWidth);
        expect(kEvaTextFieldRimWidth, 1.0);
        expect(style.border.top.color, colors.glassBorder);
        expect(style.glow, isEmpty);
      }
    });

    test('inks with `ink` and fills with `glassFill`', () {
      const EvaColors colors = EvaColors.dark();
      final EvaTextFieldStyle style = resolveTextFieldStyle(
        colors: colors,
        focused: false,
        hasError: false,
        enabled: true,
      );
      expect(style.foreground, colors.ink);
      // `glassFill` is `rgba(#fff, 0.05)` in dark (`eva_colors.dart:75`), and the
      // prototype's *unfocused* input is 0.03. The token wins and the difference
      // is recorded: a 2% alpha gap on a 52px-tall box is not a visible change,
      // and a second copy of the fill would be a second thing to drift.
      expect(style.background, colors.glassFill);
    });
  });

  group('resolveTextFieldStyle — focused', () {
    test('the rim is §14\'s ring, not the prototype\'s 1.5px solid ember', () {
      // THE ONE PLACE §14 OVERRIDES A TRANSCRIBED VALUE, and it is a real
      // conflict worth naming.
      //
      // `ds.tsx:307` gives the focused input `1.5px solid ember` — full opacity.
      // `09-quality-gates.md` §14 mandates "a 2px `ember` ring at 40% alpha on
      // every interactive widget". Both describe the same 1.5–2px band around the
      // same box, so honouring both is impossible.
      //
      // §14 wins because it is the mandatory-fix list and because the
      // prototype's focused rim is not a focus indicator at all: `focused` is a
      // **literal prop** that defect #10 records as baked in, so nothing ever
      // moved it. There is no accessibility behaviour being preserved by
      // 100% alpha; there is a static picture of one.
      //
      // The prototype's *glow* is preserved below, because a glow is a different
      // effect from a ring and it is the part that reads as "this is live".
      const EvaColors colors = EvaColors.dark();
      final EvaTextFieldStyle style = resolveTextFieldStyle(
        colors: colors,
        focused: true,
        hasError: false,
        enabled: true,
      );
      expect(style.border, evaFocusRingBorder(colors));
      expect(style.border.top.width, 2.0);
      expect(style.border.top.color, evaFocusRingSpec(colors).color);
      expect(
        style.border.top.color.a,
        moreOrLessEquals(0.40, epsilon: 0.001),
        reason: '§14 — 40% alpha, not the prototype\'s opaque ember',
      );
    });

    test('the focus fill is 6%, the prototype\'s focused value', () {
      // `ds.tsx:308` — `rgba(#fff | #000, focused ? 0.06 : 0.03)`.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        expect(
          resolveTextFieldStyle(
            colors: colors,
            focused: true,
            hasError: false,
            enabled: true,
          ).background.a,
          moreOrLessEquals(0.06, epsilon: 0.001),
        );
      }
    });

    test('keeps the redesign\'s single focus halo', () {
      // `redesign.html:378` — `box-shadow: 0 0 0 3px rgba(232,176,75,.12)`,
      // one shadow. `ds.tsx:310` wrote **two**: that ring at `.18` and a
      // `0 0 20px rgba(ember,.12)` fog. The Task 4.2 restyle dropped the fog, so
      // the **count** is the assertion — "the glow is still there" would have
      // passed with both of them, and it is the second one that made a
      // field's focus strength depend on what was painted behind it.
      //
      // The 3px one has zero blur and zero offset, which makes it a ring rather
      // than a glow; it is transcribed as `spreadRadius: 3` because that is what
      // a zero-blur, zero-offset shadow *is*, and dropping it would lose the
      // prototype's strongest focused cue.
      const EvaColors colors = EvaColors.dark();
      final EvaTextFieldStyle style = resolveTextFieldStyle(
        colors: colors,
        focused: true,
        hasError: false,
        enabled: true,
      );
      expect(style.glow, hasLength(1));
      expect(style.glow.single.color, colors.ember.withValues(alpha: 0.12));
      expect(style.glow.single.offset, Offset.zero);
      expect(style.glow.single.blurRadius, 0.0);
      expect(style.glow.single.spreadRadius, 3.0);
    });
  });

  group('resolveTextFieldStyle — error', () {
    test('the idle rim turns `err`, per the prototype', () {
      // `ds.tsx:307` — `error ? hex.err : …`. The **hue** is still that
      // prototype's, because `redesign.html` declares no error rim at all;
      // the **width** is the redesign's, per `kEvaTextFieldRimWidth`.
      const EvaColors colors = EvaColors.dark();
      final EvaTextFieldStyle style = resolveTextFieldStyle(
        colors: colors,
        focused: false,
        hasError: true,
        enabled: true,
      );
      expect(style.border.top.color, colors.err);
      expect(style.border.top.width, kEvaTextFieldRimWidth);
    });

    test('an errored field that is focused still shows the focus ring', () {
      // Focus is the reader's cursor position and outranks the error for
      // deciding the rim; the error is carried by the helper text, its icon and
      // the semantics label — never by the rim's colour alone. §14 bans
      // colour-only state, so losing the red rim here costs nothing as long as
      // those three exist, which `eva_text_field_test.dart` checks.
      const EvaColors colors = EvaColors.dark();
      expect(
        resolveTextFieldStyle(
          colors: colors,
          focused: true,
          hasError: true,
          enabled: true,
        ).border,
        evaFocusRingBorder(colors),
      );
    });

    test('an error keeps its own glow colour rather than ember', () {
      const EvaColors colors = EvaColors.dark();
      final EvaTextFieldStyle style = resolveTextFieldStyle(
        colors: colors,
        focused: false,
        hasError: true,
        enabled: true,
      );
      expect(style.glow, isEmpty, reason: 'the prototype has no error glow');
      expect(style.foreground, colors.ink);
    });
  });

  group('resolveTextFieldStyle — disabled', () {
    test('dims the fill and keeps the rim, and never gains a glow', () {
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        final EvaTextFieldStyle enabled = resolveTextFieldStyle(
          colors: colors,
          focused: false,
          hasError: false,
          enabled: true,
        );
        final EvaTextFieldStyle disabled = resolveTextFieldStyle(
          colors: colors,
          focused: false,
          hasError: false,
          enabled: false,
        );
        expect(disabled.background.a, lessThan(enabled.background.a));
        expect(disabled.border.top.width, enabled.border.top.width);
        expect(disabled.glow, isEmpty);
      }
    });

    test('a disabled field cannot be focused, whatever `focused` says', () {
      // `focused: true, enabled: false` is reachable from a widget that
      // forwards a stale focus flag, and it must not produce a ring: an
      // indicator on a control the reader cannot reach is a lie.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        expect(
          resolveTextFieldStyle(
            colors: colors,
            focused: true,
            hasError: false,
            enabled: false,
          ).border,
          isNot(evaFocusRingBorder(colors)),
        );
      }
    });
  });

  group('the enum-free geometry the widget reads', () {
    test(
      'the prototype field is 52 tall with a 14 radius and 16/44 insets',
      () {
        // `ds.tsx:306,309` — `height: 52`, `borderRadius: 14`,
        // `padding: '0 44px 0 16px'`.
        expect(kEvaTextFieldHeight, 52.0);
        expect(kEvaTextFieldRadius, EvaRadii.input);
        expect(EvaRadii.input, 14.0);
        expect(kEvaTextFieldPadding.left, EvaSpacing.lg);
        expect(kEvaTextFieldPadding.left, 16.0);
        expect(kEvaTextFieldPadding.right, 44.0);
      },
    );

    test('the label/error gap is the prototype\'s 6px', () {
      // `ds.tsx:296` — `gap: 6` between label, field and error text. 6 is not on
      // the 4px spacing scale, so it is a named constant here rather than a
      // round number invented at a call site.
      expect(kEvaTextFieldStackGap, 6.0);
    });
  });
}
