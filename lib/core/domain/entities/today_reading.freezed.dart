// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'today_reading.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TodayReading {


/// Create a copy of TodayReading
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TodayReadingCopyWith<TodayReading> get copyWith => _$TodayReadingCopyWithImpl<TodayReading>(this as TodayReading, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TodayReading;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TodayReading&&(identical(other.readingId, _this.readingId) || other.readingId == _this.readingId)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.scheduledDate, _this.scheduledDate) || other.scheduledDate == _this.scheduledDate)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.reference, _this.reference) || other.reference == _this.reference)&&(identical(other.translation, _this.translation) || other.translation == _this.translation)&&(identical(other.verseCount, _this.verseCount) || other.verseCount == _this.verseCount)&&(identical(other.firstVerseText, _this.firstVerseText) || other.firstVerseText == _this.firstVerseText)&&(identical(other.questionCount, _this.questionCount) || other.questionCount == _this.questionCount)&&(identical(other.answeredQuestionCount, _this.answeredQuestionCount) || other.answeredQuestionCount == _this.answeredQuestionCount)&&(identical(other.isFullyCompleted, _this.isFullyCompleted) || other.isFullyCompleted == _this.isFullyCompleted)&&(identical(other.pointsEarnedToday, _this.pointsEarnedToday) || other.pointsEarnedToday == _this.pointsEarnedToday)&&(identical(other.currentStreak, _this.currentStreak) || other.currentStreak == _this.currentStreak));
}


@override
int get hashCode {
  final _this = this as TodayReading;
  return Object.hash(runtimeType,_this.readingId,_this.groupId,_this.scheduledDate,_this.language,_this.reference,_this.translation,_this.verseCount,_this.firstVerseText,_this.questionCount,_this.answeredQuestionCount,_this.isFullyCompleted,_this.pointsEarnedToday,_this.currentStreak);
}

@override
String toString() {
  final _this = this as TodayReading;
  return 'TodayReading(readingId: ${_this.readingId}, groupId: ${_this.groupId}, scheduledDate: ${_this.scheduledDate}, language: ${_this.language}, reference: ${_this.reference}, translation: ${_this.translation}, verseCount: ${_this.verseCount}, firstVerseText: ${_this.firstVerseText}, questionCount: ${_this.questionCount}, answeredQuestionCount: ${_this.answeredQuestionCount}, isFullyCompleted: ${_this.isFullyCompleted}, pointsEarnedToday: ${_this.pointsEarnedToday}, currentStreak: ${_this.currentStreak})';
}


}

/// @nodoc
abstract mixin class $TodayReadingCopyWith<$Res>  {
  factory $TodayReadingCopyWith(TodayReading value, $Res Function(TodayReading) _then) = _$TodayReadingCopyWithImpl;
@useResult
$Res call({
 String readingId, int groupId, String scheduledDate, ReadingLanguage language, String reference, String translation, int verseCount, String firstVerseText, int questionCount, int answeredQuestionCount, bool isFullyCompleted, int pointsEarnedToday, int currentStreak
});




}
/// @nodoc
class _$TodayReadingCopyWithImpl<$Res>
    implements $TodayReadingCopyWith<$Res> {
  _$TodayReadingCopyWithImpl(this._self, this._then);

  final TodayReading _self;
  final $Res Function(TodayReading) _then;

/// Create a copy of TodayReading
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? readingId = null,Object? groupId = null,Object? scheduledDate = null,Object? language = null,Object? reference = null,Object? translation = null,Object? verseCount = null,Object? firstVerseText = null,Object? questionCount = null,Object? answeredQuestionCount = null,Object? isFullyCompleted = null,Object? pointsEarnedToday = null,Object? currentStreak = null,}) {
  return _then(TodayReading(
readingId: null == readingId ? _self.readingId : readingId // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int,scheduledDate: null == scheduledDate ? _self.scheduledDate : scheduledDate // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as ReadingLanguage,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,translation: null == translation ? _self.translation : translation // ignore: cast_nullable_to_non_nullable
as String,verseCount: null == verseCount ? _self.verseCount : verseCount // ignore: cast_nullable_to_non_nullable
as int,firstVerseText: null == firstVerseText ? _self.firstVerseText : firstVerseText // ignore: cast_nullable_to_non_nullable
as String,questionCount: null == questionCount ? _self.questionCount : questionCount // ignore: cast_nullable_to_non_nullable
as int,answeredQuestionCount: null == answeredQuestionCount ? _self.answeredQuestionCount : answeredQuestionCount // ignore: cast_nullable_to_non_nullable
as int,isFullyCompleted: null == isFullyCompleted ? _self.isFullyCompleted : isFullyCompleted // ignore: cast_nullable_to_non_nullable
as bool,pointsEarnedToday: null == pointsEarnedToday ? _self.pointsEarnedToday : pointsEarnedToday // ignore: cast_nullable_to_non_nullable
as int,currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TodayReading].
extension TodayReadingPatterns on TodayReading {
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
