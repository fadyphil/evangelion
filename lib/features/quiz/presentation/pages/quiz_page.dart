import 'package:auto_route/auto_route.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';

/// Stub for `/quiz`. The quiz — questions, options, instant per-question
/// feedback — arrives with `DioReadingRepository` and its cubit in a later
/// phase.
///
/// See [LoginPage] for why these stubs take the shape they do and carry no
/// constructor dependencies. Worth stating specifically for this screen: a stub
/// question with a working "correct / try again" would be the most expensive
/// kind of placeholder to write, because the backend's duplicate-submit `409`
/// and the `already_answered` flags mean the real feedback logic is not
/// something that can be faked convincingly.
@RoutePage()
class QuizPage extends StatelessWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppRoutes.quiz)),
      body: const Center(child: Text('Placeholder for ${AppRoutes.quiz}')),
    );
  }
}
