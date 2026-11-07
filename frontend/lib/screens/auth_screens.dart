import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models/auth.dart';
import '../api/api_connector.dart';
import '../api/models/consent.dart';
import '../router/routes.dart';
import '../state/auth_controller.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import '../widgets/common.dart';
import '../ui/feature_note.dart';
import '../ui/nudge_card.dart';
import 'auth_layout.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  // The launch overlay covers this while sign-in resolves.
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return AuthLayout(
      title: 'Welcome to Flow',
      subtitle: 'Flow suggests breaks that fit your work, and tells you why.',
      // the brand field shows the product: a real-looking nudge + what each part does
      showcase: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(flowCaps('What a nudge looks like'), style: FlowType.label(p, size: 9.5, color: p.text3)),
          const SizedBox(height: 10),
          IgnorePointer(
            child: NudgeCardView(
              message: "You're 48 minutes in and your typing rhythm has broken up. A short break now usually buys you the next hour.",
              reason: 'Window switching is 40% above your usual for this hour.',
              onBreak: () {},
              onSnooze: (_) {},
              onWhy: () {},
            ),
          ),
          const SizedBox(height: 22),
          const FeatureNote(
            number: 1,
            title: 'It notices',
            body: 'Counts of typing, switching and idle time. Never window titles, never what you type.',
          ),
          const SizedBox(height: 14),
          const FeatureNote(
            number: 2,
            title: 'It nudges, gently',
            body: 'Before your focus runs down, not after. Snooze or dismiss any time; it learns from both.',
          ),
          const SizedBox(height: 14),
          const FeatureNote(
            number: 3,
            title: 'It explains',
            body: 'Every nudge shows its reasons. Nothing is sensed until you agree to it.',
          ),
        ],
      ),
      form: [
        Text('Nothing is sensed until you agree. Camera and calendar stay off unless you turn them on.', style: FlowType.note(p, size: 14)),
        const SizedBox(height: 6),
        AuthPrimary(label: 'Sign in', onPressed: () => context.go(Routes.login)),
        Pressable(
          onPressed: () => context.go(Routes.register),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: const SizedBox(
            width: double.infinity,
            child: Text('Create an account', textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

/// Where an admin's invite link lands (signed out). Explains what joining a
/// team means before anything else, then carries the token into Create account.
class InviteLandingScreen extends StatelessWidget {
  const InviteLandingScreen({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final ok = token.isNotEmpty;
    return AuthLayout(
      title: ok ? "You're invited" : 'This link is incomplete',
      subtitle: ok ? 'Your team uses Flow. Join with your own account; your data stays yours.' : 'Ask your admin for a new invite link.',
      stage: ok ? StageState.rest : StageState.error,
      form: [
        if (ok) ...[
          const FeatureNote(number: 1, title: 'Only averages', body: 'Your team sees averages of 5 or more people, never you on your own.'),
          const SizedBox(height: 4),
          const FeatureNote(
            number: 2,
            title: 'Nothing until you agree',
            body: 'You choose what Flow may sense, and can change it any time.',
          ),
          const SizedBox(height: 4),
          const FeatureNote(number: 3, title: 'You can leave', body: 'Turn off team averages in Privacy, or delete your account.'),
          const SizedBox(height: 10),
          AuthPrimary(
            label: 'Create my account',
            onPressed: () => context.go(Uri(path: Routes.register, queryParameters: {'invite': token}).toString()),
          ),
        ],
        Text(ok ? 'The link is single use and expires.' : '', style: FlowType.chart(p, size: 10.5)),
      ],
      footer: [AuthLink('I already have an account', onPressed: () => context.go(Routes.login))],
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  StageState _stage = StageState.rest;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stage == StageState.busy) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      return setState(() {
        _stage = StageState.error;
        _error = 'Enter your email and password.';
      });
    }
    setState(() {
      _stage = StageState.busy;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(email: _email.text.trim(), password: _password.text);
      if (mounted) setState(() => _stage = StageState.success);
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = StageState.error;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final notice = auth is SignedOut ? auth.message : null;
    final busy = _stage == StageState.busy;
    return AuthLayout(
      title: 'Sign in',
      stage: _stage,
      form: [
        if (notice != null) AuthNote(notice),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FlowTextField(
                controller: _email,
                hint: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 10),
              FlowTextField(
                controller: _password,
                hint: 'Password',
                obscure: true,
                onSubmitted: (_) => _submit(),
                autofillHints: const [AutofillHints.password],
              ),
            ],
          ),
        ),
        if (_error != null) AuthError(_error!),
        const SizedBox(height: 4),
        AuthPrimary(label: busy ? 'Signing in…' : 'Sign in', onPressed: busy ? null : _submit),
      ],
      footer: [
        AuthLink('Forgot password?', onPressed: () => context.go(Routes.forgotPassword)),
        AuthLink('Create an account', onPressed: () => context.go(Routes.register)),
      ],
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.inviteToken});

  /// From an invite link: `/register?invite=…`. Presence = employee signup.
  final String? inviteToken;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _invite = TextEditingController(text: widget.inviteToken ?? '');
  late AccountType _type = widget.inviteToken != null ? AccountType.employee : AccountType.solo;
  StageState _stage = StageState.rest;
  String? _error;
  RegisterResult? _done;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _invite]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Enter your name.';
    if (!_email.text.contains('@')) return 'Enter a valid email.';
    if (_password.text.length < 10) return 'Use at least 10 characters.';
    if (_type == AccountType.employee && _invite.text.trim().isEmpty) return 'Employees need an invite link from their admin.';
    return null;
  }

  Future<void> _submit() async {
    if (_stage == StageState.busy) return;
    final v = _validate();
    if (v != null) {
      return setState(() {
        _stage = StageState.error;
        _error = v;
      });
    }
    setState(() {
      _stage = StageState.busy;
      _error = null;
    });
    try {
      final res = await ref
          .read(authProvider.notifier)
          .register(
            RegisterRequest(
              name: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
              accountType: _type,
              inviteToken: _type == AccountType.employee ? _invite.text.trim() : null,
            ),
          );
      if (mounted) {
        setState(() {
          _stage = StageState.success;
          _done = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = StageState.error;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done != null) {
      return AuthLayout(
        title: 'Check your email',
        stage: StageState.success,
        subtitle: 'We sent a verification link to ${_email.text.trim()}. Open it, then sign in.',
        form: [AuthPrimary(label: 'Go to sign in', onPressed: () => context.go(Routes.login))],
      );
    }
    final busy = _stage == StageState.busy;
    return AuthLayout(
      title: 'Create account',
      stage: _stage,
      form: [
        Row(
          children: [
            for (final (t, label) in const [(AccountType.solo, 'Just me'), (AccountType.employee, 'My team invited me')]) ...[
              Pressable(selected: _type == t, onPressed: () => setState(() => _type = t), child: Text(label)),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 4),
        FlowTextField(controller: _name, hint: 'Name', autofillHints: const [AutofillHints.name]),
        FlowTextField(
          controller: _email,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        FlowTextField(
          controller: _password,
          hint: 'Password (10+ characters)',
          obscure: true,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: _type == AccountType.solo ? (_) => _submit() : null,
        ),
        if (_type == AccountType.employee) FlowTextField(controller: _invite, hint: 'Invite code or link', onSubmitted: (_) => _submit()),
        if (_error != null) AuthError(_error!),
        const SizedBox(height: 4),
        AuthPrimary(label: busy ? 'Creating…' : 'Create account', onPressed: busy ? null : _submit),
      ],
      footer: [AuthLink('I already have an account', onPressed: () => context.go(Routes.login))],
    );
  }
}

class MfaScreen extends ConsumerStatefulWidget {
  const MfaScreen({super.key});
  @override
  ConsumerState<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends ConsumerState<MfaScreen> {
  final _code = TextEditingController();
  StageState _stage = StageState.rest;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stage == StageState.busy || _code.text.length != 6) return;
    setState(() {
      _stage = StageState.busy;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).verifyMfa(_code.text);
      if (mounted) setState(() => _stage = StageState.success);
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = StageState.error;
          _error = errorText(e);
          _code.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Two-step check',
    subtitle: 'Enter the 6-digit code from your authenticator app.',
    stage: _stage,
    form: [
      CodeBoxes(controller: _code, onComplete: (_) => _submit(), enabled: _stage != StageState.busy),
      if (_error != null) AuthError(_error!),
      const SizedBox(height: 4),
      AuthPrimary(label: _stage == StageState.busy ? 'Checking…' : 'Verify', onPressed: _stage == StageState.busy ? null : _submit),
    ],
    footer: [AuthLink('Use a different account', onPressed: () => ref.read(authProvider.notifier).cancelMfa())],
  );
}

/// Six recessed digit boxes over one real field: typing, paste and autofill
/// all work; a complete code submits itself (spec §4).
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({super.key, required this.controller, required this.onComplete, this.enabled = true});
  final TextEditingController controller;
  final ValueChanged<String> onComplete;
  final bool enabled;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    final digits = widget.controller.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 6 ? digits.substring(0, 6) : digits;
    if (clipped != widget.controller.text) {
      widget.controller.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
      return;
    }
    setState(() {});
    if (clipped.length == 6) widget.onComplete(clipped);
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final text = widget.controller.text;
    return Semantics(
      label: 'Six digit code',
      textField: true,
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) SizedBox(width: i == 3 ? 16 : 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.82,
                      child: CustomPaint(
                        painter: RecessPainter(p, focused: _focus.hasFocus && i == text.length.clamp(0, 5)),
                        child: Center(child: Text(i < text.length ? text[i] : '', style: FlowType.numeral(p, 26))),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // the real input, invisible, covering the boxes
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  StageState _stage = StageState.rest;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_email.text.contains('@')) {
      return setState(() {
        _stage = StageState.error;
        _error = 'Enter a valid email.';
      });
    }
    setState(() {
      _stage = StageState.busy;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).forgotPassword(_email.text.trim());
      if (mounted) setState(() => _stage = StageState.success);
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = StageState.error;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _stage == StageState.success;
    return AuthLayout(
      title: 'Reset password',
      stage: _stage,
      // Same message whether or not the account exists (no account enumeration).
      subtitle: sent ? 'If an account exists for that email, a reset link is on its way.' : "We'll email you a link to choose a new one.",
      form: [
        if (!sent) ...[
          FlowTextField(controller: _email, hint: 'Email', keyboardType: TextInputType.emailAddress, onSubmitted: (_) => _submit()),
          if (_error != null) AuthError(_error!),
          const SizedBox(height: 4),
          AuthPrimary(
            label: _stage == StageState.busy ? 'Sending…' : 'Send reset link',
            onPressed: _stage == StageState.busy ? null : _submit,
          ),
        ],
      ],
      footer: [AuthLink('Back to sign in', onPressed: () => context.go(Routes.login))],
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});
  final String token;
  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _pw = TextEditingController();
  StageState _stage = StageState.rest;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pw.text.length < 10) {
      return setState(() {
        _stage = StageState.error;
        _error = 'Use at least 10 characters.';
      });
    }
    setState(() {
      _stage = StageState.busy;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).resetPassword(token: widget.token, newPassword: _pw.text);
      if (mounted) setState(() => _stage = StageState.success);
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = StageState.error;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _stage == StageState.success;
    final missing = widget.token.isEmpty;
    return AuthLayout(
      title: done ? 'Password updated' : 'Choose a new password',
      stage: missing ? StageState.error : _stage,
      subtitle: done ? 'You can sign in with it now.' : (missing ? 'This reset link is missing its token. Request a new one.' : null),
      form: [
        if (!done && !missing) ...[
          FlowTextField(
            controller: _pw,
            hint: 'New password (10+ characters)',
            obscure: true,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) AuthError(_error!),
          const SizedBox(height: 4),
          AuthPrimary(
            label: _stage == StageState.busy ? 'Updating…' : 'Update password',
            onPressed: _stage == StageState.busy ? null : _submit,
          ),
        ],
        if (done) AuthPrimary(label: 'Sign in', onPressed: () => context.go(Routes.login)),
      ],
      footer: [
        if (missing) AuthLink('Request a new link', onPressed: () => context.go(Routes.forgotPassword)),
        if (!done) AuthLink('Back to sign in', onPressed: () => context.go(Routes.login)),
      ],
    );
  }
}

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.token});
  final String? token;
  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final Future<void> _verify = _run();

  Future<void> _run() async {
    final t = widget.token;
    if (t == null || t.isEmpty) throw StateError('This link is missing its token.');
    await ref.read(authApiProvider).verifyEmail(t);
    if (ref.read(authProvider) is SignedIn) await ref.read(authProvider.notifier).reloadUser();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _verify,
    builder: (context, snap) {
      final (stage, title, sub) = switch (snap.connectionState) {
        ConnectionState.done when snap.hasError => (StageState.error, "Couldn't verify", errorText(snap.error!)),
        ConnectionState.done => (StageState.success, 'Email verified', 'Thanks. Your account is ready.'),
        _ => (StageState.busy, 'Verifying…', 'One moment.'),
      };
      final signedIn = ref.watch(authProvider) is SignedIn;
      return AuthLayout(
        title: title,
        subtitle: sub,
        stage: stage,
        form: [
          if (snap.connectionState == ConnectionState.done)
            AuthPrimary(label: signedIn ? 'Continue' : 'Sign in', onPressed: () => context.go(signedIn ? Routes.home : Routes.login)),
        ],
      );
    },
  );
}

/// One consent scope: title, plain description, switch. The whole row toggles.
class ConsentRow extends StatelessWidget {
  const ConsentRow({super.key, required this.title, required this.description, required this.value, required this.onChanged});
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: p.text1, fontSize: 13.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(description, style: TextStyle(color: p.text2, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: PillToggle(value: value, onChanged: onChanged, semanticLabel: title),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String consentTitle(ConsentScope s) => switch (s) {
  ConsentScope.behavior => 'Behavior sensing',
  ConsentScope.camera => 'Camera (eye signal)',
  ConsentScope.calendar => 'Google Calendar',
  ConsentScope.llm => 'AI assistant',
  ConsentScope.teamAggregate => 'Team averages',
};

String consentDescription(ConsentScope s) => switch (s) {
  ConsentScope.behavior =>
    'Counts of keystrokes, window switches and idle time, plus the type of app in front. Never window titles or what you type.',
  ConsentScope.camera => 'Estimates eye openness on this computer. Frames never leave your device; only a single score is sent if enabled.',
  ConsentScope.calendar => 'Reads your next 3 hours of events (read-only) to avoid nudging right before meetings.',
  ConsentScope.llm => 'When you ask for help while stuck, your task text is sent to an AI model. Nothing else.',
  ConsentScope.teamAggregate => 'Include your data in team averages. Only shown when at least 5 people share; never per person.',
};
