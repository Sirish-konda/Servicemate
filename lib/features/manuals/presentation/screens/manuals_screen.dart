import 'package:flutter/material.dart';

import '../../domain/models/manual.dart';
import '../widgets/manual_list_card.dart';
import '../widgets/manuals_empty_state.dart';

class ManualsScreen extends StatefulWidget {
  const ManualsScreen({super.key});

  @override
  State<ManualsScreen> createState() => _ManualsScreenState();
}

class _ManualsScreenState extends State<ManualsScreen> {
  // Temporary sample data. We will replace this with local storage later.
  static const List<Manual> _sampleManuals = [
    Manual(
      id: 'sample-1',
      title: 'Drive X1 Service Manual',
      subtitle: 'Fictional equipment manual',
      pageCount: 86,
    ),
    Manual(
      id: 'sample-2',
      title: 'Pump P2 User Guide',
      subtitle: 'Fictional equipment manual',
      pageCount: 54,
    ),
  ];

  String _searchQuery = '';

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature will be added later.')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final query = _searchQuery.trim().toLowerCase();

    final filteredManuals = _sampleManuals.where((manual) {
      return manual.title.toLowerCase().contains(query) ||
          manual.subtitle.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manuals'),
        actions: [
          IconButton(
            onPressed: () => _showComingSoon('PDF import'),
            icon: const Icon(Icons.add),
            tooltip: 'Import PDF',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Your manual library',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep equipment manuals in one place for easy access.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search manuals...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your manuals',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${filteredManuals.length} shown',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (filteredManuals.isEmpty)
              ManualsEmptyState(
                title: query.isEmpty ? 'No manuals yet' : 'No manuals found',
                description: query.isEmpty
                    ? 'Your imported manuals will appear here.'
                    : 'Try searching with a different name.',
              )
            else
              ...filteredManuals.map(
                (manual) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ManualListCard(
                    manual: manual,
                    onTap: () => _showComingSoon('Manual details'),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showComingSoon('PDF import'),
              icon: const Icon(Icons.add),
              label: const Text('Import PDF'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
