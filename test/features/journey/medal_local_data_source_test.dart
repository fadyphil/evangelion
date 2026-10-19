import 'dart:io';

import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:evangelion/features/journey/data/datasources/medal_local_data_source.dart';
import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/features/journey/domain/medal_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/font_coverage.dart';

/// [MedalLocalDataSource] — the fiction, held to the prototype's own
/// numbers.
///
/// ## WHY THE PROTOTYPE IS READ AT TEST TIME AND NOT QUOTED
///
/// The data source holds four medals and a count, and both of those are
/// transcriptions of `eva/redesign.html:597-602`. A transcription written in a
/// comment is not a gate: re-typing the count, or swapping two medals' order,
/// would pass every review that did not happen to have the markup open. So
/// this suite reads the prototype at test time — the discipline
/// `library_catalogue_local_data_source_test.dart` applies to the catalogue's
/// washes — and asks the stub to agree with what is there.
///
/// ## AND WHY **NO COLOUR** IS WRITTEN DOWN HERE
///
/// The four blooms' values live in the journey feature's transcription table,
/// which is the one file on the design system's colour-exemption list, and
/// this file is not that file. So the washes are compared **by what they are**
/// rather than by their hexes: which of the four is the pale one, which is the
/// deep one, which is the only one whose green channel is its smallest, which
/// is the only one whose blue channel is its largest. Those four facts are
/// enough to prove the enum's *names* are attached to the right washes, and
/// they are checkable without a second copy of a colour in the repository.
///
/// The one colour this suite does compare against a token is the magenta, and
/// it compares **hues**: the design system's bloom token publishes the same
/// RGB as the prototype's `:600` wash, and that is the fact the transcription
/// table's magenta line rests on.
void main() {
  /// The prototype this suite reads. Read-only — `eva/` is reference material
  /// (AGENT_CONTEXT §2, §8).
  const String prototypePath = 'eva/redesign.html';

  final File prototype = File(prototypePath);
  if (!prototype.existsSync()) {
    throw StateError(
      '$prototypePath is missing. This harness cannot read the prototype, so it '
      'does not pass — a missing reference is reported, never assumed '
      'unchanged.',
    );
  }
  final String html = prototype.readAsStringSync();

  /// The four `.medal` elements, as the prototype writes them.
  final List<({String bloom, int emblem, String i18nKey, String name})>
  prototypeMedals = _medals(html);

  /// The prototype's own "4 / 12" — the medals label's count.
  final String prototypeCount = _medalsCount(html);

  group('the stub, against the prototype\'s own markup', () {
    test('the prototype really declares four medals, and this suite found them', () {
      // The anti-vacuity row: a suite that parsed nothing would pass every
      // comparison below against an empty list — green, and about nothing. The
      // four are the prototype's (`:599-602`) and the count beside them says
      // "4 / 12" (`:597`), which is the same four from the other side.
      expect(prototypeMedals, hasLength(4));
      expect(
        prototypeMedals
            .map(
              (({String bloom, int emblem, String i18nKey, String name}) m) =>
                  m.i18nKey,
            )
            .toList(),
        <String>['m1', 'm2', 'm3', 'm4'],
      );
    });

    test(
      'the stub\'s four are the prototype\'s four, in the prototype\'s order',
      () {
        final MedalShelf shelf = MedalLocalDataSource().shelf();
        expect(shelf.earned, hasLength(4));
        expect(
          shelf.earned,
          <Medal>[
            Medal.firstLight,
            Medal.psalmist,
            Medal.streakSeven,
            Medal.john,
          ],
          reason:
              'the order is `:599-602`\'s, and it is a demo order — nothing above '
              'the stub may sort it and call the result better',
        );
      },
    );

    test(
      'the count is the prototype\'s "4 / 12", and the four is the drawn four',
      () {
        // The numerator and the denominator are read out of `:597` rather than
        // typed here, so a prototype that changed the count turns this red
        // instead of quietly agreeing with itself.
        final List<String> parts = prototypeCount.split('/');
        expect(parts, hasLength(2), reason: '"4 / 12" is two numbers');
        final int earned = int.parse(parts[0].trim());
        final int total = int.parse(parts[1].trim());

        final MedalShelf shelf = MedalLocalDataSource().shelf();
        expect(
          shelf.earned.length,
          earned,
          reason: 'the drawn four are the earned four',
        );
        expect(
          shelf.total,
          total,
          reason: 'the twelve is the prototype\'s own',
        );
        expect(
          earned,
          lessThan(total),
          reason: 'a reader has not earned them all',
        );
      },
    );

    test('the four washes are four distinct values, and every one is at half alpha', () {
      final Set<String> washes = prototypeMedals
          .map(
            (({String bloom, int emblem, String i18nKey, String name}) m) =>
                m.bloom,
          )
          .toSet();
      expect(
        washes,
        hasLength(4),
        reason: 'the prototype writes four different washes',
      );

      for (final ({String bloom, int emblem, String i18nKey, String name}) medal
          in prototypeMedals) {
        expect(
          _rgba(medal.bloom).alpha,
          128,
          reason:
              '`.5 × 255 = 127.5`, which rounds to 128 — the prototype '
              'writes `.5` on all four (`:599-602`)',
        );
      }
    });

    test('and the names the enum gives them are the washes they are attached to', () {
      // The four facts that make "cream", "magenta", "amber" and "blue" checkable
      // without writing a colour down: the pale one, the deep one, the only one
      // whose green channel is its smallest, and the only one whose blue channel
      // is its largest. Between them they identify all four.
      final List<({String bloom, int r, int g, int b})> washes =
          <({String bloom, int r, int g, int b})>[
            for (final ({String bloom, int emblem, String i18nKey, String name})
                medal
                in prototypeMedals)
              (
                bloom: medal.bloom,
                r: _rgba(medal.bloom).r,
                g: _rgba(medal.bloom).g,
                b: _rgba(medal.bloom).b,
              ),
          ];

      int sum(({String bloom, int r, int g, int b}) w) => w.r + w.g + w.b;
      bool greenIsSmallest(({String bloom, int r, int g, int b}) w) =>
          w.g < w.r && w.g < w.b;
      bool blueIsLargest(({String bloom, int r, int g, int b}) w) =>
          w.b > w.r && w.b > w.g;

      final List<int> byLight = <int>[for (int i = 0; i < washes.length; i++) i]
        ..sort((int a, int b) => sum(washes[b]).compareTo(sum(washes[a])));
      final List<int> byDark = <int>[for (int i = 0; i < washes.length; i++) i]
        ..sort((int a, int b) => sum(washes[a]).compareTo(sum(washes[b])));

      expect(Medal.values[byLight.first].bloom, MedalBloom.cream);
      expect(Medal.values[byDark.first].bloom, MedalBloom.amber);
      expect(
        Medal.values[washes.indexWhere(greenIsSmallest)].bloom,
        MedalBloom.magenta,
        reason:
            'the magenta is the only wash whose green channel is its smallest',
      );
      expect(
        Medal.values[washes.indexWhere(blueIsLargest)].bloom,
        MedalBloom.blue,
        reason: 'the blue is the only wash whose blue channel is its largest',
      );
    });

    test('the magenta is the design system\'s own bloom hue, at 55% against 50%', () {
      // The one fact the transcription table's magenta line rests on: the
      // design system's `bloom` token publishes the same RGB as the prototype's
      // `:600` wash, and carries it at 55% where the prototype writes 50%.
      final Color token = const EvaColors.dark().bloom;
      expect(
        const EvaColors.light().bloom,
        token,
        reason: 'one value in both themes',
      );

      final ({int r, int g, int b, int alpha}) magenta = _rgba(
        prototypeMedals[1].bloom,
      );
      expect(magenta.r, _channel(token.r));
      expect(magenta.g, _channel(token.g));
      expect(magenta.b, _channel(token.b));
      expect(
        (token.a * 255).round(),
        140,
        reason:
            'the token carries 55% — `.55 × 255 = 140.25`, which rounds to 140',
      );
      expect(
        magenta.alpha,
        128,
        reason:
            'and the prototype writes 50%, so the two differ by five points '
            'of alpha — the difference the table records',
      );
    });

    test('and the other three are not that hue', () {
      final Color token = const EvaColors.dark().bloom;
      for (final int index in <int>[0, 2, 3]) {
        final ({int r, int g, int b, int alpha}) wash = _rgba(
          prototypeMedals[index].bloom,
        );
        expect(
          <int>[wash.r, wash.g, wash.b],
          isNot(<int>[_channel(token.r), _channel(token.g), _channel(token.b)]),
          reason: 'the wash at index $index is one of the three with no token',
        );
      }
    });

    test('the emblems are the prototype\'s four characters, in order', () {
      // The link between a name and a codepoint lives HERE and not in `lib/`:
      // the enum names a shape, and a codepoint in the domain would be a
      // character somebody types.
      const List<({MedalEmblem emblem, int codepoint})> expected =
          <({MedalEmblem emblem, int codepoint})>[
            (emblem: MedalEmblem.fourPointedStar, codepoint: 0x2726),
            (emblem: MedalEmblem.fleuron, codepoint: 0x2767),
            (emblem: MedalEmblem.malteseCross, codepoint: 0x2720),
            (emblem: MedalEmblem.crossOfSaintJohn, codepoint: 0x2629),
          ];

      expect(
        prototypeMedals
            .map(
              (({String bloom, int emblem, String i18nKey, String name}) m) =>
                  m.emblem,
            )
            .toList(),
        expected
            .map((({MedalEmblem emblem, int codepoint}) e) => e.codepoint)
            .toList(),
      );
      expect(
        Medal.values.map((Medal m) => m.emblem).toList(),
        expected
            .map((({MedalEmblem emblem, int codepoint}) e) => e.emblem)
            .toList(),
        reason: 'and the enum\'s four are in the same order',
      );
    });

    test('and three of the four are in no bundled family, so they cannot be typed', () {
      // The measurement the emblem enum's doc makes: three of the prototype's
      // four glyphs are in none of the five families `pubspec.yaml` declares, and
      // the fourth is in EB Garamond alone. This is why the emblem is a name in
      // the domain and a painting in the widget.
      final Map<String, Set<int>> coverage = <String, Set<int>>{
        for (final String family in kBundledFontFamilies)
          family: codepointsForFamily(family),
      };
      expect(
        coverage.keys.toSet(),
        kBundledFontFamilies.toSet(),
        reason:
            'every declared family was measured — a sweep over fewer '
            'families would pass vacuously',
      );

      for (final int codepoint in <int>[0x2726, 0x2720, 0x2629]) {
        for (final MapEntry<String, Set<int>> family in coverage.entries) {
          expect(
            family.value,
            isNot(contains(codepoint)),
            reason:
                'U+${codepoint.toRadixString(16).toUpperCase()} is in no '
                'family, and `${family.key}` must not carry it',
          );
        }
      }

      expect(
        coverage['EBGaramond'],
        contains(0x2767),
        reason: 'the fleuron is in EB Garamond',
      );
      for (final MapEntry<String, Set<int>> family in coverage.entries) {
        if (family.key == 'EBGaramond') continue;
        expect(
          family.value,
          isNot(contains(0x2767)),
          reason: 'and in no other family, so the widget has to pin the face',
        );
      }
    });
  });
}

