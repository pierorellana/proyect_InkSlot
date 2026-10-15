import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('InkSlot', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const Text('Bootstrap local'),
          ],
        ),
      ),
    ),
  );
}
