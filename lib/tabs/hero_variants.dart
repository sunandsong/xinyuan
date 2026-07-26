import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';

// 完成心愿在场景里的分布坐标（分数坐标，最多 8 个）
const _spots = <Offset>[
  Offset(.24, .30),
  Offset(.68, .22),
  Offset(.44, .46),
  Offset(.80, .52),
  Offset(.18, .60),
  Offset(.58, .68),
  Offset(.36, .78),
  Offset(.86, .80),
];

double _seededRand(int s) {
  s = (s * 1103515245 + 12345) & 0x7fffffff;
  return (s % 10000) / 10000.0;
}

Widget _caption(String text, {Color color = Colors.white}) {
  return Positioned(
    left: 0,
    right: 0,
    bottom: 16,
    child: Center(
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: .5,
              color: color)),
    ),
  );
}

/// ───────────────────────── A · 星空点亮 ─────────────────────────
class HeroConstellation extends StatefulWidget {
  const HeroConstellation({super.key, required this.done});
  final List<Wish> done;
  @override
  State<HeroConstellation> createState() => _HeroConstellationState();
}

class _HeroConstellationState extends State<HeroConstellation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.done.length.clamp(0, _spots.length);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF15213D), Color(0xFF0B1226)],
        ),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              painter: _StarPainter(_c.value, n, widget.done),
            ),
          ),
        ),
        _caption('已点亮 $n 颗心愿', color: const Color(0xFFDDE6FF)),
      ]),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.t, this.n, this.done);
  final double t;
  final int n;
  final List<Wish> done;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 背景微星
    final bg = Paint()..color = Colors.white;
    for (var i = 0; i < 60; i++) {
      final x = _seededRand(i * 2) * w;
      final y = _seededRand(i * 2 + 1) * h;
      final tw = (math.sin(t * 2 * math.pi + i) + 1) / 2;
      bg.color = Colors.white.withValues(alpha: .12 + .28 * tw);
      canvas.drawCircle(Offset(x, y), .6 + _seededRand(i * 3) * 1.1, bg);
    }
    // 星座连线
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .22)
      ..strokeWidth = 1;
    for (var i = 1; i < n; i++) {
      final a = Offset(_spots[i - 1].dx * w, _spots[i - 1].dy * h);
      final b = Offset(_spots[i].dx * w, _spots[i].dy * h);
      canvas.drawLine(a, b, line);
    }
    // 亮星（完成的心愿）
    for (var i = 0; i < n; i++) {
      final c = Offset(_spots[i].dx * w, _spots[i].dy * h);
      final col = done[i].color;
      final tw = (math.sin(t * 2 * math.pi + i * 1.7) + 1) / 2;
      final glow = Paint()
        ..color = col.withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(c, 9 + tw * 3, glow);
      _drawStar(canvas, c, 7.5 + tw * 1.5,
          Paint()..color = Colors.white.withValues(alpha: .95));
      canvas.drawCircle(
          c, 2.4, Paint()..color = col);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final ang = -math.pi / 2 + i * math.pi / 4;
      final rad = i.isEven ? r : r * .42;
      final pt = c + Offset(math.cos(ang) * rad, math.sin(ang) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.t != t || old.n != n;
}

/// ───────────────────────── B · 登顶之路 ─────────────────────────
class HeroSummit extends StatelessWidget {
  const HeroSummit({super.key, required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    final n = done.length.clamp(0, _spots.length);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE9CF), Color(0xFFCFE6F5)],
        ),
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _SummitPainter(n, done))),
        _caption('已抵达 $n 个里程碑', color: const Color(0xFF5B4A3A)),
      ]),
    );
  }
}

// 山路里程点（从下往上）
const _trail = <Offset>[
  Offset(.16, .86),
  Offset(.34, .74),
  Offset(.5, .64),
  Offset(.6, .48),
  Offset(.74, .36),
  Offset(.84, .22),
];

