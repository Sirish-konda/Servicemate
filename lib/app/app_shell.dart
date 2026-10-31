import 'package:flutter/material.dart';

import '../core/widgets/app_navigation_bar.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/manuals/presentation/screens/manuals_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int _chatTabIndex = 2;

  int _selectedIndex = 0;
  Key _chatScreenKey = UniqueKey();
  Key _homeScreenKey = UniqueKey();

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      if (index == 0) {
        _homeScreenKey = UniqueKey();
      }

      if (index == _chatTabIndex) {
        _chatScreenKey = UniqueKey();
      }

      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            key: _homeScreenKey,
            onTabSelected: _onDestinationSelected,
          ),
          const ManualsScreen(),
          ChatScreen(key: _chatScreenKey),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}