/// The four `.medal` elements the prototype draws.
///
/// **One regex, because the prototype writes all four the same way** — the
/// wash as an inline `--bh`, then a `.bloom`, then the emblem in a `<span>`,
/// then the name in a `.mn` — and a parser for a shape this regular is a
/// parser that will not notice the shape changing.
List<({String bloom, int emblem, String i18nKey, String name})> _medals(
  String html,
) {
  final RegExp medal = RegExp(
    r'<div class="medal" style="--bh:(rgba\([^)]*\))"><div class="bloom">'
    r'</div><span>([^<]*)</span><div class="mn" data-i18n="(m\d+)">([^<]*)</div>',
  );
  return <({String bloom, int emblem, String i18nKey, String name})>[
    for (final RegExpMatch match in medal.allMatches(html))
      (
        bloom: match.group(1)!,
        // **The first rune, not the first code unit**: an emblem outside the
        // BMP would be two units long and `substring(0, 1)` would split it.
        emblem: match.group(2)!.runes.first,
        i18nKey: match.group(3)!,
        name: match.group(4)!,
      ),
  ];
}

/// The medals label's count — the prototype's "4 / 12" (`:597`).
///
/// **The `data-i18n` attribute is the anchor**, because the i18n table at
/// `:936` carries the same key in a different shape (`medalsCount:["4 / 12",…]`)
/// and a looser pattern would read the table's row instead of the rendered
/// label.
String _medalsCount(String html) {
  final RegExpMatch? match = RegExp(r'data-i18n="medalsCount">([^<]*)<')
      .firstMatch(html);
  if (match == null) {
    throw StateError(
      'the prototype declares no `medalsCount` label, so the stub\'s count has '
      'nothing to agree with. That is a finding, not a pass.',
    );
  }
  return match.group(1)!;
}

