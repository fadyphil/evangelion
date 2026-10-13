import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// One lit verse in the witness sky.
///
/// Red-first per AGENT_CONTEXT §6 ("domain entities"). The three properties
/// that make this file more than a field list are all about **identity versus
/// position**, because that is the one place a starfield is wrong in a way a
/// reader sees: two readings of the same verse must produce one entry, while
/// the constellation still follows lit-event order.
void main() {
  group('`key` names the verse, not the reading', () {
    test('formats as `book:chapter:verse`', () {
      // The `book:chapter:verse` key is the unit `addStar` counts in
      // `eva/redesign.html:1131-1133` (the `POSRANGE`/defaults/cap context the
      // starfield lives in): one key, one star, whatever lit it.
      final SkyEntry entry = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: lit(1),
      );
      expect(entry.key, 'John:3:16');
    });

    test('and two readings of the same verse share it', () {
      final SkyEntry first = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: lit(1),
      );
      final SkyEntry second = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: lit(2),
      );
      expect(second.key, first.key);
    });

    test('while a different verse is a different key', () {
      final SkyEntry entry = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: lit(1),
      );
      expect(
        SkyEntry(book: 'John', chapter: 3, verse: 17, litAt: lit(2)).key,
        isNot(entry.key),
      );
    });
  });

  group('`isFlare` defaults to an ordinary star', () {
    test('a verse read lights `addStar(false)`', () {
      // `eva/redesign.html:1217` — the scroll-into-view read lights an ordinary
      // star. The flare is reserved for the three celebrated moments:
      // `:1123` (cheer), `:1330` (amen, the finished reading) and `:1428`
      // (a correct quiz answer), drawn with the `:124` flare keyframes.
      final SkyEntry entry = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 1,
        litAt: lit(1),
      );
      expect(entry.isFlare, isFalse);
    });
  });

  group('equality is freezed-generated from the constructor', () {
    test('two identical entries are equal and are two objects', () {
      // `identical(…, isFalse)` first: two identically-written constant
      // expressions are canonicalised by Dart into one instance and
      // `expect(a, b)` would then pass against any `==`, including a broken
      // one. The `lit(…)` helper below is what keeps both constructions
      // non-constant — the same trick `user_settings_test.dart`'s `step()`
      // plays for the same reason.
      final SkyEntry a = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: lit(1),
      );
      final SkyEntry b = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: lit(1),
      );
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('and `copyWith()` with no argument is identity', () {
      final SkyEntry base = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: lit(1),
      );
      expect(base.copyWith(), base);
    });

    test('a re-lit verse is NOT `==`: dedupe is the repository, not `==`', () {
      // `litAt` and `isFlare` stay inside `==` deliberately — freezed offers no
      // per-field exclusion (AGENT_CONTEXT §2.1 hazard 2), and excluding them
      // would make "lit twice" and "lit once, then flared" indistinguishable
      // to every `switch` and `contains` that holds entries. "Two readings of
      // the same verse produce one entry" is therefore a *repository* property
      // (stored by [key], first lit wins the position, flare upgrades in
      // place and never downgrades), and this is the test that holds the boundary: the entity says
      // "different", the repository says "one".
      final SkyEntry first = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: lit(1),
      );
      final SkyEntry relit = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: lit(2),
      );
      expect(relit, isNot(first));
    });
  });

  group('`litAt` is the audit stamp, not the sort key', () {
    test('a flare upgrade keeps the first instant', () {
      // The entity half of the repository's monotone upgrade: `copyWith`
      // carries `litAt` untouched, so brightening a star cannot move it in
      // time either.
      final SkyEntry litEntry = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 16,
        litAt: lit(1),
      );
      final SkyEntry flared = litEntry.copyWith(isFlare: true);
      expect(flared.isFlare, isTrue);
      expect(flared.litAt, lit(1));
      expect(flared.key, litEntry.key);
    });

    test('and instants are per-entry data, never a sequence', () {
      // Order is the repository's lit-event order — the sequence of `record`
      // calls — so two entries may carry out-of-chronological instants
      // without anything being wrong: `/reading` lights on scroll, and verse
      // 20 can light before verse 5 is recorded. Each entry just carries its
      // own stamp verbatim.
      final SkyEntry twentieth = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 20,
        litAt: lit(20),
      );
      final SkyEntry fifth = SkyEntry(
        book: 'John',
        chapter: 3,
        verse: 5,
        litAt: lit(10),
      );
      expect(twentieth.litAt, lit(20));
      expect(fifth.litAt, lit(10));
      expect(twentieth, isNot(fifth));
    });
  });
}

/// A lit instant reached through a call, so an entry built from it is not a
/// constant expression and cannot be canonicalised against another.
///
/// The same trick `user_settings_test.dart`'s `step()` plays, and for the same
/// reason: `prefer_const_constructors` pushes a test towards `const`, and
/// `const` is exactly what makes `expect(a, b)` vacuous.
DateTime lit(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
