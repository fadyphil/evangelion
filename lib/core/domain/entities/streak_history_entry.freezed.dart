// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'streak_history_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StreakHistoryEntry {


/// Create a copy of StreakHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StreakHistoryEntryCopyWith<StreakHistoryEntry> get copyWith => _$StreakHistoryEntryCopyWithImpl<StreakHistoryEntry>(this as StreakHistoryEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StreakHistoryEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StreakHistoryEntry&&(identical(other.readingId, _this.readingId) || other.readingId == _this.readingId)&&(identical(other.scheduledDate, _this.scheduledDate) || other.scheduledDate == _this.scheduledDate)&&(identical(other.bookNumber, _this.bookNumber) || other.bookNumber == _this.bookNumber)&&(identical(other.bookNameEn, _this.bookNameEn) || other.bookNameEn == _this.bookNameEn)&&(identical(other.bookNameAr, _this.bookNameAr) || other.bookNameAr == _this.bookNameAr)&&(identical(other.referenceEn, _this.referenceEn) || other.referenceEn == _this.referenceEn)&&(identical(other.referenceAr, _this.referenceAr) || other.referenceAr == _this.referenceAr)&&(identical(other.totalQuestions, _this.totalQuestions) || other.totalQuestions == _this.totalQuestions)&&(identical(other.answeredQuestions, _this.answeredQuestions) || other.answeredQuestions == _this.answeredQuestions)&&(identical(other.correctAnswers, _this.correctAnswers) || other.correctAnswers == _this.correctAnswers)&&(identical(other.pointsEarned, _this.pointsEarned) || other.pointsEarned == _this.pointsEarned)&&(identical(other.isCompleted, _this.isCompleted) || other.isCompleted == _this.isCompleted));
}


@override
int get hashCode {
  final _this = this as StreakHistoryEntry;
  return Object.hash(runtimeType,_this.readingId,_this.scheduledDate,_this.bookNumber,_this.bookNameEn,_this.bookNameAr,_this.referenceEn,_this.referenceAr,_this.totalQuestions,_this.answeredQuestions,_this.correctAnswers,_this.pointsEarned,_this.isCompleted);
}

@override
String toString() {
  final _this = this as StreakHistoryEntry;
  return 'StreakHistoryEntry(readingId: ${_this.readingId}, scheduledDate: ${_this.scheduledDate}, bookNumber: ${_this.bookNumber}, bookNameEn: ${_this.bookNameEn}, bookNameAr: ${_this.bookNameAr}, referenceEn: ${_this.referenceEn}, referenceAr: ${_this.referenceAr}, totalQuestions: ${_this.totalQuestions}, answeredQuestions: ${_this.answeredQuestions}, correctAnswers: ${_this.correctAnswers}, pointsEarned: ${_this.pointsEarned}, isCompleted: ${_this.isCompleted})';
}


}

/// @nodoc
abstract mixin class $StreakHistoryEntryCopyWith<$Res>  {
  factory $StreakHistoryEntryCopyWith(StreakHistoryEntry value, $Res Function(StreakHistoryEntry) _then) = _$StreakHistoryEntryCopyWithImpl;
@useResult
$Res call({
 String readingId, String scheduledDate, int bookNumber, String bookNameEn, String bookNameAr, String referenceEn, String referenceAr, int totalQuestions, int answeredQuestions, int correctAnswers, int pointsEarned, bool isCompleted
});




}
/// @nodoc
class _$StreakHistoryEntryCopyWithImpl<$Res>
    implements $StreakHistoryEntryCopyWith<$Res> {
  _$StreakHistoryEntryCopyWithImpl(this._self, this._then);

  final StreakHistoryEntry _self;
  final $Res Function(StreakHistoryEntry) _then;

/// Create a copy of StreakHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? readingId = null,Object? scheduledDate = null,Object? bookNumber = null,Object? bookNameEn = null,Object? bookNameAr = null,Object? referenceEn = null,Object? referenceAr = null,Object? totalQuestions = null,Object? answeredQuestions = null,Object? correctAnswers = null,Object? pointsEarned = null,Object? isCompleted = null,}) {
  return _then(StreakHistoryEntry(
readingId: null == readingId ? _self.readingId : readingId // ignore: cast_nullable_to_non_nullable
as String,scheduledDate: null == scheduledDate ? _self.scheduledDate : scheduledDate // ignore: cast_nullable_to_non_nullable
as String,bookNumber: null == bookNumber ? _self.bookNumber : bookNumber // ignore: cast_nullable_to_non_nullable
as int,bookNameEn: null == bookNameEn ? _self.bookNameEn : bookNameEn // ignore: cast_nullable_to_non_nullable
as String,bookNameAr: null == bookNameAr ? _self.bookNameAr : bookNameAr // ignore: cast_nullable_to_non_nullable
as String,referenceEn: null == referenceEn ? _self.referenceEn : referenceEn // ignore: cast_nullable_to_non_nullable
as String,referenceAr: null == referenceAr ? _self.referenceAr : referenceAr // ignore: cast_nullable_to_non_nullable
as String,totalQuestions: null == totalQuestions ? _self.totalQuestions : totalQuestions // ignore: cast_nullable_to_non_nullable
as int,answeredQuestions: null == answeredQuestions ? _self.answeredQuestions : answeredQuestions // ignore: cast_nullable_to_non_nullable
as int,correctAnswers: null == correctAnswers ? _self.correctAnswers : correctAnswers // ignore: cast_nullable_to_non_nullable
as int,pointsEarned: null == pointsEarned ? _self.pointsEarned : pointsEarned // ignore: cast_nullable_to_non_nullable
as int,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [StreakHistoryEntry].
extension StreakHistoryEntryPatterns on StreakHistoryEntry {
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
