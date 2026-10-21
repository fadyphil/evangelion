import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/project_import_graph.dart';

/// **A `TextEditingController` may only be created in the controlled field, or
/// in the login page.**
///
/// ## WHAT THIS GATE IS FOR
///
/// AGENT_CONTEXT's decision 188 records **six defects of one class** found in
/// this repository's servant-portal work, and **every one of them was found by
/// an agent reading the code — not by a gate**. The class is:
///
/// > **A screen and the state it mirrors can stop agreeing — and the request is
/// > the one that writes.**
///
/// The correct pattern was **not expressible**: a page that mirrors a
/// cubit-held value into a `TextEditingController` has to hand-roll it, and
/// hand-rolling has **three** ways to be wrong — the write is reported, the
/// field is seeded instead of read back, the mirror runs in the wrong
/// direction — and **no way to be caught**.
///
/// `lib/core/design_system/widgets/eva_controlled_field.dart` is that pattern,
/// made expressible. **This gate is what makes the hand-rolled version unable
/// to come back.**
///
/// ## THE RULE, AND WHY IT IS "CREATED" AND NOT "MENTIONED"
///
/// The rule is about **creating** a controller, and the word matters. A
/// `TextEditingController` is mentioned in four places in this repository that
/// create none: `EvaTextField`'s own `controller` parameter, the `List<
/// TextEditingController>` a page builds to dispose its controllers, the
/// `TextEditingController controller` parameter of a helper, and the doc
/// comments that explain all three.
///
/// **A mention is not a site.** A *creation* is: `TextEditingController(` or
/// `TextEditingController.fromValue(`. And a creation is the right thing to
/// police, because **every controller in the app is created exactly once, by
/// somebody** — a controller that arrives as a parameter was created by a
/// caller this scan already reaches, so the creation is always the place where
/// the decision "what does this controller hold, and who tells the state about
/// it" was made.
///
/// The inventory is **all of `lib/`**, not the widget directories. That is the
/// structural fix `orphan_widget_check.py`'s own header records: a path filter
/// is a proxy for "is a widget", and the proxy was wrong for a third of the
/// design system. Here the proxy would have been worse still — a page under
/// `features/*/presentation/pages/` is exactly where the hand-rolled mirror
/// lives, and a scan of the widget directories would have found **none** of the
/// six defects' sites.
///
/// ## THE KEY IS A **FILE** PLUS THE **NORMALISED TEXT** OF EACH STATEMENT
///
/// The same shape `test/setstate_budget_test.dart` uses, and for the same
/// reason: a `file:line` key is brittle in the worst way — any edit above a
/// site moves it, and the gate would cry wolf on a change that changed
/// nothing. A **file** plus the **whitespace-collapsed text of each
/// statement** is stable under line shifts, and it catches all three things a
/// gate must catch: a **new** statement, a **removed** one, and an **edited**
/// one.
///
/// **And the multiset, and not a set**, because two sites can carry the same
/// text — `servant_report_page.dart`'s two declarations differ only in the
/// field's name, and a set would collapse two rows into one and let a fifth
/// slip through.
///
/// ## AND A STALE ROW IS A **FAILURE**, NOT A NOTE
///
/// The allowlist below is a **record of what was reviewed**, and a row whose
/// site has gone is a row that still permits a controller nobody has looked at
/// — and the day the site comes back it comes back unexamined. So the second
/// test below is the one that keeps the receipts honest: **every row must still
/// match the tree.**
///
/// That is what makes the servant rows **live** rather than decorative. They
/// are scheduled for migration, and the migration is the thing that makes them
/// stale — and a stale row is red, so the migration cannot land without
/// somebody looking at the row it retires.
///
/// ## FAIL-CLOSED
///
/// AGENT_CONTEXT §7, "a gate that cannot fail is worse than no gate":
///
/// - `lib/` missing → **fail**, naming the path.
/// - a file that cannot be read → **fail**, naming the file.
/// - an empty walk → **fail**. A walk that found nothing proves nothing, and a
///   count of zero over nothing is not a pass.
/// - **a matcher that stopped matching** → **fail**. The last test in the file
///   plants the five shapes a controller can take and requires the matcher to
///   see the two that create one and ignore the three that do not.
void main() {
  group('the mirrored-controller rule', () {
    test('no file outside the allowlist creates a TextEditingController', () {
      final Map<String, List<String>> found = _creationsByFile();

      // **THE GATE THAT CAN FAIL.** A scan that finds nothing is a scan whose
      // matcher has rotted, and a scan that reports a clean run over a surface
      // it no longer examines is the ADR-0020 shape. So **zero is a failure**,
      // not a pass.
      expect(
        found.values.fold<int>(0, (int sum, List<String> v) => sum + v.length),
        greaterThan(0),
        reason:
            'the scan found NO `TextEditingController` at all, which means the '
            'matcher stopped matching rather than the tree becoming clean. A '
            'gate that reports a pass over a surface it no longer examines is '
            'worse than no gate.',
      );

      final List<String> unexpected = <String>[
        for (final MapEntry<String, List<String>> entry in found.entries)
          if (!_allowlist.containsKey(entry.key))
            '${entry.key}: ${entry.value.join(' | ')}',
      ];
      expect(
        unexpected,
        isEmpty,
        reason:
            'a `TextEditingController` created outside the allowlist. A value '
            'that is mirrored into a control is mirrored by the **one** '
            'controlled field, in one direction, and a programmatic write is '
            'never reported as the reader\'s — '
            '`lib/core/design_system/widgets/eva_controlled_field.dart` is '
            'that field, and this is the rule that keeps it the only one. '
            'Unreviewed sites:\n${unexpected.join('\n')}',
      );
    });

    test('and every allowlist row still matches a site', () {
      // **A STALE ROW IS A FAILURE, and not a note.** The allowlist is a record
      // of what was reviewed; a row whose site has gone is a row that still
      // permits a controller nobody has looked at.
      final Map<String, List<String>> found = _creationsByFile();
      final List<String> stale = <String>[];
      for (final MapEntry<String, List<String>> row in _allowlist.entries) {
        final List<String> site = found[row.key] ?? const <String>[];
        if (_sameMultiset(row.value, site)) continue;
        stale.add(
          '${row.key} — allowed: ${row.value.join(' | ')} · found: '
          '${site.join(' | ')}',
        );
      }
      expect(
        stale,
        isEmpty,
        reason:
            'an allowlist row no longer matches the tree. Either the site was '
            'removed — in which case **delete the row** — or it was changed, in '
            'which case the change has to be **re-reviewed** and the row '
            'rewritten. A stale row is an amnesty nobody re-read:\n'
            '${stale.join('\n')}',
      );
    });

    test('and the allowlist is not empty, and its size is pinned', () {
      expect(
        _allowlist,
        isNotEmpty,
        reason:
            'the allowlist is empty, which would mean the gate forbids every '
            'controller in the tree — and there are **twenty-one** that are '
            'legitimate: one in the mechanism, two in the login page, and '
            'eighteen in the servant portal, which are scheduled for '
            'migration.',
      );
      final int total = _allowlist.values.fold<int>(
        0,
        (int sum, List<String> v) => sum + v.length,
      );
      expect(
        total,
        21,
        reason:
            'twenty-one reviewed sites. If this number moved, the allowlist '
            'above and the tree have drifted apart, and one of them is wrong. '
            'The servant rows go down as the portal migrates, and this number '
            'goes with them.',
      );
    });

    test('and every allowlisted file is still there', () {
      // An exemption for a file that is not there is a hole nobody reads: the
      // walk skips a path that is not in the tree, nothing complains, and the
      // exemption is invisible.
      for (final String path in _allowlist.keys) {
        expect(
          File.fromUri(packageRoot.uri.resolve(path)).existsSync(),
          isTrue,
          reason:
              '$path is allowlisted, so it must exist — an exemption for a '
              'file that is not there is a hole nobody reads',
        );
      }
    });

    test('and the login page never writes into its controllers', () {
      // **THE ONE DELIBERATE EXCEPTION'S RECEIPT, AND HALF OF IT IS
      // MECHANICAL.**
      //
      // The login page is allowed to own controllers because its form is
      // **one-way**: the reader types, the page reports, the bloc records — and
      // **nothing ever flows back**. The bloc's state is never mirrored into
      // the field, so the screen and the state cannot disagree about what the
      // reader typed.
      //
      // That is checkable, and this is the check: **the page never assigns to
      // a controller's text.** A page that mirrored the bloc's email back into
      // the field would be the servant bug in a second costume, and this is
      // the line that says it has not happened.
      const String path =
          'lib/features/auth/presentation/pages/login_page.dart';
      final File file = File.fromUri(packageRoot.uri.resolve(path));
      expect(file.existsSync(), isTrue, reason: '$path is the exception');

      final String code = withoutDartComments(file.readAsStringSync());
      final List<String> writes = <String>[
        for (final String line in code.split('\n'))
          if (_writesControllerText.hasMatch(line)) line.trim(),
      ];
      expect(
        writes,
        isEmpty,
        reason:
            '$path writes into a controller. The login page\'s form is '
            'one-way — the reader types, the page reports, the bloc records, '
            'and the state is never mirrored back into the field — and an '
            'assignment to a controller\'s text is the mirror. The page is '
            'also the one place the state is cleared on every mount '
            '(`AuthStarted` emits a fresh `AuthState`, and the page\'s two '
            'controllers are created empty), so the screen and the state start '
            'in agreement and only the reader\'s own keystroke moves either. '
            'Offending lines:\n${writes.join('\n')}',
      );
    });

    test('and the matcher sees a controller when there is one', () {
      // The anti-vacuity for the matcher itself, in the file that depends on
      // it most. **A scan whose pattern stopped matching reports a clean
      // tree**, and the first test above would then pass over a surface it no
      // longer examines.
      //
      // Five shapes, and the five answers: two create a controller and three
      // only mention one.
      for (final String creation in const <String>[
        'final TextEditingController _x = TextEditingController();',
        'TextEditingController.fromValue(const TextEditingValue(text: \'x\'));',
      ]) {
        expect(
          _creationsIn(creation),
          isNotEmpty,
          reason: 'a controller is created here, and the scan must see it',
        );
      }

      for (final String mention in const <String>[
        // A parameter — the caller's controller, which this file did not make.
        'final TextEditingController controller;',
        // A helper's parameter.
        'void _write(TextEditingController controller, String value) {}',
        // A list of controllers, built to dispose them.
        'List<TextEditingController> get _controllers => <TextEditingController>[];',
      ]) {
        expect(
          _creationsIn(mention),
          isEmpty,
          reason:
              'this mentions a controller and creates none, and a scan that '
              'counted mentions would report a site that is not there',
        );
      }

      // **And a doc comment is not a creation**, because the comment stripper
      // runs first — the same reason the focus-ring gate strips before it
      // asks.
      expect(
        _creationsIn(
          '/// A controller like `TextEditingController()` is made '
          'by the caller.',
        ),
        isEmpty,
        reason: 'prose about a controller is not a controller',
      );
    });
  });
}

