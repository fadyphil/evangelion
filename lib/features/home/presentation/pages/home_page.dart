import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';

/// Stub for `/`. The home screen — greeting, streak flame, today's-reading panel
/// — arrives with the API-backed features in a later phase.
///
/// See [LoginPage] for why these stubs take the shape they do and carry no
/// constructor dependencies. In short: a home screen with a hard-coded streak
/// and a hard-coded "today's reading" would be fake data that reads as real,
/// and Phase 4 still needs a routable widget at `/` to point at.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppRoutes.home)),
      body: const Center(child: Text('Placeholder for ${AppRoutes.home}')),
    );
  }
}
