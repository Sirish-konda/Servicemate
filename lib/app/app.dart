import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'first_run_gate.dart';

class ServiceMateApp extends StatelessWidget {
  const ServiceMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServiceMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const FirstRunGate(),
    );
  }
}
