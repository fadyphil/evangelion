// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import 'service_locator_module.dart' as _i400;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final serviceLocatorModule = _$ServiceLocatorModule();
    gh.lazySingleton<_i174.GetIt>(() => serviceLocatorModule.serviceLocator);
    gh.lazySingleton<String>(
      () => serviceLocatorModule.apiBaseUrl,
      instanceName: 'apiBaseUrl',
    );
    return this;
  }
}

class _$ServiceLocatorModule extends _i400.ServiceLocatorModule {}
