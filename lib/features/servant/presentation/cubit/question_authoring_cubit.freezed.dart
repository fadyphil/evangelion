// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'question_authoring_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QuestionAuthoringState {





@override
bool operator ==(Object other) {
  final _this = this as QuestionAuthoringState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionAuthoringState&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.readingId, _this.readingId) || other.readingId == _this.readingId)&&(identical(other.draft, _this.draft) || other.draft == _this.draft)&&(identical(other.commitResult, _this.commitResult) || other.commitResult == _this.commitResult)&&(identical(other.failure, _this.failure) || other.failure == _this.failure)&&(identical(other.formError, _this.formError) || other.formError == _this.formError)&&(identical(other.pointsText, _this.pointsText) || other.pointsText == _this.pointsText)&&(identical(other.sortOrderText, _this.sortOrderText) || other.sortOrderText == _this.sortOrderText));
}


@override
int get hashCode {
  final _this = this as QuestionAuthoringState;
  return Object.hash(runtimeType,_this.status,_this.readingId,_this.draft,_this.commitResult,_this.failure,_this.formError,_this.pointsText,_this.sortOrderText);
}

@override
String toString() {
  final _this = this as QuestionAuthoringState;
  return 'QuestionAuthoringState(status: ${_this.status}, readingId: ${_this.readingId}, draft: ${_this.draft}, commitResult: ${_this.commitResult}, failure: ${_this.failure}, formError: ${_this.formError}, pointsText: ${_this.pointsText}, sortOrderText: ${_this.sortOrderText})';
}


}




/// Adds pattern-matching-related methods to [QuestionAuthoringState].
extension QuestionAuthoringStatePatterns on QuestionAuthoringState {
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
