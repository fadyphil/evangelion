// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i7;
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart'
    as _i10;
import 'package:evangelion/features/auth/presentation/pages/login_page.dart'
    as _i2;
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart'
    as _i9;
import 'package:evangelion/features/home/presentation/pages/home_page.dart'
    as _i1;
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart'
    as _i3;
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart'
    as _i11;
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart'
    as _i4;
import 'package:evangelion/features/result/presentation/pages/result_page.dart'
    as _i5;
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart'
    as _i6;
import 'package:flutter/material.dart' as _i8;

/// generated route for
/// [_i1.HomePage]
class HomeRoute extends _i7.PageRouteInfo<HomeRouteArgs> {
  HomeRoute({
    _i8.Key? key,
    _i9.HomeBloc? bloc,
    List<_i7.PageRouteInfo>? children,
  }) : super(
         HomeRoute.name,
         args: HomeRouteArgs(key: key, bloc: bloc),
         initialChildren: children,
       );

  static const String name = 'HomeRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeRouteArgs>(
        orElse: () => const HomeRouteArgs(),
      );
      return _i1.HomePage(key: args.key, bloc: args.bloc);
    },
  );
}

class HomeRouteArgs {
  const HomeRouteArgs({this.key, this.bloc});

  final _i8.Key? key;

  final _i9.HomeBloc? bloc;

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
/// [_i2.LoginPage]
class LoginRoute extends _i7.PageRouteInfo<LoginRouteArgs> {
  LoginRoute({
    _i8.Key? key,
    _i2.LoginResultCallback? onResult,
    _i10.AuthBloc? bloc,
    List<_i7.PageRouteInfo>? children,
  }) : super(
         LoginRoute.name,
         args: LoginRouteArgs(key: key, onResult: onResult, bloc: bloc),
         initialChildren: children,
       );

  static const String name = 'LoginRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LoginRouteArgs>(
        orElse: () => const LoginRouteArgs(),
      );
      return _i2.LoginPage(
        key: args.key,
        onResult: args.onResult,
        bloc: args.bloc,
      );
    },
  );
}

class LoginRouteArgs {
  const LoginRouteArgs({this.key, this.onResult, this.bloc});

  final _i8.Key? key;

  final _i2.LoginResultCallback? onResult;

  final _i10.AuthBloc? bloc;

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
/// [_i3.QuizPage]
class QuizRoute extends _i7.PageRouteInfo<void> {
  const QuizRoute({List<_i7.PageRouteInfo>? children})
    : super(QuizRoute.name, initialChildren: children);

  static const String name = 'QuizRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return const _i3.QuizPage();
    },
  );
}

/// generated route for
/// [_i4.ReadingPage]
class ReadingRoute extends _i7.PageRouteInfo<ReadingRouteArgs> {
  ReadingRoute({
    _i8.Key? key,
    _i11.ReadingCubit? cubit,
    List<_i7.PageRouteInfo>? children,
  }) : super(
         ReadingRoute.name,
         args: ReadingRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'ReadingRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReadingRouteArgs>(
        orElse: () => const ReadingRouteArgs(),
      );
      return _i4.ReadingPage(key: args.key, cubit: args.cubit);
    },
  );
}

class ReadingRouteArgs {
  const ReadingRouteArgs({this.key, this.cubit});

  final _i8.Key? key;

  final _i11.ReadingCubit? cubit;

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
/// [_i5.ResultPage]
class ResultRoute extends _i7.PageRouteInfo<void> {
  const ResultRoute({List<_i7.PageRouteInfo>? children})
    : super(ResultRoute.name, initialChildren: children);

  static const String name = 'ResultRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return const _i5.ResultPage();
    },
  );
}

/// generated route for
/// [_i6.SettingsPage]
class SettingsRoute extends _i7.PageRouteInfo<void> {
  const SettingsRoute({List<_i7.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return const _i6.SettingsPage();
    },
  );
}
