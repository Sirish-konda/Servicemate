import 'package:flutter/material.dart';

import '../../domain/models/manual_search_result.dart';

class ManualSearchResultCard extends StatelessWidget {
  const ManualSearchResultCard({
    super.key,
    required this.result,
    required this.onTap,
  });

  final ManualSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PDF page ${result.pdfPageNumber}',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Text(result.snippet),
            ],
          ),
        ),
      ),
    );
  }
}
