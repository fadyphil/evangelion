// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UserSettings {


/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserSettingsCopyWith<UserSettings> get copyWith => _$UserSettingsCopyWithImpl<UserSettings>(this as UserSettings, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as UserSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserSettings&&(identical(other.themeMode, _this.themeMode) || other.themeMode == _this.themeMode)&&(identical(other.fontStep, _this.fontStep) || other.fontStep == _this.fontStep)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.reducedMotion, _this.reducedMotion) || other.reducedMotion == _this.reducedMotion)&&(identical(other.veilWitnesses, _this.veilWitnesses) || other.veilWitnesses == _this.veilWitnesses)&&(identical(other.showPodium, _this.showPodium) || other.showPodium == _this.showPodium)&&(identical(other.shaderEnabled, _this.shaderEnabled) || other.shaderEnabled == _this.shaderEnabled)&&(identical(other.curtainShape, _this.curtainShape) || other.curtainShape == _this.curtainShape)&&(identical(other.reach, _this.reach) || other.reach == _this.reach)&&(identical(other.glow, _this.glow) || other.glow == _this.glow)&&(identical(other.touchGlow, _this.touchGlow) || other.touchGlow == _this.touchGlow)&&(identical(other.hue, _this.hue) || other.hue == _this.hue)&&(identical(other.multichromeMelt, _this.multichromeMelt) || other.multichromeMelt == _this.multichromeMelt)&&(identical(other.rayCombing, _this.rayCombing) || other.rayCombing == _this.rayCombing)&&(identical(other.whiteCores, _this.whiteCores) || other.whiteCores == _this.whiteCores)&&(identical(other.dotVeil, _this.dotVeil) || other.dotVeil == _this.dotVeil)&&(identical(other.starsOn, _this.starsOn) || other.starsOn == _this.starsOn)&&(identical(other.constellationsOn, _this.constellationsOn) || other.constellationsOn == _this.constellationsOn)&&(identical(other.starCount, _this.starCount) || other.starCount == _this.starCount)&&(identical(other.starBrightness, _this.starBrightness) || other.starBrightness == _this.starBrightness)&&(identical(other.starShape, _this.starShape) || other.starShape == _this.starShape)&&(identical(other.starField, _this.starField) || other.starField == _this.starField)&&(identical(other.twinkle, _this.twinkle) || other.twinkle == _this.twinkle)&&(identical(other.focusDelaySec, _this.focusDelaySec) || other.focusDelaySec == _this.focusDelaySec)&&(identical(other.selahLengthSec, _this.selahLengthSec) || other.selahLengthSec == _this.selahLengthSec)&&(identical(other.breathGuide, _this.breathGuide) || other.breathGuide == _this.breathGuide)&&(identical(other.vespersAutoDim, _this.vespersAutoDim) || other.vespersAutoDim == _this.vespersAutoDim)&&(identical(other.calmMotion, _this.calmMotion) || other.calmMotion == _this.calmMotion)&&(identical(other.haptics, _this.haptics) || other.haptics == _this.haptics));
}


@override
int get hashCode {
  final _this = this as UserSettings;
  return Object.hashAll([runtimeType,_this.themeMode,_this.fontStep,_this.language,_this.reducedMotion,_this.veilWitnesses,_this.showPodium,_this.shaderEnabled,_this.curtainShape,_this.reach,_this.glow,_this.touchGlow,_this.hue,_this.multichromeMelt,_this.rayCombing,_this.whiteCores,_this.dotVeil,_this.starsOn,_this.constellationsOn,_this.starCount,_this.starBrightness,_this.starShape,_this.starField,_this.twinkle,_this.focusDelaySec,_this.selahLengthSec,_this.breathGuide,_this.vespersAutoDim,_this.calmMotion,_this.haptics]);
}

@override
String toString() {
  final _this = this as UserSettings;
  return 'UserSettings(themeMode: ${_this.themeMode}, fontStep: ${_this.fontStep}, language: ${_this.language}, reducedMotion: ${_this.reducedMotion}, veilWitnesses: ${_this.veilWitnesses}, showPodium: ${_this.showPodium}, shaderEnabled: ${_this.shaderEnabled}, curtainShape: ${_this.curtainShape}, reach: ${_this.reach}, glow: ${_this.glow}, touchGlow: ${_this.touchGlow}, hue: ${_this.hue}, multichromeMelt: ${_this.multichromeMelt}, rayCombing: ${_this.rayCombing}, whiteCores: ${_this.whiteCores}, dotVeil: ${_this.dotVeil}, starsOn: ${_this.starsOn}, constellationsOn: ${_this.constellationsOn}, starCount: ${_this.starCount}, starBrightness: ${_this.starBrightness}, starShape: ${_this.starShape}, starField: ${_this.starField}, twinkle: ${_this.twinkle}, focusDelaySec: ${_this.focusDelaySec}, selahLengthSec: ${_this.selahLengthSec}, breathGuide: ${_this.breathGuide}, vespersAutoDim: ${_this.vespersAutoDim}, calmMotion: ${_this.calmMotion}, haptics: ${_this.haptics})';
}


}

