// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i9;
import 'package:evangelion/core/domain/entities/submit_result.dart' as _i17;
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart'
    as _i14;
import 'package:evangelion/features/auth/presentation/pages/login_page.dart'
    as _i4;
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart'
    as _i12;
import 'package:evangelion/features/home/presentation/pages/home_page.dart'
    as _i2;
import 'package:evangelion/features/journey/presentation/bloc/journey_cubit.dart'
    as _i13;
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart'
    as _i3;
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart'
    as _i11;
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart'
    as _i1;
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart'
    as _i15;
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart'
    as _i5;
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart'
    as _i16;
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart'
    as _i6;
import 'package:evangelion/features/result/presentation/pages/result_page.dart'
    as _i7;
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart'
    as _i18;
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart'
    as _i8;
import 'package:flutter/material.dart' as _i10;

/// generated route for
/// [_i1.CommunionPage]
class CommunionRoute extends _i9.PageRouteInfo<CommunionRouteArgs> {
  CommunionRoute({
    _i10.Key? key,
    _i11.LeaderboardCubit? cubit,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         CommunionRoute.name,
         args: CommunionRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'CommunionRoute';

  static _i9.PageInfo page = _i9.PageInfo(
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

  final _i10.Key? key;

  final _i11.LeaderboardCubit? cubit;

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
/// [_i2.HomePage]
class HomeRoute extends _i9.PageRouteInfo<HomeRouteArgs> {
  HomeRoute({
    _i10.Key? key,
    _i12.HomeBloc? bloc,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         HomeRoute.name,
         args: HomeRouteArgs(key: key, bloc: bloc),
         initialChildren: children,
       );

  static const String name = 'HomeRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeRouteArgs>(
        orElse: () => const HomeRouteArgs(),
      );
      return _i2.HomePage(key: args.key, bloc: args.bloc);
    },
  );
}

class HomeRouteArgs {
  const HomeRouteArgs({this.key, this.bloc});

  final _i10.Key? key;

  final _i12.HomeBloc? bloc;

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
/// [_i3.JourneyPage]
class JourneyRoute extends _i9.PageRouteInfo<JourneyRouteArgs> {
  JourneyRoute({
    _i10.Key? key,
    _i13.JourneyCubit? cubit,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         JourneyRoute.name,
         args: JourneyRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'JourneyRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<JourneyRouteArgs>(
        orElse: () => const JourneyRouteArgs(),
      );
      return _i3.JourneyPage(key: args.key, cubit: args.cubit);
    },
  );
}

class JourneyRouteArgs {
  const JourneyRouteArgs({this.key, this.cubit});

  final _i10.Key? key;

  final _i13.JourneyCubit? cubit;

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
/// [_i4.LoginPage]
class LoginRoute extends _i9.PageRouteInfo<LoginRouteArgs> {
  LoginRoute({
    _i10.Key? key,
    _i4.LoginResultCallback? onResult,
    _i14.AuthBloc? bloc,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         LoginRoute.name,
         args: LoginRouteArgs(key: key, onResult: onResult, bloc: bloc),
         initialChildren: children,
       );

  static const String name = 'LoginRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LoginRouteArgs>(
        orElse: () => const LoginRouteArgs(),
      );
      return _i4.LoginPage(
        key: args.key,
        onResult: args.onResult,
        bloc: args.bloc,
      );
    },
  );
}

class LoginRouteArgs {
  const LoginRouteArgs({this.key, this.onResult, this.bloc});

  final _i10.Key? key;

  final _i4.LoginResultCallback? onResult;

  final _i14.AuthBloc? bloc;

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
/// [_i5.QuizPage]
class QuizRoute extends _i9.PageRouteInfo<QuizRouteArgs> {
  QuizRoute({
    _i10.Key? key,
    _i15.QuizBloc? bloc,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         QuizRoute.name,
         args: QuizRouteArgs(key: key, bloc: bloc),
         initialChildren: children,
       );

  static const String name = 'QuizRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<QuizRouteArgs>(
        orElse: () => const QuizRouteArgs(),
      );
      return _i5.QuizPage(key: args.key, bloc: args.bloc);
    },
  );
}

class QuizRouteArgs {
  const QuizRouteArgs({this.key, this.bloc});

  final _i10.Key? key;

  final _i15.QuizBloc? bloc;

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
/// [_i6.ReadingPage]
class ReadingRoute extends _i9.PageRouteInfo<ReadingRouteArgs> {
  ReadingRoute({
    _i10.Key? key,
    _i16.ReadingCubit? cubit,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         ReadingRoute.name,
         args: ReadingRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'ReadingRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReadingRouteArgs>(
        orElse: () => const ReadingRouteArgs(),
      );
      return _i6.ReadingPage(key: args.key, cubit: args.cubit);
    },
  );
}

class ReadingRouteArgs {
  const ReadingRouteArgs({this.key, this.cubit});

  final _i10.Key? key;

  final _i16.ReadingCubit? cubit;

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
/// [_i7.ResultPage]
class ResultRoute extends _i9.PageRouteInfo<ResultRouteArgs> {
  ResultRoute({
    required _i17.SubmitResult result,
    _i10.Key? key,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         ResultRoute.name,
         args: ResultRouteArgs(result: result, key: key),
         initialChildren: children,
       );

  static const String name = 'ResultRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResultRouteArgs>();
      return _i7.ResultPage(result: args.result, key: args.key);
    },
  );
}

class ResultRouteArgs {
  const ResultRouteArgs({required this.result, this.key});

  final _i17.SubmitResult result;

  final _i10.Key? key;

  @override
  String toString() {
    return 'ResultRouteArgs{result: $result, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ResultRouteArgs) return false;
    return result == other.result && key == other.key;
  }

  @override
  int get hashCode => result.hashCode ^ key.hashCode;
}

/// generated route for
/// [_i8.SettingsPage]
class SettingsRoute extends _i9.PageRouteInfo<SettingsRouteArgs> {
  SettingsRoute({
    _i10.Key? key,
    _i18.SettingsCubit? cubit,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         SettingsRoute.name,
         args: SettingsRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'SettingsRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingsRouteArgs>(
        orElse: () => const SettingsRouteArgs(),
      );
      return _i8.SettingsPage(key: args.key, cubit: args.cubit);
    },
  );
}

class SettingsRouteArgs {
  const SettingsRouteArgs({this.key, this.cubit});

  final _i10.Key? key;

  final _i18.SettingsCubit? cubit;

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
