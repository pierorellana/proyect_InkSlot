import 'package:flutter/material.dart';

/// Top spacing for pages rendered below the `AdminShell` chrome.
///
/// The mobile shell already consumes the safe area in its header, so child
/// pages must not add `MediaQuery.padding.top` a second time.
double adminPageTopInset(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 860 ? 28 : 20;
