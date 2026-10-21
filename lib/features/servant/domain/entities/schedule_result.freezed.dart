// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScheduleResult {


/// Create a copy of ScheduleResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleResultCopyWith<ScheduleResult> get copyWith => _$ScheduleResultCopyWithImpl<ScheduleResult>(this as ScheduleResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ScheduleResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleResult&&(identical(other.message, _this.message) || other.message == _this.message)&&const DeepCollectionEquality().equals(other.readingIds, _this.readingIds));
}


@override
int get hashCode {
  final _this = this as ScheduleResult;
  return Object.hash(runtimeType,_this.message,const DeepCollectionEquality().hash(_this.readingIds));
}

@override
String toString() {
  final _this = this as ScheduleResult;
  return 'ScheduleResult(message: ${_this.message}, readingIds: ${_this.readingIds})';
}


}

/// @nodoc
abstract mixin class $ScheduleResultCopyWith<$Res>  {
  factory $ScheduleResultCopyWith(ScheduleResult value, $Res Function(ScheduleResult) _then) = _$ScheduleResultCopyWithImpl;
@useResult
$Res call({
 String message, List<String> readingIds
});




}
/// @nodoc
class _$ScheduleResultCopyWithImpl<$Res>
    implements $ScheduleResultCopyWith<$Res> {
  _$ScheduleResultCopyWithImpl(this._self, this._then);

  final ScheduleResult _self;
  final $Res Function(ScheduleResult) _then;

/// Create a copy of ScheduleResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? readingIds = null,}) {
  return _then(ScheduleResult(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,readingIds: null == readingIds ? _self.readingIds : readingIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduleResult].
extension ScheduleResultPatterns on ScheduleResult {
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
