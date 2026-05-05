import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/user_profile.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/subscription/data/subscription_state.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/otp_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/billing/presentation/billing_page.dart';
import '../../features/checkin/presentation/checkin_page.dart';
import '../../features/checkin/presentation/checkin_success_page.dart';
import '../../features/gyms/presentation/explore_page.dart';
import '../../features/gyms/presentation/favorites_page.dart';
import '../../features/gyms/presentation/gym_detail_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/referral/presentation/invite_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/subscription/presentation/checkout_page.dart';
import '../../features/subscription/presentation/my_subscription_page.dart';
import '../../features/subscription/presentation/plans_page.dart';
import '../../features/subscription/presentation/welcome_page.dart';
import '../../features/support/presentation/contact_support_page.dart';
import '../../features/support/presentation/faq_page.dart';
import '../../features/support/presentation/help_page.dart';
import '../../features/support/presentation/report_issue_page.dart';

/// Key on the inner shell navigator (the one that owns /home /explore /scan
/// /profile and any modal sheets pushed from those pages). Exported so
/// HomeShell can dismiss open bottom sheets on tab swap without depending
/// on `Navigator.of(context)` — which would resolve to the *root* navigator
/// from HomeShell's context and miss anything one level deeper.
final shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellNavigator',
);

/// Short, snappy cross-page transition used everywhere. Material's default is
/// ~300ms with a heavy elevation curve — too sluggish for the interaction
/// density in this app. This is a fade + slight slide at 160ms.
CustomTransitionPage<T> _fastPage<T>(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final path = state.uri.path;
      // Splash owns its own routing after it finishes animating. Returning
      // here short-circuits the provider reads below, so the first frame
      // doesn't trigger the secure_storage cascade (auth + profile +
      // subscription + billing + referral) and can paint immediately.
      if (path == '/splash') return null;

      final authState = ref.read(authControllerProvider);
      final profile = ref.read(profileProvider);
      final sub = ref.read(subscriptionProvider);
      final isAuthed = authState.phase == AuthPhase.authed;
      final hasProfile = profile.isComplete;
      final hasSubscription = sub.hasSubscription;

      const publicPaths = [
        '/splash',
        '/sign-in',
        '/otp',
        '/register',
        '/forgot-password',
      ];
      final isPublic = publicPaths.any(path.startsWith);

      // Pages that *require* an active subscription to be meaningful.
      // Everything else is open — unsubscribed members can browse the app
      // and each page renders its own empty-state CTA pointing to /plans.
      // Keeping this list explicit (vs. an allow-list) means new routes
      // default to "browsable without a plan" rather than silently locked.
      //
      // `/checkin` is deliberately NOT listed: an unsubscribed member can
      // still open the scanner, but CheckinController short-circuits the
      // scan result to `/gyms/<slug>` where the unlock CTA lives. This
      // beats bouncing to `/plans` with no context for why — the member
      // sees the specific gym they wanted to enter and the concrete tier
      // they'd need to unlock it.
      const subscriptionRequiredPaths = [
        '/subscription',
        '/welcome',
        '/billing',
      ];
      final requiresSubscription =
          subscriptionRequiredPaths.any(path.startsWith);

      if (!isAuthed && !isPublic) return '/sign-in';
      if (isAuthed && !hasProfile && path != '/register') return '/register';
      // Browse-first onboarding: a freshly-registered or freshly-signed-in
      // member always lands at /home so they get the bottom nav and can
      // explore the gym network before they're asked to pay. The previous
      // flow gated post-auth on `hasSubscription`, dumping unsubscribed
      // members onto /plans (which sits outside the home shell, no
      // bottom nav). That blocked the simple "I want to see what gyms
      // are nearby first" flow — they're now free to drill into any
      // gym profile from /explore, and the upgrade pill on the gym
      // card / detail page is what funnels them into /plans when
      // they're ready, with concrete context for what they're paying
      // for.
      if (isAuthed && hasProfile && path == '/register') {
        return '/home';
      }
      if (isAuthed && (path == '/sign-in' || path == '/otp')) {
        if (!hasProfile) return '/register';
        return '/home';
      }
      if (isAuthed && hasProfile && !hasSubscription && requiresSubscription) {
        return '/plans';
      }
      return null;
    },
    // Catch-all for unknown paths (typo'd deep link, stale push
    // notification target, deleted resource). Without this go_router
    // throws, leaves the user on a black screen, and the app is
    // effectively dead until restart. Render a small "not found"
    // surface with a Home button so the navigation graph stays
    // recoverable.
    errorBuilder: (context, state) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.help_outline, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.uri.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, __) => const NoTransitionPage(child: SplashPage()),
      ),
      GoRoute(path: '/sign-in', pageBuilder: (_, __) => _fastPage(const SignInPage())),
      GoRoute(path: '/otp', pageBuilder: (_, __) => _fastPage(const OtpPage())),
      GoRoute(path: '/register', pageBuilder: (_, __) => _fastPage(const RegisterPage())),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, s) => _fastPage(
          ForgotPasswordPage(phone: s.uri.queryParameters['phone'] ?? ''),
        ),
      ),
      GoRoute(path: '/plans', pageBuilder: (_, __) => _fastPage(const PlansPage())),
      GoRoute(
        path: '/checkout',
        pageBuilder: (_, s) => _fastPage(CheckoutPage(
          isRenewal: s.uri.queryParameters['renewal'] == '1',
        ),),
      ),
      GoRoute(path: '/welcome', pageBuilder: (_, __) => _fastPage(const WelcomePage())),
      GoRoute(path: '/subscription', pageBuilder: (_, __) => _fastPage(const MySubscriptionPage())),
      GoRoute(path: '/notifications', pageBuilder: (_, __) => _fastPage(const NotificationsPage())),
      GoRoute(path: '/settings', pageBuilder: (_, __) => _fastPage(const SettingsPage())),
      GoRoute(path: '/help', pageBuilder: (_, __) => _fastPage(const HelpPage())),
      GoRoute(path: '/support', pageBuilder: (_, __) => _fastPage(const ContactSupportPage())),
      GoRoute(path: '/faq', pageBuilder: (_, __) => _fastPage(const FaqPage())),
      GoRoute(path: '/report-issue', pageBuilder: (_, __) => _fastPage(const ReportIssuePage())),
      GoRoute(path: '/billing', pageBuilder: (_, __) => _fastPage(const BillingPage())),
      GoRoute(path: '/favorites', pageBuilder: (_, __) => _fastPage(const FavoritesPage())),
      GoRoute(path: '/invite', pageBuilder: (_, __) => _fastPage(const InvitePage())),
      GoRoute(
        path: '/gyms/:slug',
        pageBuilder: (_, s) =>
            _fastPage(GymDetailPage(slug: s.pathParameters['slug']!)),
      ),
      GoRoute(
        path: '/checkin/success',
        pageBuilder: (_, __) => _fastPage(const CheckinSuccessPage()),
      ),
      ShellRoute(
        // Anchor a key on the inner shell navigator so HomeShell can
        // pop modal bottom sheets (gym profile card, filters sheet)
        // before swapping tabs. Without this, `Navigator.of(...)` from
        // HomeShell's bottom-nav context returns the *root* navigator
        // — and any modal pushed from inside the shell (e.g. the
        // floating gym card on /explore) lives on a navigator one
        // level deeper, so it'd survive the tab swap and keep
        // painting over the new tab's content.
        navigatorKey: shellNavigatorKey,
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/home', pageBuilder: (_, __) => _fastPage(const HomePage())),
          GoRoute(path: '/explore', pageBuilder: (_, __) => _fastPage(const ExplorePage())),
          GoRoute(path: '/checkin', pageBuilder: (_, __) => _fastPage(const CheckinPage())),
          GoRoute(path: '/profile', pageBuilder: (_, __) => _fastPage(const ProfilePage())),
        ],
      ),
    ],
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    // `ref.listen` eagerly instantiates each provider it subscribes to.
    // Wiring them up inside the constructor — which runs as part of
    // `appRouterProvider`'s build during the first frame — would kick off
    // the auth/profile/subscription cold-boot chain (all of which hit
    // secure_storage and force the Android Keystore to initialize) before
    // the splash can paint. Defer until after the first frame so the splash
    // renders immediately and the provider cascade happens in the background.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen<AuthState>(
        authControllerProvider,
        (_, __) => notifyListeners(),
      );
      ref.listen<UserProfile>(
        profileProvider,
        (_, __) => notifyListeners(),
      );
      ref.listen<SubscriptionState>(
        subscriptionProvider,
        (prev, next) {
          // Only re-evaluate routes when the "are they subscribed?" bit flips.
          // Visit / streak / pending changes never gate navigation.
          if (prev?.hasSubscription != next.hasSubscription) {
            notifyListeners();
          }
        },
      );
    });
  }
}
