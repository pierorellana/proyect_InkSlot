import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import 'admin_session_controller.dart';
import 'widgets/d_coin.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({
    required this.sessionController,
    super.key,
    this.onAuthenticated,
  });

  final AdminSessionController sessionController;
  final VoidCallback? onAuthenticated;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _usernameError;
  String? _passwordError;
  int _shakes = 0;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String value) {
    if (value.trim().isEmpty) return 'Ingresa tu usuario.';
    return null;
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final usernameError = _validateUsername(_usernameController.text);
    final passwordError = _passwordController.text.isEmpty
        ? 'Escribe tu contraseña para entrar.'
        : null;
    widget.sessionController.clearError();
    setState(() {
      _usernameError = usernameError;
      _passwordError = passwordError;
      if (usernameError != null || passwordError != null) _shakes++;
    });
    if (usernameError != null || passwordError != null) return;

    await widget.sessionController.login(
      _usernameController.text,
      _passwordController.text,
    );
    if (!mounted) return;

    if (widget.sessionController.status == AdminSessionStatus.signedIn) {
      widget.onAuthenticated?.call();
    } else {
      setState(() => _shakes++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top < 58 ? 58.0 : media.padding.top;
    final bottomInset = media.padding.bottom + 6 < 40
        ? 40.0
        : media.padding.bottom + 6;
    return Scaffold(
      backgroundColor: InkSlotColors.ink,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.maxWidth > 488
                    ? (constraints.maxWidth - 440) / 2
                    : 24.0;
                return InkSlotScreenIn(
                  duration: const Duration(milliseconds: 550),
                  offset: 14,
                  fromScale: 1,
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            side,
                            topInset + 52,
                            side,
                            bottomInset,
                          ),
                          child: _LoginContent(
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            usernameError: _usernameError,
                            passwordError: _passwordError,
                            shakes: _shakes,
                            sessionController: widget.sessionController,
                            onSubmit: _submit,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Positioned.fill(child: RepaintBoundary(child: InkSlotGrain())),
        ],
      ),
    );
  }
}

class _LoginContent extends StatelessWidget {
  const _LoginContent({
    required this.usernameController,
    required this.passwordController,
    required this.usernameError,
    required this.passwordError,
    required this.shakes,
    required this.sessionController,
    required this.onSubmit,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String? usernameError;
  final String? passwordError;
  final int shakes;
  final AdminSessionController sessionController;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: sessionController,
    builder: (context, _) {
      final loading = sessionController.status == AdminSessionStatus.checking;
      final apiError = sessionController.errorMessage;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: DCoin()),
          const SizedBox(height: 34),
          InkSlotRise(
            delay: const Duration(milliseconds: 60),
            duration: const Duration(milliseconds: 650),
            offset: 16,
            child: Column(
              children: [
                Text(
                  'PANEL DEL ESTUDIO',
                  style: inkSlotMono(color: InkSlotColors.ash, spacing: .4),
                ),
                const SizedBox(height: 12),
                Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(text: 'Tu agenda,\n'),
                      TextSpan(
                        text: 'en orden.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFCFC9BF),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: inkSlotSerif(42),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          InkSlotRise(
            delay: const Duration(milliseconds: 120),
            duration: const Duration(milliseconds: 650),
            offset: 16,
            child: _Shake(
              trigger: shakes,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkSlotField(
                    label: 'Usuario',
                    controller: usernameController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    errorText: usernameError,
                  ),
                  const SizedBox(height: 14),
                  InkSlotField(
                    label: 'Contraseña',
                    controller: passwordController,
                    hint: 'Tu contraseña',
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => onSubmit(),
                    errorText: passwordError,
                  ),
                  if (apiError != null) ...[
                    const SizedBox(height: 14),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        apiError,
                        style: const TextStyle(
                          color: InkSlotColors.errorText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Spacer(),
          InkSlotPrimaryButton(
            label: loading ? 'Entrando…' : 'Entrar',
            loading: loading,
            onPressed: loading ? null : onSubmit,
          ),
        ],
      );
    },
  );
}

/// `.shake`: 450 ms, ±8 px en 20/40/60/80 %.
class _Shake extends StatefulWidget {
  const _Shake({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _offset = TweenSequence<double>([
    for (final (from, to) in const [
      (0.0, -8.0),
      (-8.0, 8.0),
      (8.0, -8.0),
      (-8.0, 8.0),
      (8.0, 0.0),
    ])
      TweenSequenceItem(
        tween: Tween(
          begin: from,
          end: to,
        ).chain(CurveTween(curve: Curves.ease)),
        weight: 20,
      ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(_Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && !inkSlotReduceMotion(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _offset,
    child: widget.child,
    builder: (context, child) =>
        Transform.translate(offset: Offset(_offset.value, 0), child: child),
  );
}
