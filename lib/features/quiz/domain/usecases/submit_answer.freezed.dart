// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'submit_answer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SubmitAnswerParams {


/// Create a copy of SubmitAnswerParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubmitAnswerParamsCopyWith<SubmitAnswerParams> get copyWith => _$SubmitAnswerParamsCopyWithImpl<SubmitAnswerParams>(this as SubmitAnswerParams, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SubmitAnswerParams;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubmitAnswerParams&&(identical(other.readingId, _this.readingId) || other.readingId == _this.readingId)&&(identical(other.questionId, _this.questionId) || other.questionId == _this.questionId)&&(identical(other.answer, _this.answer) || other.answer == _this.answer));
}


@override
int get hashCode {
  final _this = this as SubmitAnswerParams;
  return Object.hash(runtimeType,_this.readingId,_this.questionId,_this.answer);
}

@override
String toString() {
  final _this = this as SubmitAnswerParams;
  return 'SubmitAnswerParams(readingId: ${_this.readingId}, questionId: ${_this.questionId}, answer: ${_this.answer})';
}


}

/// @nodoc
abstract mixin class $SubmitAnswerParamsCopyWith<$Res>  {
  factory $SubmitAnswerParamsCopyWith(SubmitAnswerParams value, $Res Function(SubmitAnswerParams) _then) = _$SubmitAnswerParamsCopyWithImpl;
@useResult
$Res call({
 String readingId, String questionId, String answer
});




}
/// @nodoc
class _$SubmitAnswerParamsCopyWithImpl<$Res>
    implements $SubmitAnswerParamsCopyWith<$Res> {
  _$SubmitAnswerParamsCopyWithImpl(this._self, this._then);

  final SubmitAnswerParams _self;
  final $Res Function(SubmitAnswerParams) _then;

/// Create a copy of SubmitAnswerParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? readingId = null,Object? questionId = null,Object? answer = null,}) {
  return _then(SubmitAnswerParams(
readingId: null == readingId ? _self.readingId : readingId // ignore: cast_nullable_to_non_nullable
as String,questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,answer: null == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SubmitAnswerParams].
extension SubmitAnswerParamsPatterns on SubmitAnswerParams {
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
