import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  bool _waitingOnly = false;
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context);
    return PageBody(
      maxWidth: 800,
      children: [
        PageHeader(
          'Chats',
          subtitle: 'Every WhatsApp conversation. The Assistant answers unless someone has taken over.',
          actions: [
            FilterChip(
              label: const Text('Waiting for you'),
              selected: _waitingOnly,
              onSelected: (v) => setState(() => _waitingOnly = v),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => _key = UniqueKey()),
            ),
          ],
        ),
        Card(
          child: Loader<List<Conversation>>(
            key: ValueKey('${me.businessId}$_waitingOnly$_key'),
            load: () => repo.conversations(me.businessId, waitingOnly: _waitingOnly),
            builder: (context, list, _) => list.isEmpty
                ? EmptyState(_waitingOnly ? 'No chats are waiting for you.' : 'No chats yet.')
                : Column(
                    children: [
                      for (final c in list)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: c.withPerson ? Brand.ochre : Brand.sand,
                            foregroundColor: c.withPerson ? Brand.white : Brand.indigo,
                            child: Text(c.title.characters.first.toUpperCase()),
                          ),
                          title: Text(c.title),
                          subtitle: Text(c.withPerson ? 'With your team' : 'The Assistant is answering'),
                          trailing: Text(ago(c.lastMessageAt), style: const TextStyle(color: Colors.black54)),
                          onTap: () => context.go('/chats/${c.id}'),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
