import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_pages.dart';
import 'data/models.dart';
import 'data/repository.dart';
import 'format.dart';
import 'auth/set_password_page.dart';
import 'pages/account_page.dart';
import 'pages/admin_page.dart';
import 'pages/assistant_page.dart';
import 'pages/bookings_page.dart';
import 'pages/chat_page.dart';
import 'pages/chats_page.dart';
import 'pages/questions_page.dart';
import 'pages/team_page.dart';
import 'pages/today_page.dart';
import 'theme.dart';

late Repository repo;

enum AuthStatus { loading, signedOut, needsVerify, noAccess, ready }

/// Where the signed-in person is in sign-in (password, then their code if
/// they've turned on two-step sign-in), and which business they're looking at.
class AuthState extends ChangeNotifier {
  AuthState(this.client) {
    _sub = client.auth.onAuthStateChange.listen((_) => _update());
    _update();
  }

  final SupabaseClient client;
  late final StreamSubscription<dynamic> _sub;
  AuthStatus status = AuthStatus.loading;
  List<Membership> memberships = [];
  Membership? current;

  /// IsangoTech's own admins, who onboard businesses. They may belong to no business.
  bool isPlatformAdmin = false;

  /// The page someone asked for before being sent to sign-in or the loading screen.
  String? pendingLocation;

  int _generation = 0;

  void select(Membership m) {
    if (m.businessId == current?.businessId) return;
    current = m;
    setBusinessTimeZone(m.timeZone);
    notifyListeners();
  }

  Future<void> _update() async {
    // Only the latest check counts, so a slow, older one can't undo a newer one.
    final generation = ++_generation;
    final next = await _compute();
    if (generation != _generation) return;
    status = next;
    notifyListeners();
  }

