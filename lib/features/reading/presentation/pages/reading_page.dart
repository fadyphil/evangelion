import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/app/sky_scope.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/ritual_haptic.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/reading/domain/reading_focus.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:evangelion/features/reading/presentation/reading_l10n.dart';
import 'package:evangelion/features/reading/presentation/widgets/breath_guide_line.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_app_bar.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_quiz_cta.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The reading sanctuary, rebuilt against `eva/redesign.html:540-560`.
///
/// ## THE SCREEN IS A **COLUMN**, AND EVERY PART OF IT FOLLOWS FROM THAT
///
/// `:128` gives `.route` `display:flex; flex-direction:column; overflow:hidden`,
/// and the reader's five children are in source order: `.appbar`, `.appbar.sub`,
/// `.versebox`, `.qcta`, `.pill`. Only `.versebox` grows — `:159` gives it
/// `flex:1` and `overflow-y:auto` — so it is the screen's only scrollable and the
/// other four keep their own heights, pinned top and bottom.
///
/// The previous version was a `Stack` over a scaffold with a header, a controls
/// row, a passage block and a *sticky* CTA floated above the lot. Nothing here is
/// floating: the CTA and the pill are siblings of the list, and the list scrolls
/// between them.
///
/// ## AND THE SKY IS BEHIND THE WHOLE COLUMN, NOT BEHIND THE VERSES
///
/// `#sky` (`:116`) is `position:absolute; inset:0` on the **screen**, and
/// `WitnessSky`'s doc is explicit that it fills whatever box it is given. So it is
/// the stack's first child at `Positioned.fill` and the column draws over it —
/// which is what makes the pill's translucent fill read as glass even though the
/// pill does not blur (§13.4's budget; `reading_pill.dart`'s doc carries the
/// recorded consequence).
@RoutePage()
class ReadingPage extends StatelessWidget {
  const ReadingPage({super.key, this.cubit});

  /// The cubit, or `null` to resolve the registered singleton — the same two
  /// sources for one cubit `HomePage` uses, and for its reason.
  final ReadingCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final ReadingCubit? passed = cubit;
    final ReadingCubit resolved = passed ?? getIt<ReadingCubit>();

    return BlocProvider<ReadingCubit>.value(
      value: resolved,
      child: const _ReadingBody(),
    );
  }
}

/// Everything below the scaffold: the two bars, the verses, the CTA, the pill.
///
/// A [StatefulWidget] for three reasons, and every one of them is a **clock or a
/// measurement** with nowhere else to live: the entrance stagger
/// (`eva/redesign.html:1383`), the star observer (`:1211-1219`), and focus mode
/// (`:1286-1294`).
///
/// ## AND THE LOAD FIRES FROM `didChangeDependencies`, NOT `initState`
///
/// `Localizations.localeOf` is an inherited-widget lookup and Flutter forbids
/// those in `initState`. The fix is the phase the framework names for a lookup,
/// and it is also the phase that fires **on a locale change** — the second trigger
/// this screen needs, because the pill's `EN`/`ع` control changes the locale and
/// `/reading` must then show the other arm's passage, not the same text under new
/// chrome.
///
/// Guarded on [_requested] being a [ReadingLanguage] and not a `bool`: a `bool`
/// cannot say **which** arm was asked for, so a locale change would re-issue no
/// request and leave English chrome over Arabic scripture.
class _ReadingBody extends StatefulWidget {
  const _ReadingBody();

  @override
  State<_ReadingBody> createState() => _ReadingBodyState();
}

class _ReadingBodyState extends State<_ReadingBody> {
  /// The arm of the corpus on screen, or `null` before the first dispatch.
  ///
  /// A **getter**, because it reads an inherited widget — caching it in
  /// `initState` is the mistake [didChangeDependencies]'s doc describes.
  ReadingLanguage get _language =>
      ReadingLanguage.forLocale(Localizations.localeOf(context).languageCode);

  ReadingLanguage? _requested;

  /// The arm **on screen** — the dial's truth, and the page's own.
  ///
  /// ## WHY THIS IS A FIELD AND NOT ANOTHER LOCALE READ
  ///
  /// Because the reader can change it **without changing the locale**:
  /// `eva/redesign.html:554`'s dial is on the screen's own face, and
  /// `:1477-1480`'s `data-l` buttons set the arm in place. In production the dial
  /// *also* writes `UserSettings.language`, and `app.dart` rebuilds the locale —
  /// so the two agree. In a widget test that mounts the page over a bare
  /// `MaterialApp.router`, nothing rebuilds the locale on a settings write, and a
  /// getter would snap the dial's selection back to the locale's arm while the
  /// passage below it was the other one — a screen that contradicts itself, which
  /// is the failure this field exists to make unreachable.
  ///
  /// [_load] keeps it in step with the locale, so a settings change still wins:
  /// the dial is a local override, the locale is the owner.
  ReadingLanguage _arm = ReadingLanguage.english;

