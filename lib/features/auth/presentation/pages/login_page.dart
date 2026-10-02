import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';

/// Stub for `/login`. Phase 5 replaces this with the real onboarding + login
/// screen backed by `FakeAuthRepository`.
///
/// It exists so the composition root has a pre-auth entry point from Phase 0c
/// onward. It is deliberately NOT a login form: a plausible-looking form built
/// now would be thrown away by Phase 5, and every field, validator and error
/// message invented here would be work with no consumer. What it does give the
/// later phases is the shape Phase 4 wires up — a `Scaffold` with an app bar and
/// a body — and a screen that names its own route, so a screenshot or a test
/// failure says which screen it came from.
///
/// No constructor dependencies, and that is the honest state of affairs: there
/// is nothing to inject until the repository this screen will read exists.
/// The route name comes from [AppRoutes] rather than a literal so the page and
/// the router cannot disagree about the path.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppRoutes.login)),
      body: const Center(child: Text('Placeholder for ${AppRoutes.login}')),
    );
  }
}
