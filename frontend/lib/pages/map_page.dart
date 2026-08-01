import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';

/// 点亮地图：暗色星座图，金点涟漪 + 航线流动
class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = mapPoints();
    final lit = points.where((c) => c.lit).length;
    final next = points
        .firstWhere(
          (c) => !c.lit,
          orElse: () => const MapPoint('…', 0, 0, false),
        )
        .name;
    return Scaffold(
      backgroundColor: T.darkBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.6,
            colors: [Color(0xFF16233F), Color(0xFF0B1120), Color(0xFF080C17)],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    DarkPill(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          '点 亮 地 图',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 4,
                            color: Color(0xFFE8EEF8),
                          ),
                        ),
                      ),
                    ),
                    DarkPill(
                      icon: Icons.ios_share_rounded,
                      onTap: () => snack(context, '已保存到相册（演示）'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .07),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) => CustomPaint(
                        painter: _MapPainter(_c.value, points),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stat('$lit', '处已点亮'),
                    const SizedBox(width: 40),
                    _stat(next, '下一站'),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String v, String label) {
    return Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w600,
            color: T.gold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 15, color: T.darkMuted)),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.t, this.points);
  final double t;
  final List<MapPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // ---- 网格 ----
    final gridP = Paint()
      ..color = const Color(0xFF7896D2).withValues(alpha: .10)
      ..strokeWidth = 1;
    for (double x = 0; x < w; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridP);
    }
    for (double y = 0; y < h; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridP);
    }

    Offset pos(MapPoint c) => Offset(w * c.fx, h * c.fy);

    // ---- 航线（点亮城市依次相连，虚线流动）----
    final litCities = points.where((c) => c.lit).toList();
    final lineP = Paint()
      ..color = T.gold.withValues(alpha: .35)
      ..strokeWidth = 1;
    for (var i = 0; i < litCities.length - 1; i++) {
      _dashedLine(
        canvas,
        pos(litCities[i]),
        pos(litCities[i + 1]),
        lineP,
        phase: t * 20,
      );
    }

    // ---- 城市点 ----
    for (var i = 0; i < points.length; i++) {
      final c = points[i];
      final p = pos(c);
      if (c.lit) {
        // 涟漪
        final rp = (t * 1.4 + i * .23) % 1.0;
        canvas.drawCircle(
          p,
          6 + rp * 13,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = T.gold.withValues(alpha: (1 - rp) * .5),
        );
        // 光晕 + 核
        canvas.drawCircle(
          p,
          9,
          Paint()
            ..color = T.gold.withValues(alpha: .35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
        canvas.drawCircle(p, 3.6, Paint()..color = T.gold);
      } else {
        canvas.drawCircle(p, 2.6, Paint()..color = const Color(0xFF3E4E74));
      }
      // 标签
      final tp = TextPainter(
        text: TextSpan(
          text: c.name,
          style: TextStyle(
            fontSize: 15.5,
            letterSpacing: 1,
            color: c.lit ? T.gold : const Color(0xFFAFC0DE),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p + const Offset(8, -14));
    }
  }

  void _dashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    double phase = 0,
  }) {
    const dash = 4.0, gap = 5.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var d = -(phase % (dash + gap));
    while (d < total) {
      final s = math.max(d, 0.0);
      final e = math.min(d + dash, total);
      if (e > 0 && e > s) {
        canvas.drawLine(a + dir * s, a + dir * e, paint);
      }
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.t != t;
}