  /// The reader's font step, read back out of the installed scaler.
  ///
  /// ## WHY A GETTER AND NOT A FIELD
  ///
  /// A field would have to be kept in step with `UserSettings`, and there is one
  /// writer of that value in the process (`SettingsCubit`). Reading it means this
  /// screen cannot hold a stale copy: `MediaApp`'s `builder` installs
  /// `evaScalerFor(step)`, and `fontStepFromScaler` is the table's own inverse.
  int get _fontStep => fontStepFromScaler(MediaQuery.textScalerOf(context));

  /// How many verses have finished their reveal.
  ///
  /// **A count and not a set of indices**, because `reading_focus.dart`'s schedule
  /// is strictly increasing (`80 + 25n`), so the revealed set is always a prefix
  /// and a count is the whole of it. A set could describe a state the prototype
  /// cannot reach, and a screen that reaches it has a bug nobody would notice.
  int _revealed = 0;

  /// The passage whose entrance is running or has run, so it runs **once** per
  /// passage rather than on every state change.
  ///
  /// **Keyed on the reading id and not on the state object**, because the state is
  /// freezed and a new instance arrives on every emit — including the font step's
  /// and the focus timer's, which would restart a reader's stagger every time they
  /// adjusted their text size.
  String? _entranceFor;

  /// The verse the reader last selected — `:1385-1386`'s `.hot`.
  ///
  /// **`null` until one is chosen, and that is the prototype's own default**:
  /// nothing opens a sheet with a verse selected, and `:1443`'s 460 ms timer adds
  /// `.hot` to the verse that was tapped.
  int? _hot;

  /// Whether focus mode is dimming the chrome. `:1292` adds `.focus` after the
  /// idle delay; `:1290` removes it on any pointer press.
  bool _focusDim = false;

  /// The idle timer behind [_focusDim]. See [_poke].
  Timer? _idle;

  /// The timer chain running the entrance stagger.
  Timer? _stagger;

  /// The verse the reader left off at — `:1380`'s `.resume`, and the only state
  /// on this screen that outlives the mount.
  int? _resume;

  /// Whether the bookmark is lit — `:154`'s `.iconbtn.lit`.
  ///
  /// **Local state and not persisted, and that is a recorded gap rather than an
  /// oversight**: `:1394`'s toggle calls `haptic(12)` and a toast and nothing
  /// else, and §2's route table has no bookmark endpoint — so a stored bookmark
  /// would be a fiction in the one place this screen is otherwise entirely real.
  /// It survives a rebuild and nothing else.
  bool _bookmarked = false;

  /// A key per built verse, so the observer can measure it.
  ///
  /// **Cleared whenever the passage changes**, which bounds it by the passage's
  /// own length: a `GlobalKey` per verse for a 200-verse psalm is 200 keys, which
  /// is why the map holds only verses `ListView.builder` has **built** — the ones
  /// the observer can actually see — and the next passage starts from empty.
  final Map<int, GlobalKey> _verseKeys = <int, GlobalKey>{};

  /// The verses already credited with a star. `:1218`'s `vObs.unobserve(p)`.
  final Set<int> _lit = <int>{};

  /// The sky's seam.
  ///
  /// [SkyScope.read] and not [SkyScope.of], because the observer runs inside a
  /// scroll callback: **subscribing** there would register a dependency during
  /// layout and rebuild the reader on every frame a star was lit.
  SkyHandle get _sky => SkyScope.read(context);

  /// The reader's preferences, as of the last build.
  ///
  /// ## WHY A FIELD AND NOT A `context` READ IN THE SCROLL CALLBACK
  ///
  /// The Stars-off gate ([_recordStar]) is asked on a scroll frame, and
  /// `SettingsScope.of` is a **dependent** lookup — `dependOnInheritedWidgetOf
  /// ExactType` — which may not be called outside a build: registering a
  /// dependency during layout is what `WitnessSky`'s own `_reducedMotion` field
  /// exists to avoid, and the same rule applies here.
  ///
  /// So the build reads the settings (once, watched, and the scope rebuilds
  /// this page when they change) and the scroll callback reads the field. **The
  /// field is a cache of the last built frame, not a second copy of the
  /// preference**: it is overwritten on every build, and the only writer of the
  /// preference is the settings cubit, which announces through the scope.
  ///
  /// **The default is the default install's preferences** — `UserSettings()` —
  /// so a page that has not built yet answers the gate the way it would render
  /// anyway: with the stars on.
  UserSettings _skySettings = const UserSettings();

  /// The reader's focus delay, as of the last build.
  ///
  /// **A field for [_skySettings]'s reason**: the idle timer is armed from a
  /// pointer callback and from a post-frame callback, and neither may register
  /// a dependency.
  Duration _focusDelay = const Duration(seconds: 4);

