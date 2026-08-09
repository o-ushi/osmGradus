import 'package:flutter/material.dart';

/// リセット直後はボタンを隠し、状態が変わったら再表示する共通ロジック。
mixin ResetButtonVisibilityMixin<T extends StatefulWidget> on State<T> {
  bool _hideResetUntilStateChanges = false;
  String _resetBaselineKey = '';

  bool showResetButton(String currentStateKey) =>
      !_hideResetUntilStateChanges || currentStateKey != _resetBaselineKey;

  void hideResetUntilNextChange(String currentStateKey) {
    _hideResetUntilStateChanges = true;
    _resetBaselineKey = currentStateKey;
  }
}
