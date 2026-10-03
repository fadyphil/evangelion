import 'package:auto_route/auto_route.dart';
import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';

/// Stub for `/reading`. The reading sanctuary — English and Arabic scripture,
/// laid out RTL for the Arabic arm — arrives in a later phase, and the
/// bilingual string table with it.
///
/// Note what this stub does *not* decide, because getting it wrong early is
/// expensive: AGENT_CONTEXT §2 describes this screen as "zero chrome", yet this
/// one carries an `AppBar`. The `AppBar` is scaffolding, not a design decision —
/// the real screen is built to hide it. It is here so the page has the shape
/// the router and the widget tests can both recognise.
@RoutePage()
class ReadingPage extends StatelessWidget {
  const ReadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppRoutes.reading)),
      body: const Center(child: Text('Placeholder for ${AppRoutes.reading}')),
    );
  }
}
