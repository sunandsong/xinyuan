import 'package:flutter/material.dart';
import '../home.dart';

/// 开屏动画页：白勾一笔画出 + 「心愿清单」浮现 + 标语，然后淡入主界面
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));

  late final Animation<double> _check =
      CurvedAnimation(parent: _c, curve: const Interval(0, .42, curve: Curves.easeInOut));
  late final Animation<double> _pop =
      CurvedAnimation(parent: _c, curve: const Interval(0, .5, curve: Curves.easeOutBack));
  late final Animation<double> _title =
      CurvedAnimation(parent: _c, curve: const Interval(.42, .7, curve: Curves.easeOut));
  late final Animation<double> _sub =
      CurvedAnimation(parent: _c, curve: const Interval(.62, .9, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    // 先停留一下纯蓝屏，再开始画勾
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _c.forward();
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _goHome();
    });
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (_, __, ___) => const HomeShell(initialIndex: 1),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A82F2), Color(0xFF4772FA)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 白勾（一笔画出 + 轻微弹入）
                  Transform.scale(
                    scale: .8 + .2 * _pop.value,
                    child: SizedBox(
                      width: 104,
                      height: 104,
                      child: CustomPaint(painter: _CheckPainter(_check.value)),
                    ),
                  ),
                  const SizedBox(height: 26),
                  // 心愿清单
                  Opacity(
                    opacity: _title.value.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - _title.value)),
                      child: const Text(
                        '心愿清单',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 标语
                  Opacity(
                    opacity: (_sub.value * .9).clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - _sub.value)),
                      child: Text(
                        '所有远方，都始于此刻的一步',
                        style: TextStyle(
                          fontSize: 13.5,
                          letterSpacing: 1,
                          color: Colors.white.withValues(alpha: .82),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 白色对勾：按进度一笔画出
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.p);
  final double p;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * .18, h * .52)
      ..lineTo(w * .40, h * .74)
      ..lineTo(w * .84, h * .28);
    final draw = Path();
    for (final m in path.computeMetrics()) {
      draw.addPath(m.extractPath(0, m.length * p.clamp(0, 1)), Offset.zero);
    }
    canvas.drawPath(
      draw,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .1
        ..color = Colors.white
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.p != p;
}
