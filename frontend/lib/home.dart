import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'tabs/me_tab.dart';
import 'tabs/tasks_tab.dart';
import 'tabs/wishes_tab.dart';
import 'theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  static const _tabs = [TasksTab(), WishesTab(), MeTab()];

  void _go(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBg()),
          // 切换无动画（瞬间切，保留各页状态）；
          // TickerMode 让没在看的 tab 里的循环动画停表，别白烧帧
          IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < _tabs.length; i++)
                TickerMode(enabled: i == _index, child: _tabs[i]),
            ],
          ),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .6),
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: .5), width: .5)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _item(0, Icons.calendar_today_outlined,
                        Icons.calendar_month_rounded, '任务'),
                    _item(1, Icons.star_outline_rounded, Icons.star_rounded,
                        '人生清单'),
                    _item(2, Icons.person_outline_rounded,
                        Icons.person_rounded, '我的'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData outline, IconData filled, String label) {
    final on = _index == i;
    Widget iconWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (c, a) =>
          ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
      child: on
          ? ShaderMask(
              key: const ValueKey('on'),
              shaderCallback: (r) => T.plusGrad.createShader(r),
              child: Icon(filled, size: 22, color: Colors.white),
            )
          : Icon(outline, key: const ValueKey('off'), size: 22, color: T.muted),
    );
    if (i == 1) {
      iconWidget = AnimatedRotation(
        turns: on ? 1 : 0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        child: iconWidget,
      );
    }
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _go(i),
        child: SizedBox(
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              padding:
                  EdgeInsets.symmetric(horizontal: on ? 15 : 11, vertical: 8),
              decoration: BoxDecoration(
                gradient: on
                    ? const LinearGradient(
                        colors: [Color(0xFFDDE4FF), Color(0xFFEBE2FF)])
                    : null,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    child: on
                        ? Row(
                            children: [
                              const SizedBox(width: 7),
                              Text(label,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: T.accent)),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 多彩柔光背景 —— 静态极光（不动，省一整条 60fps 的帧预算）
class AuroraBg extends StatelessWidget {
  const AuroraBg({super.key});

  // (left, top, size, color)
  static const _blobs = <(double, double, double, int)>[
    (-80, -60, 320, 0xFFB9C9FF),
    (180, 120, 300, 0xFFE6C9FF),
    (-60, 380, 320, 0xFFFFCFE6),
    (200, 560, 300, 0xFFC6F0E6),
    (-40, 760, 340, 0xFFCBD8FF),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFEDEFF8)),
        child: Stack(
          children: [
            for (final (left, top, size, color) in _blobs)
              Positioned(
                left: left,
                top: top,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Color(color).withValues(alpha: .7),
                      Color(color).withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
