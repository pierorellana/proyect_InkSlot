import 'package:flutter/material.dart';

import '../../../core/layout/inkslot_breakpoints.dart';

/// Top spacing for pages rendered below the `AdminShell` chrome.
///
/// The mobile shell already consumes the safe area in its header, so child
/// pages must not add `MediaQuery.padding.top` a second time.
double adminPageTopInset(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 1024 ? 28 : 20;

class AdminPageFrame extends StatelessWidget {
  const AdminPageFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final windowWidth = MediaQuery.sizeOf(context).width;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: adminPageMaxWidthFor(windowWidth),
        ),
        child: child,
      ),
    );
  }
}
