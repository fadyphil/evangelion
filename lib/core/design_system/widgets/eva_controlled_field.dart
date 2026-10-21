import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// A **controlled** text field: the state holds the value, the reader holds the
/// input, and this widget is the only thing that keeps the two in step.
///
/// ## WHAT IT IS FOR, AND WHAT IT IS NOT A FIX FOR
///
/// **Six defects of one class** were found in this repository's servant-portal
/// work, and **every one of them was found by an agent reading the code — not by
/// a gate.** The class is:
///
/// > **A screen and the state it mirrors can stop agreeing — and the request is
/// > the one that writes.**
///
/// The six, in the order they were found, are recorded in AGENT_CONTEXT §7's
/// "Recorded decisions — the servant portal" as decision 188, and they reduce to
/// **two** mistakes:
///
/// 1. **a write the program made, reported as a write the reader made** — the
///    page wrote the state's own value into a controller, the controller told
///    its listener, and the listener was the page's way of reporting a
///    keystroke, so the cubit was told the reader had edited the question. The
///    cubit's edit writer answers an edit by dropping the server's refusal with
///    it, so **a server's refusal erased itself in one frame**; and
/// 2. **a controller seeded from the program instead of read back from the
///    state** — the page *seeded* the cubit with the controllers' contents at
///    mount, and the controllers start empty, so the seed told the cubit "the
///    reader cleared the question", and the admin's in-progress question was
///    wiped on re-entry over the singleton cubit.
///
/// **The root cause is that the correct pattern is not expressible.** A page
/// that mirrors a cubit-held value into a `TextEditingController` has to
/// hand-roll it, and hand-rolling has **three** ways to be wrong — the write is
/// reported, the field is seeded instead of read back, the mirror runs in the
/// wrong direction — and **no way to be caught**. This widget is that pattern,
/// made expressible, and the gate in
/// `test/core/design_system/widgets/mirrored_controller_check_test.dart` is what
/// catches the hand-rolled version coming back.
///
/// ## THE CONTRACT, IN TWO SENTENCES
///
/// **[value] is the value.** It is the state's value, it is read, and it is
/// mirrored into the field when it moves on its own. **[onChanged] is the
/// reader's input and nothing else** — it is called when the reader types, and
/// **never** when this widget writes into its own controller.
///
/// ## HOW A WRITE THE WIDGET MAKES IS NEVER REPORTED AS THE READER'S
///
/// This is the whole point of the widget, so it is worth being exact about the
/// mechanism, because **the obvious mechanism is the wrong one**.
///
/// The obvious one is a flag: "I am writing now, ignore the notification".
/// The servant pages use exactly that (`_writing`), and it works — but it is a
/// **boolean that has to be set and cleared around every write**, and the
/// failure mode of a boolean that is not set is that a programmatic write
/// arrives as the reader's edit. It is also the reason the pages' contract
/// cannot be stated in one line: the reader has to know that the page might be
/// writing, and the page has to know that the reader might be typing, and the
/// two have to be told apart by a flag both of them can get wrong.
///
/// **This widget compares instead.** It keeps two things — the controlled value
/// and the last text it reported — and asks two questions of them, and it
/// holds a third guard of its own:
///
/// | question | answer | what it buys |
/// | --- | --- | --- |
/// | *is the controller's new text the controlled value?* | then it is **this widget's own write** — or an echo of a value the state already holds — and **nothing is reported** | the server's draft arrives, the field fills, and the cubit is **not** told the admin typed it |
/// | *is the controlled value the last text this widget reported?* | then the state has **caught up with the reader** — the controller already holds that text — and **nothing is mirrored back** | the mirror's only trigger stays unambiguous: **the state moving somewhere the reader did not put it** |
///
/// The first question is the crux, and it works **because this widget only ever
/// writes the controlled value into its controller.** There is no other write,
/// so "the controller's text is the controlled value" is not a coincidence to be
/// detected — it is the only thing that can have happened.
///
/// **AND THE MIRROR ITSELF HAS A THIRD GUARD, AND IT IS THE OLDEST ONE: THE
/// CONTROLLED VALUE MUST HAVE *MOVED*.** A rebuild that does not change the
/// value changes nothing to show, and a state that is one keystroke behind has
/// not changed — so the character the reader has just typed stays on the
/// screen. A mirror that ran on every rebuild would take it away and put it
/// back on the next one.
///
/// ## AND WHY THE COMPARISON IS AGAINST THE **CONTROLLED VALUE** AND NOT
/// ## ONLY AGAINST THE LAST REPORTED TEXT
///
/// A design that only remembered "the last text I reported" and compared
/// against **that** would be wrong in the most important direction, and the
/// servant pages' defect #1 is exactly the case it gets wrong.
///
/// The state can move for a reason the reader had nothing to do with: the
/// server's draft arrives, the cubit resets the form, the admin picks a cohort
/// from a list. **None of those is the reader's last reported text**, so a
/// comparison against the last reported value alone would read them as *the
/// reader typing* — and report them.
///
/// Comparing against the **controlled value** closes that door, because a
/// value the state moved to on its own is by definition a value the state
/// holds, and a value the state holds is not news.
///
/// The last reported text is still needed — but for the **other** direction. It
/// is what tells the mirror "the state has caught up with the reader", and the
/// mirror's whole trigger is then unambiguous: **the state moving somewhere the
/// reader did not put it.** **Two comparisons, two directions, and neither of
/// them is a flag.**
///
/// ## WHAT IT DOES **NOT** DO
///
/// * **It does not own the value.** The value is the state's, and the state is
///   the only place it lives. A page that wants the field's text reads it from
///   the state — which is the point, and the reason this widget does not expose
///   its controller.
/// * **It does not fix the cubit half.** Whether a keystroke clears a failure,
///   and whether a **write's receipt** survives an edit, are rules in the
///   cubit and not in the field: the cubit's edit writer decides. This widget
///   removes the *programmatic* writes from that path, and it cannot remove the
///   reader's own keystroke from it.
/// * **It does not fix a stale answer.** An in-flight answer that lands under
///   a form which has moved on is a race in the cubit, and no field can see
///   it — the request's own identity is remembered by the cubit and compared
///   with the form when the answer lands.
/// * **It does not make a state that *refuses* a keystroke agree with the
///   screen.** The mirror runs when the controlled value **moves**, so a state
///   that takes a keystroke and then quietly keeps the old value leaves the
///   reader's text on the screen until the value next moves. **That is a rule
///   in the cubit, and this is the field's boundary**: the cubit must take
///   every keystroke, or the screen and the state disagree and the field
///   cannot tell which of them is right.
///
///   **AND A REFUSAL IS NOT A TEMPORARY MISMATCH BUT A PERMANENT ONE.** The
///   third guard — *the controlled value must have moved* — means a value the
///   state kept is never written back, so the character the reader typed
///   stays on the screen **for ever** while the state does not have it, and
///   neither of them knows which of them is right.
///
///   **AND THE RULE IS **CHECKED**, NOT ASSERTED.** No cubit behind a
///   controlled field refuses a keystroke — there are three today, the
///   question editor's, the schedule form's and the report form's — and the
///   check is a gate:
///
///   `flutter test test/core/design_system/widgets/keystroke_taker_check_test.dart`
///
///   **THE GATE **DERIVES** ITS SUBJECT**: the cubits behind the controlled
///   field, from the files that use one to the cubits those files import, and
///   it fails if one of their keystroke writers can leave without emitting —
///   a `return` before the emit, or an emit of the state the cubit already
///   holds. **A gate that names its own subject cannot notice the subject
///   moving**, so a screen that adopts the controlled field brings its cubit
///   with it, and a writer added to one of them is checked the day it is
///   written.
///
///   **AND THE BEHAVIOUR IS CHECKED TOO**, writer by writer, in
///   `test/features/servant/presentation/cubit/question_authoring_cubit_test.dart`:
///   the question editor's cubit is asked to take a keystroke by each of its
///   writers in turn and is checked to have taken it. **`setPointsText`
///   writes `pointsText: text` and nothing else** — that is what a writer
///   that takes the keystroke looks like, and the table in that test is the
///   list of them.
///
///   **AND THE SENTENCE THIS REPLACES WAS **FALSE**, WHICH IS WHY IT IS
///   WRITTEN DOWN HERE.** It used to say that "every cubit in this repository
///   does take it", and one did not: `QuestionAuthoringCubit.setOptionText`
///   returned early when the question had no option under the letter, so a
///   keystroke for a letter with no option was **refused**. **The refusal was
///   unreachable from the page** — the option editor is drawn only for the
///   letters the question already has — and that is exactly how it survived:
///   a defect nobody can reach is a defect nobody looks for. **AND A PREMISE
///   NOBODY CAN CHECK IS A GATE THAT CANNOT FAIL**: the safety does not
///   depend on the claim being true *being* true — it depends on a reader
///   being able to check it. The writer takes the keystroke now, and creates
///   the option the reader typed into, and the claim is the narrower one the
///   check can carry.
///
/// ## THE COST, STATED RATHER THAN HIDDEN
///
/// **This widget is one more abstraction over [EvaTextField].** It adds a
/// `value` and an `onChanged` to a field that already had a controller, and a
/// reader who knows [EvaTextField] now has to know this too.
///
/// The price is paid in exchange for the gate: the gate can say *one file may
/// create a `TextEditingController`*, because the pattern is in one place
/// instead of in every page that mirrors a value. **A page that needs a
/// controller for something other than a mirrored value has to say why it is
/// not mirroring one** — and the gate asks.
///
/// ## §14, AND THE RING
///
/// The field's rim **is** the focus ring — [EvaTextField] draws
/// `evaFocusRingBorder` when it is focused and never builds an
/// `EvaFocusRing` — so this widget delegates the ring the same way it
/// delegates everything else. It owns a controller and **no focus node**, so it
/// adds no interactive surface of its own; the focus-ring gate records that
/// delegation in `focus_ring_gate_test.dart`'s `_delegatesFocusRingTo`.
///
/// ## AND THE PROTOTYPE'S FIELD IS THE ONE IT IS BUILT ON
///
/// `redesign.html:376-379` is the field's box, its focused rim, its fill and
/// its error line, and **this widget draws none of them** — [EvaTextField]
/// does, unchanged. What this widget adds is the **relationship** between the
/// field and the state behind it, and the prototype has no such relationship:
/// its `<input>` is uncontrolled, and nothing in `redesign.html` says what a
/// form should do when the value arrives from somewhere else.
class EvaControlledField extends StatefulWidget {
  /// A text field whose value is [value] and whose reader's input is
  /// [onChanged].
  const EvaControlledField({
    required this.value,
    required this.onChanged,
    required this.label,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
    this.showLabel = true,
    super.key,
  });

