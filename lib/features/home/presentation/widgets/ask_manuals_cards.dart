import 'package:flutter/material.dart';

class AskManualsCard extends StatelessWidget {
  const AskManualsCard({
    super.key,
    required this.onQuestionSubmitted,
    required this.onTroubleshootPressed,
    required this.onProcedurePressed,
  });

  final ValueChanged<String> onQuestionSubmitted;
  final VoidCallback onTroubleshootPressed;
  final VoidCallback onProcedurePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.chat_outlined,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask your manuals',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Find troubleshooting information and procedures '
                      'in your manuals.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _QuestionField(onSubmitted: onQuestionSubmitted),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.build_outlined, size: 16),
                label: const Text('Troubleshoot an issue'),
                onPressed: onTroubleshootPressed,
              ),
              ActionChip(
                avatar: const Icon(Icons.list_alt_outlined, size: 16),
                label: const Text('Find a procedure'),
                onPressed: onProcedurePressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionField extends StatefulWidget {
  const _QuestionField({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  State<_QuestionField> createState() => _QuestionFieldState();
}

class _QuestionFieldState extends State<_QuestionField> {
  final TextEditingController _controller = TextEditingController();

  void _submitQuestion() {
    final question = _controller.text.trim();

    if (question.isEmpty) {
      return;
    }

    widget.onSubmitted(question);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _submitQuestion(),
      decoration: InputDecoration(
        hintText: 'Ask a question...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Padding(
          padding: const EdgeInsets.all(5),
          child: IconButton.filled(
            onPressed: _submitQuestion,
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Ask question',
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
