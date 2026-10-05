// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quiz_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QuizAnswer {


/// Create a copy of QuizAnswer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuizAnswerCopyWith<QuizAnswer> get copyWith => _$QuizAnswerCopyWithImpl<QuizAnswer>(this as QuizAnswer, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as QuizAnswer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuizAnswer&&(identical(other.question, _this.question) || other.question == _this.question)&&(identical(other.selectedLetter, _this.selectedLetter) || other.selectedLetter == _this.selectedLetter)&&(identical(other.verdict, _this.verdict) || other.verdict == _this.verdict));
}


@override
int get hashCode {
  final _this = this as QuizAnswer;
  return Object.hash(runtimeType,_this.question,_this.selectedLetter,_this.verdict);
}

@override
String toString() {
  final _this = this as QuizAnswer;
  return 'QuizAnswer(question: ${_this.question}, selectedLetter: ${_this.selectedLetter}, verdict: ${_this.verdict})';
}


}

/// @nodoc
abstract mixin class $QuizAnswerCopyWith<$Res>  {
  factory $QuizAnswerCopyWith(QuizAnswer value, $Res Function(QuizAnswer) _then) = _$QuizAnswerCopyWithImpl;
@useResult
$Res call({
 Question question, String? selectedLetter, SubmitResult? verdict
});




}
/// @nodoc
class _$QuizAnswerCopyWithImpl<$Res>
    implements $QuizAnswerCopyWith<$Res> {
  _$QuizAnswerCopyWithImpl(this._self, this._then);

  final QuizAnswer _self;
  final $Res Function(QuizAnswer) _then;

/// Create a copy of QuizAnswer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? question = null,Object? selectedLetter = freezed,Object? verdict = freezed,}) {
  return _then(QuizAnswer(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as Question,selectedLetter: freezed == selectedLetter ? _self.selectedLetter : selectedLetter // ignore: cast_nullable_to_non_nullable
as String?,verdict: freezed == verdict ? _self.verdict : verdict // ignore: cast_nullable_to_non_nullable
as SubmitResult?,
  ));
}

}


/// Adds pattern-matching-related methods to [QuizAnswer].
extension QuizAnswerPatterns on QuizAnswer {
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
mixin _$QuizSession {


/// Create a copy of QuizSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuizSessionCopyWith<QuizSession> get copyWith => _$QuizSessionCopyWithImpl<QuizSession>(this as QuizSession, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as QuizSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuizSession&&(identical(other.readingId, _this.readingId) || other.readingId == _this.readingId)&&const DeepCollectionEquality().equals(other.answers, _this.answers));
}


@override
int get hashCode {
  final _this = this as QuizSession;
  return Object.hash(runtimeType,_this.readingId,const DeepCollectionEquality().hash(_this.answers));
}

@override
String toString() {
  final _this = this as QuizSession;
  return 'QuizSession(readingId: ${_this.readingId}, answers: ${_this.answers})';
}


}

/// @nodoc
abstract mixin class $QuizSessionCopyWith<$Res>  {
  factory $QuizSessionCopyWith(QuizSession value, $Res Function(QuizSession) _then) = _$QuizSessionCopyWithImpl;
@useResult
$Res call({
 String readingId, List<QuizAnswer> answers
});




}
/// @nodoc
class _$QuizSessionCopyWithImpl<$Res>
    implements $QuizSessionCopyWith<$Res> {
  _$QuizSessionCopyWithImpl(this._self, this._then);

  final QuizSession _self;
  final $Res Function(QuizSession) _then;

/// Create a copy of QuizSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? readingId = null,Object? answers = null,}) {
  return _then(QuizSession(
readingId: null == readingId ? _self.readingId : readingId // ignore: cast_nullable_to_non_nullable
as String,answers: null == answers ? _self.answers : answers // ignore: cast_nullable_to_non_nullable
as List<QuizAnswer>,
  ));
}

}


/// Adds pattern-matching-related methods to [QuizSession].
extension QuizSessionPatterns on QuizSession {
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
