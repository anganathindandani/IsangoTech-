import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_pages.dart';
import 'data/models.dart';
import 'data/repository.dart';
import 'pages/assessments_page.dart';
import 'pages/audit_page.dart';
import 'pages/client_page.dart';
import 'pages/clients_page.dart';
import 'pages/home_page.dart';
import 'pages/invoice_page.dart';
import 'pages/invoices_page.dart';
import 'pages/lead_page.dart';
import 'pages/leads_page.dart';
import 'pages/packages_page.dart';
import 'pages/quote_page.dart';
import 'pages/quotes_page.dart';
import 'pages/settings_page.dart';
import 'theme.dart';

late Repository repo;

enum AuthStatus { loading, signedOut, needsVerify, noAccess, ready }

/// Where the signed-in person is in sign-in: password, the code from their
/// authenticator app if they've turned on two-step sign-in, then team access.
class AuthState extends ChangeNotifier {
  AuthState(this.client) {
    _sub = client.auth.onAuthStateChange.listen((_) => _update());
    _update();
  }

  final SupabaseClient client;
  late final StreamSubscription<dynamic> _sub;
  AuthStatus status = AuthStatus.loading;
  TeamMember? me;

  /// The page someone asked for before being sent to sign-in or the loading screen.
  String? pendingLocation;

  int _generation = 0;

  Future<void> _update() async {
    // Auth events can arrive in quick succession; only the latest check counts,
    // so a slow, older check can't undo a newer one.
    final generation = ++_generation;
    final next = await _compute();
    if (generation != _generation) return;
    if (next != status) {
      status = next;
      notifyListeners();
    }
  }

  Future<AuthStatus> _compute() async {
    if (client.auth.currentSession == null) {
      me = null;
      return AuthStatus.signedOut;
    }
    // Two-step sign-in is optional. Once someone has turned it on, they need
    // their code as well as their password (the database insists on it too).
    final aal = client.auth.mfa.getAuthenticatorAssuranceLevel();
    if (aal.currentLevel != AuthenticatorAssuranceLevels.aal2 && aal.nextLevel == AuthenticatorAssuranceLevels.aal2) {
      return AuthStatus.needsVerify;
    }
    try {
      me = await repo.me();
    } catch (_) {
      me = null;
    }
    return me != null && me!.active ? AuthStatus.ready : AuthStatus.noAccess;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class PortalApp extends StatefulWidget {
  const PortalApp({super.key});

  @override
  State<PortalApp> createState() => _PortalAppState();
}

class _PortalAppState extends State<PortalApp> {
  late final AuthState auth = AuthState(Supabase.instance.client);
  late final GoRouter router = buildRouter(auth);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IsangoTech Portal',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}

GoRouter buildRouter(AuthState auth) {
  const gateRoutes = {
    AuthStatus.signedOut: '/sign-in',
    AuthStatus.needsVerify: '/verify',
    AuthStatus.noAccess: '/no-access',
  };

  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/',
    redirect: (context, state) {
      final here = state.matchedLocation;
      final isGate = here == '/loading' || gateRoutes.containsValue(here);
      // Remember where someone was going, so sign-in and reloads take them back there.
      if (!isGate) auth.pendingLocation = state.uri.toString();
      if (auth.status == AuthStatus.loading) return here == '/loading' ? null : '/loading';
      final gate = gateRoutes[auth.status];
      if (gate != null) return here == gate ? null : gate;
      if (!isGate) return null;
      final target = auth.pendingLocation ?? '/';
      auth.pendingLocation = null;
      return target;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInPage()),
      // Opened from Settings to turn on two-step sign-in.
      GoRoute(path: '/two-step-sign-in', builder: (_, _) => const EnrolPage()),
      GoRoute(path: '/verify', builder: (_, _) => const VerifyPage()),
      GoRoute(path: '/no-access', builder: (_, _) => const NoAccessPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, me: auth.me, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomePage()),
          GoRoute(path: '/leads', builder: (_, _) => const LeadsPage()),
          GoRoute(
            path: '/leads/:id',
            builder: (_, s) => LeadPage(id: s.pathParameters['id']!),
          ),
          GoRoute(path: '/clients', builder: (_, _) => const ClientsPage()),
          GoRoute(
            path: '/clients/:id',
            builder: (_, s) => ClientPage(id: s.pathParameters['id']!),
          ),
          GoRoute(path: '/assessments', builder: (_, _) => const AssessmentsPage()),
          GoRoute(path: '/quotes', builder: (_, _) => const QuotesPage()),
          GoRoute(
            path: '/quotes/:id',
            builder: (_, s) => QuotePage(id: s.pathParameters['id']!),
          ),
          GoRoute(path: '/invoices', builder: (_, _) => const InvoicesPage()),
          GoRoute(
            path: '/invoices/:id',
            builder: (_, s) => InvoicePage(id: s.pathParameters['id']!),
          ),
          GoRoute(path: '/price-list', builder: (_, _) => const PackagesPage()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          GoRoute(path: '/audit-log', builder: (_, _) => const AuditPage()),
        ],
      ),
    ],
  );
}

class _Dest {
  const _Dest(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const _destinations = [
  _Dest('/', 'Today', Icons.today_outlined),
  _Dest('/leads', 'Leads', Icons.person_search_outlined),
  _Dest('/clients', 'Clients', Icons.storefront_outlined),
  _Dest('/assessments', 'Assessments', Icons.event_available_outlined),
  _Dest('/quotes', 'Quotes', Icons.request_quote_outlined),
  _Dest('/invoices', 'Invoices', Icons.receipt_long_outlined),
  _Dest('/price-list', 'Price list', Icons.sell_outlined),
  _Dest('/settings', 'Settings', Icons.tune),
  _Dest('/audit-log', 'Audit log', Icons.history),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child, this.me});
  final String location;
  final Widget child;
  final TeamMember? me;

  int get _selected {
    for (var i = _destinations.length - 1; i >= 0; i--) {
      final p = _destinations[i].path;
      if (p == '/' ? location == '/' : location.startsWith(p)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final signOut = IconButton(
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout),
      onPressed: () => Supabase.instance.client.auth.signOut(),
    );
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              minExtendedWidth: 200,
              selectedIndex: _selected,
              onDestinationSelected: (i) => context.go(_destinations[i].path),
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
                child: Image.asset('assets/brand/mark-reversed.png', height: 36, semanticLabel: 'IsangoTech'),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(me?.fullName ?? '', style: const TextStyle(color: Brand.sand)),
                        IconButton(
                          tooltip: 'Sign out',
                          color: Brand.sand,
                          icon: const Icon(Icons.logout),
                          onPressed: () => Supabase.instance.client.auth.signOut(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final d in _destinations) NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_destinations[_selected].label), actions: [signOut]),
      drawer: Drawer(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Image.asset('assets/brand/logo.png', height: 30, alignment: Alignment.centerLeft),
            ),
            for (final (i, d) in _destinations.indexed)
              ListTile(
                leading: Icon(d.icon),
                title: Text(d.label),
                selected: i == _selected,
                onTap: () {
                  Navigator.pop(context);
                  context.go(d.path);
                },
              ),
          ],
        ),
      ),
      body: child,
    );
  }
}

/// Page header used inside the shell: title, optional actions.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.actions = const [], this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.black54)),
          ],
        ),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}