/// @nodoc
abstract mixin class $UserSettingsCopyWith<$Res>  {
  factory $UserSettingsCopyWith(UserSettings value, $Res Function(UserSettings) _then) = _$UserSettingsCopyWithImpl;
@useResult
$Res call({
 AppThemeMode themeMode, int fontStep, ReadingLanguage? language, bool reducedMotion, bool veilWitnesses, bool showPodium, bool shaderEnabled, CurtainShape curtainShape, int reach, int glow, int touchGlow, int hue, bool multichromeMelt, bool rayCombing, bool whiteCores, bool dotVeil, bool starsOn, bool constellationsOn, int starCount, int starBrightness, SkyStarShape starShape, SkyStarField starField, bool twinkle, int focusDelaySec, int selahLengthSec, bool breathGuide, bool vespersAutoDim, bool calmMotion, bool haptics
});




}
/// @nodoc
class _$UserSettingsCopyWithImpl<$Res>
    implements $UserSettingsCopyWith<$Res> {
  _$UserSettingsCopyWithImpl(this._self, this._then);

  final UserSettings _self;
  final $Res Function(UserSettings) _then;

/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeMode = null,Object? fontStep = null,Object? language = freezed,Object? reducedMotion = null,Object? veilWitnesses = null,Object? showPodium = null,Object? shaderEnabled = null,Object? curtainShape = null,Object? reach = null,Object? glow = null,Object? touchGlow = null,Object? hue = null,Object? multichromeMelt = null,Object? rayCombing = null,Object? whiteCores = null,Object? dotVeil = null,Object? starsOn = null,Object? constellationsOn = null,Object? starCount = null,Object? starBrightness = null,Object? starShape = null,Object? starField = null,Object? twinkle = null,Object? focusDelaySec = null,Object? selahLengthSec = null,Object? breathGuide = null,Object? vespersAutoDim = null,Object? calmMotion = null,Object? haptics = null,}) {
  return _then(UserSettings(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as AppThemeMode,fontStep: null == fontStep ? _self.fontStep : fontStep // ignore: cast_nullable_to_non_nullable
as int,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as ReadingLanguage?,reducedMotion: null == reducedMotion ? _self.reducedMotion : reducedMotion // ignore: cast_nullable_to_non_nullable
as bool,veilWitnesses: null == veilWitnesses ? _self.veilWitnesses : veilWitnesses // ignore: cast_nullable_to_non_nullable
as bool,showPodium: null == showPodium ? _self.showPodium : showPodium // ignore: cast_nullable_to_non_nullable
as bool,shaderEnabled: null == shaderEnabled ? _self.shaderEnabled : shaderEnabled // ignore: cast_nullable_to_non_nullable
as bool,curtainShape: null == curtainShape ? _self.curtainShape : curtainShape // ignore: cast_nullable_to_non_nullable
as CurtainShape,reach: null == reach ? _self.reach : reach // ignore: cast_nullable_to_non_nullable
as int,glow: null == glow ? _self.glow : glow // ignore: cast_nullable_to_non_nullable
as int,touchGlow: null == touchGlow ? _self.touchGlow : touchGlow // ignore: cast_nullable_to_non_nullable
as int,hue: null == hue ? _self.hue : hue // ignore: cast_nullable_to_non_nullable
as int,multichromeMelt: null == multichromeMelt ? _self.multichromeMelt : multichromeMelt // ignore: cast_nullable_to_non_nullable
as bool,rayCombing: null == rayCombing ? _self.rayCombing : rayCombing // ignore: cast_nullable_to_non_nullable
as bool,whiteCores: null == whiteCores ? _self.whiteCores : whiteCores // ignore: cast_nullable_to_non_nullable
as bool,dotVeil: null == dotVeil ? _self.dotVeil : dotVeil // ignore: cast_nullable_to_non_nullable
as bool,starsOn: null == starsOn ? _self.starsOn : starsOn // ignore: cast_nullable_to_non_nullable
as bool,constellationsOn: null == constellationsOn ? _self.constellationsOn : constellationsOn // ignore: cast_nullable_to_non_nullable
as bool,starCount: null == starCount ? _self.starCount : starCount // ignore: cast_nullable_to_non_nullable
as int,starBrightness: null == starBrightness ? _self.starBrightness : starBrightness // ignore: cast_nullable_to_non_nullable
as int,starShape: null == starShape ? _self.starShape : starShape // ignore: cast_nullable_to_non_nullable
as SkyStarShape,starField: null == starField ? _self.starField : starField // ignore: cast_nullable_to_non_nullable
as SkyStarField,twinkle: null == twinkle ? _self.twinkle : twinkle // ignore: cast_nullable_to_non_nullable
as bool,focusDelaySec: null == focusDelaySec ? _self.focusDelaySec : focusDelaySec // ignore: cast_nullable_to_non_nullable
as int,selahLengthSec: null == selahLengthSec ? _self.selahLengthSec : selahLengthSec // ignore: cast_nullable_to_non_nullable
as int,breathGuide: null == breathGuide ? _self.breathGuide : breathGuide // ignore: cast_nullable_to_non_nullable
as bool,vespersAutoDim: null == vespersAutoDim ? _self.vespersAutoDim : vespersAutoDim // ignore: cast_nullable_to_non_nullable
as bool,calmMotion: null == calmMotion ? _self.calmMotion : calmMotion // ignore: cast_nullable_to_non_nullable
as bool,haptics: null == haptics ? _self.haptics : haptics // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UserSettings].
extension UserSettingsPatterns on UserSettings {
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
