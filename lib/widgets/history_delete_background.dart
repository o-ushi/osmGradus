import 'package:flutter/material.dart';

/// 履歴一覧で左スワイプ削除したときにカードの下から現れる赤い背景。
class HistoryDeleteBackground extends StatelessWidget {
  const HistoryDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_rounded, color: Colors.white),
    );
  }
}
