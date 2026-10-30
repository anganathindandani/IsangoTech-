import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// One WhatsApp chat: the messages, taking over and handing back, and
/// replying in person. Checks for new messages every 10 seconds.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.id});
  final String id;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  Conversation? _conversation;
  List<Message> _messages = [];
  Object? _error;
  bool _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([repo.conversation(widget.id), repo.messages(widget.id)]);
      if (!mounted) return;
      final grew = (results[1] as List<Message>).length != _messages.length;
      setState(() {
        _conversation = results[0] as Conversation;
        _messages = results[1] as List<Message>;
        _error = null;
      });
      if (grew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _setHandledBy(String who) async {
    final ok = await run(
      context,
      () => repo.setHandledBy(widget.id, who),
      done: who == 'person'
          ? 'You have this chat. The Assistant will stay quiet until you hand it back.'
          : 'The Assistant is answering this chat again.',
    );
    if (ok) _load();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final ok = await run(context, () => repo.reply(widget.id, text));
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _reply.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _conversation;
    if (c == null) {
      return _error != null ? Center(child: Text(errorMessage(_error!))) : const _ChatSkeleton();
    }
    final canReply = c.canReply(DateTime.now());
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Column(
      children: [
        Material(
          color: Brand.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'All chats',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/chats'),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                      if (c.number != null)
                        Text('+${c.number}', style: const TextStyle(color: Colors.black54), softWrap: false),
                    ],
                  ),
                ),
                c.withPerson
                    ? OutlinedButton.icon(
                        onPressed: () => _setHandledBy('assistant'),
                        icon: const Icon(Icons.smart_toy_outlined),
                        label: Text(narrow ? 'Hand back' : 'Hand back to the Assistant'),
                      )
                    : FilledButton.icon(
                        onPressed: () => _setHandledBy('person'),
                        icon: const Icon(Icons.pan_tool_outlined),
                        label: const Text('Take over'),
                      ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _messages.isEmpty
              ? const EmptyState('No messages yet.')
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _Bubble(_messages[i]),
                ),
        ),
        const Divider(height: 1),
        Material(
          color: Brand.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: canReply
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('reply'),
                          controller: _reply,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 2000,
                          decoration: InputDecoration(
                            hintText: c.withPerson
                                ? 'Reply on WhatsApp'
                                : 'Reply on WhatsApp (this takes the chat over from the Assistant)',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _sending ? null : _send, child: Text(_sending ? 'Sending…' : 'Send')),
                    ],
                  )
                : const Text(
                    "WhatsApp only allows replies within 24 hours of the customer's last message. They'll be able "
                    'to reach you again as soon as they write.',
                    style: TextStyle(color: Colors.black54),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m);
  final Message m;

  @override
  Widget build(BuildContext context) {
    final mine = !m.fromCustomer;
    final who = switch (m.sender) {
      'assistant' => 'Assistant',
      'person' => 'Your team',
      _ => 'Customer',
    };
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: switch (m.sender) {
              'assistant' => const Color(0xFFE3F4F2),
              'person' => const Color(0xFFFBE9D6),
              _ => Brand.white,
            },
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.body),
              const SizedBox(height: 4),
              Text('$who · ${dateTime(m.createdAt)}', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chat's shape in grey while it loads: a header and alternating messages.
class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 200, height: 22),
            const SizedBox(height: 8),
            const SkeletonBox(width: 140, height: 12),
            const SizedBox(height: 28),
            for (final (mine, width) in const [(false, 220.0), (true, 260.0), (false, 180.0), (true, 200.0)])
              Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SkeletonBox(width: width, height: 44, radius: 14),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