  /// The value the field shows — **the state's value, not the field's own**.
  ///
  /// **The field never edits this.** It reads it, it mirrors it when the state
  /// moves it, and that is all. A caller that wants the field's text reads
  /// [onChanged]'s argument, which is the same string.
  final String value;

  /// Reports **the reader's input**, and nothing else.
  ///
  /// **Called when the reader types. Never called for a write this widget made
  /// on purpose** — which is the whole contract, and the reason this widget
  /// exists. See the class doc.
  final ValueChanged<String> onChanged;

  /// The mono-caps label above the field, and the field's accessible name.
  ///
  /// Forwarded to [EvaTextField.label] unchanged.
  final String label;

  /// Greyed placeholder text drawn while the field is empty.
  ///
  /// Forwarded to [EvaTextField.hintText] unchanged.
  final String? hintText;

  /// The error helper text below the field.
  ///
  /// Forwarded to [EvaTextField.errorText] unchanged.
  final String? errorText;

  /// Whether to mask the entry.
  ///
  /// Forwarded to [EvaTextField.obscureText] unchanged.
  final bool obscureText;

  /// Forwarded to [TextField.keyboardType].
  final TextInputType? keyboardType;

  /// Forwarded to [TextField.textInputAction].
  final TextInputAction? textInputAction;

