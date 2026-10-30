import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';

/// Questions the Assistant couldn't answer. Answering one adds it to the
/// business's answers, so the Assistant can answer it next time.
class QuestionsPage extends StatefulWidget {
  const QuestionsPage({super.key});

  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _answer(Question q) async {
    final answer = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Answer this question'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${q.question}"', style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              TextField(
                controller: answer,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Your answer',
                  helperText: 'The Assistant will use this for the same question from now on.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final ok = await run(ctx, () => repo.answerQuestion(q.id, answer.text));
              if (ok && ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save answer'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      showDone(context, 'Saved. The Assistant knows the answer now.');
      _reload();
    }
  }

  Future<void> _dismiss(Question q) async {
    if (await run(context, () => repo.dismissQuestion(q.id))) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context);
    return PageBody(
      maxWidth: 800,
      children: [
        const PageHeader(
          'Questions to answer',
          subtitle: "Customers asked these and the Assistant didn't know. Answer once and it knows from then on.",
        ),
        Loader<List<Question>>(
          key: ValueKey('${me.businessId}$_key'),
          placeholder: const Card(child: SkeletonList()),
          load: () => repo.openQuestions(me.businessId),
          builder: (context, list, _) => list.isEmpty
              ? const Card(child: EmptyState('Nothing to answer. The Assistant has handled everything so far.'))
              : Column(
                  children: [
                    for (final q in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(q.question, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text('Asked ${ago(q.createdAt)}', style: const TextStyle(color: Colors.black54)),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton(onPressed: () => _answer(q), child: const Text('Answer')),
                                    if (q.conversationId != null)
                                      OutlinedButton(
                                        onPressed: () => context.go('/chats/${q.conversationId}'),
                                        child: const Text('Open the chat'),
                                      ),
                                    TextButton(onPressed: () => _dismiss(q), child: const Text('Dismiss')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