/// One 0-255 channel of a [Color], read the way the current `Color` API reads
/// it.
///
/// **`Color.red` and its siblings are deprecated**, and
/// `deprecated_member_use` is a hard error in this repository (AGENT_CONTEXT
/// §4). The replacement is the float channel scaled back to 0-255 — and
/// `clamp` because a float channel can be a hair outside the range.
int _channel(double unit) => (unit * 255.0).round().clamp(0, 255);

/// The r, g, b and alpha byte of an `rgba(r,g,b,a)` literal.
///
/// **The leading dot is part of the number**: `.5` is not `5`, and a pattern
/// that read `\.?` would let `\d+` start at the `5` and measure a hundred
/// times too much. The same rule `library_catalogue_local_data_source_test.dart`
/// encodes, for the same measured reason.
({int r, int g, int b, int alpha}) _rgba(String css) {
  final RegExpMatch? match = RegExp(
    r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*((?:\.\d+)|(?:[01](?:\.\d+)?))\)',
  ).firstMatch(css);
  if (match == null) {
    throw StateError('`$css` is not an rgba literal this suite reads');
  }
  return (
    r: int.parse(match.group(1)!),
    g: int.parse(match.group(2)!),
    b: int.parse(match.group(3)!),
    alpha: (double.parse(match.group(4)!) * 255).round(),
  );
}