  /// Forwarded to [TextField.onSubmitted].
  ///
  /// **The reader's own submission**, and it is forwarded untouched: it is a
  /// reader's action, not a write the widget made, and the text it carries was
  /// already reported keystroke by keystroke.
  final ValueChanged<String>? onSubmitted;

  /// A control in the field's right inset.
  ///
  /// Forwarded to [EvaTextField.trailing] unchanged.
  final Widget? trailing;

  /// Whether the mono-caps label row renders at all.
  ///
  /// Forwarded to [EvaTextField.showLabel] unchanged.
  final bool showLabel;

  @override
  State<EvaControlledField> createState() => _EvaControlledFieldState();
}

class _EvaControlledFieldState extends State<EvaControlledField> {
  /// The field's own controller.
  ///
  /// **Owned here, and never handed out.** [EvaTextField]'s contract is that
  /// the controller is the caller's, and this widget **is** the caller — the
  /// point being that the *page* is not.
  late final TextEditingController _controller;

  /// The last text this widget reported to [EvaControlledField.onChanged].
  ///
  /// **The reader's last keystroke, as the state saw it.** `null` until the
  /// reader has typed something.
  ///
  /// It is what tells the mirror "the state has caught up with the reader", and
  /// it is what keeps the mirror's trigger unambiguous: **the state moving
  /// somewhere the reader did not put it.**
  String? _lastReported;