  Future<AuthStatus> _compute() async {
    if (client.auth.currentSession == null) {
      memberships = [];
      current = null;
      isPlatformAdmin = false;
      return AuthStatus.signedOut;
    }
    final aal = client.auth.mfa.getAuthenticatorAssuranceLevel();
    if (aal.currentLevel != AuthenticatorAssuranceLevels.aal2 && aal.nextLevel == AuthenticatorAssuranceLevels.aal2) {
      return AuthStatus.needsVerify;
    }
    try {
      final results = await Future.wait([repo.memberships(), repo.isPlatformAdmin()]);
      memberships = results[0] as List<Membership>;
      isPlatformAdmin = results[1] as bool;
    } catch (_) {
      memberships = [];
      isPlatformAdmin = false;
    }
    if (memberships.isEmpty) {
      current = null;
      return isPlatformAdmin ? AuthStatus.ready : AuthStatus.noAccess;
    }
    current = memberships.firstWhere((m) => m.businessId == current?.businessId, orElse: () => memberships.first);
    setBusinessTimeZone(current!.timeZone);
    return AuthStatus.ready;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// The business and role the pages work with.
class Session extends InheritedNotifier<AuthState> {
  const Session({super.key, required AuthState auth, required super.child}) : super(notifier: auth);

  static Membership of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Session>()!.notifier!.current!;

  static AuthState auth(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Session>()!.notifier!;
}

class BusinessApp extends StatefulWidget {
  const BusinessApp({super.key});

  @override
  State<BusinessApp> createState() => _BusinessAppState();
}

class _BusinessAppState extends State<BusinessApp> {
  late final AuthState auth = AuthState(Supabase.instance.client);
  late final GoRouter router = buildRouter(auth);

  @override
  Widget build(BuildContext context) {
    return Session(
      auth: auth,
      child: MaterialApp.router(
        title: 'IsangoTech Business',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: router,
      ),
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
      // Opened from a setup link or Account; works in any state (the page checks for a session).
      if (here == '/set-password') return null;
      final isGate = here == '/loading' || gateRoutes.containsValue(here);
      if (!isGate) auth.pendingLocation = state.uri.toString();
      if (auth.status == AuthStatus.loading) return here == '/loading' ? null : '/loading';
      final gate = gateRoutes[auth.status];
      if (gate != null) return here == gate ? null : gate;
      // Admins who belong to no business only have the Businesses screen.
      if (auth.current == null) return here.startsWith('/admin') ? null : '/admin';
      if (here.startsWith('/admin') && !auth.isPlatformAdmin) return '/';
      if (here.startsWith('/team') && !auth.current!.isOwner) return '/';
      // Staff only see their own bookings; the rest is for owners and managers.
      if (!auth.current!.isManager &&
          !here.startsWith('/admin') &&
          !_staffPages.any((p) => p == '/' ? here == '/' : here.startsWith(p))) {
        return '/';
      }
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
      GoRoute(path: '/two-step-sign-in', builder: (_, _) => const EnrolPage()),
      GoRoute(path: '/verify', builder: (_, _) => const VerifyPage()),
      GoRoute(path: '/no-access', builder: (_, _) => const NoAccessPage()),
      GoRoute(path: '/set-password', builder: (_, _) => const SetPasswordPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(auth: auth, location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const TodayPage()),
          GoRoute(path: '/chats', builder: (_, _) => const ChatsPage()),
          GoRoute(
            path: '/chats/:id',
            builder: (_, s) => ChatPage(id: s.pathParameters['id']!),
          ),
          GoRoute(path: '/questions', builder: (_, _) => const QuestionsPage()),
          GoRoute(path: '/bookings', builder: (_, _) => const BookingsPage()),
          GoRoute(path: '/assistant', builder: (_, _) => const AssistantPage()),
          GoRoute(path: '/team', builder: (_, _) => const TeamPage()),
          GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
          GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
        ],
      ),
    ],
  );
}

const _staffPages = ['/', '/bookings', '/account'];

class _Dest {
  const _Dest(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const _destinations = [
  _Dest('/', 'Today', Icons.today_outlined),
  _Dest('/chats', 'Chats', Icons.forum_outlined),
  _Dest('/questions', 'Questions', Icons.help_outline),
  _Dest('/bookings', 'Bookings', Icons.event_outlined),
  _Dest('/assistant', 'Assistant', Icons.smart_toy_outlined),
  _Dest('/team', 'Team', Icons.group_outlined),
  _Dest('/account', 'Account', Icons.person_outline),
];

void _go(BuildContext context, String path) {
  if (path == '/account-signout') {
    Supabase.instance.client.auth.signOut();
  } else {
    context.go(path);
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.auth, required this.location, required this.child});
  final AuthState auth;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final me = auth.current;
    final dests = [
      if (me != null)
        for (final d in _destinations)
          if ((me.isManager || _staffPages.contains(d.path)) && (d.path != '/team' || me.isOwner)) d,
      if (auth.isPlatformAdmin) const _Dest('/admin', 'Businesses', Icons.storefront_outlined),
      if (me == null) const _Dest('/account-signout', 'Sign out', Icons.logout),
    ];
    var selected = 0;
    for (var i = dests.length - 1; i >= 0; i--) {
      final p = dests[i].path;
      if (p == '/' ? location == '/' : location.startsWith(p)) {
        selected = i;
        break;
      }
    }
    final switcher = auth.memberships.length < 2
        ? null
        : PopupMenuButton<Membership>(
            tooltip: 'Switch business',
            onSelected: (m) {
              auth.select(m);
              context.go('/');
            },
            itemBuilder: (_) => [
              for (final m in auth.memberships)
                CheckedPopupMenuItem(value: m, checked: m.businessId == me?.businessId, child: Text(m.businessName)),
            ],
            child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.swap_horiz)),
          );

    if (MediaQuery.sizeOf(context).width >= 900) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              minExtendedWidth: 220,
              selectedIndex: selected,
              onDestinationSelected: (i) => _go(context, dests[i].path),
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                child: SizedBox(
                  width: 196,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/brand/mark-reversed.png', height: 32, semanticLabel: 'IsangoTech'),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              me?.businessName ?? 'IsangoTech',
                              style: const TextStyle(color: Brand.white, fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ),
                          if (switcher != null)
                            IconTheme(
                              data: const IconThemeData(color: Brand.sand),
                              child: switcher,
                            ),
                        ],
                      ),
                      Text(
                        me == null ? 'Admin' : roles[me.role] ?? me.role,
                        style: const TextStyle(color: Brand.sand, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              destinations: [
                for (final d in dests) NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(me?.businessName ?? 'IsangoTech'), actions: [?switcher]),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => _go(context, dests[i].path),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.icon), label: d.label)],
      ),
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