/// A controller **creation** — the constructor, with or without a named one.
///
/// **The type on its own is not a creation**, and that is the whole
/// distinction: `final TextEditingController controller;` is a parameter, and
/// `List<TextEditingController>` is a type.
final RegExp _creation = RegExp(r'\bTextEditingController\s*(?:\.\w+\s*)?\(');

/// An assignment to a controller's text — the mirror, written down.
///
/// **`\.text\s*=` and not `=` alone**, because a page that *reads* a
/// controller's text is doing the ordinary thing: the login page reads both
/// of its controllers on every keystroke.
final RegExp _writesControllerText = RegExp(r'\.text\s*=(?!=)');

/// The creation sites in [source], as whitespace-collapsed lines.
List<String> _creationsIn(String source) => <String>[
  for (final String line in withoutDartComments(source).split('\n'))
    if (_creation.hasMatch(line)) line.replaceAll(RegExp(r'\s+'), ''),
];

/// The controller creations in every file of `lib/`, by file.
///
/// **The statements are the matched line, whitespace-collapsed** — the same
/// key `test/setstate_budget_test.dart` uses, and for the same reason: it is
/// stable under line shifts and it catches a new statement, a removed one and
/// an edited one alike.
Map<String, List<String>> _creationsByFile() {
  final Directory lib = Directory.fromUri(packageRoot.uri.resolve('lib/'));
  if (!lib.existsSync()) {
    throw StateError(
      'lib/ does not exist — the scan would find nothing and report a clean '
      'run over a surface it never examined',
    );
  }

  final List<File> files = <File>[];
  try {
    files.addAll(<File>[
      for (final FileSystemEntity entity in lib.listSync(
        recursive: true,
        followLinks: false,
      ))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ]);
  } on FileSystemException catch (error) {
    throw StateError('lib/ could not be walked: ${error.message}');
  }
  if (files.isEmpty) {
    throw StateError(
      'the walk found no .dart file under lib/. That is not a clean tree.',
    );
  }

  final Map<String, List<String>> found = <String, List<String>>{};
  for (final File file in files) {
    if (_generated.contains(_fileName(file))) continue;
    final List<String> statements = _creationsIn(file.readAsStringSync());
    if (statements.isNotEmpty) {
      found[packageRelative(file.uri)] = statements;
    }
  }
  return found;
}

