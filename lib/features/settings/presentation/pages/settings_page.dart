import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';

/// Stub for `/settings`. Appearance, reading and about — local only, via
/// `shared_preferences`, never synced (AGENT_CONTEXT §2, decision 4).
///
/// See [LoginPage] for why these stubs take the shape they do and carry no
/// constructor dependencies. This screen is also where the app's locale is
/// eventually chosen, which is why `EvangelionApp` already resolves `ar` and
/// `en`: the switch has to render both directions correctly, and building that
/// from scratch after the fact means revisiting every screen.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppRoutes.settings)),
      body: const Center(child: Text('Placeholder for ${AppRoutes.settings}')),
    );
  }
}
