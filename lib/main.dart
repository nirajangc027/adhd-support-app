import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/dump_screen.dart';
import 'screens/feel_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/support_screen.dart';
import 'screens/today_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://hadcnsywhfnqylgpgsoe.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhhZGNuc3l3aGZucXlsZ3Bnc29lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNTE4NDQsImV4cCI6MjA4OTcyNzg0NH0.Utw1gyolUJGnCNrzjSEicJOj4ghm6LCRtInk-2JDlNk',
  );
  runApp(const ProviderScope(child: App()));
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _todayBranchKey = GlobalKey<NavigatorState>(debugLabel: 'today');
final _focusBranchKey = GlobalKey<NavigatorState>(debugLabel: 'focus');
final _dumpBranchKey = GlobalKey<NavigatorState>(debugLabel: 'dump');
final _feelBranchKey = GlobalKey<NavigatorState>(debugLabel: 'feel');
final _supportBranchKey = GlobalKey<NavigatorState>(debugLabel: 'support');

const _teal = Color(0xFF4EC8C8);

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/home/today',
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _todayBranchKey,
            routes: [
              GoRoute(
                path: '/home/today',
                name: 'homeToday',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _focusBranchKey,
            routes: [
              GoRoute(
                path: '/home/focus',
                name: 'homeFocus',
                builder: (context, state) => const FocusScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _dumpBranchKey,
            routes: [
              GoRoute(
                path: '/home/dump',
                name: 'homeDump',
                builder: (context, state) => const DumpScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _feelBranchKey,
            routes: [
              GoRoute(
                path: '/home/feel',
                name: 'homeFeel',
                builder: (context, state) => const FeelScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _supportBranchKey,
            routes: [
              GoRoute(
                path: '/home/support',
                name: 'homeSupport',
                builder: (context, state) => const SupportScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'ADHD Support Australia',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.white,
                indicatorColor: _teal.withValues(alpha: 0.2),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    );
                  }
                  return const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: _teal, size: 28);
                  }
                  return const IconThemeData(color: Colors.grey, size: 28);
                }),
              ),
              child: NavigationBar(
                height: 72,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) {
                  navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  );
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.calendar_today),
                    label: 'Today',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.timer),
                    label: 'Focus',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.lightbulb),
                    label: 'Dump',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite),
                    label: 'Feel',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.star),
                    label: 'Support',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