/// Whether two multisets of statements are the same.
///
/// **Sorted, and compared element by element** — and *not* as sets, because
/// two sites can carry the same text and a set would collapse them.
bool _sameMultiset(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final List<String> sortedA = List<String>.of(a)..sort();
  final List<String> sortedB = List<String>.of(b)..sort();
  for (int i = 0; i < sortedA.length; i++) {
    if (sortedA[i] != sortedB[i]) return false;
  }
  return true;
}

/// The generated files, which are the framework's and the generator's and not
/// the tree's.
const Set<String> _generated = <String>{
  '.freezed.dart',
  '.gr.dart',
  '.config.dart',
};

String _fileName(File file) {
  final String path = file.path;
  final int slash = path.lastIndexOf('/');
  return slash == -1 ? path : path.substring(slash + 1);
}

/// The reviewed sites, and why each is legitimate.
///
/// **Every row's reason is the same question**: *is this controller mirroring a
/// value the state holds?* If yes, it belongs to the controlled field. If no,
/// it has to say why it is not mirroring one — and the answer has to be
/// checkable, or it is a claim.
const Map<String, List<String>> _allowlist = <String, List<String>>{
  // ## THE **MECHANISM** — the one controlled field, and the only place in the
  // tree where a controller may be created on purpose.
  //
  // It owns its controller, it fills it from the state's value, and it reports
  // **only the reader's input**. A write it makes on purpose is never reported
  // as the reader's, because the comparison is against the controlled value and
  // the controlled value is the only thing it ever writes.
  'lib/core/design_system/widgets/eva_controlled_field.dart': <String>[
    '_controller=TextEditingController(text:widget.value);',
  ],

  // ## THE **ONE DELIBERATE EXCEPTION** — the login page.
  //
  // **WHY IT IS SAFE, IN TWO PARTS.** The first is mechanical and is checked
  // by the test above: **the page never writes into its controllers.** Its
  // form is one-way — the reader types, the page reports, the bloc records —
  // and the bloc's state is never mirrored back into the field, so the screen
  // and the state cannot disagree about what the reader typed. There is no
  // mirror to get wrong, and therefore none of the six defects can happen
  // here.
  //
  // The second is the mount. **The state is cleared on every path that
  // unmounts the page, and the page's two controllers are created empty** — so
  // the screen and the state start every mount in agreement, and the only
  // thing that moves either of them afterwards is the reader's own keystroke.
  // `LoginPage.build` dispatches `AuthStarted` on every build, and
  // `AuthBloc._onStarted` emits a **fresh** `AuthState` in both of its arms —
  // the signed-out one and the signed-in one — and a fresh `AuthState` holds
  // an empty email and an empty password. The page's own doc says the same
  // thing about the controller: "This widget never creates one from the bloc's
  // text, so a rebuild of the state does not overwrite a character the reader
  // is in the middle of typing."
  //
  // **It is a coincidence, not a design** — which is why it is an *exception
  // with a receipt* rather than a pattern, and why the receipt is checked
  // rather than asserted in a paragraph.
  'lib/features/auth/presentation/pages/login_page.dart': <String>[
    'finalTextEditingController_email=TextEditingController();',
    'finalTextEditingController_password=TextEditingController();',
  ],

  // ## THE **SERVANT PORTAL**, AND THESE ROWS ARE **SCHEDULED FOR MIGRATION**.
  //
  // **The three pages and the one widget below still hand-roll their
  // controllers**, and the hand-rolled version is what produced six defects of
  // one class (decision 188). Their migration to the controlled field is a
  // **separate task**, and until it lands these rows are what keeps the tree
  // legal.
  //
  // **THEY ARE NOT DECORATIVE.** A row that no longer matches its site is a
  // **failure**, not a note — the same rule `test/setstate_budget_test.dart`
  // applies to its `setState` rows — so the migration cannot land without
  // somebody looking at the row it retires, and a controller that somebody
  // adds to one of these files without a review turns the gate red.
  //
  // **What each site is**, so a reader can recognise the next one:
  //
  // - `schedule_reading_page.dart` — the scheduling form: the cohort, the day,
  //   the passage's book, chapters, verses and the excluded passages. **The
  //   server's insert is `ON CONFLICT (group_id, scheduled_date) DO UPDATE`**,
  //   so scheduling the same cohort and date again **replaces** the cohort's
  //   passage. A form that shows the admin an empty passage while the state
  //   holds one sends a passage nobody can see.
  // - `question_authoring_page.dart` — the question editor: the reading id,
  //   the Arabic and English prompts, the correct answer, the points and the
  //   sort order. **The editor's own write of the state's `pointsText` into a
  //   controller that started empty is defect #1** — it arrived at the cubit
  //   as an edit the reader had made, and the cubit's edit writer dropped the
  //   server's failure with it.
  // - `servant_report_page.dart` — the report's form: the cohort and the day.
  //   **Its seed is defect #4**: the seed reported the two controllers'
  //   contents at mount, the controllers start empty, and the servant's cohort
  //   and day were wiped along with the roster they had loaded.
  // - `question_option_editor.dart` — one answer option's two lines. It is a
  //   **widget**, not a page, and it is the fourth site rather than the third:
  //   the option is a **pair** (`{ar, en}` in the commit body), and a pair of
  //   fields that lived in different places would need the page to hold two
  //   controllers per option and to know which letter each pair belongs to.
  'lib/features/servant/presentation/pages/schedule_reading_page.dart':
      <String>[
        'finalTextEditingController_groupIds=TextEditingController();',
        'finalTextEditingController_date=TextEditingController();',
        'finalTextEditingController_book=TextEditingController();',
        'finalTextEditingController_startChapter=TextEditingController();',
        'finalTextEditingController_startVerse=TextEditingController();',
        'finalTextEditingController_endChapter=TextEditingController();',
        'finalTextEditingController_endVerse=TextEditingController();',
        'finalTextEditingController_excluded=TextEditingController();',
      ],
  'lib/features/servant/presentation/pages/question_authoring_page.dart':
      <String>[
        'finalTextEditingController_readingId=TextEditingController();',
        'finalTextEditingController_promptAr=TextEditingController();',
        'finalTextEditingController_promptEn=TextEditingController();',
        'finalTextEditingController_correctAnswer=TextEditingController();',
        'finalTextEditingController_points=TextEditingController();',
        'finalTextEditingController_sortOrder=TextEditingController();',
      ],
  'lib/features/servant/presentation/pages/servant_report_page.dart': <String>[
    'finalTextEditingController_group=TextEditingController();',
    'finalTextEditingController_date=TextEditingController();',
  ],
  'lib/features/servant/presentation/widgets/question_option_editor.dart':
      <String>[
        'finalTextEditingController_arabic=TextEditingController();',
        'finalTextEditingController_english=TextEditingController();',
      ],
};
