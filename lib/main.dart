import 'package:evangelion/app/bootstrap.dart';
import 'package:flutter/material.dart';

/// Process entry point.
///
/// One line, because the content is [bootstrapApp] and nothing else. This file
/// used to hold the three bootstrap steps inline and be verified by a test that
/// read it as *text* — a `main()` with an empty body passed that suite, and so
/// did one with the three calls sitting inside a string literal. The steps now
/// live in `bootstrapApp`, where they are executable, and
/// `main_bootstrap_test.dart` proves the order by making DI throw.
///
/// `runApp` is passed rather than called so `bootstrapApp` stays testable; see
/// its doc comment for why that is the seam and not a decoration.
///
/// `main` is `Future<void>` on purpose. The engine awaits it, so a DI failure
/// during bootstrap surfaces as a failed launch instead of an unhandled async
/// error with a blank frame on screen.
Future<void> main() async => bootstrapApp(run: runApp);