class _SummitPainter extends CustomPainter {
  _SummitPainter(this.n, this.done);
  final int n;
  final List<Wish> done;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 远山
    final far = Paint()..color = const Color(0xFFBFD4E6);
    final p1 = Path()
      ..moveTo(0, h)
      ..lineTo(w * .30, h * .34)
      ..lineTo(w * .60, h)
      ..close();
    canvas.drawPath(p1, far);
    // 主山
    final near = Paint()..color = const Color(0xFF9DBBD2);
    final p2 = Path()
      ..moveTo(w * .35, h)
      ..lineTo(w * .82, h * .16)
      ..lineTo(w * 1.15, h)
      ..close();
    canvas.drawPath(p2, near);
    // 山顶雪帽
    final snow = Paint()..color = Colors.white.withValues(alpha: .85);
    final cap = Path()
      ..moveTo(w * .82, h * .16)
      ..lineTo(w * .74, h * .30)
      ..lineTo(w * .78, h * .30)
      ..lineTo(w * .82, h * .24)
      ..lineTo(w * .86, h * .30)
      ..lineTo(w * .90, h * .30)
      ..close();
    canvas.drawPath(cap, snow);
    // 山路（虚线）
    final trail = <Offset>[for (final o in _trail) Offset(o.dx * w, o.dy * h)];
    final pathPaint = Paint()
      ..color = const Color(0xFF7D6A57).withValues(alpha: .6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final full = Path()..moveTo(trail.first.dx, trail.first.dy);
    for (var i = 1; i < trail.length; i++) {
      final prev = trail[i - 1], cur = trail[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      full.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      full.lineTo(cur.dx, cur.dy);
    }
    _dashed(canvas, full, pathPaint, 7, 6);
    // 里程碑小旗
    for (var i = 0; i < n && i < trail.length; i++) {
      _flag(canvas, trail[i], done[i].color);
    }
  }

  void _flag(Canvas canvas, Offset base, Color color) {
    final pole = Paint()
      ..color = const Color(0xFF6B5A48)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, base + const Offset(0, -20), pole);
    final flag = Path()
      ..moveTo(base.dx, base.dy - 20)
      ..lineTo(base.dx + 14, base.dy - 16)
      ..lineTo(base.dx, base.dy - 11)
      ..close();
    canvas.drawPath(flag, Paint()..color = color);
    canvas.drawCircle(
        base, 2.6, Paint()..color = const Color(0xFF6B5A48));
  }

  void _dashed(Canvas canvas, Path path, Paint paint, double on, double off) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + on), paint);
        d += on + off;
      }
    }
  }

  @override
  bool shouldRepaint(_SummitPainter old) => old.n != n;
}

/// ───────────────────────── C · 星愿罐 ─────────────────────────
class HeroJar extends StatefulWidget {
  const HeroJar({super.key, required this.done});
  final List<Wish> done;
  @override
  State<HeroJar> createState() => _HeroJarState();
}

class _HeroJarState extends State<HeroJar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.done.length.clamp(0, _spots.length);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2444), Color(0xFF101830)],
        ),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) =>
                CustomPaint(painter: _JarPainter(_c.value, n, widget.done)),
          ),
        ),
        _caption('$n 个心愿在发光', color: const Color(0xFFDDE6FF)),
      ]),
    );
  }
}

