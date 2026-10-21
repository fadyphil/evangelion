import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/commit_result.dart';
import 'package:evangelion/features/servant/domain/entities/question_draft.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_report_repository.dart';
import 'package:evangelion/features/servant/domain/usecases/commit_questions.dart';
import 'package:evangelion/features/servant/domain/usecases/generate_ai_draft.dart';
import 'package:evangelion/features/servant/domain/usecases/load_daily_report.dart';
import 'package:evangelion/features/servant/domain/usecases/schedule_reading.dart';
import 'package:evangelion/features/servant/presentation/cubit/question_authoring_cubit.dart';
import 'package:evangelion/features/servant/presentation/cubit/schedule_reading_cubit.dart';
import 'package:evangelion/features/servant/presentation/cubit/servant_report_cubit.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../support/design_system_harness.dart';

/// The shared fixture for every servant-portal test.
///
/// ## WHY IT IS HERE AND NOT IN EACH SUITE
///
/// `login_harness.dart` records the reason: one copy of a fixture, so the
/// copies cannot drift, and a fixture that drifts is how a screen ends up
/// tested in two arrangements at once.
///
/// ## AND WHY THE **LOCALISATION DELEGATE** IS INSTALLED HERE
///
/// `evaPrimitiveHarness` installs Material's own delegates and **not** the
/// app's — so `context.l10n` would find no `AppLocalizations` and every
/// servant string would be a null lookup. The app's delegate and the pair of
/// locales the app ships are therefore installed here, and the Arabic arm is
/// reachable by passing `locale: Locale('ar')`.
///
/// ## AND WHY THE DIRECTION IS **DERIVED** from the locale
///
/// `evaPrimitiveHarness` wraps its child in an explicit `Directionality`, which
/// wins over the one `MaterialApp` installs from the resolved locale. So an
/// `ar` locale with the harness's `ltr` default would render Arabic
/// left-to-right, and the failure would read as "the page ignores RTL" rather
/// than as "the harness forced a direction".
TextDirection servantDirectionFor(Locale locale) =>
    locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

/// The **other** language than [locale].
///
/// ## WHY THE HARNESS KNOWS ABOUT THE OTHER ARM
///
/// The app ships two languages, and a string that exists in only one of them
/// is a string half the readers never see. So a test that asserts a message
/// asserts it in **both** arms, and the second arm is reached by repainting
/// the same widget in the other locale.
///
/// ## AND WHY THE REPINT IS **THE SAME WIDGET**
///
/// `pumpServant` builds the whole composition again, and the widget under test
/// is rebuilt **in place** — the same type, the same key — so the `State`
/// survives and the screen is still in the state the first arm put it in. That
/// is what makes "the same state, in the other language" a claim about the
/// state and not about a second, freshly-mounted screen.
Locale otherArmFor(Locale locale) =>
    locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar');

/// The delegates the app's own strings need.
const List<LocalizationsDelegate<dynamic>> kServantLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      // **The plural list**, because the singular one leaves the Cupertino
      // delegate out and the Arabic arm then fails on a missing
      // `CupertinoLocalizations` — a failure about the harness and not about
      // the screen.
      ...GlobalMaterialLocalizations.delegates,
    ];

/// The locales the app ships.
const List<Locale> kServantSupportedLocales = <Locale>[
  Locale('en'),
  Locale('ar'),
];

/// Pumps [child] on a phone-sized surface with the app's strings installed.
Future<void> pumpServant(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1.0,
  bool disableAnimations = false,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: theme,
      locale: locale,
      textScale: textScale,
      disableAnimations: disableAnimations,
      textDirection: servantDirectionFor(locale),
      localizationsDelegates: kServantLocalizationsDelegates,
      supportedLocales: kServantSupportedLocales,
      child: child,
    ),
  );
}

// ## THE TWO PORT STUBS, AND WHY THEY ARE NOT THE PAGE TESTS' FAKES
//
// The three page suites each hold a **behavioural** fake: it records what the
// port was asked and answers a payload the suite then asserts on. Those are
// about the *request*, and they are the right shape for what they are for.
//
// The two below are the opposite: they are **stubs for a screen that never
// asks**. The golden tests pump the portal's four screens in their **initial**
// state — the form before anybody pressed anything — and a port that is never
// called is the honest fixture for that. They answer a `Failure` rather than a
// payload, so a screen that *did* ask would show a failure instead of quietly
// showing a made-up roster.

/// A [ServantReportRepository] that is never asked.
final class StubServantReportRepository implements ServantReportRepository {
  @override
  Future<Result<ServantReport>> loadDailyReport({
    required int groupId,
    required String date,
  }) async => const Left<Failure, ServantReport>(
    Failure(kind: FailureKind.network, message: 'This stub is never asked.'),
  );
}

/// A [ServantAdminRepository] that is never asked.
final class StubServantAdminRepository implements ServantAdminRepository {
  @override
  Future<Result<ScheduleResult>> scheduleReading(
    ReadingSchedule schedule,
  ) async => const Left<Failure, ScheduleResult>(
    Failure(kind: FailureKind.network, message: 'This stub is never asked.'),
  );

  @override
  Future<Result<CommitResult>> commitQuestions({
    required String readingId,
    required List<QuestionDraft> questions,
  }) async => const Left<Failure, CommitResult>(
    Failure(kind: FailureKind.network, message: 'This stub is never asked.'),
  );

  @override
  Future<Result<QuestionDraft>> generateAiDraft({
    required String readingId,
    required QuestionType type,
  }) async => const Left<Failure, QuestionDraft>(
    Failure(kind: FailureKind.network, message: 'This stub is never asked.'),
  );
}

/// The report cubit over a port that is never asked.
///
/// The cubit is a **whole-state writer** and it is closed by the caller, so the
/// golden tests add a `tearDown` for it — the same arrangement
/// `servant_report_page_test.dart` uses.
ServantReportCubit stubServantReportCubit() => ServantReportCubit(
  loadDailyReport: LoadDailyReport(StubServantReportRepository()),
);

/// The schedule cubit over a port that is never asked.
ScheduleReadingCubit stubScheduleReadingCubit() => ScheduleReadingCubit(
  scheduleReading: ScheduleReading(StubServantAdminRepository()),
);

/// The question-authoring cubit over a port that is never asked.
QuestionAuthoringCubit stubQuestionAuthoringCubit() => QuestionAuthoringCubit(
  commitQuestions: CommitQuestions(StubServantAdminRepository()),
  generateAiDraft: GenerateAiDraft(StubServantAdminRepository()),
);
