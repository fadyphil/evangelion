// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'load_leaderboard.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LeaderboardQuery {


/// Create a copy of LeaderboardQuery
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeaderboardQueryCopyWith<LeaderboardQuery> get copyWith => _$LeaderboardQueryCopyWithImpl<LeaderboardQuery>(this as LeaderboardQuery, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LeaderboardQuery;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeaderboardQuery&&(identical(other.window, _this.window) || other.window == _this.window)&&(identical(other.limit, _this.limit) || other.limit == _this.limit));
}


@override
int get hashCode {
  final _this = this as LeaderboardQuery;
  return Object.hash(runtimeType,_this.window,_this.limit);
}

@override
String toString() {
  final _this = this as LeaderboardQuery;
  return 'LeaderboardQuery(window: ${_this.window}, limit: ${_this.limit})';
}


}

/// @nodoc
abstract mixin class $LeaderboardQueryCopyWith<$Res>  {
  factory $LeaderboardQueryCopyWith(LeaderboardQuery value, $Res Function(LeaderboardQuery) _then) = _$LeaderboardQueryCopyWithImpl;
@useResult
$Res call({
 LeaderboardWindow window, int limit
});




}
/// @nodoc
class _$LeaderboardQueryCopyWithImpl<$Res>
    implements $LeaderboardQueryCopyWith<$Res> {
  _$LeaderboardQueryCopyWithImpl(this._self, this._then);

  final LeaderboardQuery _self;
  final $Res Function(LeaderboardQuery) _then;

/// Create a copy of LeaderboardQuery
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? window = null,Object? limit = null,}) {
  return _then(LeaderboardQuery(
window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as LeaderboardWindow,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LeaderboardQuery].
extension LeaderboardQueryPatterns on LeaderboardQuery {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({required TResult orElse(),}){
final _that = this;
switch (_that) {
case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({required TResult orElse(),}) {final _that = this;
switch (_that) {
case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  return null;

}
}

}

// dart format on
