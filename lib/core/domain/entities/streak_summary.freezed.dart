// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'streak_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StreakSummary {


/// Create a copy of StreakSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StreakSummaryCopyWith<StreakSummary> get copyWith => _$StreakSummaryCopyWithImpl<StreakSummary>(this as StreakSummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StreakSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StreakSummary&&(identical(other.currentStreak, _this.currentStreak) || other.currentStreak == _this.currentStreak)&&(identical(other.longestStreak, _this.longestStreak) || other.longestStreak == _this.longestStreak)&&(identical(other.lastCompletedDate, _this.lastCompletedDate) || other.lastCompletedDate == _this.lastCompletedDate)&&(identical(other.todayStatus, _this.todayStatus) || other.todayStatus == _this.todayStatus)&&(identical(other.todayCompleted, _this.todayCompleted) || other.todayCompleted == _this.todayCompleted)&&(identical(other.todayScheduled, _this.todayScheduled) || other.todayScheduled == _this.todayScheduled)&&(identical(other.nextMilestone, _this.nextMilestone) || other.nextMilestone == _this.nextMilestone)&&(identical(other.daysToMilestone, _this.daysToMilestone) || other.daysToMilestone == _this.daysToMilestone));
}


@override
int get hashCode {
  final _this = this as StreakSummary;
  return Object.hash(runtimeType,_this.currentStreak,_this.longestStreak,_this.lastCompletedDate,_this.todayStatus,_this.todayCompleted,_this.todayScheduled,_this.nextMilestone,_this.daysToMilestone);
}

@override
String toString() {
  final _this = this as StreakSummary;
  return 'StreakSummary(currentStreak: ${_this.currentStreak}, longestStreak: ${_this.longestStreak}, lastCompletedDate: ${_this.lastCompletedDate}, todayStatus: ${_this.todayStatus}, todayCompleted: ${_this.todayCompleted}, todayScheduled: ${_this.todayScheduled}, nextMilestone: ${_this.nextMilestone}, daysToMilestone: ${_this.daysToMilestone})';
}


}

/// @nodoc
abstract mixin class $StreakSummaryCopyWith<$Res>  {
  factory $StreakSummaryCopyWith(StreakSummary value, $Res Function(StreakSummary) _then) = _$StreakSummaryCopyWithImpl;
@useResult
$Res call({
 int currentStreak, int longestStreak, String lastCompletedDate, StreakTodayStatus todayStatus, bool todayCompleted, bool todayScheduled, int nextMilestone, int daysToMilestone
});




}
/// @nodoc
class _$StreakSummaryCopyWithImpl<$Res>
    implements $StreakSummaryCopyWith<$Res> {
  _$StreakSummaryCopyWithImpl(this._self, this._then);

  final StreakSummary _self;
  final $Res Function(StreakSummary) _then;

/// Create a copy of StreakSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentStreak = null,Object? longestStreak = null,Object? lastCompletedDate = null,Object? todayStatus = null,Object? todayCompleted = null,Object? todayScheduled = null,Object? nextMilestone = null,Object? daysToMilestone = null,}) {
  return _then(StreakSummary(
currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,longestStreak: null == longestStreak ? _self.longestStreak : longestStreak // ignore: cast_nullable_to_non_nullable
as int,lastCompletedDate: null == lastCompletedDate ? _self.lastCompletedDate : lastCompletedDate // ignore: cast_nullable_to_non_nullable
as String,todayStatus: null == todayStatus ? _self.todayStatus : todayStatus // ignore: cast_nullable_to_non_nullable
as StreakTodayStatus,todayCompleted: null == todayCompleted ? _self.todayCompleted : todayCompleted // ignore: cast_nullable_to_non_nullable
as bool,todayScheduled: null == todayScheduled ? _self.todayScheduled : todayScheduled // ignore: cast_nullable_to_non_nullable
as bool,nextMilestone: null == nextMilestone ? _self.nextMilestone : nextMilestone // ignore: cast_nullable_to_non_nullable
as int,daysToMilestone: null == daysToMilestone ? _self.daysToMilestone : daysToMilestone // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [StreakSummary].
extension StreakSummaryPatterns on StreakSummary {
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
