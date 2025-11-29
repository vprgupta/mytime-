import 'package:go_router/go_router.dart';
import 'package:mytime/core/config/navigation_service.dart';
import 'package:mytime/features/app_blocking_new/screens/app_blocking_screen_v2.dart';
import 'package:mytime/features/app_blocking_new/screens/app_selection_screen_v2.dart';
import 'package:mytime/features/app_blocking_new/screens/permission_setup_screen_v2.dart';

import 'package:mytime/features/app_blocking/screens/bypass_attempts_screen.dart';
import 'package:mytime/features/app_blocking/screens/blocking_overlay_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String appBlocking = '/app-blocking';
  static const String appSelection = '/app-selection';
  static const String permissionSetup = '/permission-setup';
  static const String bypassAttempts = '/bypass-attempts';
  static const String blockingOverlay = '/blocking-overlay';


  static final router = GoRouter(
    navigatorKey: NavigationService.navigatorKey,
    initialLocation: home,
    routes: [
      GoRoute(
        path: home,
        builder: (context, state) => const AppBlockingScreenV2(),
      ),
      GoRoute(
        path: appBlocking,
        builder: (context, state) => const AppBlockingScreenV2(),
      ),
      GoRoute(
        path: appSelection,
        builder: (context, state) => const AppSelectionScreenV2(),
      ),
      GoRoute(
        path: permissionSetup,
        builder: (context, state) => const PermissionSetupScreenV2(),
      ),
      GoRoute(
        path: bypassAttempts,
        builder: (context, state) => const BypassAttemptsScreen(),
      ),
      GoRoute(
        path: blockingOverlay,
        builder: (context, state) {
          final appName = state.uri.queryParameters['appName'] ?? 'Unknown App';
          final remainingMinutes = int.tryParse(state.uri.queryParameters['remainingMinutes'] ?? '0') ?? 0;
          return BlockingOverlayScreen(
            appName: appName,
            remainingTime: Duration(minutes: remainingMinutes),
          );
        },
      ),
    ],
  );
}