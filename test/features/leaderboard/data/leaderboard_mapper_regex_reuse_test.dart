import 'dart:io';

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/features/leaderboard/data/mappers/leaderboard_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../support/project_import_graph.dart';

/// The names the gates below read.
///
/// ## WHY THESE TEN
///
/// Because they are the cases a **shared** `RegExp` could get wrong and a
/// fresh one could not: several separators in a row, a name with digits, a
/// name with more than one parenthetical span, a name that is nothing but an
/// annotation, a name that is nothing at all, and a name in a script with no
/// case to upper-case.
///
/// A pattern that carried state between calls — a `lastIndex`, a cursor — would
/// answer the **second** call differently from the first, and the gate below
/// calls every name twice, and calls a *different* name in between, precisely
/// so that a stateful pattern cannot pass.
const List<String> kNames = <String>[
  'David Mina (Grade 5)',
  'Peter George (Grade 6)',
  'Mark Anton (Grade 5)',
  'Ana Maria Silva',
  'Servant Michael',
  'مريم الحسن',
  'Omar 3 Said',
  'Ann (Grade 5) Bee (Honours)',
  '(Grade 6)',
  '',
];

/// What [kNames] must map to.
///
/// Pinned as **literals**, not recomputed from the rule — a gate that
/// recomputed the answer would agree with any implementation of that rule,
/// including a wrong one.
const List<String> kInitials = <String>[
  'DM',
  'PG',
  'MA',
  'AS',
  'SM',
  'ما',
  'OS',
  'AB',
  '?',
  '?',
];

/// The server's own default cap, and `LeaderboardCubit.rowLimit`.
///
/// A board is read at this limit, so a board load maps at most this many
/// rows — and a hoist that helps one row has to help fifty.
const int kLimit = 50;

/// The source of the member whose declaration starts with [signature].
///
/// Brace-matched, and **string-aware**: a `}` inside a string literal does
/// not close the member.
///
/// ## WHY IT HAS TO BE
///
/// Because the body of `initialsOf` ends with
/// `'${_initialOf(tokens.first)}${_initialOf(tokens.last)}'` — a string with a
/// brace in it, and a **balanced** one. A scanner that counted braces
/// blindly would be right by luck here and wrong the day a name's string
/// carried an unbalanced brace; a scanner that counted them and ignored
/// strings would stop *inside* the interpolation. Either way it would hand
/// back half a member, and a gate that reads half a file is a gate that
/// cannot fail.
String _memberSource(String source, String signature) {
  final int start = source.indexOf(signature);
  if (start < 0) {
    throw StateError('no member declared as "$signature"');
  }
  int depth = 0;
  bool sawBrace = false;
  String terminator = '';
  int i = start;
  while (i < source.length) {
    final String ch = source[i];
    if (terminator.isNotEmpty) {
      if (ch == r'\' && terminator.length == 1 && i + 1 < source.length) {
        i += 2;
        continue;
      }
      if (source.startsWith(terminator, i)) {
        i += terminator.length;
        terminator = '';
        continue;
      }
      i++;
      continue;
    }
    if (ch == "'" || ch == '"') {
      terminator = source.startsWith(ch * 3, i) ? ch * 3 : ch;
      i += terminator.length;
      continue;
    }
    if (ch == '{') {
      depth++;
      sawBrace = true;
      i++;
      continue;
    }
    if (ch == '}') {
      depth--;
      i++;
      if (sawBrace && depth == 0) {
        return source.substring(start, i);
      }
      continue;
    }
    i++;
  }
  throw StateError('the member declared as "$signature" never closed');
}

/// The mapper's own source, with the comments removed.
///
/// The comments go because this file's gate is about **code**: a doc comment
/// that names `RegExp` is prose, and a gate that counted prose would count
/// the explanation of the hoist as an instance of the thing being hoisted.
String _mapperSource() => withoutDartComments(
  File('lib/features/leaderboard/data/mappers/leaderboard_mapper.dart')
      .readAsStringSync(),
);

/// One row, in the server's shape.
Map<String, Object?> _row({required int rank, required String fullName}) =>
    <String, Object?>{
      'userId': '22222222-2222-2222-2222-22222222222$rank',
      'score': 100 - rank,
      'rank': rank,
      'full_name': fullName,
      'current_streak': rank,
    };

/// A board of [count] rows, whose names cycle through [kNames].
Map<String, Object?> _board(int count) => <String, Object?>{
  'group_id': 3,
  'window': 'weekly',
  'total_ranked': count,
  'my_standing': null,
  'leaderboard': <Object?>[
    for (int i = 0; i < count; i++)
      _row(rank: i + 1, fullName: kNames[i % kNames.length]),
  ],
};

/// Unwraps a [Result] that must have succeeded.
T _success<T>(Result<T> result) {
  switch (result) {
    case Right<Failure, T>(:final T value):
      return value;
    case Left<Failure, T>(value: final Failure failure):
      fail('expected a success, got ${failure.kind}: ${failure.message}');
  }
}

