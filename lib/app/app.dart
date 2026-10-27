import 'package:flutter/material.dart';
import 'package:servicemate/app/app_shell.dart';

import '../core/theme/app_theme.dart';

class ServiceMateApp extends StatelessWidget {
  const ServiceMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServiceMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppShell(),
    );
  }
}
