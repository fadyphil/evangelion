import 'dart:io';

/// One `name: value` declaration, and the selector that owns it.
///
/// The selector is not decoration. `eva/redesign.html` declares `--gold` twice —
/// once in `:root` and once under `.screen[data-mode=light]` — and the two hold
/// different colours. A resolver that returned one value per token name would be
/// wrong for every token the light mode overrides, so the scope travels with the
/// declaration and a lookup states which scope it is asking about.
class CssDeclaration {
  const CssDeclaration({
    required this.name,
    required this.value,
    required this.selector,
    required this.line,
  });

  /// The custom property, without the leading `--`.
  final String name;

  /// The declared value, verbatim and un-resolved. May itself be `var(--other)`.
  final String value;

  /// The selector that owns this declaration, trimmed. `:root` for the base palette.
  final String selector;

  /// 1-based line the declaration is on, so a failure can be cited.
  final int line;

  @override
  String toString() => '$selector { $name: $value }  (line $line)';
}

/// A parsed CSS custom-property table, with `var()` resolution.
///
/// ## Why this exists
///
/// The redesigned reference at `eva/redesign.html` is token-driven: 264
/// `var(--token)` call sites against 210 literal declarations. The geometry
/// harnesses work by extracting `property: <number>` at a call site and asserting
/// the cited line still declares that number. Against this design most call sites
/// have **no number to extract** — the value lives in a `:root` definition, and the
/// call site says `width: var(--card-w)`.
///
/// So the harness model has to change from "read a number off the line" to
/// "read the value off the line, then resolve the tokens in it". That is this
/// class.
///
/// ## What it refuses to do
///
/// It never guesses. An unknown token, an unclosed `var(`, or a cycle all
/// resolve to `null` rather than to a plausible value, because a plausible value
/// here would be a transcribed number that the design does not actually contain —
/// the defect the harnesses exist to prevent. Every one of those is counted by
/// [unresolvedTokens] so "it returned null" and "it was never asked" are different
/// answers.
class CssReference {
  CssReference._(this.lines, this.declarations, this.path);

  /// The source, split so a line number means what a citation means.
  final List<String> lines;

  /// Every custom-property declaration in source order, grouped by name.
  final Map<String, List<CssDeclaration>> declarations;

  /// Where this came from, for error messages.
  final String path;

  /// The deepest `var()` chain followed before giving up.
  ///
  /// Eight is not arbitrary and not a guess. The deepest chain in
  /// `redesign.html` is one (`--glass-fill` to a literal), so eight is room for
  /// a real chain with room to spare, while staying far below anything that could
  /// turn a cycle into a hang. A cycle is detected by [seen], not by this — see
  /// [resolveValue].
  static const int maxDepth = 8;

  /// Reads and parses a file. Returns `null` if it cannot be read, so a caller
  /// can report a missing reference rather than an empty table.
  static CssReference? fromFile(File file) {
    final List<String> source;
    try {
      source = file.readAsLinesSync();
    } on Object {
      return null;
    }
    return parse(source.join('\n'), path: file.path);
  }

  /// Parses CSS source. [path] is used only in messages.
  static CssReference parse(String source, {String? path}) {
    final List<String> lines = source.split('\n');
    final Map<String, List<CssDeclaration>> byToken =
        <String, List<CssDeclaration>>{};
    final Map<String, List<String>> defaults =
        <String, List<String>>{}; // token -> comma-split defaults

    String selector = ':root';
    // A `<script>` body is JavaScript. `eva/redesign.html` sets several custom
    // properties at runtime — `el.style.setProperty('--tw', ...)` — and without
    // this the table recorded `--tw: ${3+Math.random()*4}` under a selector parsed
    // out of the surrounding JavaScript. That is not a CSS declaration, it is
    // JavaScript that happens to look like one, and every call site using it
    // carries a fallback anyway.
    bool inScript = false;
    // Depth 0 is outside any block. `{` opens a block and `}` closes one; the
    // selector is whatever preceded the innermost `{`.
    int depth = 0;
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];

