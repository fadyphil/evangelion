// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingState {


/// Create a copy of ReadingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingStateCopyWith<ReadingState> get copyWith => _$ReadingStateCopyWithImpl<ReadingState>(this as ReadingState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReadingState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingState&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.scripture, _this.scripture) || other.scripture == _this.scripture)&&(identical(other.failure, _this.failure) || other.failure == _this.failure)&&(identical(other.fontStep, _this.fontStep) || other.fontStep == _this.fontStep)&&(identical(other.textSizePanelOpen, _this.textSizePanelOpen) || other.textSizePanelOpen == _this.textSizePanelOpen));
}


@override
int get hashCode {
  final _this = this as ReadingState;
  return Object.hash(runtimeType,_this.status,_this.scripture,_this.failure,_this.fontStep,_this.textSizePanelOpen);
}

@override
String toString() {
  final _this = this as ReadingState;
  return 'ReadingState(status: ${_this.status}, scripture: ${_this.scripture}, failure: ${_this.failure}, fontStep: ${_this.fontStep}, textSizePanelOpen: ${_this.textSizePanelOpen})';
}


}

/// @nodoc
abstract mixin class $ReadingStateCopyWith<$Res>  {
  factory $ReadingStateCopyWith(ReadingState value, $Res Function(ReadingState) _then) = _$ReadingStateCopyWithImpl;
@useResult
$Res call({
 ReadingStatus status, ScriptureText? scripture, Failure? failure, int fontStep, bool textSizePanelOpen
});




}
/// @nodoc
class _$ReadingStateCopyWithImpl<$Res>
    implements $ReadingStateCopyWith<$Res> {
  _$ReadingStateCopyWithImpl(this._self, this._then);

  final ReadingState _self;
  final $Res Function(ReadingState) _then;

/// Create a copy of ReadingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? scripture = freezed,Object? failure = freezed,Object? fontStep = null,Object? textSizePanelOpen = null,}) {
  return _then(ReadingState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ReadingStatus,scripture: freezed == scripture ? _self.scripture : scripture // ignore: cast_nullable_to_non_nullable
as ScriptureText?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,fontStep: null == fontStep ? _self.fontStep : fontStep // ignore: cast_nullable_to_non_nullable
as int,textSizePanelOpen: null == textSizePanelOpen ? _self.textSizePanelOpen : textSizePanelOpen // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingState].
extension ReadingStatePatterns on ReadingState {
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