  @override
  void initState() {
    super.initState();
    // **THE FIELD STARTS WITH THE STATE'S VALUE, AND THE STATE IS NOT TOLD.**
    //
    // The controller is created holding the controlled value, so the field shows
    // the state from the first frame — and a controller's constructor notifies
    // nobody, so the mount reports nothing. The reader has not typed anything,
    // and the cubit must not be told that they have.
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(EvaControlledField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // **THE MIRROR, AND IT RUNS ONLY WHEN THE STATE MOVED.**
    //
    // A rebuild that does not change the value changes nothing to show, and a
    // mirror that ran anyway would fight the reader: the state is one keystroke
    // behind more often than not, and writing the older value back would take
    // the character the reader has just typed off the screen — and put it back
    // on the next rebuild, which is a caret jump nobody asked for.
    if (widget.value == oldWidget.value) return;
    // **THE STATE HAS CAUGHT UP WITH THE READER.** The controlled value is the
    // last text this widget reported, so the controller already holds it, and
    // writing it back would move the caret for nothing.
    if (widget.value == _lastReported) return;
    _mirror();
  }

  /// The controller changed. **Either the reader typed, or this widget wrote.**
  ///
  /// **AND THE CONTROLLED VALUE IS WHAT TELLS THE TWO APART.** This widget
  /// writes nothing but the controlled value into its controller, so a
  /// controller whose text is the controlled value is either this widget's own
  /// write or an echo of a value the state already holds — and **neither is the
  /// reader's input.**
  ///
  /// The comparison is the whole mechanism. A flag would say the same thing
  /// about the writes this widget makes, and it would have to be set and cleared
  /// around every one of them; a comparison cannot be forgotten, because there
  /// is nothing to forget.
  void _onControllerChanged() {
    final String text = _controller.text;
    if (text == widget.value) return;
    _lastReported = text;
    widget.onChanged(text);
  }

  /// Writes the controlled value into the controller.
  ///
  /// **AND IT REPORTS NOTHING**, because the listener compares the controller's
  /// text against the controlled value and this write put the controlled value
  /// there. The suppression is not a side effect of this method — it is the
  /// comparison in [_onControllerChanged], and it holds for this write for the
  /// same reason it holds for every other one.
  void _mirror() {
    final String value = widget.value;
    if (_controller.text == value) return;
    _controller.text = value;
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EvaTextField(
    label: widget.label,
    controller: _controller,
    hintText: widget.hintText,
    errorText: widget.errorText,
    obscureText: widget.obscureText,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    onSubmitted: widget.onSubmitted,
    trailing: widget.trailing,
    showLabel: widget.showLabel,
  );
}