      // `<script>` and `</script>` are the only two lines that flip this. The
      // body between them is JavaScript, and the custom properties it assigns at
      // runtime are not declarations this table can honestly report.
      if (RegExp(r'<script\b').hasMatch(line)) inScript = true;
      if (RegExp(r'</script>').hasMatch(line)) inScript = false;

      // Attribute selectors contain `[` and `]` but no `{`, so they are safe to
      // read with this. An inline `style="--x:1"` in the markup is NOT CSS, and
      // the only shape that produces it is an HTML style attribute — matched on
      // `style=` specifically, because an earlier guard matched any `=` and that
      // silently discarded every CSS attribute selector, including
      // `.screen[data-mode=light]`, which is where the light palette lives.
      for (final RegExpMatch open in RegExp(r'([^{}]+)\{').allMatches(line)) {
        final String candidate = open.group(1)!.trim();
        if (candidate.isEmpty || candidate.startsWith('@')) continue;
        if (RegExp(r'\bstyle\s*=').hasMatch(candidate)) continue;
        selector = candidate;
      }
      depth += '{'.allMatches(line).length;
      depth -= '}'.allMatches(line).length;
      if (depth < 0) depth = 0;
      if (inScript) continue;

      // A `style="--x: v"` attribute on an HTML element is an INSTANCE value, not
      // a token definition. `redesign.html` sets `--bh` this way on four audit
      // spans, and three other rules read `var(--bh)` with no fallback — so
      // recording the inline value put a real-looking colour in the table and
      // those three call sites resolved to it instead of reporting that the value
      // is per-element. A harness citing one of them would have asserted against a
      // value no rule in the file actually declares.
      if (RegExp(r'''style\s*=\s*["']''').hasMatch(line)) continue;

