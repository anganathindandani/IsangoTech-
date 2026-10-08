import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/repository.dart';
import 'theme.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  if (!Config.isConfigured) {
    runApp(const _NotConfigured());
    return;
  }
  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
  repo = Repository(Supabase.instance.client);
  runApp(const PortalApp());
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildTheme(),
    home: const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This build has no Supabase settings. Build with --dart-define=SUPABASE_URL=… and --dart-define=SUPABASE_PUBLISHABLE_KEY=….',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
