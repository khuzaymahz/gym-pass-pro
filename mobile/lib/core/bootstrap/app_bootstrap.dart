import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/user_profile.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/subscription/data/subscription_state.dart';

/// Force-instantiates every provider the router's redirect reads at runtime
/// and resolves once each has finished restoring its persisted state from
/// secure_storage. The splash awaits this before handing off to the router,
/// so returning members don't get bounced to `/sign-in` while bootstrap is
/// still in flight. Reading this provider kicks off the whole auth/profile/
/// subscription cascade — it is only read from the splash's post-frame
/// callback so the first Flutter frame paints before the cascade begins.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  await Future.wait([
    ref.read(authControllerProvider.notifier).ready,
    ref.read(profileProvider.notifier).ready,
    ref.read(subscriptionProvider.notifier).ready,
  ]);
});