class _JarPainter extends CustomPainter {
  _JarPainter(this.t, this.n, this.done);
  final double t;
  final int n;
  final List<Wish> done;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final jarW = w * .42, jarH = h * .62;
    final left = (w - jarW) / 2, top = h * .12;
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, jarW, jarH), const Radius.circular(26));
    // 罐盖
    final lid = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + jarW * .18, top - 14, jarW * .64, 16),
        const Radius.circular(6));
    canvas.drawRRect(
        lid, Paint()..color = Colors.white.withValues(alpha: .35));
    // 罐身
    canvas.drawRRect(
        body, Paint()..color = Colors.white.withValues(alpha: .08));
    canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: .5));
    // 高光
    canvas.drawLine(
        Offset(left + 10, top + 16),
        Offset(left + 10, top + jarH - 28),
        Paint()
          ..color = Colors.white.withValues(alpha: .18)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
    // 萤火（完成的心愿）
    for (var i = 0; i < n; i++) {
      final bx = left + jarW * (.22 + .56 * _seededRand(i * 5));
      final bob = math.sin(t * 2 * math.pi + i) * 6;
      final by = top + jarH * (.30 + .55 * _seededRand(i * 5 + 1)) + bob;
      final col = done[i].color;
      canvas.drawCircle(
          Offset(bx, by),
          9,
          Paint()
            ..color = col.withValues(alpha: .5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      canvas.drawCircle(Offset(bx, by), 3.4,
          Paint()..color = Colors.white.withValues(alpha: .95));
    }
  }

  @override
  bool shouldRepaint(_JarPainter old) => old.t != t || old.n != n;
}

/// ───────────────────────── D · 记忆卡墙 ─────────────────────────
class HeroWall extends StatelessWidget {
  const HeroWall({super.key, required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    final n = done.length.clamp(0, _spots.length);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3EFE7), Color(0xFFEDE7F2)],
        ),
      ),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 40),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: done.length,
            separatorBuilder: (_, __) => const SizedBox(width: 2),
            itemBuilder: (_, i) => _polaroid(done[i], i),
          ),
        ),
        _caption('$n 段已实现的旅程', color: const Color(0xFF6A5F55)),
      ]),
    );
  }

  Widget _polaroid(Wish w, int i) {
    final tilt = (i.isEven ? -1 : 1) * (0.03 + (i % 3) * 0.015);
    return Center(
      child: Transform.rotate(
        angle: tilt,
        child: Container(
          width: 128,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      w.color,
                      Color.lerp(w.color, Colors.white, .4)!,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(height: 7),
              Text(w.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: T.ink)),
              if (w.quote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(w.quote!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: T.muted)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ═════════════ 高端/成就系列 ═════════════

/// ───────────────── E · 金色奖章陈列 ─────────────────
class HeroMedals extends StatelessWidget {
  const HeroMedals({super.key, required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    final n = done.length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.3),
          radius: 1.1,
          colors: [Color(0xFF1C2540), Color(0xFF0A0E1A)],
        ),
      ),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 42),
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 12,
              children: [for (var i = 0; i < n; i++) _medal(done[i], i)],
            ),
          ),
        ),
        _caption('$n 枚成就徽章', color: T.gold),
      ]),
    );
  }

  Widget _medal(Wish w, int i) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFFF7D98C), Color(0xFF8A6A2E), Color(0xFFFFF3CE),
            Color(0xFF8A6A2E), Color(0xFFF7D98C),
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: T.gold.withValues(alpha: .35),
              blurRadius: 14,
              spreadRadius: -2),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A3350), Color(0xFF161C2E)],
          ),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.star_rounded, color: T.gold, size: 26),
      ),
    );
  }
}

/// ───────────────── F · 年度报告大数据 ─────────────────
class HeroWrapped extends StatefulWidget {
  const HeroWrapped({super.key, required this.done, this.maxH = 280});
  final List<Wish> done;
  final double maxH;
  @override
  State<HeroWrapped> createState() => _HeroWrappedState();
}

