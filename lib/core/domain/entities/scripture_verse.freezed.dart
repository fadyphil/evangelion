// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scripture_verse.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Verse {


/// Create a copy of Verse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VerseCopyWith<Verse> get copyWith => _$VerseCopyWithImpl<Verse>(this as Verse, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Verse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Verse&&(identical(other.bookNumber, _this.bookNumber) || other.bookNumber == _this.bookNumber)&&(identical(other.chapter, _this.chapter) || other.chapter == _this.chapter)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.textClean, _this.textClean) || other.textClean == _this.textClean));
}


@override
int get hashCode {
  final _this = this as Verse;
  return Object.hash(runtimeType,_this.bookNumber,_this.chapter,_this.number,_this.text,_this.textClean);
}

@override
String toString() {
  final _this = this as Verse;
  return 'Verse(bookNumber: ${_this.bookNumber}, chapter: ${_this.chapter}, number: ${_this.number}, text: ${_this.text}, textClean: ${_this.textClean})';
}


}

/// @nodoc
abstract mixin class $VerseCopyWith<$Res>  {
  factory $VerseCopyWith(Verse value, $Res Function(Verse) _then) = _$VerseCopyWithImpl;
@useResult
$Res call({
 int bookNumber, int chapter, int number, String text, String? textClean
});




}
/// @nodoc
class _$VerseCopyWithImpl<$Res>
    implements $VerseCopyWith<$Res> {
  _$VerseCopyWithImpl(this._self, this._then);

  final Verse _self;
  final $Res Function(Verse) _then;

/// Create a copy of Verse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookNumber = null,Object? chapter = null,Object? number = null,Object? text = null,Object? textClean = freezed,}) {
  return _then(Verse(
bookNumber: null == bookNumber ? _self.bookNumber : bookNumber // ignore: cast_nullable_to_non_nullable
as int,chapter: null == chapter ? _self.chapter : chapter // ignore: cast_nullable_to_non_nullable
as int,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,textClean: freezed == textClean ? _self.textClean : textClean // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Verse].
extension VersePatterns on Verse {
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
mixin _$ScriptureText {


/// Create a copy of ScriptureText
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScriptureTextCopyWith<ScriptureText> get copyWith => _$ScriptureTextCopyWithImpl<ScriptureText>(this as ScriptureText, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ScriptureText;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScriptureText&&(identical(other.readingId, _this.readingId) || other.readingId == _this.readingId)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.scheduledDate, _this.scheduledDate) || other.scheduledDate == _this.scheduledDate)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.reference, _this.reference) || other.reference == _this.reference)&&(identical(other.translation, _this.translation) || other.translation == _this.translation)&&const DeepCollectionEquality().equals(other.verses, _this.verses)&&const DeepCollectionEquality().equals(other.questions, _this.questions)&&(identical(other.isFullyCompleted, _this.isFullyCompleted) || other.isFullyCompleted == _this.isFullyCompleted)&&(identical(other.pointsEarnedToday, _this.pointsEarnedToday) || other.pointsEarnedToday == _this.pointsEarnedToday)&&(identical(other.currentStreak, _this.currentStreak) || other.currentStreak == _this.currentStreak));
}


@override
int get hashCode {
  final _this = this as ScriptureText;
  return Object.hash(runtimeType,_this.readingId,_this.groupId,_this.scheduledDate,_this.language,_this.reference,_this.translation,const DeepCollectionEquality().hash(_this.verses),const DeepCollectionEquality().hash(_this.questions),_this.isFullyCompleted,_this.pointsEarnedToday,_this.currentStreak);
}

@override
String toString() {
  final _this = this as ScriptureText;
  return 'ScriptureText(readingId: ${_this.readingId}, groupId: ${_this.groupId}, scheduledDate: ${_this.scheduledDate}, language: ${_this.language}, reference: ${_this.reference}, translation: ${_this.translation}, verses: ${_this.verses}, questions: ${_this.questions}, isFullyCompleted: ${_this.isFullyCompleted}, pointsEarnedToday: ${_this.pointsEarnedToday}, currentStreak: ${_this.currentStreak})';
}


}

/// @nodoc
abstract mixin class $ScriptureTextCopyWith<$Res>  {
  factory $ScriptureTextCopyWith(ScriptureText value, $Res Function(ScriptureText) _then) = _$ScriptureTextCopyWithImpl;
@useResult
$Res call({
 String readingId, int groupId, String scheduledDate, ReadingLanguage language, String reference, String translation, List<Verse> verses, List<Question> questions, bool isFullyCompleted, int pointsEarnedToday, int currentStreak
});




}
/// @nodoc
class _$ScriptureTextCopyWithImpl<$Res>
    implements $ScriptureTextCopyWith<$Res> {
  _$ScriptureTextCopyWithImpl(this._self, this._then);

  final ScriptureText _self;
  final $Res Function(ScriptureText) _then;

/// Create a copy of ScriptureText
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? readingId = null,Object? groupId = null,Object? scheduledDate = null,Object? language = null,Object? reference = null,Object? translation = null,Object? verses = null,Object? questions = null,Object? isFullyCompleted = null,Object? pointsEarnedToday = null,Object? currentStreak = null,}) {
  return _then(ScriptureText(
readingId: null == readingId ? _self.readingId : readingId // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int,scheduledDate: null == scheduledDate ? _self.scheduledDate : scheduledDate // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as ReadingLanguage,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,translation: null == translation ? _self.translation : translation // ignore: cast_nullable_to_non_nullable
as String,verses: null == verses ? _self.verses : verses // ignore: cast_nullable_to_non_nullable
as List<Verse>,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<Question>,isFullyCompleted: null == isFullyCompleted ? _self.isFullyCompleted : isFullyCompleted // ignore: cast_nullable_to_non_nullable
as bool,pointsEarnedToday: null == pointsEarnedToday ? _self.pointsEarnedToday : pointsEarnedToday // ignore: cast_nullable_to_non_nullable
as int,currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ScriptureText].
extension ScriptureTextPatterns on ScriptureText {
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