void main() {
  group('initialsOf — the same answer, every time', () {
    test('every name maps to its monogram', () {
      for (int i = 0; i < kNames.length; i++) {
        expect(
          LeaderboardMapper.initialsOf(kNames[i]),
          kInitials[i],
          reason: 'the monogram of "${kNames[i]}"',
        );
      }
    });

    test('and it maps to it AGAIN, on the second call', () {
      // ## THE STATEFULNESS GATE, AND WHY IT IS TWO CALLS
      //
      // The change hoisted two `RegExp`s out of `initialsOf` and onto the
      // class, so every call now shares one pattern object. That is only safe
      // if a Dart `RegExp` carries **no state** between `replaceAll` and
      // `split` — and the SDK's own implementation is the evidence
      // (`dart:_internal/vm/lib/regexp_patch.dart:185-190` returns a fresh
      // `_AllMatchesIterable` per call; the cursor lives in the per-call
      // `_AllMatchesIterator` at `:259-304`; `String.replaceAll` and
      // `String.split` both iterate that fresh iterable).
      //
      // **This test is that claim, made falsifiable.** A pattern with a
      // `lastIndex` — a JavaScript-shaped `RegExp`, which Dart's does not
      // have — would answer the second call with a different string, and the
      // suite would be red.
      final List<String> first = <String>[
        for (final String name in kNames) LeaderboardMapper.initialsOf(name),
      ];
      final List<String> second = <String>[
        for (final String name in kNames) LeaderboardMapper.initialsOf(name),
      ];

      expect(
        second,
        first,
        reason:
            'the shared pattern answered the second pass differently — a '
            'pattern that carries state between calls cannot be hoisted',
      );
      expect(second, kInitials);
    });

    test('and it maps to it AGAIN, with another name in between', () {
      // The same claim, one step sharper: the interleaved call is what a
      // `lastIndex` would corrupt. A cursor left on the previous match would
      // make the *next* name start at the wrong place.
      for (int i = 0; i < kNames.length; i++) {
        LeaderboardMapper.initialsOf(kNames[(i + 1) % kNames.length]);
        expect(
          LeaderboardMapper.initialsOf(kNames[i]),
          kInitials[i],
          reason:
              'the answer for "${kNames[i]}" changed after another name was '
              'read — the pattern is carrying state between calls',
        );
      }
    });

    test('and the whole board maps to the same rows', () {
      // ## THE BOARD-LEVEL GATE
      //
      // `initialsOf` is called **once per row**, and the board is read at
      // fifty rows, so a hoist is worth nothing unless it holds for a whole
      // board rather than for one name in isolation. The expected monograms
      // are written out for all fifty rows, in order.
      final LeaderboardBoard board = _success(
        const LeaderboardMapper().map(_board(kLimit), limit: kLimit),
      );

      expect(board.rows, hasLength(kLimit));
      expect(
        board.rows.map((LeaderboardRow row) => row.initials).join(' '),
        'DM PG MA AS SM ما OS AB ? ? '
        'DM PG MA AS SM ما OS AB ? ? '
        'DM PG MA AS SM ما OS AB ? ? '
        'DM PG MA AS SM ما OS AB ? ? '
        'DM PG MA AS SM ما OS AB ? ?',
        reason: 'the monograms of a fifty-row board, in order',
      );
    });
  });

  group('the hoist itself — the source gate', () {
    test('initialsOf compiles no pattern of its own', () {
      // ## WHY A SOURCE GATE AND NOT A BEHAVIOURAL ONE
      //
      // Because the claim this file is about is an **allocation** claim, and
      // no output can witness it: a mapper that compiled a pattern per row
      // and one that compiled none produce **the same strings**. A
      // behavioural gate here would be green for the version of the code that
      // allocates — a gate that cannot fail.
      //
      // So the allocation is gated on the source, and the *output* is gated
      // behaviourally above. The two together are the whole claim: the
      // output did not change, and the allocation is gone.
      final String member = _memberSource(
        _mapperSource(),
        'static String initialsOf(',
      );
      expect(
        member,
        isNot(contains('RegExp(')),
        reason:
            'initialsOf compiles a pattern per call again. The two patterns '
            'are hoisted onto the class, and a Dart RegExp carries no state '
            'between calls, so sharing one is safe.',
      );
    });

    test('and the file compiles exactly two patterns, both above it', () {
      // The count is the other half: "no pattern inside `initialsOf`" would
      // also be satisfied by a file that compiled none at all, and the
      // monograms above would then be impossible. Two patterns, both at
      // class level, is the shape the hoist is supposed to have.
      final String source = _mapperSource();
      final List<int> sites = <int>[
        for (final Match match in RegExp('RegExp\\(').allMatches(source))
          match.start,
      ];
      final int initialsAt = source.indexOf('static String initialsOf(');

      expect(
        sites,
        hasLength(2),
        reason:
            'the mapper compiles exactly two patterns — one for the grade '
            'annotation and one for the whitespace — and both are hoisted '
            'onto the class',
      );
      expect(
        sites.every((int at) => at < initialsAt),
        isTrue,
        reason: 'both patterns are declared above initialsOf, not inside it',
      );
    });
  });
}
