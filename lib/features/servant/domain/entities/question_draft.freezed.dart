// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'question_draft.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QuestionOption {


/// Create a copy of QuestionOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionOptionCopyWith<QuestionOption> get copyWith => _$QuestionOptionCopyWithImpl<QuestionOption>(this as QuestionOption, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as QuestionOption;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionOption&&(identical(other.ar, _this.ar) || other.ar == _this.ar)&&(identical(other.en, _this.en) || other.en == _this.en));
}


@override
int get hashCode {
  final _this = this as QuestionOption;
  return Object.hash(runtimeType,_this.ar,_this.en);
}

@override
String toString() {
  final _this = this as QuestionOption;
  return 'QuestionOption(ar: ${_this.ar}, en: ${_this.en})';
}


}

/// @nodoc
abstract mixin class $QuestionOptionCopyWith<$Res>  {
  factory $QuestionOptionCopyWith(QuestionOption value, $Res Function(QuestionOption) _then) = _$QuestionOptionCopyWithImpl;
@useResult
$Res call({
 String ar, String en
});




}
/// @nodoc
class _$QuestionOptionCopyWithImpl<$Res>
    implements $QuestionOptionCopyWith<$Res> {
  _$QuestionOptionCopyWithImpl(this._self, this._then);

  final QuestionOption _self;
  final $Res Function(QuestionOption) _then;

/// Create a copy of QuestionOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ar = null,Object? en = null,}) {
  return _then(QuestionOption(
ar: null == ar ? _self.ar : ar // ignore: cast_nullable_to_non_nullable
as String,en: null == en ? _self.en : en // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [QuestionOption].
extension QuestionOptionPatterns on QuestionOption {
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
mixin _$QuestionDraft {


/// Create a copy of QuestionDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionDraftCopyWith<QuestionDraft> get copyWith => _$QuestionDraftCopyWithImpl<QuestionDraft>(this as QuestionDraft, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as QuestionDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionDraft&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.promptAr, _this.promptAr) || other.promptAr == _this.promptAr)&&(identical(other.promptEn, _this.promptEn) || other.promptEn == _this.promptEn)&&const DeepCollectionEquality().equals(other.options, _this.options)&&(identical(other.correctAnswer, _this.correctAnswer) || other.correctAnswer == _this.correctAnswer)&&(identical(other.pointsValue, _this.pointsValue) || other.pointsValue == _this.pointsValue)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.isApproved, _this.isApproved) || other.isApproved == _this.isApproved));
}


@override
int get hashCode {
  final _this = this as QuestionDraft;
  return Object.hash(runtimeType,_this.type,_this.promptAr,_this.promptEn,const DeepCollectionEquality().hash(_this.options),_this.correctAnswer,_this.pointsValue,_this.sortOrder,_this.isApproved);
}

@override
String toString() {
  final _this = this as QuestionDraft;
  return 'QuestionDraft(type: ${_this.type}, promptAr: ${_this.promptAr}, promptEn: ${_this.promptEn}, options: ${_this.options}, correctAnswer: ${_this.correctAnswer}, pointsValue: ${_this.pointsValue}, sortOrder: ${_this.sortOrder}, isApproved: ${_this.isApproved})';
}


}

/// @nodoc
abstract mixin class $QuestionDraftCopyWith<$Res>  {
  factory $QuestionDraftCopyWith(QuestionDraft value, $Res Function(QuestionDraft) _then) = _$QuestionDraftCopyWithImpl;
@useResult
$Res call({
 QuestionType type, String promptAr, String promptEn, Map<String, QuestionOption> options, String correctAnswer, int pointsValue, int sortOrder, bool isApproved
});




}
/// @nodoc
class _$QuestionDraftCopyWithImpl<$Res>
    implements $QuestionDraftCopyWith<$Res> {
  _$QuestionDraftCopyWithImpl(this._self, this._then);

  final QuestionDraft _self;
  final $Res Function(QuestionDraft) _then;

/// Create a copy of QuestionDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? promptAr = null,Object? promptEn = null,Object? options = null,Object? correctAnswer = null,Object? pointsValue = null,Object? sortOrder = null,Object? isApproved = null,}) {
  return _then(QuestionDraft(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as QuestionType,promptAr: null == promptAr ? _self.promptAr : promptAr // ignore: cast_nullable_to_non_nullable
as String,promptEn: null == promptEn ? _self.promptEn : promptEn // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as Map<String, QuestionOption>,correctAnswer: null == correctAnswer ? _self.correctAnswer : correctAnswer // ignore: cast_nullable_to_non_nullable
as String,pointsValue: null == pointsValue ? _self.pointsValue : pointsValue // ignore: cast_nullable_to_non_nullable
as int,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,isApproved: null == isApproved ? _self.isApproved : isApproved // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [QuestionDraft].
extension QuestionDraftPatterns on QuestionDraft {
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
