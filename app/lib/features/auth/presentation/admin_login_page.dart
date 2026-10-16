import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_logo.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import 'admin_session_controller.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await widget.sessionController.login(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;

    if (widget.sessionController.status == AdminSessionStatus.signedIn) {
      widget.onAuthenticated?.call();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: InkSlotColors.deep,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          final content = _LoginForm(
            formKey: _formKey,
            emailController: _emailController,
            passwordController: _passwordController,
            sessionController: widget.sessionController,
            onSubmit: _submit,
          );

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 48 : 20,
              vertical: isWide ? 48 : 28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(child: _LoginIdentity()),
                          const SizedBox(width: 64),
                          Expanded(child: content),
                        ],
                      )
                    : Column(
                        children: [
                          const _LoginIdentity(compact: true),
                          const SizedBox(height: 36),
                          content,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _LoginIdentity extends StatelessWidget {
  const _LoginIdentity({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: compact
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      const InkSlotLogo(size: 62),
      const SizedBox(height: 28),
      const InkSlotMonoLabel(
        'Panel del estudio',
        color: InkSlotColors.copperLight,
      ),
      const SizedBox(height: 16),
      Text(
        'Tu estudio,\nen control.',
        textAlign: compact ? TextAlign.center : TextAlign.start,
        style: Theme.of(context).textTheme.displayMedium,
      ),
      const SizedBox(height: 18),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Text(
          'Administra solicitudes, comparte enlaces privados y mantén cada reserva en movimiento.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ],
  );
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.sessionController,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final AdminSessionController sessionController;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: sessionController,
    builder: (context, child) {
      final isLoading = sessionController.status == AdminSessionStatus.checking;
      final disableAnimations = MediaQuery.disableAnimationsOf(context);
      final error = sessionController.errorMessage;

      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: InkSlotColors.surface,
          borderRadius: BorderRadius.circular(InkSlotRadii.card),
          border: Border.all(color: InkSlotColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InkSlotMonoLabel('Acceso administrativo'),
              const SizedBox(height: 12),
              Text(
                'Bienvenido de vuelta',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresa para continuar con tus solicitudes.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              _AdminTextField(
                controller: emailController,
                label: 'Correo electrónico',
                hint: 'tu@estudio.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !isLoading,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Ingresa tu correo electrónico.';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Revisa el formato del correo.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _AdminTextField(
                controller: passwordController,
                label: 'Contraseña',
                hint: 'Tu contraseña',
                obscureText: true,
                textInputAction: TextInputAction.done,
                enabled: !isLoading,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => onSubmit(),
                validator: (value) => (value?.isNotEmpty ?? false)
                    ? null
                    : 'Ingresa tu contraseña.',
              ),
              AnimatedSwitcher(
                duration: disableAnimations
                    ? Duration.zero
                    : InkSlotMotion.micro,
                child: error == null
                    ? const SizedBox(height: 20, key: ValueKey('no-error'))
                    : Semantics(
                        liveRegion: true,
                        key: const ValueKey('login-error'),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            error,
                            style: const TextStyle(
                              color: InkSlotColors.errorText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              InkSlotPrimaryButton(
                label: isLoading ? 'Verificando…' : 'Entrar',
                onPressed: isLoading ? null : onSubmit,
                trailing: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: InkSlotColors.ink,
                        ),
                      )
                    : const Icon(Icons.arrow_forward, size: 20),
              ),
              const SizedBox(height: 18),
              Text(
                'Acceso privado para artistas y estudios.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
    required this.autofillHints,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final Iterable<String> autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    label: label,
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofillHints: autofillHints,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: InkSlotColors.field,
        labelStyle: const TextStyle(color: InkSlotColors.secondary),
        hintStyle: const TextStyle(color: InkSlotColors.tertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: InkSlotColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: InkSlotColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: InkSlotColors.copper, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: InkSlotColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: InkSlotColors.error, width: 1.5),
        ),
      ),
    ),
  );
}
