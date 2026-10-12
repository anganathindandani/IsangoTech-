import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui.dart';

/// Shows a setup link with buttons to copy it, or a ready-to-send WhatsApp message.
Future<void> showSetupLink(
  BuildContext context, {
  required String title,
  required String intro,
  required String ownerName,
  required String link,
}) {
  final message =
      'Hi ${ownerName.split(' ').first}, welcome to IsangoTech! Open this link to choose your password for your '
      'business dashboard: $link\n\nThe link works once, so open it soon. After that, sign in at app.isangotech.co.za.';
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(intro),
            const SizedBox(height: 12),
            SelectableText(link, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            const Text(
              'The link works once and expires after an hour, unless you set a longer time in Supabase.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: link));
            showDone(ctx, 'Link copied.');
          },
          child: const Text('Copy link'),
        ),
        FilledButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: message));
            showDone(ctx, 'Message copied. Paste it into WhatsApp.');
          },
          child: const Text('Copy WhatsApp message'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
      ],
    ),
  );
}
