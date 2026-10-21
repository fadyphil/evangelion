import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:evangelion/features/servant/presentation/widgets/roster_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../servant_harness.dart';

/// One child on the roster.
const RosterStudent student = RosterStudent(
  userId: '11111111-1111-1111-1111-111111111111',
  fullName: 'David Mina',
  preferredLang: 'en',
  totalPoints: 120,
  currentStreak: 4,
  pointsEarnedToday: 10,
  completedToday: true,
  questionsProgress: '3/5',
);

void main() {
  group('the roster row', () {
    testWidgets('shows the name, the points, the streak and the progress', (
      WidgetTester tester,
    ) async {
      await pumpServant(tester, const RosterRow(student: student));

      expect(find.text('David Mina'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets("shows the server's own progress token, verbatim", (
      WidgetTester tester,
    ) async {
      await pumpServant(tester, const RosterRow(student: student));

      // **The string is the server's**, and it is not re-parsed into two
      // numbers: `admin.routes.ts:412` writes `` `${answeredQ}/${totalQ}` ``.
      expect(find.text('3/5'), findsOneWidget);
      // And the two numbers beside it are the client's own, so they are drawn
      // through the arm's numerals.
      expect(find.text('3'), findsNothing);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('and the Arabic arm draws Arabic-Indic numerals', (
      WidgetTester tester,
    ) async {
      await pumpServant(
        tester,
        const RosterRow(student: student),
        locale: const Locale('ar'),
      );

      // **The two numbers are converted; the progress string is not.** The
      // server's token is the server's token, in whichever script it was
      // written in.
      expect(find.text('١٢٠'), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
    });
  });
}
