import 'package:flutter/material.dart';

/// Wrapper estático conservado para mantener los call sites administrativos.
class AdminScaleIn extends StatelessWidget {
  const AdminScaleIn({required this.child, super.key, this.duration});

  final Widget child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) => child;
}

/// Wrapper estático conservado para mantener los call sites administrativos.
class AdminScaleRise extends StatelessWidget {
  const AdminScaleRise({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
  });

  factory AdminScaleRise.step(int step, {Key? key, required Widget child}) =>
      AdminScaleRise(
        key: key,
        delay: Duration(milliseconds: 55 * step),
        child: child,
      );

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) => child;
}

/// Wrapper estático para valores administrativos que antes tenían una entrada.
class AdminTok extends StatelessWidget {
  const AdminTok({required this.child, super.key, this.token});

  final Widget child;
  final Object? token;

  @override
  Widget build(BuildContext context) => child;
}

/// Wrapper estático para el emblema del enlace generado.
class AdminChain extends StatelessWidget {
  const AdminChain({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
