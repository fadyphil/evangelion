// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i7;
import 'package:evangelion/features/auth/presentation/pages/login_page.dart'
    as _i2;
import 'package:evangelion/features/home/presentation/pages/home_page.dart'
    as _i1;
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart'
    as _i3;
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart'
    as _i4;
import 'package:evangelion/features/result/presentation/pages/result_page.dart'
    as _i5;
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart'
    as _i6;
import 'package:flutter/material.dart' as _i8;

/// generated route for
/// [_i1.HomePage]
class HomeRoute extends _i7.PageRouteInfo<void> {
  const HomeRoute({List<_i7.PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return const _i1.HomePage();
    },
  );
}

/// generated route for
/// [_i2.LoginPage]
class LoginRoute extends _i7.PageRouteInfo<LoginRouteArgs> {
  LoginRoute({
    _i8.Key? key,
    _i2.LoginResultCallback? onResult,
    List<_i7.PageRouteInfo>? children,
  }) : super(
         LoginRoute.name,
         args: LoginRouteArgs(key: key, onResult: onResult),
         initialChildren: children,
       );

  static const String name = 'LoginRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LoginRouteArgs>(
        orElse: () => const LoginRouteArgs(),
      );
      return _i2.LoginPage(key: args.key, onResult: args.onResult);
    },
  );
}

class LoginRouteArgs {
  const LoginRouteArgs({this.key, this.onResult});

  final _i8.Key? key;

  final _i2.LoginResultCallback? onResult;

  @override
  String toString() {
    return 'LoginRouteArgs{key: $key, onResult: $onResult}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoginRouteArgs) return false;
    return key == other.key && onResult == other.onResult;
  }

  @override
  int get hashCode => key.hashCode ^ onResult.hashCode;
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
class ReadingRoute extends _i7.PageRouteInfo<void> {
  const ReadingRoute({List<_i7.PageRouteInfo>? children})
    : super(ReadingRoute.name, initialChildren: children);

  static const String name = 'ReadingRoute';

  static _i7.PageInfo page = _i7.PageInfo(
    name,
    builder: (data) {
      return const _i4.ReadingPage();
    },
  );
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
