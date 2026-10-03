import 'package:auto_route/auto_route.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';

/// Stub for `/result`. The result screen — score, streak, stat tiles — arrives
/// with the quiz, because AGENT_CONTEXT §2 has it read the quiz's *submit*
/// response rather than fetch anything of its own.
///
/// See [LoginPage] for why these stubs take the shape they do and carry no
/// constructor dependencies. One thing this screen will need and does not have
/// yet: AGENT_CONTEXT §5 trap 4, that streak fields only change when
/// `reading_completed == true`, so a result screen that shows a streak without
/// reading that flag is wrong in a way no widget test would catch.
@RoutePage()
class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppRoutes.result)),
      body: const Center(child: Text('Placeholder for ${AppRoutes.result}')),
    );
  }
}
