// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'leaderboard_board.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LeaderboardRow {


/// Create a copy of LeaderboardRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeaderboardRowCopyWith<LeaderboardRow> get copyWith => _$LeaderboardRowCopyWithImpl<LeaderboardRow>(this as LeaderboardRow, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LeaderboardRow;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeaderboardRow&&(identical(other.rank, _this.rank) || other.rank == _this.rank)&&(identical(other.score, _this.score) || other.score == _this.score)&&(identical(other.initials, _this.initials) || other.initials == _this.initials));
}


@override
int get hashCode {
  final _this = this as LeaderboardRow;
  return Object.hash(runtimeType,_this.rank,_this.score,_this.initials);
}

@override
String toString() {
  final _this = this as LeaderboardRow;
  return 'LeaderboardRow(rank: ${_this.rank}, score: ${_this.score}, initials: ${_this.initials})';
}


}

/// @nodoc
abstract mixin class $LeaderboardRowCopyWith<$Res>  {
  factory $LeaderboardRowCopyWith(LeaderboardRow value, $Res Function(LeaderboardRow) _then) = _$LeaderboardRowCopyWithImpl;
@useResult
$Res call({
 int rank, int score, String initials
});




}
/// @nodoc
class _$LeaderboardRowCopyWithImpl<$Res>
    implements $LeaderboardRowCopyWith<$Res> {
  _$LeaderboardRowCopyWithImpl(this._self, this._then);

  final LeaderboardRow _self;
  final $Res Function(LeaderboardRow) _then;

/// Create a copy of LeaderboardRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rank = null,Object? score = null,Object? initials = null,}) {
  return _then(LeaderboardRow(
rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,initials: null == initials ? _self.initials : initials // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LeaderboardRow].
extension LeaderboardRowPatterns on LeaderboardRow {
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
mixin _$LeaderboardStanding {


/// Create a copy of LeaderboardStanding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeaderboardStandingCopyWith<LeaderboardStanding> get copyWith => _$LeaderboardStandingCopyWithImpl<LeaderboardStanding>(this as LeaderboardStanding, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LeaderboardStanding;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeaderboardStanding&&(identical(other.rank, _this.rank) || other.rank == _this.rank)&&(identical(other.score, _this.score) || other.score == _this.score));
}


@override
int get hashCode {
  final _this = this as LeaderboardStanding;
  return Object.hash(runtimeType,_this.rank,_this.score);
}

@override
String toString() {
  final _this = this as LeaderboardStanding;
  return 'LeaderboardStanding(rank: ${_this.rank}, score: ${_this.score})';
}


}

/// @nodoc
abstract mixin class $LeaderboardStandingCopyWith<$Res>  {
  factory $LeaderboardStandingCopyWith(LeaderboardStanding value, $Res Function(LeaderboardStanding) _then) = _$LeaderboardStandingCopyWithImpl;
@useResult
$Res call({
 int? rank, int score
});




}
/// @nodoc
class _$LeaderboardStandingCopyWithImpl<$Res>
    implements $LeaderboardStandingCopyWith<$Res> {
  _$LeaderboardStandingCopyWithImpl(this._self, this._then);

  final LeaderboardStanding _self;
  final $Res Function(LeaderboardStanding) _then;

/// Create a copy of LeaderboardStanding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rank = freezed,Object? score = null,}) {
  return _then(LeaderboardStanding(
rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LeaderboardStanding].
extension LeaderboardStandingPatterns on LeaderboardStanding {
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
mixin _$LeaderboardBoard {


/// Create a copy of LeaderboardBoard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeaderboardBoardCopyWith<LeaderboardBoard> get copyWith => _$LeaderboardBoardCopyWithImpl<LeaderboardBoard>(this as LeaderboardBoard, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LeaderboardBoard;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeaderboardBoard&&(identical(other.window, _this.window) || other.window == _this.window)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&const DeepCollectionEquality().equals(other.rows, _this.rows)&&(identical(other.standing, _this.standing) || other.standing == _this.standing));
}


@override
int get hashCode {
  final _this = this as LeaderboardBoard;
  return Object.hash(runtimeType,_this.window,_this.groupId,const DeepCollectionEquality().hash(_this.rows),_this.standing);
}

@override
String toString() {
  final _this = this as LeaderboardBoard;
  return 'LeaderboardBoard(window: ${_this.window}, groupId: ${_this.groupId}, rows: ${_this.rows}, standing: ${_this.standing})';
}


}

/// @nodoc
abstract mixin class $LeaderboardBoardCopyWith<$Res>  {
  factory $LeaderboardBoardCopyWith(LeaderboardBoard value, $Res Function(LeaderboardBoard) _then) = _$LeaderboardBoardCopyWithImpl;
@useResult
$Res call({
 LeaderboardWindow window, int groupId, List<LeaderboardRow> rows, LeaderboardStanding? standing
});




}
/// @nodoc
class _$LeaderboardBoardCopyWithImpl<$Res>
    implements $LeaderboardBoardCopyWith<$Res> {
  _$LeaderboardBoardCopyWithImpl(this._self, this._then);

  final LeaderboardBoard _self;
  final $Res Function(LeaderboardBoard) _then;

/// Create a copy of LeaderboardBoard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? window = null,Object? groupId = null,Object? rows = null,Object? standing = freezed,}) {
  return _then(LeaderboardBoard(
window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as LeaderboardWindow,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<LeaderboardRow>,standing: freezed == standing ? _self.standing : standing // ignore: cast_nullable_to_non_nullable
as LeaderboardStanding?,
  ));
}

}


/// Adds pattern-matching-related methods to [LeaderboardBoard].
extension LeaderboardBoardPatterns on LeaderboardBoard {
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
