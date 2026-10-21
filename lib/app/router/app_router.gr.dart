// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i13;
import 'package:evangelion/app/router/dock_shell_page.dart' as _i2;
import 'package:evangelion/core/navigation/role_access.dart' as _i23;
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart'
    as _i18;
import 'package:evangelion/features/auth/presentation/pages/login_page.dart'
    as _i5;
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart'
    as _i16;
import 'package:evangelion/features/home/presentation/pages/home_page.dart'
    as _i3;
import 'package:evangelion/features/journey/presentation/bloc/journey_cubit.dart'
    as _i17;
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart'
    as _i4;
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart'
    as _i15;
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart'
    as _i1;
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart'
    as _i20;
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart'
    as _i7;
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart'
    as _i21;
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart'
    as _i8;
import 'package:evangelion/features/servant/presentation/cubit/question_authoring_cubit.dart'
    as _i19;
import 'package:evangelion/features/servant/presentation/cubit/schedule_reading_cubit.dart'
    as _i22;
import 'package:evangelion/features/servant/presentation/cubit/servant_report_cubit.dart'
    as _i24;
import 'package:evangelion/features/servant/presentation/pages/question_authoring_page.dart'
    as _i6;
import 'package:evangelion/features/servant/presentation/pages/schedule_reading_page.dart'
    as _i9;
import 'package:evangelion/features/servant/presentation/pages/servant_home_page.dart'
    as _i10;
import 'package:evangelion/features/servant/presentation/pages/servant_report_page.dart'
    as _i11;
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart'
    as _i25;
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart'
    as _i12;
import 'package:flutter/material.dart' as _i14;

/// generated route for
/// [_i1.CommunionPage]
class CommunionRoute extends _i13.PageRouteInfo<CommunionRouteArgs> {
  CommunionRoute({
    _i14.Key? key,
    _i15.LeaderboardCubit? cubit,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         CommunionRoute.name,
         args: CommunionRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'CommunionRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CommunionRouteArgs>(
        orElse: () => const CommunionRouteArgs(),
      );
      return _i1.CommunionPage(key: args.key, cubit: args.cubit);
    },
  );
}

class CommunionRouteArgs {
  const CommunionRouteArgs({this.key, this.cubit});

  final _i14.Key? key;

  final _i15.LeaderboardCubit? cubit;

  @override
  String toString() {
    return 'CommunionRouteArgs{key: $key, cubit: $cubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CommunionRouteArgs) return false;
    return key == other.key && cubit == other.cubit;
  }

  @override
  int get hashCode => key.hashCode ^ cubit.hashCode;
}

/// generated route for
/// [_i2.DockShellPage]
class DockShellRoute extends _i13.PageRouteInfo<void> {
  const DockShellRoute({List<_i13.PageRouteInfo>? children})
    : super(DockShellRoute.name, initialChildren: children);

  static const String name = 'DockShellRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i2.DockShellPage();
    },
  );
}

/// generated route for
/// [_i3.HomePage]
class HomeRoute extends _i13.PageRouteInfo<HomeRouteArgs> {
  HomeRoute({
    _i14.Key? key,
    _i16.HomeBloc? bloc,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         HomeRoute.name,
         args: HomeRouteArgs(key: key, bloc: bloc),
         initialChildren: children,
       );

  static const String name = 'HomeRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeRouteArgs>(
        orElse: () => const HomeRouteArgs(),
      );
      return _i3.HomePage(key: args.key, bloc: args.bloc);
    },
  );
}

class HomeRouteArgs {
  const HomeRouteArgs({this.key, this.bloc});

  final _i14.Key? key;

  final _i16.HomeBloc? bloc;

  @override
  String toString() {
    return 'HomeRouteArgs{key: $key, bloc: $bloc}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HomeRouteArgs) return false;
    return key == other.key && bloc == other.bloc;
  }

  @override
  int get hashCode => key.hashCode ^ bloc.hashCode;
}

/// generated route for
/// [_i4.JourneyPage]
class JourneyRoute extends _i13.PageRouteInfo<JourneyRouteArgs> {
  JourneyRoute({
    _i14.Key? key,
    _i17.JourneyCubit? cubit,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         JourneyRoute.name,
         args: JourneyRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'JourneyRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<JourneyRouteArgs>(
        orElse: () => const JourneyRouteArgs(),
      );
      return _i4.JourneyPage(key: args.key, cubit: args.cubit);
    },
  );
}

class JourneyRouteArgs {
  const JourneyRouteArgs({this.key, this.cubit});

  final _i14.Key? key;

  final _i17.JourneyCubit? cubit;

  @override
  String toString() {
    return 'JourneyRouteArgs{key: $key, cubit: $cubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JourneyRouteArgs) return false;
    return key == other.key && cubit == other.cubit;
  }

