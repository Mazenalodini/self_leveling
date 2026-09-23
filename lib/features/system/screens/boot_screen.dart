import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/contracts/runtime_contract.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/app_init_provider.dart';
import '../../../widgets/system_background.dart';

/// Boot screen — checks system state and routes accordingly.
/// This is the TRUE entry point of the app after splash.
class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen> {
  @override
  void initState() {
    super.initState();
    // Wait for widgets to build, then route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateAndRoute();
    });
  }

  Future<void> _evaluateAndRoute() async {
    // Small delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final initState = ref.read(appInitProvider);

    // If already loaded before delay finished
    if (!initState.isLoading) {
      _routeBasedOnState(initState);
      return;
    }

    bool handled = false;
    ProviderSubscription<AppInitState>? subscription;

    // Listen for when loading completes naturally
    subscription =
        ref.listenManual<AppInitState>(appInitProvider, (prev, next) {
      if (!next.isLoading && mounted && !handled) {
        handled = true;
        subscription?.close();
        _routeBasedOnState(next);
      }
    });

    // Failsafe timeout to absolutely prevent infinite boot spinners
    await Future.delayed(const Duration(seconds: 5));
    if (mounted && !handled) {
      handled = true;
      subscription.close();
      // On safety timeout it is critical we route away from boot
      _routeBasedOnState(const AppInitState(
        readiness: ReadinessState.unauthenticated,
        isLoading: false,
      ));
    }
  }

  void _routeBasedOnState(AppInitState initState) {
    if (!mounted) return;

    switch (initState.entryTarget) {
      case AppEntryTarget.welcome:
        context.go(RoutePaths.welcome);
        break;
      case AppEntryTarget.onboarding:
        context.go(RoutePaths.onboarding);
        break;
      case AppEntryTarget.setup:
        context.go(RoutePaths.setup);
        break;
      case AppEntryTarget.dashboard:
        context.go(RoutePaths.dashboard);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SystemBackground(
        particleCount: 6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing shield icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                builder: (_, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.4),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.shield, color: Colors.white, size: 40),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Self Leveling',
                style: AppTextStyles.h2,
              ),

              const SizedBox(height: 12),

              Text(
                'Initializing system...',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryBlue.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
