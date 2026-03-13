import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class QuietoApp extends StatelessWidget {
  const QuietoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Quieto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