  @override
  int get hashCode => key.hashCode ^ cubit.hashCode;
}

/// generated route for
/// [_i5.LoginPage]
class LoginRoute extends _i13.PageRouteInfo<LoginRouteArgs> {
  LoginRoute({
    _i14.Key? key,
    _i5.LoginResultCallback? onResult,
    _i18.AuthBloc? bloc,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         LoginRoute.name,
         args: LoginRouteArgs(key: key, onResult: onResult, bloc: bloc),
         initialChildren: children,
       );

  static const String name = 'LoginRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LoginRouteArgs>(
        orElse: () => const LoginRouteArgs(),
      );
      return _i5.LoginPage(
        key: args.key,
        onResult: args.onResult,
        bloc: args.bloc,
      );
    },
  );
}

class LoginRouteArgs {
  const LoginRouteArgs({this.key, this.onResult, this.bloc});

  final _i14.Key? key;

  final _i5.LoginResultCallback? onResult;

  final _i18.AuthBloc? bloc;

  @override
  String toString() {
    return 'LoginRouteArgs{key: $key, onResult: $onResult, bloc: $bloc}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoginRouteArgs) return false;
    return key == other.key && onResult == other.onResult && bloc == other.bloc;
  }

  @override
  int get hashCode => key.hashCode ^ onResult.hashCode ^ bloc.hashCode;
}

/// generated route for
/// [_i6.QuestionAuthoringPage]
class QuestionAuthoringRoute
    extends _i13.PageRouteInfo<QuestionAuthoringRouteArgs> {
  QuestionAuthoringRoute({
    _i14.Key? key,
    _i19.QuestionAuthoringCubit? cubit,
    String? readingId,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         QuestionAuthoringRoute.name,
         args: QuestionAuthoringRouteArgs(
           key: key,
           cubit: cubit,
           readingId: readingId,
         ),
         initialChildren: children,
       );

  static const String name = 'QuestionAuthoringRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<QuestionAuthoringRouteArgs>(
        orElse: () => const QuestionAuthoringRouteArgs(),
      );
      return _i6.QuestionAuthoringPage(
        key: args.key,
        cubit: args.cubit,
        readingId: args.readingId,
      );
    },
  );
}

class QuestionAuthoringRouteArgs {
  const QuestionAuthoringRouteArgs({this.key, this.cubit, this.readingId});

  final _i14.Key? key;

  final _i19.QuestionAuthoringCubit? cubit;

  final String? readingId;

  @override
  String toString() {
    return 'QuestionAuthoringRouteArgs{key: $key, cubit: $cubit, readingId: $readingId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QuestionAuthoringRouteArgs) return false;
    return key == other.key &&
        cubit == other.cubit &&
        readingId == other.readingId;
  }

  @override
  int get hashCode => key.hashCode ^ cubit.hashCode ^ readingId.hashCode;
}

/// generated route for
/// [_i7.QuizPage]
class QuizRoute extends _i13.PageRouteInfo<QuizRouteArgs> {
  QuizRoute({
    _i14.Key? key,
    _i20.QuizBloc? bloc,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         QuizRoute.name,
         args: QuizRouteArgs(key: key, bloc: bloc),
         initialChildren: children,
       );

  static const String name = 'QuizRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<QuizRouteArgs>(
        orElse: () => const QuizRouteArgs(),
      );
      return _i7.QuizPage(key: args.key, bloc: args.bloc);
    },
  );
}

class QuizRouteArgs {
  const QuizRouteArgs({this.key, this.bloc});

  final _i14.Key? key;

  final _i20.QuizBloc? bloc;

  @override
  String toString() {
    return 'QuizRouteArgs{key: $key, bloc: $bloc}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QuizRouteArgs) return false;
    return key == other.key && bloc == other.bloc;
  }

  @override
  int get hashCode => key.hashCode ^ bloc.hashCode;
}

/// generated route for
/// [_i8.ReadingPage]
class ReadingRoute extends _i13.PageRouteInfo<ReadingRouteArgs> {
  ReadingRoute({
    _i14.Key? key,
    _i21.ReadingCubit? cubit,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         ReadingRoute.name,
         args: ReadingRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'ReadingRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReadingRouteArgs>(
        orElse: () => const ReadingRouteArgs(),
      );
      return _i8.ReadingPage(key: args.key, cubit: args.cubit);
    },
  );
}

class ReadingRouteArgs {
  const ReadingRouteArgs({this.key, this.cubit});

  final _i14.Key? key;

  final _i21.ReadingCubit? cubit;