      final RegExp decl = RegExp(r'(--[A-Za-z0-9_-]+)\s*:\s*([^;}]+)');
      for (final RegExpMatch m in decl.allMatches(line)) {
        final String name = m.group(1)!.substring(2);
        final String value = m.group(2)!.trim();
        (byToken[name] ??= <CssDeclaration>[]).add(
          CssDeclaration(
            name: name,
            value: value,
            selector: selector,
            line: i + 1,
          ),
        );
      }
      // `var(--x, 12px)` supplies a default. Recorded per token so resolution can
      // use it when the token is undefined, which is what CSS does.
      final RegExp fallback = RegExp(r'var\(\s*(--[A-Za-z0-9_-]+)\s*,');
      for (final RegExpMatch m in fallback.allMatches(line)) {
        (defaults[m.group(1)!.substring(2)] ??= <String>[]).add(line);
      }
    }
    return CssReference._(lines, byToken, path ?? '<source>');
  }

  /// The raw declared value of [name] under [scope], or `null` if it has none.
  ///
  /// [scope] of `null` means the base palette, so a lookup for `--gold` with no
  /// scope returns the `:root` value. A scoped lookup prefers a declaration owned
  /// by exactly that selector and falls back to the base, which is what the
  /// cascade does here: `.screen[data-mode=light]` sets nine tokens and inherits
  /// the rest from `:root`.
  CssDeclaration? declaration(String name, {String? scope}) {
    final List<CssDeclaration>? all = declarations[name];
    if (all == null || all.isEmpty) return null;
    if (scope != null) {
      for (final CssDeclaration d in all) {
        if (d.selector == scope) return d;
      }
    }
    for (final CssDeclaration d in all) {
      if (d.selector == ':root') return d;
    }
    return all.first;
  }

  /// Resolves every `var(--x)` in [raw] to its value, recursively.
  ///
  /// Returns `null` — never a partial answer — when a token is undefined with no
  /// fallback, a `var(` is unclosed, or the chain cycles. [seen] is the cycle
  /// guard, and it is the **path**, not a set of everything seen.
  ///
  /// That distinction was a bug before it was a comment. A set shared across
  /// sibling references reports a token used twice in one value as a cycle — and
  /// `.route` in `redesign.html` writes `var(--e-light)` four times on one line,
  /// so every whole-line resolution returned null. A cycle is a token appearing in
  /// its own resolution chain, so each branch gets its own copy of the path and
  /// only an ancestor is a cycle.
  String? resolveValue(
    String raw, {
    String? scope,
    Set<String>? seen,
    int depth = 0,
  }) {
    if (depth > maxDepth) return null;
    final Set<String> path = seen ?? <String>{};

    final RegExp ref = RegExp(
      r'var\(\s*(--[A-Za-z0-9_-]+)\s*'
      r'(?:,\s*([^()]*))?\)',
    );
    if (!ref.hasMatch(raw)) return raw;

    final List<String> out = <String>[];
    int cursor = 0;
    for (final RegExpMatch m in ref.allMatches(raw)) {
      out.add(raw.substring(cursor, m.start));
      final String token = m.group(1)!.substring(2);
      if (path.contains(token)) return null; // cycle: already on this chain

      final CssDeclaration? d = declaration(token, scope: scope);
      if (d == null) {
        // An undefined token is legal CSS ONLY when a fallback is supplied.
        // Without one there is no value at all, and returning an empty string
        // here would be a guess wearing the costume of an answer: the caller
        // would resolve a width to '' and read that as "not a number, skip it",
        // rather than as "this design does not contain the thing you cited".
        final String? fallback = m.group(2)?.trim();
        if (fallback == null) return null;
        out.add(fallback);
      } else {
        final String? nested = resolveValue(
          d.value,
          scope: scope,
          seen: <String>{...path, token},
          depth: depth + 1,
        );
        if (nested == null) return null;
        out.add(nested);
      }
      cursor = m.end;
    }
    out.add(raw.substring(cursor));
    return out.join();
  }

  /// The numeric value declared for [property] on 1-based [line], with any
  /// `var()` in it resolved first.
  ///
  /// Returns `null` when the line declares nothing for that property, when the
  /// value is not a number after resolution, or when resolution failed. It does
  /// not fall back to a neighbouring declaration, because a claim that names a
  /// line is a claim about that line.
  double? numericAt(int line, String property, {String? scope}) {
    if (line < 1 || line > lines.length) return null;
    final RegExp decl = RegExp('${RegExp.escape(property)}\\s*:\\s*([^;}]+)');
    final RegExpMatch? m = decl.firstMatch(lines[line - 1]);
    if (m == null) return null;
    final String? resolved = resolveValue(m.group(1)!.trim(), scope: scope);
    if (resolved == null) return null;
    final RegExp num = RegExp(r'-?\d+(?:\.\d+)?');
    final RegExpMatch? n = num.firstMatch(resolved);
    if (n == null) return null;
    return double.tryParse(n.group(0)!);
  }

  /// Every `var(--x)` in the source whose token is undefined **and** has no
  /// fallback, as `token` strings. An empty list is the only clean answer.
  List<String> unresolvedTokens() {
    final List<String> out = <String>[];
    for (final String line in lines) {
      for (final RegExpMatch m in RegExp(
        r'var\(\s*(--[A-Za-z0-9_-]+)\s*\)',
      ).allMatches(line)) {
        final String name = m.group(1)!.substring(2);
        if (!declarations.containsKey(name)) out.add(name);
      }
    }
    return out.toSet().toList()..sort();
  }

  /// Every token name the source declares, sorted. Used to assert the table is
  /// not silently empty, which is the vacuous-pass shape this whole class exists
  /// to avoid.
  List<String> tokenNames() {
    final List<String> names = declarations.keys.toList()..sort();
    return names;
  }
}
