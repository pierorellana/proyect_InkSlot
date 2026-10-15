import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/theme/inkslot_tokens.dart';

class PublicEntryController extends ChangeNotifier {
  Timer? _timer;
  bool _complete = false;
  VoidCallback? _onComplete;

  bool get isComplete => _complete;
  bool get shouldSkipSplash => _complete;

  void start({required bool reduceMotion, required VoidCallback onComplete}) {
    if (_timer != null || _complete) return;
    _onComplete = onComplete;

    if (reduceMotion) {
      scheduleMicrotask(_completeEntry);
      return;
    }

    _timer = Timer(InkSlotMotion.splash, _completeEntry);
  }

  void skip() {
    _timer?.cancel();
    _timer = null;
    _complete = true;
    final callback = _onComplete;
    _onComplete = null;
    callback?.call();
  }

  void _completeEntry() {
    if (_complete) return;
    _complete = true;
    _timer = null;
    final callback = _onComplete;
    _onComplete = null;
    callback?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _onComplete = null;
    super.dispose();
  }
}