  /// The aurora's scene, cached for the focus dim.
  ///
  /// **A field and not a lookup at the point of use**, because
  /// `NeuralMotionScope.of` is a *dependent* lookup and the idle timer is
  /// armed from a pointer callback — where registering a dependency is not
  /// allowed.
  LumenScene? _scene;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scene = NeuralMotionScope.of(context).lumenScene;
    if (_requested != _language) _load();
  }

  /// Dispatches `load` for the language on screen.
  void _load() {
    final ReadingLanguage language = _language;
    _requested = language;
    _arm = language;
    context.read<ReadingCubit>().load(language);
  }

  /// The dial's write: the arm changes here, immediately, and the setting follows.
  ///
  /// **`setState` before the write**, so the dial's thumb moves on the frame the
  /// reader taps it rather than on the frame the store answers — the prototype's
  /// own order (`:1477-1480` sets `lang`, then re-renders synchronously), and the
  /// difference between a control that feels connected and one that waits for a
  /// disk.
  void _onLanguageChanged(ReadingLanguage chosen) {
    setState(() {
      _requested = chosen;
      _arm = chosen;
    });
    unawaited(SettingsScope.of(context).setLanguage(chosen));
    context.read<ReadingCubit>().load(chosen);
  }

  @override
  void dispose() {
    // **Every** timer this class owns. `flutter_test` fails a test on a pending
    // timer, which is the cheap half; the other half is a reader who leaves the
    // screen inside the entrance stagger and returns to a state advancing against
    // a disposed object.
    _idle?.cancel();
    _stagger?.cancel();
    // ## AND THE **FOCUS DIM** IS RELEASED
    //
    // The aurora's dim is a count (`LumenScene.dimFocus`), and a reader who
    // leaves the sanctuary inside the idle window would otherwise leave the
    // whole app dimmed. The prototype's `focusDim` is a global flag with the
    // same problem — and the same answer, which is that the next `poke()`
    // clears it — except that this client's reader may never come back.
    if (_focusDim) {
      _scene?.undimFocus();
    }
    super.dispose();
  }

  /// Runs `eva/redesign.html:1383`'s stagger, once per passage.
  ///
  /// ```js
  /// [...el('verseBox').children].forEach((v,i)=>setTimeout(()=>v.classList.add('in'),80+i*25));
  /// ```
  ///
  /// **One timer, chained** — not `verseEntranceSchedule` mapped over six timers.
  /// The schedule is a pure list of delays (`reading_focus.dart` owns the
  /// arithmetic and its 37 tests), and this walks it, so the *numbers* are TDD'd
  /// and the *walking* is a loop a reader can follow. Six timers would fire in one
  /// frame and produce the same result with a fifth of the bookkeeping.
  ///
  /// **[immediate] is the calm and reduced-motion branch** (`:1382`): every verse
  /// `.in` synchronously, because the reader asked for no stagger.
  /// `NeuralMotionScope` publishes the same setting the prototype's three paths
  /// to it arrive at (`:882`, `:1490`, `:1530-1532`).
  void _runEntrance(ScriptureText passage) {
    _stagger?.cancel();
    final int count = passage.verses.length;
    if (count == 0) return;
    // `MediaQuery.disableAnimations` and not the app's reduced-motion setting:
    // this is a **per-gesture** question about whether to animate, and the OS
    // signal is the one a screen can read without owning the settings store. The
    // prototype's `:882`, `:1490` and `:1530-1532` are three paths to the same
    // branch, and the harness's `disableAnimations:` flag drives this one.
    if (MediaQuery.disableAnimationsOf(context)) {
      if (mounted) setState(() => _revealed = count);
      return;
    }
    final List<Duration> schedule = verseEntranceSchedule(
      count: count,
      immediate: false,
    );
    int step = 0;
    void next() {
      if (!mounted || step >= schedule.length) return;
      _stagger = Timer(schedule[step], () {
        step++;
        if (mounted) setState(() => _revealed = step);
        next();
      });
    }

    next();
  }

  /// Arms focus mode's idle timer, and disarms it on any press.
  ///
  /// ```js
  /// // eva/redesign.html:1288-1294, verbatim
  /// function poke(){
  ///   const s=el('screen');
  ///   if(s.classList.contains('focus')){ s.classList.remove('focus'); focusDim=false; }
  ///   clearTimeout(idleT);
  ///   if(cur==='reader') idleT=setTimeout(()=>{ s.classList.add('focus'); focusDim=true; },focusDelay*1000);
  /// }
  /// el('screen').addEventListener('pointerdown',poke);
  /// ```
  ///
  /// **Four seconds, and `:1287` is the only place that is written.** `:683` is
  /// a `<input type="range" min="2" max="15" value="4">` with **no `oninput`
  /// anywhere in the file** — an unwired intent — so this port takes the value the
  /// prototype actually runs. Task 5.7 wires the range and [focusIdleDelay] is
  /// where the wired value lands.
  ///
  /// ## AND THE DELAY IS NOW **THE READER'S CHOICE**
  ///
  /// Phase 7 wired it: `_focusDelay` carries
  /// `UserSettings.focusDelaySec`, the Workshop's own 2…15 second range
  /// (`:683`), and a reader who asks for fifteen seconds gets fifteen. The
  /// constant below is the **default** the range starts at and not the delay
  /// the screen uses.
  void _poke() {
    _idle?.cancel();
    _setFocusDim(false);
    _idle = Timer(_focusDelay, () {
      if (!mounted) return;
      setState(() => _focusDim = true);
      // ## THE **AMBIENT** DIMS TOO, AND NOT ONLY THE CHROME
      //
      // `eva/redesign.html:891` — `base=ambBase*bright*vesp*(focusDim?0.45:1)`
      // — the focus mode's half of the aurora's intensity. The chrome's dim
      // (`:176`) and the aurora's dim are the **same flag** in the prototype
      // (`focusDim`, `:884`), and this client keeps them as one.
      _scene?.dimFocus();
    });
  }

  /// Whether the screen is dimmed, and whether the aurora is told about it.
  ///
  /// **One flag and one call**, because the prototype has one flag
  /// (`eva/redesign.html:884`) and two consequences for it: the chrome's
  /// opacity (`:176`) and the aurora's intensity (`:891`).
  void _setFocusDim(bool dimmed) {
    if (_focusDim == dimmed) return;
    if (mounted) setState(() => _focusDim = dimmed);
    if (dimmed) {
      _scene?.dimFocus();
    } else {
      _scene?.undimFocus();
    }
  }

  /// The scroll callback behind `:1211-1219`, and the line that **places
  /// `WitnessSky`** — the widget Phase 3 built with no consumer, and the reason
  /// `orphan_widget_check.py`'s allowlist entry for it names this task.
  ///
  /// ## WHAT IT DOES IN THIS CLIENT IS LESS THAN WHAT THE BROWSER'S DOES
  ///
  /// An `IntersectionObserver` reports an **intersection ratio**, so it fires
  /// when a verse crosses `:1219`'s `threshold: .6` and `:1218` unobserves it —
  /// one event per verse. A [ScrollNotification] carries no ratios, so this
  /// measures the two rects itself and asks `verseVisibilityFor`, which is the
  /// same arithmetic in Dart and is TDD'd in `reading_focus.dart`.
  ///
  /// ## AND IT IS **GUARDED**, or the sky would evict the reader's own stars
  ///
  /// The observer is one-shot per verse. Without [_lit], a scroll frame inside the
  /// threshold records a star *every frame*, and `sky_star_cap`'s 44 would evict
  /// the reader's earlier stars in a burst — the cap exists to trim the sky, not to
  /// make a burst of it.
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (_verseKeys.isEmpty) return false;

    final RenderBox? viewport = context.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return false;
    final Offset origin = viewport.localToGlobal(Offset.zero);

    for (final MapEntry<int, GlobalKey> entry in _verseKeys.entries) {
      final int number = entry.key;
      if (_lit.contains(number)) continue;
      final RenderObject? rendered = entry.value.currentContext
          ?.findRenderObject();
      if (rendered is! RenderBox || !rendered.hasSize) continue;
      final Rect rect = rendered.localToGlobal(Offset.zero) & rendered.size;

      final VerseVisibility visibility = verseVisibilityFor(
        verseTop: rect.top - origin.dy,
        verseBottom: rect.bottom - origin.dy,
        viewportTop: 0,
        viewportBottom: viewport.size.height,
      );
      if (visibility != VerseVisibility.inView) continue;

      _lit.add(number);
      _recordStar(number);
    }
    return false;
  }

  /// Lights a star for [number], and sets the resume marker the first time.
  ///
  /// ## AND THE BOOK IS ITS NUMBER, STRINGIFIED — A RECORDED KEY-SPACE MISMATCH
  ///
  /// `SkyEntry.book` is a [String]; the fiction's stars are keyed by name
  /// (`'psalms'`), and the only stable book identity a passage carries is
  /// `Verse.bookNumber` (43). `ScriptureText.reference` holds the name as text
  /// (`John 3:1-5`) and is **documented as rendered verbatim and never parsed**,
  /// so parsing it here would contradict that.
  ///
  /// So a star lit here is keyed `"43"` and will not match a constellation point,
  /// which Phase 3 keyed by name. **Recorded rather than papered over**: the stars
  /// render, the crumb's count is right, and the join between the two key spaces
  /// belongs to Task 5.6, where the constellation and the rings meet.
  void _recordStar(int number) {
    // ## THE STARS-OFF GATE, AND IT IS **HERE** AND NOT IN THE CUBIT
    //
    // The prototype gates lighting on `starsOn` inside `addStar` itself
    // (`eva/redesign.html:1144`), and `SkyCubit.record`'s doc says the same
    // thing about this client: the cubit does not check the switch, so **the
    // caller** must skip the record while Stars is off — or the next scroll
    // pass re-lights what the switch just stopped.
    //
    // **And the verse is still marked as lit** (`_lit` is filled by the
    // observer, above), which is the prototype's own behaviour: it sets
    // `p.dataset.star='1'` and unobserves the verse (`:1217-1218`) whether or
    // not `addStar` went on to add anything. A verse crossed while the stars
    // are off is not re-lit later either — in the prototype or here.
    if (!_skySettings.starsOn) return;
    final ScriptureText? passage = _passage;
    if (passage == null) return;
    final Verse? verse = passage.verses
        .where((Verse v) => v.number == number)
        .firstOrNull;
    if (verse == null) return;
    _resume ??= number;
    // `unawaited` because §4 forbids dropping a `Future` as a bare statement, and
    // the write is genuinely fire-and-forget: `SkyCubit.record` emits
    // optimistically, so the sky has the star before this returns.
    unawaited(
      _sky.record(
        SkyEntry(
          book: '${verse.bookNumber}',
          chapter: verse.chapter,
          verse: verse.number,
          // **Stamped here and not by the cubit**, because `SkyEntry.litAt` is
          // required and the observer is the only thing that knows *when* a verse
          // crossed the threshold. UTC for the same reason `AuthSession.createdAt`
          // is: the sky is a ledger, and a ledger has one timezone.
          litAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }

  /// The passage the current state holds, or `null`.
  ScriptureText? get _passage => context.read<ReadingCubit>().state.scripture;

  /// Reports a new font step, through the app's settings.
  ///
  /// **`SettingsScope` and not the settings cubit**, because §3 forbids
  /// `features/reading` from naming `features/settings` and `tool/verify_purity.sh`
  /// Gate 2 fails on the line. `lib/app/settings_scope.dart` is the
  /// composition-root seam that exists for exactly this case.
  void _onFontStepChanged(int step) {
    // `eva/redesign.html:1396-1397` — `el('fPlus').onclick=()=>{…;haptic(10)};`
    // and `el('fMinus')` likewise. The tick is on the **press**, so it is
    // fired here rather than after the write.
    fireRitualHaptic(RitualHaptic.fontStep, enabled: _skySettings.haptics);
    // `unawaited` because §4 forbids dropping a `Future` as a bare expression
    // statement, and the write is fire-and-forget from here: the optimistic emit
    // in `SettingsCubit.apply` has already moved the app's scale by the time the
    // next frame runs.
    unawaited(SettingsScope.of(context).setFontStep(step));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = context.l10n;
    final ReadingLanguage language = _language;
    // ## THE SKY'S PREFERENCES, READ **ONCE** AND WATCHED
    //
    // `SettingsScope.of` is a dependent lookup, so this registers the page's
    // dependency on the settings scope: when the reader changes a sky
    // preference in `/settings`, the scope announces, this page rebuilds, and
    // the sky is redrawn with the new shape. **A page pumped bare would not
    // rebuild** — `SettingsScope.of`'s locator fallback is not watched, and
    // `settings_harness.dart`'s header records that warning — so the reading
    // harness installs the scope.
    //
    // The value is also stashed for the scroll callback, which cannot depend on
    // an inherited widget mid-layout: see [_skySettings].
    final UserSettings settings = SettingsScope.of(context).settings;
    _skySettings = settings;
    // **The reader's own focus delay**, read with the rest of the settings.
    _focusDelay = Duration(seconds: settings.focusDelaySec);

    return BlocBuilder<ReadingCubit, ReadingState>(
      builder: (BuildContext context, ReadingState state) {
        final ScriptureText? passage = state.scripture;

        // The entrance runs **once per passage**, keyed on its reading id — see
        // [_entranceFor]'s note on why a state comparison would not do.
        if (passage != null && _entranceFor != passage.readingId) {
          _entranceFor = passage.readingId;
          _lit.clear();
          _verseKeys.clear();
          _resume = _sky.lastLit?.verse;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _runEntrance(passage);
            // **`:1377` arms focus mode on entry**, not on the first press:
            // `enterReader(){ renderVerses(); observeVerses(); poke(); ... }`. A
            // reader who opens the passage and reads without touching anything is
            // exactly the reader focus mode exists for, so arming the idle timer
            // only from `onPointerDown` would make the mode unreachable for them.
            // [_poke] carries the four seconds and `:683`'s unwired slider.
            _poke();
          });
        }

        // The pointer that arms focus mode, wrapping the scaffold rather than
        // sitting inside it: `:1294` listens for the **press itself** on the
        // screen, not for a tap some child may have consumed — a pointer that
        // lands on a verse and is swallowed by that verse's own gesture still
        // counts as the reader being there. A [Listener] and not a
        // `GestureDetector` because it wants the pointer, not the gesture arena.
        return Listener(
          onPointerDown: (PointerDownEvent _) => _poke(),
          child: NeuralScaffold(
            variant: language == ReadingLanguage.english
                ? NeuralVariant.readingEn
                : NeuralVariant.readingAr,
            // `EdgeInsets.zero`: the route's own `padding` is `:142`'s and
            // `:159`'s, transcribed by the two widgets that own them, and a second
            // inset here would compose with them.
            padding: EdgeInsets.zero,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // ## AND THE SKY IS **THE READER'S** SKY — EVERY KNOB IS THEIRS
                //
                // `eva/redesign.html:667-681` is the witness-sky group of the
                // Workshop, and each of its seven controls reaches this widget:
                //
                // | preference | reaches | how |
                // | --- | --- | --- |
                // | `starsOn` | whether the sky is drawn at all | the widget is not mounted |
                // | `constellationsOn` | `showConstellation` | |
                // | `starShape` | `shape` | |
                // | `starField` | `field` | |
                // | `starBrightness` | `brightness` | `--starB = value/100` (`:1488`) |
                // | `twinkle` | `twinkle` | **and** reduce motion (`:1489`) |
                // | `starCount` | the sky's **cap** | the two writers, not this widget |
                //
                // **Stars-off does not mount the sky at all**, which is the
                // prototype's own reading of the switch: `addStar` returns
                // early when it is off (`:1144`) and `drawConstellation` refuses
                // while it is off (`:1168`).
                //
                // **And the crumb's `sky N` keeps counting the stored stars
                // while they are off** — a consequence of the decision that
                // Stars-off hides and does not clear (`:1483` would have
                // cleared them, and the count with them). The count is the
                // reader's own record of what they have read, so it stays
                // true.
                if (settings.starsOn)
                  WitnessSky(
                    entries: _sky.entries,
                    brightness: skyBrightnessFor(settings.starBrightness),
                    twinkle: skyTwinklesFor(
                      twinkle: settings.twinkle,
                      reducedMotion: settings.reducedMotion,
                    ),
                    shape: settings.starShape,
                    field: settings.starField,
                    showConstellation: settings.constellationsOn,
                  ),
                Column(
                  children: <Widget>[
                    _bars(context, strings, state),
                    Expanded(child: _body(context, strings, state)),
                    // ## AND THE CTA IS GATED ON A QUESTION, NOT ON A PASSAGE
                    // `questionCount == 0` is reachable: `TodayReadingMapper`
                    // **skips** an unreadable question rather than refusing the
                    // passage (recorded decision 40), so four unreadable questions
                    // report zero — and "Begin reflection" was still offered, so a
                    // reader with nothing to reflect on was invited into an empty
                    // quiz. The passage is untouched; the invitation goes.
                    if (passage != null && passage.questionCount > 0)
                      ReadingQuizCta(
                        caption: strings.quizCaption(passage.questionCount),
                        // **The CTA navigates and nothing else**: Phase 6 replaced
                        // this with the route's own builder, and `:1404`'s
                        // `el('qcta').onclick = () => openQuiz()` has its analogue
                        // in the client that has built `/quiz` against the redesign.
                        onPressed: () =>
                            unawaited(context.router.pushPath(AppRoutes.quiz)),
                      ),
                    ReadingPill(
                      fontStep: _fontStep,
                      onFontStepChanged: _onFontStepChanged,
                      language: _arm,
                      // **The dial writes the LANGUAGE SETTING, and the app's
                      // own rebuild does the rest.** `eva/redesign.html:1477-1480`'s
                      // `data-l` buttons set `lang` and re-render in place; this
                      // client's equivalent of "the language" is
                      // `UserSettings.language`, and `app.dart` rebuilds
                      // `MaterialApp` with the locale it names — which is the
                      // trigger [didChangeDependencies] exists for, and the reason
                      // `_load` guards on which arm was *asked for* rather than on
                      // a bool. Writing the setting is also what makes the choice
                      // survive a restart, which a local `setState` would not.
                      onLanguageChanged: _onLanguageChanged,

                      // **`onListen` is deliberately not passed**, and that is
                      // the whole of that control in this build: there is no audio
                      // in the prototype and none here, so the button ships inert
                      // with its accessible name carrying the reason. The analyzer
                      // calls the omitted argument redundant and it is right — the
                      // *record* belongs in this comment and in
                      // `reading_pill.dart`'s doc, which carries the `grep` that
                      // established it and why the `.wave` is not built either.
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The two bars, and the chrome dimming focus mode applies to them.
  ///
  /// `:176` — `.screen.focus .appbar,.screen.focus .pill,.screen.focus .qcta
  /// {opacity:.2;transition:opacity .9s var(--e-out)}` — dims **three** things
  /// and the verse rows are not among them. `:177` is the rule that *would* have
  /// touched them, and it is the one the plan records as the defect to correct
  /// (1.000:1 in focus).
  ///
  /// **Only the bars are dimmed here**, which is faithful to `:176` and is also
  /// the whole of the correction: the CTA and the pill carry
  /// [chromeDimOpacity] from the same constant, and `VerseLine`'s three-state enum
  /// is what makes "the verses are not dimmed" expressible rather than accidental.
  Widget _bars(
    BuildContext context,
    AppLocalizations strings,
    ReadingState state,
  ) {
    final ScriptureText? passage = state.scripture;

    return AnimatedOpacity(
      opacity: _focusDim ? chromeDimOpacity : 1,
      duration: focusDimTransition,
      curve: EvaMotion.interactiveCurve,
      child: ReadingAppBar(
        // `:1345` — `bookTitle(b)`. **The passage's own reference, and there is
        // no better source**: §2's route table has no endpoint that enumerates
        // books, so a book *name* here would be the catalogue fiction ADR-0022
        // removed from `/`.
        title: passage?.reference ?? '',
        meta: strings.crumbMeta(
          // **The book number, not a category word** — and the divergence from
          // `:1346`'s `CATS[b.cat][li()]` is real. That clause is a `/`-side
          // fiction (`LibraryCategory.label`, which `home_l10n.dart` owns because
          // the `CATS` table is shared); a passage carries no category at all, and
          // inventing one here would put a second book's metadata on a screen whose
          // data is real. The number is what the passage knows.
          category: passage == null || passage.verses.isEmpty
              ? '—'
              : '${passage.verses.first.bookNumber}',
          verses: passage?.verses.length ?? 0,
          litStars: _sky.litCount,
        ),
        onBack: () => unawaited(context.router.maybePop()),
        onBookmarkToggled: () {
          // `eva/redesign.html:1394` — `el('bmBtn').onclick=function(){
          // this.classList.toggle('lit'); haptic(12); … }`.
          fireRitualHaptic(
            RitualHaptic.bookmark,
            enabled: _skySettings.haptics,
          );
          setState(() => _bookmarked = !_bookmarked);
        },
        bookmarked: _bookmarked,
      ),
    );
  }

  /// The screen's only scrollable — `.versebox`, `:159`.
  Widget _body(
    BuildContext context,
    AppLocalizations strings,
    ReadingState state,
  ) => switch (state.status) {
    // Nothing on screen but the request: `:162`'s hidden state is a property of a
    // verse, and there is no verse to place, so this is a centred indicator.
    ReadingStatus.loading => const Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    ReadingStatus.failed => Center(
      child: Padding(
        // `:159`'s own horizontal padding, so the failure sits on the inset the
        // verses would have.
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: ErrorView(
          message: state.failure?.message ?? '',
          // The failure's **message**, not a string from the table — Phase 6's
          // precedent, and `reading_page_test.dart`'s failure rows: the mapper
          // writes "Could not read today's reading: `verses` is absent …" and
          // inventing a sentence here would hide the field that is actually wrong.
          onRetry: () => context.read<ReadingCubit>().retry(_language),
          retryLabel: strings.readingRetry,
          // The label is the string table's, and on the Arabic arm it is Arabic
          // text in a button whose only family knob this is.
          // **`arabicAwareFamily` and not a new switch** — the deleted
          // `StickyCta.ctaFamilyFor` answered the same question per arm
          // (`uiFamily` / `arabicFamily`), and that is exactly what the helper is;
          // reusing it is what keeps a fourth call site from becoming a fourth
          // answer.
          retryFamily: arabicAwareFamily(
            Directionality.of(context),
            EvaTypography.uiFamily,
          ),
        ),
      ),
    ),
    ReadingStatus.ready => _verseList(context, state.scripture!),
  };

  /// The verses themselves, each measured by the observer above.
  Widget _verseList(BuildContext context, ScriptureText passage) {
    // ## THE BREATH GUIDE'S ANCHOR
    //
    // `eva/redesign.html:1372-1376` — `setBreathUnder(p)` removes every
    // existing `.breath` and puts a new one **after** the verse `p`. The
    // prototype calls it from `openSheet` (the verse the reader selected) and
    // from `enterReader`'s `finish()` (the one they left off at), so the guide
    // belongs to **one** verse: the selected one, or the resumed one when
    // nothing is selected.
    //
    // **And the reader's own switch decides whether there is one at all** —
    // `UserSettings.breathGuide`, the Workshop's `:685`.
    final int? anchor = _skySettings.breathGuide ? (_hot ?? _resume) : null;
    final int anchorIndex = anchor == null
        ? -1
        : passage.verses.indexWhere((Verse v) => v.number == anchor);

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.builder(
        // `:159` — `padding: 14px 26px 12px`. **14 and 26 are not spacing
        // tokens**, for the reason `VerseLine.verseGap` records.
        padding: const EdgeInsets.fromLTRB(26, 14, 26, 12),
        // **One extra row, and it is the guide.** A `Column` around each verse
        // would have changed **every** verse's layout to accommodate one
        // verse's guide, and the reading harness measures those verses.
        itemCount: passage.verses.length + (anchorIndex >= 0 ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (anchorIndex >= 0 && index == anchorIndex + 1) {
            return const BreathGuideLine();
          }
          final int verseIndex = anchorIndex >= 0 && index > anchorIndex
              ? index - 1
              : index;
          final Verse verse = passage.verses[verseIndex];
          final GlobalKey key = _verseKeys.putIfAbsent(
            verse.number,
            GlobalKey.new,
          );
          return GestureDetector(
            // `:1385-1386` — tapping a verse makes it the selected one and
            // removes `.hot` from every other. **The sheet itself is not built**:
            // `openSheet` opens a bottom sheet the redesign's reader route does
            // not contain a trigger for beyond the verse itself, and Phase 7's
            // ritual step is where it belongs. What this port keeps is the
            // selection, which is the state a sheet would read.
            onTap: () => setState(() => _hot = verse.number),
            behavior: HitTestBehavior.opaque,
            child: VerseLine(
              key: key,
              number: verse.number,
              // **`Verse.text`, NOT `displayText`** — recorded decision 51, and
              // the Arabic arm's typography gate is what caught this page getting
              // it wrong: `displayText` is the *preview* projection
              // (`textClean ?? text`), so the sanctuary was rendering every verse
              // with its diacritics stripped, and the gate reported the fixture's
              // diacritised `text` as a declared-but-unrendered run while the tree
              // held the cleaned one. The reading screen shows scripture whole.
              text: verse.text,
              paint: versePaintFor(
                // The **stagger's** answer, not the observer's. The prototype's
                // `.in` class is what the schedule adds (`:1383`), so "revealed"
                // is a question about the schedule and not about the scroll
                // position — the observer's visibility answer is spent on
                // *stars* (`_onScroll`), never on paint.
                visibility: index < _revealed
                    ? VerseVisibility.inView
                    : VerseVisibility.outOfView,
                hot: _hot == verse.number,
                entranceComplete: index < _revealed,
              ),
              resume: _resume == verse.number,
            ),
          );
        },
      ),
    );
  }
}

/// `eva/redesign.html:1287`'s `focusDelay = 4`, in seconds.
///
/// **Four, and `:683`'s slider is not it**: that `<input type="range"
/// min="2" max="15" value="4">` has no `oninput` handler anywhere in the file, so
/// the prototype runs on the literal and the slider is an unwired intent. Task 5.7
/// wires the range and this is the default it starts from.
const Duration focusIdleDelay = Duration(seconds: 4);

/// `eva/redesign.html:176`'s `opacity: .2` for the three dimmed surfaces.
const double chromeDimOpacity = 0.2;

/// `eva/redesign.html:176`'s `transition: opacity .9s var(--e-out)`.
const Duration focusDimTransition = Duration(milliseconds: 900);

/// The witness sky's brightness — `--starB` — from the reader's slider value.
///
/// `eva/redesign.html:1488` writes `--starB` as `value/100`, and the slider is
/// 30…150 (`:670`), so the sky's brightness is 0.3…1.5 — the range
/// `WitnessSky.brightness` takes.
///
/// **A named function and not an inline `/ 100`**, for the reason AGENT_CONTEXT
/// §6 gives: domain logic must not be buried inside a widget, and a division
/// whose wrong answer is a sky at 44× or at 0.01× is worth a name and a test.
///
/// **And it lives here rather than in the sky feature** because the cap's rule
/// is read by *two* writers that may not import each other — which is why that
/// one is in `features/sky/domain/sky_star_cap.dart` — while the brightness is
/// read by **one** consumer, this page. The rule follows the number of readers.
double skyBrightnessFor(int brightness) => brightness / 100;

/// Whether the witness sky twinkles.
///
/// `eva/redesign.html:1489` toggles `notwinkle` when the switch is off **or**
/// reduce motion is on, and `:1491` says the same from the other side — the two
/// are one rule.
///
/// **Reduce motion is combined with the twinkle, never substituted for it**:
/// the reader's own reduce-motion preference is an *additional* off switch
/// (`UserSettings.reducedMotion`'s doc), and the platform's signal is applied
/// by `WitnessSky` itself, which reads `MediaQuery.disableAnimationsOf`.
///
/// **A named function and not an inline `&&`**, for AGENT_CONTEXT §6's reason:
/// the rule is a decision with a prototype line behind it, and it is worth
/// being able to name it in a test.
bool skyTwinklesFor({required bool twinkle, required bool reducedMotion}) =>
    twinkle && !reducedMotion;
