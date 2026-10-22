// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'servant_report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ServantReport {


/// Create a copy of ServantReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServantReportCopyWith<ServantReport> get copyWith => _$ServantReportCopyWithImpl<ServantReport>(this as ServantReport, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ServantReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServantReport&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.reportDate, _this.reportDate) || other.reportDate == _this.reportDate)&&(identical(other.totalStudents, _this.totalStudents) || other.totalStudents == _this.totalStudents)&&(identical(other.completedCount, _this.completedCount) || other.completedCount == _this.completedCount)&&const DeepCollectionEquality().equals(other.students, _this.students));
}


@override
int get hashCode {
  final _this = this as ServantReport;
  return Object.hash(runtimeType,_this.groupId,_this.reportDate,_this.totalStudents,_this.completedCount,const DeepCollectionEquality().hash(_this.students));
}



}

/// @nodoc
abstract mixin class $ServantReportCopyWith<$Res>  {
  factory $ServantReportCopyWith(ServantReport value, $Res Function(ServantReport) _then) = _$ServantReportCopyWithImpl;
@useResult
$Res call({
 int groupId, String reportDate, int totalStudents, int completedCount, List<RosterStudent> students
});




}
/// @nodoc
class _$ServantReportCopyWithImpl<$Res>
    implements $ServantReportCopyWith<$Res> {
  _$ServantReportCopyWithImpl(this._self, this._then);

  final ServantReport _self;
  final $Res Function(ServantReport) _then;

/// Create a copy of ServantReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupId = null,Object? reportDate = null,Object? totalStudents = null,Object? completedCount = null,Object? students = null,}) {
  return _then(ServantReport(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int,reportDate: null == reportDate ? _self.reportDate : reportDate // ignore: cast_nullable_to_non_nullable
as String,totalStudents: null == totalStudents ? _self.totalStudents : totalStudents // ignore: cast_nullable_to_non_nullable
as int,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,students: null == students ? _self.students : students // ignore: cast_nullable_to_non_nullable
as List<RosterStudent>,
  ));
}

}


/// Adds pattern-matching-related methods to [ServantReport].
extension ServantReportPatterns on ServantReport {
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
