// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'roster_student.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RosterStudent {


/// Create a copy of RosterStudent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RosterStudentCopyWith<RosterStudent> get copyWith => _$RosterStudentCopyWithImpl<RosterStudent>(this as RosterStudent, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RosterStudent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RosterStudent&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.fullName, _this.fullName) || other.fullName == _this.fullName)&&(identical(other.preferredLang, _this.preferredLang) || other.preferredLang == _this.preferredLang)&&(identical(other.totalPoints, _this.totalPoints) || other.totalPoints == _this.totalPoints)&&(identical(other.currentStreak, _this.currentStreak) || other.currentStreak == _this.currentStreak)&&(identical(other.pointsEarnedToday, _this.pointsEarnedToday) || other.pointsEarnedToday == _this.pointsEarnedToday)&&(identical(other.completedToday, _this.completedToday) || other.completedToday == _this.completedToday)&&(identical(other.questionsProgress, _this.questionsProgress) || other.questionsProgress == _this.questionsProgress));
}


@override
int get hashCode {
  final _this = this as RosterStudent;
  return Object.hash(runtimeType,_this.userId,_this.fullName,_this.preferredLang,_this.totalPoints,_this.currentStreak,_this.pointsEarnedToday,_this.completedToday,_this.questionsProgress);
}



}

/// @nodoc
abstract mixin class $RosterStudentCopyWith<$Res>  {
  factory $RosterStudentCopyWith(RosterStudent value, $Res Function(RosterStudent) _then) = _$RosterStudentCopyWithImpl;
@useResult
$Res call({
 String userId, String fullName, String preferredLang, int totalPoints, int currentStreak, int pointsEarnedToday, bool completedToday, String questionsProgress
});




}
/// @nodoc
class _$RosterStudentCopyWithImpl<$Res>
    implements $RosterStudentCopyWith<$Res> {
  _$RosterStudentCopyWithImpl(this._self, this._then);

  final RosterStudent _self;
  final $Res Function(RosterStudent) _then;

/// Create a copy of RosterStudent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? fullName = null,Object? preferredLang = null,Object? totalPoints = null,Object? currentStreak = null,Object? pointsEarnedToday = null,Object? completedToday = null,Object? questionsProgress = null,}) {
  return _then(RosterStudent(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,preferredLang: null == preferredLang ? _self.preferredLang : preferredLang // ignore: cast_nullable_to_non_nullable
as String,totalPoints: null == totalPoints ? _self.totalPoints : totalPoints // ignore: cast_nullable_to_non_nullable
as int,currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,pointsEarnedToday: null == pointsEarnedToday ? _self.pointsEarnedToday : pointsEarnedToday // ignore: cast_nullable_to_non_nullable
as int,completedToday: null == completedToday ? _self.completedToday : completedToday // ignore: cast_nullable_to_non_nullable
as bool,questionsProgress: null == questionsProgress ? _self.questionsProgress : questionsProgress // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RosterStudent].
extension RosterStudentPatterns on RosterStudent {
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