  @override
  String toString() {
    return 'ReadingRouteArgs{key: $key, cubit: $cubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ReadingRouteArgs) return false;
    return key == other.key && cubit == other.cubit;
  }

  @override
  int get hashCode => key.hashCode ^ cubit.hashCode;
}

/// generated route for
/// [_i9.ScheduleReadingPage]
class ScheduleReadingRoute
    extends _i13.PageRouteInfo<ScheduleReadingRouteArgs> {
  ScheduleReadingRoute({
    _i14.Key? key,
    _i22.ScheduleReadingCubit? cubit,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         ScheduleReadingRoute.name,
         args: ScheduleReadingRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'ScheduleReadingRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ScheduleReadingRouteArgs>(
        orElse: () => const ScheduleReadingRouteArgs(),
      );
      return _i9.ScheduleReadingPage(key: args.key, cubit: args.cubit);
    },
  );
}

class ScheduleReadingRouteArgs {
  const ScheduleReadingRouteArgs({this.key, this.cubit});

  final _i14.Key? key;

  final _i22.ScheduleReadingCubit? cubit;

  @override
  String toString() {
    return 'ScheduleReadingRouteArgs{key: $key, cubit: $cubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ScheduleReadingRouteArgs) return false;
    return key == other.key && cubit == other.cubit;
  }

  @override
  int get hashCode => key.hashCode ^ cubit.hashCode;
}

/// generated route for
/// [_i10.ServantHomePage]
class ServantHomeRoute extends _i13.PageRouteInfo<ServantHomeRouteArgs> {
  ServantHomeRoute({
    _i14.Key? key,
    _i23.RoleAccess? roleAccess,
    void Function(String)? onOpenRoute,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         ServantHomeRoute.name,
         args: ServantHomeRouteArgs(
           key: key,
           roleAccess: roleAccess,
           onOpenRoute: onOpenRoute,
         ),
         initialChildren: children,
       );

  static const String name = 'ServantHomeRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ServantHomeRouteArgs>(
        orElse: () => const ServantHomeRouteArgs(),
      );
      return _i10.ServantHomePage(
        key: args.key,
        roleAccess: args.roleAccess,
        onOpenRoute: args.onOpenRoute,
      );
    },
  );
}

class ServantHomeRouteArgs {
  const ServantHomeRouteArgs({this.key, this.roleAccess, this.onOpenRoute});

  final _i14.Key? key;

  final _i23.RoleAccess? roleAccess;

  final void Function(String)? onOpenRoute;

  @override
  String toString() {
    return 'ServantHomeRouteArgs{key: $key, roleAccess: $roleAccess, onOpenRoute: $onOpenRoute}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ServantHomeRouteArgs) return false;
    return key == other.key && roleAccess == other.roleAccess;
  }

  @override
  int get hashCode => key.hashCode ^ roleAccess.hashCode;
}

/// generated route for
/// [_i11.ServantReportPage]
class ServantReportRoute extends _i13.PageRouteInfo<ServantReportRouteArgs> {
  ServantReportRoute({
    _i14.Key? key,
    _i24.ServantReportCubit? cubit,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         ServantReportRoute.name,
         args: ServantReportRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'ServantReportRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ServantReportRouteArgs>(
        orElse: () => const ServantReportRouteArgs(),
      );
      return _i11.ServantReportPage(key: args.key, cubit: args.cubit);
    },
  );
}

class ServantReportRouteArgs {
  const ServantReportRouteArgs({this.key, this.cubit});

  final _i14.Key? key;

  final _i24.ServantReportCubit? cubit;

  @override
  String toString() {
    return 'ServantReportRouteArgs{key: $key, cubit: $cubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ServantReportRouteArgs) return false;
    return key == other.key && cubit == other.cubit;
  }

  @override
  int get hashCode => key.hashCode ^ cubit.hashCode;
}

/// generated route for
/// [_i12.SettingsPage]
class SettingsRoute extends _i13.PageRouteInfo<SettingsRouteArgs> {
  SettingsRoute({
    _i14.Key? key,
    _i25.SettingsCubit? cubit,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         SettingsRoute.name,
         args: SettingsRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'SettingsRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingsRouteArgs>(
        orElse: () => const SettingsRouteArgs(),
      );
      return _i12.SettingsPage(key: args.key, cubit: args.cubit);
    },
  );
}

class SettingsRouteArgs {
  const SettingsRouteArgs({this.key, this.cubit});

  final _i14.Key? key;

  final _i25.SettingsCubit? cubit;

  @override
  String toString() {
    return 'SettingsRouteArgs{key: $key, cubit: $cubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SettingsRouteArgs) return false;
    return key == other.key && cubit == other.cubit;
  }

  @override
  int get hashCode => key.hashCode ^ cubit.hashCode;
}
