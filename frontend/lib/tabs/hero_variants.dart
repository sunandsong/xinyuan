import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data.dart';

/// ───────────────── F · 年度报告大数据 ─────────────────
class HeroWrapped extends StatelessWidget {
  const HeroWrapped(
      {super.key, required this.done, this.maxH = 280, this.minH = 96});
  final List<Wish> done;
  final double maxH;
  final double minH;

  @override
  Widget build(BuildContext context) {
    final n = done.length;
    final total = AppData.I.wishes.length;
    final frac = total == 0 ? 0.0 : n / total;
    return LayoutBuilder(builder: (context, cons) {
      final h = cons.maxHeight;
      final topInset = MediaQuery.paddingOf(context).top;
      // 展开→折叠 进度 t：1=展开(大图) 0=收成顶部摘要条（不消失）
      final range = maxH - minH;
      final t = range <= 0 ? 1.0 : ((h - minH) / range).clamp(0.0, 1.0);
      final pad = topInset * t;
      final pct = (frac * 100).round();
      final bigOp = ((t - 0.35) / 0.55).clamp(0.0, 1.0); // 展开态可见
      final barOp = ((0.45 - t) / 0.45).clamp(0.0, 1.0); // 收起态可见
      final barH = (minH - topInset).clamp(40.0, 72.0);
      return ClipRect(
        child: Stack(children: [
          // 网格光晕背景，定格一帧当静态图（始终满宽满高、含刘海区）
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _MeshPainter(.3)),
            ),
          ),
          // 大内容（展开态）——随收起淡出，刘海下方居中
          Positioned(
            top: pad,
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: bigOp,
                child: Center(
                  child: OverflowBox(
                    minHeight: 0,
                    maxHeight: double.infinity,
                    alignment: Alignment.center,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Stack(alignment: Alignment.center, children: [
                        SizedBox(
                          width: 190,
                          height: 190,
                          child: CustomPaint(painter: _RingPainter(frac)),
                        ),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('$n',
                              style: const TextStyle(
                                  fontSize: 72,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('已实现 · 共 $total',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: .8))),
                        ]),
                      ]),
                      const SizedBox(height: 16),
                      Text('完成度 $pct%',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .5,
                              color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          // 顶部摘要条（收起态）——随收起淡入，常驻不消失（右侧让出排行榜+分享两个按钮）
          Positioned(
            top: topInset,
            left: 22,
            right: 104,
            height: barH,
            child: IgnorePointer(
              child: Opacity(
                opacity: barOp,
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 9),
                  Text('已实现 $n / $total',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const Spacer(),
                  Text('完成度 $pct%',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .9))),
                ]),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.frac);
  final double frac;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = Colors.white.withValues(alpha: .16));
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * frac,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFEAFBF2)])
              .createShader(Rect.fromCircle(center: c, radius: r)));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.frac != frac;
}

/// 流动网格光晕：多个冷色光斑叠加发光、缓慢飘动，中间一团亮光
class _MeshPainter extends CustomPainter {
  _MeshPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    // 深色底
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF16204A), Color(0xFF0E2A33)],
          ).createShader(rect));

    void blob(double fx, double fy, double fr, Color color) {
      final c = Offset(fx * w, fy * h);
      final r = fr * w;
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ).createShader(Rect.fromCircle(center: c, radius: r))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }

    final a = t * 2 * math.pi;
    blob(.26 + .10 * math.sin(a), .24 + .08 * math.cos(a), .52,
        const Color(0xFF3E6FE6).withValues(alpha: .42));
    blob(.78 + .09 * math.cos(a * 1.1), .30 + .09 * math.sin(a * 1.3), .46,
        const Color(0xFF1FB6C0).withValues(alpha: .38));
    blob(.58 + .12 * math.sin(a * .8 + 1), .74 + .07 * math.cos(a * .9), .52,
        const Color(0xFF3FB877).withValues(alpha: .40));
    blob(.22 + .08 * math.cos(a * 1.2 + 2), .70 + .08 * math.sin(a * 1.1), .48,
        const Color(0xFF7A5CF0).withValues(alpha: .46));
    blob(.82 + .07 * math.sin(a * 1.4), .78 + .06 * math.cos(a * 1.2), .42,
        const Color(0xFFE86FC0).withValues(alpha: .34));
    // 中间微光（弱，别糊住数字）
    blob(.5, .44, .24, const Color(0xFF9CD8FF).withValues(alpha: .14));
    // 数字后面压一层暗，提升白字对比
    final dark = Offset(w * .5, h * .44);
    canvas.drawCircle(
        dark,
        w * .26,
        Paint()
          ..blendMode = BlendMode.multiply
          ..shader = RadialGradient(colors: [
            Colors.black.withValues(alpha: .28),
            Colors.black.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: dark, radius: w * .26)));
  }

  @override
  bool shouldRepaint(_MeshPainter old) => old.t != t;
}
