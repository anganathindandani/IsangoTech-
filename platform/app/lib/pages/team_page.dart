import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/setup_link.dart';
import '../widgets/ui.dart';

/// Owners only: who can sign in to the business, and as what.
class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _add(String businessId) async {
    final result = await showDialog<_Added>(
      context: context,
      builder: (_) => _AddDialog(businessId: businessId),
    );
    if (result == null || !mounted) return;
    _reload();
    if (result.link == null) {
      showDone(
        context,
        '${result.name} already has an IsangoTech login, so they sign in with it as usual and will see your business.',
      );
      return;
    }
    await showSetupLink(
      context,
      title: '${result.name} is added',
      intro: 'Send them this link on WhatsApp. It signs them in once so they can choose a password.',
      ownerName: result.name,
      link: result.link!,
    );
  }

  Future<void> _link(String businessId, TeamMember m) async {
    String? link;
    final ok = await run(context, () async => link = await repo.teamSetupLink(businessId, m.email));
    if (!ok || !mounted) return;
    await showSetupLink(
      context,
      title: 'Setup link for ${m.fullName}',
      intro: 'It signs them in once so they can choose a new password.',
      ownerName: m.fullName,
      link: link!,
    );
  }

  Future<void> _change(String businessId, TeamMember m, {String? role, bool? active}) async {
    if (active == false &&
        !await confirm(
          context,
          'Remove ${m.fullName}?',
          "They won't be able to sign in to your business any more. You can add them back later.",
          action: 'Remove',
        )) {
      return;
    }
    if (!mounted) return;
    final ok = await run(
      context,
      () => repo.updateTeamMember(businessId, m.userId, role: role, active: active),
      done: active == false
          ? '${m.fullName} can no longer sign in to your business.'
          : active == true
          ? '${m.fullName} can sign in again.'
          : '${m.fullName} is now ${roles[role]!.toLowerCase()}.',
    );
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context);
    return PageBody(
      maxWidth: 800,
      children: [
        PageHeader(
          'Team',
          subtitle:
              'Managers run the daily work (chats, bookings, the Assistant) but not billing or the team. '
              'Staff see only their own bookings.',
          actions: [
            FilledButton.icon(
              onPressed: () => _add(me.businessId),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add someone'),
            ),
          ],
        ),
        Card(
          child: Loader<List<TeamMember>>(
            key: ValueKey('${me.businessId}$_key'),
            load: () => repo.team(me.businessId),
            builder: (context, list, _) => Column(
              children: [
                for (final m in list)
                  ListTile(
                    title: Text(m.fullName, style: TextStyle(color: m.active ? null : Colors.black45)),
                    subtitle: Text(
                      [
                        m.email,
                        if (m.staffName != null) 'Bookings as ${m.staffName}',
                        if (!m.signedIn && m.active) "Hasn't signed in yet",
                        if (!m.active) 'Removed',
                      ].join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusChip(roles[m.role] ?? m.role),
                        if (m.role != 'owner')
                          PopupMenuButton<String>(
                            tooltip: 'Change',
                            onSelected: (v) => switch (v) {
                              'manager' || 'staff' => _change(me.businessId, m, role: v),
                              'remove' => _change(me.businessId, m, active: false),
                              'restore' => _change(me.businessId, m, active: true),
                              _ => _link(me.businessId, m),
                            },
                            itemBuilder: (_) => [
                              if (m.active && m.role != 'manager')
                                const PopupMenuItem(value: 'manager', child: Text('Make manager')),
                              if (m.active && m.role != 'staff' && m.staffName != null)
                                const PopupMenuItem(value: 'staff', child: Text('Make staff')),
                              if (m.active) const PopupMenuItem(value: 'link', child: Text('New setup link')),
                              m.active
                                  ? const PopupMenuItem(value: 'remove', child: Text('Remove from the team'))
                                  : const PopupMenuItem(value: 'restore', child: Text('Add back')),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Added {
  _Added(this.name, this.link);
  final String name;
  final String? link;
}

class _AddDialog extends StatefulWidget {
  const _AddDialog({required this.businessId});
  final String businessId;

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final _form = GlobalKey<FormState>();
  late final Future<List<StaffMember>> _staff = repo.staff(widget.businessId);
  String _name = '';
  String _email = '';
  String _role = 'staff';

  /// Which staff record their bookings come from; null means a new one in their name.
  String? _staffId;
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    ({String? setupLink, bool newLogin})? result;
    final ok = await run(
      context,
      () async => result = await repo.addTeamMember(
        widget.businessId,
        fullName: _name.trim(),
        email: _email.trim(),
        role: _role,
        staffId: _role == 'staff' ? _staffId : null,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, _Added(_name.trim(), result!.setupLink));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add someone to your team'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Their name'),
                validator: requiredText,
                onChanged: (v) => _name = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Their email',
                  helperText: 'They sign in with this. No email is sent; you share a setup link on WhatsApp.',
                  helperMaxLines: 2,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim())
                    ? null
                    : "That email address doesn't look right",
                onChanged: (v) => _email = v,
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'staff', label: Text('Staff')),
                  ButtonSegment(value: 'manager', label: Text('Manager')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                _role == 'staff'
                    ? 'Sees only their own bookings, and can mark them done.'
                    : 'Runs the daily work: chats, bookings, questions and the Assistant. Not billing or the team.',
                style: const TextStyle(color: Colors.black54),
              ),
              if (_role == 'staff') ...[
                const SizedBox(height: 16),
                FutureBuilder<List<StaffMember>>(
                  future: _staff,
                  builder: (context, snap) {
                    final free = [
                      for (final s in snap.data ?? <StaffMember>[])
                        if (!s.hasLogin && s.active) s,
                    ];
                    if (free.isEmpty) return const SizedBox.shrink();
                    return DropdownButtonFormField<String?>(
                      initialValue: _staffId,
                      decoration: const InputDecoration(
                        labelText: 'Their bookings',
                        helperText: 'Pick them if they are already on your staff list',
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Add them to the staff list')),
                        for (final s in free) DropdownMenuItem(value: s.id, child: Text('Bookings for ${s.fullName}')),
                      ],
                      onChanged: (v) => setState(() => _staffId = v),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Adding…' : 'Add')),
      ],
    );
  }
}
