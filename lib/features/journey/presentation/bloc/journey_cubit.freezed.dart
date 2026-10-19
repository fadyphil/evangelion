// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journey_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JourneyState {


/// Create a copy of JourneyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JourneyStateCopyWith<JourneyState> get copyWith => _$JourneyStateCopyWithImpl<JourneyState>(this as JourneyState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as JourneyState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JourneyState&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.session, _this.session) || other.session == _this.session)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.rings, _this.rings) || other.rings == _this.rings)&&(identical(other.constellations, _this.constellations) || other.constellations == _this.constellations)&&(identical(other.starsLit, _this.starsLit) || other.starsLit == _this.starsLit)&&(identical(other.shelf, _this.shelf) || other.shelf == _this.shelf)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}


@override
int get hashCode {
  final _this = this as JourneyState;
  return Object.hash(runtimeType,_this.status,_this.session,_this.summary,_this.rings,_this.constellations,_this.starsLit,_this.shelf,_this.failure);
}

@override
String toString() {
  final _this = this as JourneyState;
  return 'JourneyState(status: ${_this.status}, session: ${_this.session}, summary: ${_this.summary}, rings: ${_this.rings}, constellations: ${_this.constellations}, starsLit: ${_this.starsLit}, shelf: ${_this.shelf}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $JourneyStateCopyWith<$Res>  {
  factory $JourneyStateCopyWith(JourneyState value, $Res Function(JourneyState) _then) = _$JourneyStateCopyWithImpl;
@useResult
$Res call({
 JourneyStatus status, AuthSession? session, StreakSummary? summary, JourneyRings? rings, int constellations, int starsLit, MedalShelf? shelf, Failure? failure
});




}
/// @nodoc
class _$JourneyStateCopyWithImpl<$Res>
    implements $JourneyStateCopyWith<$Res> {
  _$JourneyStateCopyWithImpl(this._self, this._then);

  final JourneyState _self;
  final $Res Function(JourneyState) _then;

/// Create a copy of JourneyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? session = freezed,Object? summary = freezed,Object? rings = freezed,Object? constellations = null,Object? starsLit = null,Object? shelf = freezed,Object? failure = freezed,}) {
  return _then(JourneyState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JourneyStatus,session: freezed == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as AuthSession?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as StreakSummary?,rings: freezed == rings ? _self.rings : rings // ignore: cast_nullable_to_non_nullable
as JourneyRings?,constellations: null == constellations ? _self.constellations : constellations // ignore: cast_nullable_to_non_nullable
as int,starsLit: null == starsLit ? _self.starsLit : starsLit // ignore: cast_nullable_to_non_nullable
as int,shelf: freezed == shelf ? _self.shelf : shelf // ignore: cast_nullable_to_non_nullable
as MedalShelf?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [JourneyState].
extension JourneyStatePatterns on JourneyState {
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
