// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule_reading_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScheduleReadingForm {


/// Create a copy of ScheduleReadingForm
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleReadingFormCopyWith<ScheduleReadingForm> get copyWith => _$ScheduleReadingFormCopyWithImpl<ScheduleReadingForm>(this as ScheduleReadingForm, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ScheduleReadingForm;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleReadingForm&&(identical(other.groupIdsText, _this.groupIdsText) || other.groupIdsText == _this.groupIdsText)&&(identical(other.scheduledDateText, _this.scheduledDateText) || other.scheduledDateText == _this.scheduledDateText)&&(identical(other.bookNumberText, _this.bookNumberText) || other.bookNumberText == _this.bookNumberText)&&(identical(other.startChapterText, _this.startChapterText) || other.startChapterText == _this.startChapterText)&&(identical(other.startVerseText, _this.startVerseText) || other.startVerseText == _this.startVerseText)&&(identical(other.endChapterText, _this.endChapterText) || other.endChapterText == _this.endChapterText)&&(identical(other.endVerseText, _this.endVerseText) || other.endVerseText == _this.endVerseText)&&(identical(other.excludedVersesText, _this.excludedVersesText) || other.excludedVersesText == _this.excludedVersesText)&&(identical(other.generateAiQuestions, _this.generateAiQuestions) || other.generateAiQuestions == _this.generateAiQuestions));
}


@override
int get hashCode {
  final _this = this as ScheduleReadingForm;
  return Object.hash(runtimeType,_this.groupIdsText,_this.scheduledDateText,_this.bookNumberText,_this.startChapterText,_this.startVerseText,_this.endChapterText,_this.endVerseText,_this.excludedVersesText,_this.generateAiQuestions);
}

@override
String toString() {
  final _this = this as ScheduleReadingForm;
  return 'ScheduleReadingForm(groupIdsText: ${_this.groupIdsText}, scheduledDateText: ${_this.scheduledDateText}, bookNumberText: ${_this.bookNumberText}, startChapterText: ${_this.startChapterText}, startVerseText: ${_this.startVerseText}, endChapterText: ${_this.endChapterText}, endVerseText: ${_this.endVerseText}, excludedVersesText: ${_this.excludedVersesText}, generateAiQuestions: ${_this.generateAiQuestions})';
}


}

/// @nodoc
abstract mixin class $ScheduleReadingFormCopyWith<$Res>  {
  factory $ScheduleReadingFormCopyWith(ScheduleReadingForm value, $Res Function(ScheduleReadingForm) _then) = _$ScheduleReadingFormCopyWithImpl;
@useResult
$Res call({
 String groupIdsText, String scheduledDateText, String bookNumberText, String startChapterText, String startVerseText, String endChapterText, String endVerseText, String excludedVersesText, bool generateAiQuestions
});




}
/// @nodoc
class _$ScheduleReadingFormCopyWithImpl<$Res>
    implements $ScheduleReadingFormCopyWith<$Res> {
  _$ScheduleReadingFormCopyWithImpl(this._self, this._then);

  final ScheduleReadingForm _self;
  final $Res Function(ScheduleReadingForm) _then;

/// Create a copy of ScheduleReadingForm
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupIdsText = null,Object? scheduledDateText = null,Object? bookNumberText = null,Object? startChapterText = null,Object? startVerseText = null,Object? endChapterText = null,Object? endVerseText = null,Object? excludedVersesText = null,Object? generateAiQuestions = null,}) {
  return _then(ScheduleReadingForm(
groupIdsText: null == groupIdsText ? _self.groupIdsText : groupIdsText // ignore: cast_nullable_to_non_nullable
as String,scheduledDateText: null == scheduledDateText ? _self.scheduledDateText : scheduledDateText // ignore: cast_nullable_to_non_nullable
as String,bookNumberText: null == bookNumberText ? _self.bookNumberText : bookNumberText // ignore: cast_nullable_to_non_nullable
as String,startChapterText: null == startChapterText ? _self.startChapterText : startChapterText // ignore: cast_nullable_to_non_nullable
as String,startVerseText: null == startVerseText ? _self.startVerseText : startVerseText // ignore: cast_nullable_to_non_nullable
as String,endChapterText: null == endChapterText ? _self.endChapterText : endChapterText // ignore: cast_nullable_to_non_nullable
as String,endVerseText: null == endVerseText ? _self.endVerseText : endVerseText // ignore: cast_nullable_to_non_nullable
as String,excludedVersesText: null == excludedVersesText ? _self.excludedVersesText : excludedVersesText // ignore: cast_nullable_to_non_nullable
as String,generateAiQuestions: null == generateAiQuestions ? _self.generateAiQuestions : generateAiQuestions // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduleReadingForm].
extension ScheduleReadingFormPatterns on ScheduleReadingForm {
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
mixin _$ScheduleReadingState {





@override
bool operator ==(Object other) {
  final _this = this as ScheduleReadingState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleReadingState&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.form, _this.form) || other.form == _this.form)&&(identical(other.result, _this.result) || other.result == _this.result)&&(identical(other.failure, _this.failure) || other.failure == _this.failure)&&(identical(other.formError, _this.formError) || other.formError == _this.formError)&&(identical(other.formField, _this.formField) || other.formField == _this.formField));
}


@override
int get hashCode {
  final _this = this as ScheduleReadingState;
  return Object.hash(runtimeType,_this.status,_this.form,_this.result,_this.failure,_this.formError,_this.formField);
}

@override
String toString() {
  final _this = this as ScheduleReadingState;
  return 'ScheduleReadingState(status: ${_this.status}, form: ${_this.form}, result: ${_this.result}, failure: ${_this.failure}, formError: ${_this.formError}, formField: ${_this.formField})';
}


}




/// Adds pattern-matching-related methods to [ScheduleReadingState].
extension ScheduleReadingStatePatterns on ScheduleReadingState {
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
