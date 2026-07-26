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

  late final Animation<double> _logo =
      CurvedAnimation(parent: _c, curve: const Interval(0, .5, curve: Curves.easeInOut));
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4B84DB), Color(0xFF5EB87C)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 新 logo 图形（两行「勾+横线」逐笔画出 + 轻微弹入）
                  Transform.scale(
                    scale: .82 + .18 * _pop.value,
                    child: SizedBox(
                      width: 128,
                      height: 128,
                      child: CustomPaint(painter: _LogoPainter(_logo.value)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // 人生清单
                  Opacity(
                    opacity: _title.value.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - _title.value)),
                      child: const Text(
                        '人生清单',
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
                        '不留遗憾，活成自己想要的样子',
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

/// 新 logo 图形：两行「白勾 + 白横线」，按进度逐笔画出（与 App 图标一致）
class _LogoPainter extends CustomPainter {
  _LogoPainter(this.p);
  final double p;

  double _seg(double a, double b) => ((p - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100; // 设计基于 100×100，内容居中于 (50,50)
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.4 * s
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 勾（逐笔画出）
    void check(double x1, double y1, double x2, double y2, double x3,
        double y3, double prog) {
      if (prog <= 0) return;
      final path = Path()
        ..moveTo(x1 * s, y1 * s)
        ..lineTo(x2 * s, y2 * s)
        ..lineTo(x3 * s, y3 * s);
      final draw = Path();
      for (final m in path.computeMetrics()) {
        draw.addPath(m.extractPath(0, m.length * prog), Offset.zero);
      }
      canvas.drawPath(draw, paint);
    }

    // 横线（从左向右延伸）
    void line(double x1, double y, double x2, double prog) {
      if (prog <= 0) return;
      canvas.drawLine(Offset(x1 * s, y * s),
          Offset((x1 + (x2 - x1) * prog) * s, y * s), paint);
    }

    // 居中（与 App 图标一致，内容包围盒居中于画布）
    // 第一行
    check(22.5, 41, 28.5, 47, 39.5, 33, _seg(0, .28));
    line(51.5, 39, 77.5, _seg(.20, .5));
    // 第二行
    check(22.5, 61, 28.5, 67, 39.5, 53, _seg(.45, .73));
    line(51.5, 59, 77.5, _seg(.68, 1));
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.p != p;
}
