import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/login_harness.dart';

void main() {
  testWidgets(
    'the login page keeps its RenderBox size across pumps once the email '
    'field is focused',
    (WidgetTester tester) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        AuthLocalDataSource(),
      );
      final AuthBloc bloc = AuthBloc(
        signIn: SignIn(repository),
        getCurrentSession: GetCurrentSession(repository),
        signOut: SignOut(repository),
      );
      addTearDown(bloc.close);

      await pumpLogin(tester, bloc: bloc);
      await tester.pump(const Duration(milliseconds: 1200));

      // Focus the email field so the caret is blinking — the state the reported
      // frame cost was measured in.
      await tester.tap(find.byType(TextField).at(0));
      await tester.pump();

      final RenderBox pageBox =
          tester.renderObject(find.byType(LoginPage)) as RenderBox;
      final Size baseline = pageBox.size;

      for (int i = 0; i < 10; i++) {
        await tester.pump();
        final RenderBox current =
            tester.renderObject(find.byType(LoginPage)) as RenderBox;
        expect(
          current.size,
          equals(baseline),
          reason:
              'pump $i changed the page size from $baseline to ${current.size}',
        );
      }
    },
  );
}