class _HeroWrappedState extends State<HeroWrapped>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.done.length;
    final total = AppData.I.wishes.length;
    final frac = total == 0 ? 0.0 : n / total;
    return LayoutBuilder(builder: (context, cons) {
      final h = cons.maxHeight;
      final topInset = MediaQuery.paddingOf(context).top;
      // 展开→折叠 进度 t：1=展开 0=折叠
      final t = ((h / widget.maxH - 0.55) / 0.45).clamp(0.0, 1.0);
      // 展开时把内容压到刘海下方；折叠时可进入刘海区（挡住无妨）
      final pad = topInset * t;
      return ClipRect(
        child: Stack(children: [
          // 流动网格光晕背景（始终满宽满高、含刘海区）
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(painter: _MeshPainter(_c.value)),
            ),
          ),
          // 内容在「刘海下方~底部」区域内居中，原大小不缩字
          Positioned(
            top: pad,
            left: 0,
            right: 0,
            bottom: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 240,
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
                  Text('完成度 ${(frac * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .5,
                          color: Colors.white)),
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

/// ───────────────── G · 宇宙星球轨道 ─────────────────
class HeroOrbit extends StatefulWidget {
  const HeroOrbit({super.key, required this.done});
  final List<Wish> done;
  @override
  State<HeroOrbit> createState() => _HeroOrbitState();
}

class _HeroOrbitState extends State<HeroOrbit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))
        ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.done.length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [Color(0xFF241748), Color(0xFF08060F)],
        ),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) =>
                CustomPaint(painter: _OrbitPainter(_c.value, n, widget.done)),
          ),
        ),
        _caption('$n 颗心愿绕你而转', color: const Color(0xFFE7DBFF)),
      ]),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t, this.n, this.done);
  final double t;
  final int n;
  final List<Wish> done;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * .46);
    // 星尘
    for (var i = 0; i < 50; i++) {
      final x = _seededRand(i * 2) * size.width;
      final y = _seededRand(i * 2 + 1) * size.height;
      canvas.drawCircle(Offset(x, y), _seededRand(i) * 1.1 + .3,
          Paint()..color = Colors.white.withValues(alpha: .18));
    }
    // 核心光
    canvas.drawCircle(
        c,
        26,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0xFFFFF3CE), Color(0x00FFF3CE)])
              .createShader(Rect.fromCircle(center: c, radius: 26)));
    canvas.drawCircle(c, 9, Paint()..color = const Color(0xFFFFE9B0));
    // 轨道 + 行星
    final maxR = size.height * .40;
    for (var i = 0; i < n; i++) {
      final rr = maxR * (0.42 + 0.58 * ((i + 1) / n));
      canvas.drawOval(
          Rect.fromCenter(center: c, width: rr * 2, height: rr * 1.2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: .12));
      final ang = t * 2 * math.pi * (i.isEven ? 1 : -1) + i * 1.3;
      final p =
          Offset(c.dx + math.cos(ang) * rr, c.dy + math.sin(ang) * rr * .6);
      final col = done[i].color;
      canvas.drawCircle(
          p,
          10,
          Paint()
            ..color = col.withValues(alpha: .5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(p, 5, Paint()..color = col);
      canvas.drawCircle(p - const Offset(1.4, 1.4), 1.6,
          Paint()..color = Colors.white.withValues(alpha: .8));
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t || old.n != n;
}

/// ───────────────── H · 全息成就卡 ─────────────────
class HeroFoilCard extends StatefulWidget {
  const HeroFoilCard({super.key, required this.done});
  final List<Wish> done;
  @override
  State<HeroFoilCard> createState() => _HeroFoilCardState();
}

class _HeroFoilCardState extends State<HeroFoilCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.done.length;
    final total = AppData.I.wishes.length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF10131C), Color(0xFF1B2030)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: AspectRatio(
            aspectRatio: 1.6,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(
                painter: _FoilPainter(_c.value),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('人生成就',
                          style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const Spacer(),
                      Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                        Text('$n',
                            style: const TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.w800,
                                height: 1,
                                color: Colors.white)),
                        Text(' / $total 已实现',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: .85))),
                      ]),
                      const SizedBox(height: 4),
                      Text('RARE · 追梦者',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: Colors.white.withValues(alpha: .7))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoilPainter extends CustomPainter {
  _FoilPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    // 全息底
    final shift = t;
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-1 + shift * 2, -1),
            end: Alignment(1 + shift * 2, 1),
            colors: const [
              Color(0xFF6C8DFF), Color(0xFFB07BFF), Color(0xFFFF9ECB),
              Color(0xFF6FD6C4), Color(0xFF8DA6FF),
            ],
          ).createShader(rect));
    // 斜向高光扫过
    final glossX = (-.4 + t * 1.8) * size.width;
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
        Rect.fromLTWH(glossX, 0, size.width * .22, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.restore();
    // 描边
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: .5));
  }

  @override
  bool shouldRepaint(_FoilPainter old) => old.t != t;
}
