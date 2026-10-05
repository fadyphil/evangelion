// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'submit_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SubmitResult {


/// Create a copy of SubmitResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubmitResultCopyWith<SubmitResult> get copyWith => _$SubmitResultCopyWithImpl<SubmitResult>(this as SubmitResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SubmitResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubmitResult&&(identical(other.questionId, _this.questionId) || other.questionId == _this.questionId)&&(identical(other.isCorrect, _this.isCorrect) || other.isCorrect == _this.isCorrect)&&(identical(other.pointsEarned, _this.pointsEarned) || other.pointsEarned == _this.pointsEarned)&&(identical(other.currentTotalPoints, _this.currentTotalPoints) || other.currentTotalPoints == _this.currentTotalPoints)&&(identical(other.currentStreak, _this.currentStreak) || other.currentStreak == _this.currentStreak)&&(identical(other.longestStreak, _this.longestStreak) || other.longestStreak == _this.longestStreak)&&(identical(other.readingCompleted, _this.readingCompleted) || other.readingCompleted == _this.readingCompleted));
}


@override
int get hashCode {
  final _this = this as SubmitResult;
  return Object.hash(runtimeType,_this.questionId,_this.isCorrect,_this.pointsEarned,_this.currentTotalPoints,_this.currentStreak,_this.longestStreak,_this.readingCompleted);
}

@override
String toString() {
  final _this = this as SubmitResult;
  return 'SubmitResult(questionId: ${_this.questionId}, isCorrect: ${_this.isCorrect}, pointsEarned: ${_this.pointsEarned}, currentTotalPoints: ${_this.currentTotalPoints}, currentStreak: ${_this.currentStreak}, longestStreak: ${_this.longestStreak}, readingCompleted: ${_this.readingCompleted})';
}


}

/// @nodoc
abstract mixin class $SubmitResultCopyWith<$Res>  {
  factory $SubmitResultCopyWith(SubmitResult value, $Res Function(SubmitResult) _then) = _$SubmitResultCopyWithImpl;
@useResult
$Res call({
 String questionId, bool isCorrect, int pointsEarned, int currentTotalPoints, int currentStreak, int longestStreak, bool readingCompleted
});




}
/// @nodoc
class _$SubmitResultCopyWithImpl<$Res>
    implements $SubmitResultCopyWith<$Res> {
  _$SubmitResultCopyWithImpl(this._self, this._then);

  final SubmitResult _self;
  final $Res Function(SubmitResult) _then;

/// Create a copy of SubmitResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? questionId = null,Object? isCorrect = null,Object? pointsEarned = null,Object? currentTotalPoints = null,Object? currentStreak = null,Object? longestStreak = null,Object? readingCompleted = null,}) {
  return _then(SubmitResult(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,isCorrect: null == isCorrect ? _self.isCorrect : isCorrect // ignore: cast_nullable_to_non_nullable
as bool,pointsEarned: null == pointsEarned ? _self.pointsEarned : pointsEarned // ignore: cast_nullable_to_non_nullable
as int,currentTotalPoints: null == currentTotalPoints ? _self.currentTotalPoints : currentTotalPoints // ignore: cast_nullable_to_non_nullable
as int,currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,longestStreak: null == longestStreak ? _self.longestStreak : longestStreak // ignore: cast_nullable_to_non_nullable
as int,readingCompleted: null == readingCompleted ? _self.readingCompleted : readingCompleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SubmitResult].
extension SubmitResultPatterns on SubmitResult {
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
