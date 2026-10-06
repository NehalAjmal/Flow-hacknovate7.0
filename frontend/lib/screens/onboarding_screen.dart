import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/theme.dart';

/// First-login walkthrough, shown once per device (SharedPreferences flag).
/// Four calm steps: what FLOW is, how tracking works, reading the dashboard,
/// and the call to action for the first session.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const int _stepCount = 4;

  void _finish(BuildContext context) {
    context.read<AppState>().completeOnboarding();
  }

  void _next() {
    if (_page >= _stepCount - 1) {
      _finish(context);
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final steps = _steps(theme, isDark);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: skip
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextButton(
                  onPressed: () => _finish(context),
                  child: const Text('Skip'),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _stepCount,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final step = steps[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark ? FlowTheme.brandGradientDark : FlowTheme.brandGradientLight,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(step.icon, size: 44, color: Colors.white),
                        ),
                        const SizedBox(height: 36),
                        Text('STEP ${i + 1} OF $_stepCount',
                            style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.7, fontSize: 14),
                        ),
                        if (step.detail != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: FlowTheme.iconChipBg(context),
                              borderRadius: BorderRadius.circular(FlowTheme.radiusMd),
                            ),
                            child: Text(
                              step.detail!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_stepCount, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? theme.primaryColor
                              : theme.primaryColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FlowTheme.radiusPill),
                        ),
                      ),
                      child: Text(
                        _page == _stepCount - 1 ? 'Declare your first intention' : 'Next',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Step> _steps(ThemeData theme, bool isDark) {
    return [
      const _Step(
        icon: Icons.self_improvement_rounded,
        title: 'Welcome to FLOW',
        body: 'Declare what you are about to work on. FLOW measures your focus in real time, '
            'spots drift and fatigue, and protects your natural rhythm instead of letting you burn out.',
      ),
      const _Step(
        icon: Icons.sensors_rounded,
        title: 'How tracking works',
        body: 'While a session runs, a small agent reads your active window, keystroke rhythm and idle '
            'time every 30 seconds. Your webcam adds an eye-fatigue signal - nothing is recorded, only numbers.',
        detail: 'The backend needs macOS Camera and Input Monitoring permission.\n'
            'Run once:  python Backend/check_camera.py',
      ),
      const _Step(
        icon: Icons.dashboard_rounded,
        title: 'Reading your dashboard',
        body: 'Focus score blends every signal into one number. The rhythm bar shows where you are '
            'in your natural ultradian cycle. When FLOW spots stuck, drift or fatigue, it intervenes.',
      ),
      const _Step(
        icon: Icons.play_circle_rounded,
        title: 'Your first session',
        body: 'Head to the Intent screen, declare what you will work on, and begin. '
            'The more sessions you complete, the smarter your patterns and predictions get.',
      ),
    ];
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String body;
  final String? detail;

  const _Step({required this.icon, required this.title, required this.body, this.detail});
}
