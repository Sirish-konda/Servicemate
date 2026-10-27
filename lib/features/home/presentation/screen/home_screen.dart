import 'package:flutter/material.dart';
import 'package:servicemate/features/home/presentation/widgets/ask_manuals_cards.dart';

import '../../../../core/widgets/app_navigation_bar.dart';
import '../widgets/recent_manual_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature will be added later.')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: RichText(
          text: TextSpan(
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            children: [
              const TextSpan(text: 'Service'),
              TextSpan(
                text: 'Mate',
                style: TextStyle(color: colorScheme.primary),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showComingSoon(context, 'Settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What do you need\nhelp with?',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ask a question about your equipment and find '
                'answers in your manuals.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              AskManualsCard(
                onQuestionSubmitted: (question) {
                  _showComingSoon(context, 'Question search');
                },
                onTroubleshootPressed: () {
                  _showComingSoon(context, 'Troubleshooting');
                },
                onProcedurePressed: () {
                  _showComingSoon(context, 'Procedure search');
                },
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recently viewed',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _showComingSoon(context, 'Manual library');
                    },
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RecentManualCard(
                title: 'Drive X1 Service Manual',
                subtitle: 'Fictional example manual',
                onTap: () {
                  _showComingSoon(context, 'Manual details');
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index != 0) {
            _showComingSoon(context, 'Navigation');
          }
        },
      ),
    );
  }
}
