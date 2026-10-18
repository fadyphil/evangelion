// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LibraryBook {


/// Create a copy of LibraryBook
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryBookCopyWith<LibraryBook> get copyWith => _$LibraryBookCopyWithImpl<LibraryBook>(this as LibraryBook, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LibraryBook;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryBook&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.nameEn, _this.nameEn) || other.nameEn == _this.nameEn)&&(identical(other.nameAr, _this.nameAr) || other.nameAr == _this.nameAr)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.sealed, _this.sealed) || other.sealed == _this.sealed)&&(identical(other.bloomArgb, _this.bloomArgb) || other.bloomArgb == _this.bloomArgb)&&(identical(other.verseCount, _this.verseCount) || other.verseCount == _this.verseCount));
}


@override
int get hashCode {
  final _this = this as LibraryBook;
  return Object.hash(runtimeType,_this.id,_this.nameEn,_this.nameAr,_this.category,_this.sealed,_this.bloomArgb,_this.verseCount);
}

@override
String toString() {
  final _this = this as LibraryBook;
  return 'LibraryBook(id: ${_this.id}, nameEn: ${_this.nameEn}, nameAr: ${_this.nameAr}, category: ${_this.category}, sealed: ${_this.sealed}, bloomArgb: ${_this.bloomArgb}, verseCount: ${_this.verseCount})';
}


}

/// @nodoc
abstract mixin class $LibraryBookCopyWith<$Res>  {
  factory $LibraryBookCopyWith(LibraryBook value, $Res Function(LibraryBook) _then) = _$LibraryBookCopyWithImpl;
@useResult
$Res call({
 String id, String nameEn, String nameAr, LibraryCategory category, bool sealed, int bloomArgb, int? verseCount
});




}
/// @nodoc
class _$LibraryBookCopyWithImpl<$Res>
    implements $LibraryBookCopyWith<$Res> {
  _$LibraryBookCopyWithImpl(this._self, this._then);

  final LibraryBook _self;
  final $Res Function(LibraryBook) _then;

/// Create a copy of LibraryBook
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nameEn = null,Object? nameAr = null,Object? category = null,Object? sealed = null,Object? bloomArgb = null,Object? verseCount = freezed,}) {
  return _then(LibraryBook(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nameEn: null == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String,nameAr: null == nameAr ? _self.nameAr : nameAr // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as LibraryCategory,sealed: null == sealed ? _self.sealed : sealed // ignore: cast_nullable_to_non_nullable
as bool,bloomArgb: null == bloomArgb ? _self.bloomArgb : bloomArgb // ignore: cast_nullable_to_non_nullable
as int,verseCount: freezed == verseCount ? _self.verseCount : verseCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibraryBook].
extension LibraryBookPatterns on LibraryBook {
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
