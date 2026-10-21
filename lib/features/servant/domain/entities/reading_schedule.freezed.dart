// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ExcludedVerse {


/// Create a copy of ExcludedVerse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExcludedVerseCopyWith<ExcludedVerse> get copyWith => _$ExcludedVerseCopyWithImpl<ExcludedVerse>(this as ExcludedVerse, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ExcludedVerse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExcludedVerse&&(identical(other.chapter, _this.chapter) || other.chapter == _this.chapter)&&(identical(other.verse, _this.verse) || other.verse == _this.verse));
}


@override
int get hashCode {
  final _this = this as ExcludedVerse;
  return Object.hash(runtimeType,_this.chapter,_this.verse);
}

@override
String toString() {
  final _this = this as ExcludedVerse;
  return 'ExcludedVerse(chapter: ${_this.chapter}, verse: ${_this.verse})';
}


}

/// @nodoc
abstract mixin class $ExcludedVerseCopyWith<$Res>  {
  factory $ExcludedVerseCopyWith(ExcludedVerse value, $Res Function(ExcludedVerse) _then) = _$ExcludedVerseCopyWithImpl;
@useResult
$Res call({
 int chapter, int verse
});




}
/// @nodoc
class _$ExcludedVerseCopyWithImpl<$Res>
    implements $ExcludedVerseCopyWith<$Res> {
  _$ExcludedVerseCopyWithImpl(this._self, this._then);

  final ExcludedVerse _self;
  final $Res Function(ExcludedVerse) _then;

/// Create a copy of ExcludedVerse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chapter = null,Object? verse = null,}) {
  return _then(ExcludedVerse(
chapter: null == chapter ? _self.chapter : chapter // ignore: cast_nullable_to_non_nullable
as int,verse: null == verse ? _self.verse : verse // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ExcludedVerse].
extension ExcludedVersePatterns on ExcludedVerse {
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

/// @nodoc
mixin _$ReadingSchedule {


/// Create a copy of ReadingSchedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingScheduleCopyWith<ReadingSchedule> get copyWith => _$ReadingScheduleCopyWithImpl<ReadingSchedule>(this as ReadingSchedule, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReadingSchedule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingSchedule&&const DeepCollectionEquality().equals(other.groupIds, _this.groupIds)&&(identical(other.scheduledDate, _this.scheduledDate) || other.scheduledDate == _this.scheduledDate)&&(identical(other.bookNumber, _this.bookNumber) || other.bookNumber == _this.bookNumber)&&(identical(other.startChapter, _this.startChapter) || other.startChapter == _this.startChapter)&&(identical(other.startVerse, _this.startVerse) || other.startVerse == _this.startVerse)&&(identical(other.endChapter, _this.endChapter) || other.endChapter == _this.endChapter)&&(identical(other.endVerse, _this.endVerse) || other.endVerse == _this.endVerse)&&const DeepCollectionEquality().equals(other.excludedVerses, _this.excludedVerses)&&(identical(other.generateAiQuestions, _this.generateAiQuestions) || other.generateAiQuestions == _this.generateAiQuestions));
}


@override
int get hashCode {
  final _this = this as ReadingSchedule;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.groupIds),_this.scheduledDate,_this.bookNumber,_this.startChapter,_this.startVerse,_this.endChapter,_this.endVerse,const DeepCollectionEquality().hash(_this.excludedVerses),_this.generateAiQuestions);
}

@override
String toString() {
  final _this = this as ReadingSchedule;
  return 'ReadingSchedule(groupIds: ${_this.groupIds}, scheduledDate: ${_this.scheduledDate}, bookNumber: ${_this.bookNumber}, startChapter: ${_this.startChapter}, startVerse: ${_this.startVerse}, endChapter: ${_this.endChapter}, endVerse: ${_this.endVerse}, excludedVerses: ${_this.excludedVerses}, generateAiQuestions: ${_this.generateAiQuestions})';
}


}

/// @nodoc
abstract mixin class $ReadingScheduleCopyWith<$Res>  {
  factory $ReadingScheduleCopyWith(ReadingSchedule value, $Res Function(ReadingSchedule) _then) = _$ReadingScheduleCopyWithImpl;
@useResult
$Res call({
 List<int> groupIds, String scheduledDate, int bookNumber, int startChapter, int startVerse, int endVerse, int? endChapter, List<ExcludedVerse> excludedVerses, bool generateAiQuestions
});




}
/// @nodoc
class _$ReadingScheduleCopyWithImpl<$Res>
    implements $ReadingScheduleCopyWith<$Res> {
  _$ReadingScheduleCopyWithImpl(this._self, this._then);

  final ReadingSchedule _self;
  final $Res Function(ReadingSchedule) _then;

/// Create a copy of ReadingSchedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupIds = null,Object? scheduledDate = null,Object? bookNumber = null,Object? startChapter = null,Object? startVerse = null,Object? endVerse = null,Object? endChapter = freezed,Object? excludedVerses = null,Object? generateAiQuestions = null,}) {
  return _then(ReadingSchedule(
groupIds: null == groupIds ? _self.groupIds : groupIds // ignore: cast_nullable_to_non_nullable
as List<int>,scheduledDate: null == scheduledDate ? _self.scheduledDate : scheduledDate // ignore: cast_nullable_to_non_nullable
as String,bookNumber: null == bookNumber ? _self.bookNumber : bookNumber // ignore: cast_nullable_to_non_nullable
as int,startChapter: null == startChapter ? _self.startChapter : startChapter // ignore: cast_nullable_to_non_nullable
as int,startVerse: null == startVerse ? _self.startVerse : startVerse // ignore: cast_nullable_to_non_nullable
as int,endVerse: null == endVerse ? _self.endVerse : endVerse // ignore: cast_nullable_to_non_nullable
as int,endChapter: freezed == endChapter ? _self.endChapter : endChapter // ignore: cast_nullable_to_non_nullable
as int?,excludedVerses: null == excludedVerses ? _self.excludedVerses : excludedVerses // ignore: cast_nullable_to_non_nullable
as List<ExcludedVerse>,generateAiQuestions: null == generateAiQuestions ? _self.generateAiQuestions : generateAiQuestions // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingSchedule].
extension ReadingSchedulePatterns on ReadingSchedule {
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
