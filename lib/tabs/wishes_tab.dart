import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../data.dart';
import 'hero_variants.dart';
import '../pages/wish_pages.dart';
import '../sheets.dart';
import '../theme.dart';
import '../ui.dart';

class WishesTab extends StatelessWidget {
  const WishesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final active = AppData.I.activeWishes;
        final done = AppData.I.doneWishes;
        return Stack(
          children: [
            LayoutBuilder(builder: (context, cons) {
            // 黄金分割：主视觉 38.2%，心愿列表 61.8%；上划头部变小、下滑变大
            final treeH = cons.maxHeight * 0.382;
            return CustomScrollView(
              slivers: [
                if (done.isNotEmpty)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _HeroHeader(
                      child: _hero(done, treeH),
                      maxH: treeH,
                      minH: treeH * 0.8,
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(13, 16, 13, 10),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i == 0) {
                          return const Padding(
                            padding:
                                EdgeInsets.only(left: 4, right: 8, bottom: 8),
                            child: Text('不留遗憾，活成自己想要的样子',
                                style: TextStyle(
                                    fontSize: 15,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                    color: T.muted)),
                          );
                        }
                        final idx = i - 1;
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: idx == active.length - 1 ? 0 : 10),
                          child: _activeCard(context, active[idx]),
                        );
                      },
                      childCount: active.length + 1,
                    ),
                  ),
                ),
              ],
            );
            }),
            // 悬浮加号
            Positioned(
              top: topInset + 8,
              right: 13,
              child: PlusBtn(onTap: () => showNewWishSheet(context)),
            ),
          ],
        );
      },
    );
  }

  // 上半部分主视觉方案：
  // 0=星空 1=登顶 2=星愿罐 3=记忆卡墙 4=金色奖章 5=年度报告 6=宇宙轨道 7=全息卡
  static const int heroVariant = 5;
  Widget _hero(List<Wish> done, double maxH) {
    switch (heroVariant) {
      case 1:
        return HeroSummit(done: done);
      case 2:
        return HeroJar(done: done);
      case 3:
        return HeroWall(done: done);
      case 4:
        return HeroMedals(done: done);
      case 5:
        return HeroWrapped(done: done, maxH: maxH);
      case 6:
        return HeroOrbit(done: done);
      case 7:
        return HeroFoilCard(done: done);
      default:
        return HeroConstellation(done: done);
    }
  }

  // 独立白卡 + 左侧竖色条 + 加粗标题
  Widget _activeCard(BuildContext context, Wish w) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => WishDetailPage(wish: w))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: T.shadowCard,
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 24,
              decoration: BoxDecoration(
                color: w.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(w.title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: T.ink)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20, color: T.faint),
          ],
        ),
      ),
    );
  }
}

/// 可折叠头部：上划整体缩小、下滑放大（等比缩放，顶部对齐）
class _HeroHeader extends SliverPersistentHeaderDelegate {
  _HeroHeader({required this.child, required this.maxH, required this.minH});
  final Widget child;
  final double maxH;
  final double minH;

  @override
  double get maxExtent => maxH;
  @override
  double get minExtent => minH;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    // 背景通栏满宽，仅高度变化；内容缩放由 hero 内部按高度处理
    return ClipRect(child: SizedBox.expand(child: child));
  }

  @override
  bool shouldRebuild(_HeroHeader old) =>
      old.maxH != maxH || old.minH != minH || old.child != child;
}

/// 玻璃照片卡墙 —— 已完成心愿是一张张凭证卡片
class _DoneWall extends StatelessWidget {
  const _DoneWall({required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
          child: Row(
            children: [
              const Text('已实现的心愿',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${done.length}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: T.accent,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const Text(' 个已完成',
                  style: TextStyle(fontSize: 12.5, color: T.muted)),
            ],
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: done.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _card(context, done[i]),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, Wish w) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))),
      child: Container(
        width: 134,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: Colors.white.withValues(alpha: .7), width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1A243A66),
                blurRadius: 16,
                offset: Offset(0, 8)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: w.hero ?? AppData.heroes[0],
                ),
              ),
            ),
            // 底部遮罩
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [.45, 1],
                    colors: [Colors.transparent, Color(0xCC0C1327)],
                  ),
                ),
              ),
            ),
            // 右上角柔彩星标
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: T.plusGrad,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .8), width: 1.5),
                ),
                child: const Icon(Icons.check_rounded,
                    size: 15, color: Colors.white),
              ),
            ),
            // 底部文字
            Positioned(
              left: 11,
              right: 11,
              bottom: 11,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(ymDots(w.doneAt!),
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white.withValues(alpha: .75))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 柔彩成就环 —— 渐变圆环 + 完成数
class _DoneRing extends StatelessWidget {
  const _DoneRing({required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    final total = AppData.I.wishes.length;
    final frac = total == 0 ? 0.0 : done.length / total;
    return SheetCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(96, 96),
                  painter: _RingPainter(frac),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${done.length}',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: T.ink)),
                    Text('/ $total',
                        style: const TextStyle(
                            fontSize: 12, color: T.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('已实现的心愿',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('还有 ${total - done.length} 个等你点亮',
                    style: const TextStyle(fontSize: 13.5, color: T.muted)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final w in done.take(8))
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: w.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.frac);
  final double frac;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = const Color(0xFFE7E9F5));
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
        rect,
        -1.5708,
        6.2832 * frac,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
            colors: [Color(0xFF6C8DFF), Color(0xFFB07BFF), Color(0xFFFF9ECB), Color(0xFF6C8DFF)],
          ).createShader(rect));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.frac != frac;
}

/// 浅色星辰 —— 柔彩玻璃卡上的渐变星星连成星座
class _LightStars extends StatefulWidget {
  const _LightStars({required this.done});
  final List<Wish> done;
  @override
  State<_LightStars> createState() => _LightStarsState();
}

class _LightStarsState extends State<_LightStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 5))
    ..repeat();
  static const _pos = [
    Offset(.16, .58), Offset(.34, .40), Offset(.50, .60),
    Offset(.64, .38), Offset(.80, .56), Offset(.90, .34),
    Offset(.26, .78), Offset(.58, .80),
  ];
  static const _cols = [
    Color(0xFF6C8DFF), Color(0xFFB07BFF), Color(0xFFFF9ECB),
    Color(0xFF6FD6C4), Color(0xFF8DA6FF), Color(0xFFD79BFF),
    Color(0xFFFFB0D0), Color(0xFF7FC8FF),
  ];
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final n = widget.done.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .65), width: 1),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    painter: _LightPainter(_c.value, n.clamp(0, _pos.length)),
                  ),
                ),
              ),
              Positioned(
                left: 18, top: 16, right: 18,
                child: Row(
                  children: [
                    const Text('已点亮的心愿',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: T.ink)),
                    const Spacer(),
                    Text('$n',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
                    Text(' / ${AppData.I.wishes.length}',
                        style: const TextStyle(fontSize: 13, color: T.muted)),
                  ],
                ),
              ),
              for (var i = 0; i < n && i < _pos.length; i++)
                Align(
                  alignment: Alignment(_pos[i].dx * 2 - 1, _pos[i].dy * 2 - 1),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => DoneWishPage(wish: widget.done[i]))),
                    child: const SizedBox(width: 40, height: 40),
                  ),
                ),
              Positioned(
                left: 18, bottom: 14,
                child: Text('轻点星辰，回望那一刻',
                    style: TextStyle(fontSize: 11.5, color: T.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LightPainter extends CustomPainter {
  _LightPainter(this.t, this.n);
  final double t;
  final int n;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset at(Offset f) => Offset(f.dx * w, f.dy * h);
    final pts = [for (var i = 0; i < n && i < _LightStarsState._pos.length; i++) at(_LightStarsState._pos[i])];
    if (pts.length > 1) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = const Color(0xFF9BA6FF).withValues(alpha: .35));
    }
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final col = _LightStarsState._cols[i % _LightStarsState._cols.length];
      final tw = (t + i * .13) % 1.0;
      final glow = .55 + .45 * (0.5 - (tw - 0.5).abs()) * 2;
      final r = 3.0 + (i % 3) * .8;
      canvas.drawCircle(p, r + 8 * glow, Paint()..color = col.withValues(alpha: .22 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      final rayLen = (9 + (i % 3) * 2) * glow;
      final rayP = Paint()..color = col.withValues(alpha: .6 * glow)..strokeWidth = 1.2..strokeCap = StrokeCap.round;
      canvas.drawLine(p + Offset(0, -rayLen), p + Offset(0, rayLen), rayP);
      canvas.drawLine(p + Offset(-rayLen, 0), p + Offset(rayLen, 0), rayP);
      canvas.drawCircle(p, r, Paint()..color = col);
      canvas.drawCircle(p, r * .5, Paint()..color = Colors.white);
    }
  }
  @override
  bool shouldRepaint(_LightPainter old) => old.t != t || old.n != n;
}

/// 照片马赛克 —— 已完成心愿的凭证照片拼成方格墙
class _PhotoMosaic extends StatelessWidget {
  const _PhotoMosaic({required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    return SheetCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('已实现的心愿',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${done.length}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
              const Text(' 个', style: TextStyle(fontSize: 12.5, color: T.muted)),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 1,
            ),
            itemCount: done.length,
            itemBuilder: (context, i) {
              final w = done[i];
              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .7), width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Color(0x14243A66), blurRadius: 10, offset: Offset(0, 5)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: w.hero ?? AppData.heroes[0],
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [.5, 1],
                              colors: [Colors.transparent, Color(0xB30C1327)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 7, right: 7, bottom: 7,
                        child: Text(w.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                height: 1.2, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 柔彩奖章横排 —— 每个完成心愿是一枚发光徽章
class _Medals extends StatelessWidget {
  const _Medals({required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    return SheetCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('已实现的心愿',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${done.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
            const Text(' 枚勋章', style: TextStyle(fontSize: 12.5, color: T.muted)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: done.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final w = done[i];
                final c = w.color;
                return GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [
                                Color.lerp(c, Colors.white, .35)!,
                                Color.lerp(c, const Color(0xFF3A5CE0), .35)!,
                              ],
                            ),
                            border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2.5),
                            boxShadow: [
                              BoxShadow(color: c.withValues(alpha: .5), blurRadius: 12, spreadRadius: -1, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded, size: 26, color: Colors.white),
                        ),
                        const SizedBox(height: 7),
                        Text(w.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10.5, height: 1.2, color: T.muted)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 竖向时间线 —— 完成心愿沿时间轴排列
class _Timeline extends StatelessWidget {
  const _Timeline({required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    return SheetCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('走过的路',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${done.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
            const Text(' 个里程碑', style: TextStyle(fontSize: 12.5, color: T.muted)),
          ]),
          const SizedBox(height: 6),
          for (var i = 0; i < done.length; i++) _node(context, done[i], i == done.length - 1),
        ],
      ),
    );
  }

  Widget _node(BuildContext context, Wish w, bool last) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))),
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 13, height: 13,
                  decoration: BoxDecoration(
                    color: w.color, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: w.color.withValues(alpha: .5), blurRadius: 6)],
                  ),
                ),
                if (!last)
                  Expanded(child: Container(width: 2, color: const Color(0xFFE2E5F0))),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 10, bottom: last ? 6 : 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text('${ymDots(w.doneAt!)}  「${w.quote}」',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: T.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: w.hero ?? AppData.heroes[0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 荣誉大卡 —— 每个完成的心愿都珍贵、酷炫、大气地展示
class _TrophyCards extends StatefulWidget {
  const _TrophyCards({required this.done});
  final List<Wish> done;
  @override
  State<_TrophyCards> createState() => _TrophyCardsState();
}

class _TrophyCardsState extends State<_TrophyCards>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(children: [
            const Text('我实现过的心愿',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${widget.done.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
            const Text(' 个珍贵时刻', style: TextStyle(fontSize: 12.5, color: T.muted)),
          ]),
        ),
        SizedBox(
          height: 222,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            clipBehavior: Clip.none,
            itemCount: widget.done.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => SizedBox(
              width: 288,
              child: _card(context, widget.done[i], i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, Wish w, int idx) {
    final no = AppData.I.doneNumberOf(w);
    final c = w.color;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))),
      child: Container(
        // 珠光描边
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .9),
              c.withValues(alpha: .5),
              Colors.white.withValues(alpha: .85),
              const Color(0xFFB07BFF).withValues(alpha: .4),
              Colors.white.withValues(alpha: .9),
            ],
            stops: const [0, .28, .5, .74, 1],
          ),
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: .35), blurRadius: 22, spreadRadius: -4, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21.5),
          child: SizedBox(
            height: 208,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 凭证照片
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: w.hero ?? AppData.heroes[0],
                    ),
                  ),
                ),
                // 遮罩
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        stops: [.3, 1],
                        colors: [Colors.transparent, Color(0xDD0B1020)],
                      ),
                    ),
                  ),
                ),
                // 流光
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) {
                        final v = (_c.value + idx * .22) % 1.0;
                        final x = v * 2.4 - .7;
                        return Align(
                          alignment: Alignment(x * 2 - 1, 0),
                          child: Transform.rotate(
                            angle: .35,
                            child: Container(
                              width: 60, height: 400,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: .12),
                                  Colors.white.withValues(alpha: 0),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // 顶部角标
                Positioned(
                  top: 13, left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: .35)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('✦', style: TextStyle(fontSize: 11, color: Colors.white,
                          shadows: [Shadow(color: Colors.white, blurRadius: 8)])),
                      const SizedBox(width: 5),
                      Text('第 $no 个心愿',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ]),
                  ),
                ),
                // 底部文字
                Positioned(
                  left: 16, right: 16, bottom: 15,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('「${w.quote}」',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .9))),
                      const SizedBox(height: 6),
                      Text([if (w.location != null) w.location!, ymdDots(w.doneAt!)].join(' · '),
                          style: TextStyle(fontSize: 10.5, letterSpacing: .5, color: Colors.white.withValues(alpha: .65))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 叠层卡牌堆 —— 已完成心愿像一叠珍藏卡牌
class _StackDeck extends StatelessWidget {
  const _StackDeck({required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    final show = done.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(children: [
            const Text('我的珍藏',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${done.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
            const Text(' 个珍贵时刻', style: TextStyle(fontSize: 12.5, color: T.muted)),
          ]),
        ),
        SizedBox(
          height: 230,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              for (var i = show.length - 1; i >= 0; i--)
                Positioned(
                  top: i * 14.0,
                  left: 10 + i * 4.0,
                  right: 10 + i * 4.0,
                  child: Transform.rotate(
                    angle: (i == 0 ? 0 : (i.isEven ? 1 : -1) * .018 * i),
                    child: Opacity(
                      opacity: i == 0 ? 1 : .96,
                      child: _card(context, show[i], i == 0),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => DoneWishPage(wish: done.first))),
            child: Text('翻看全部 ${done.length} 个 ›',
                style: const TextStyle(fontSize: 13, color: T.accent, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, Wish w, bool top) {
    final no = AppData.I.doneNumberOf(w);
    final c = w.color;
    return GestureDetector(
      onTap: top ? () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))) : null,
      child: Container(
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Colors.white.withValues(alpha: .9), c.withValues(alpha: .5), Colors.white.withValues(alpha: .85)],
          ),
          boxShadow: [BoxShadow(color: c.withValues(alpha: .3), blurRadius: 18, spreadRadius: -4, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21.5),
          child: SizedBox(
            height: 176,
            child: Stack(fit: StackFit.expand, children: [
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight, colors: w.hero ?? AppData.heroes[0]))),
              const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.35, 1],
                colors: [Colors.transparent, Color(0xDD0B1020)])))),
              Positioned(top: 12, left: 13, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: .35))),
                child: Text('✦ 第 $no 个', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white)),
              )),
              Positioned(left: 15, right: 15, bottom: 14, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 5),
                  Text('「${w.quote}」  ${ymDots(w.doneAt!)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .82))),
                ])),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 相册主图 + 胶片条 —— 大图聚焦 + 下方缩略切换
class _Gallery extends StatefulWidget {
  const _Gallery({required this.done});
  final List<Wish> done;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _sel = 0;
  @override
  Widget build(BuildContext context) {
    final w = widget.done[_sel];
    final no = AppData.I.doneNumberOf(w);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(children: [
            const Text('我实现过的心愿',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${widget.done.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
            const Text(' 个珍贵时刻', style: TextStyle(fontSize: 12.5, color: T.muted)),
          ]),
        ),
        // 主图
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))),
          child: Container(
            padding: const EdgeInsets.all(1.6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: .9), w.color.withValues(alpha: .5), Colors.white.withValues(alpha: .85)]),
              boxShadow: [BoxShadow(color: w.color.withValues(alpha: .35), blurRadius: 22, spreadRadius: -4, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.5),
              child: SizedBox(height: 190, child: Stack(fit: StackFit.expand, children: [
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight, colors: w.hero ?? AppData.heroes[0]))),
                const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.35, 1],
                  colors: [Colors.transparent, Color(0xDD0B1020)])))),
                Positioned(top: 12, left: 13, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: .35))),
                  child: Text('✦ 第 $no 个心愿', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white)),
                )),
                Positioned(left: 15, right: 15, bottom: 14, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 5),
                  Text('「${w.quote}」  ${ymDots(w.doneAt!)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .82))),
                ])),
              ])),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 胶片缩略条
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.done.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final d = widget.done[i];
              final on = i == _sel;
              return GestureDetector(
                onTap: () => setState(() => _sel = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: d.hero ?? AppData.heroes[0]),
                    border: Border.all(color: on ? T.accent : Colors.white.withValues(alpha: .7), width: on ? 2.5 : 1.5),
                    boxShadow: on ? [BoxShadow(color: T.accent.withValues(alpha: .4), blurRadius: 8)] : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 门票存根风 —— 每个心愿是一张纪念门票
class _Tickets extends StatelessWidget {
  const _Tickets({required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(children: [
            const Text('我的纪念票根',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${done.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
            const Text(' 张', style: TextStyle(fontSize: 12.5, color: T.muted)),
          ]),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: done.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => _ticket(context, done[i]),
          ),
        ),
      ],
    );
  }

  Widget _ticket(BuildContext context, Wish w) {
    final no = AppData.I.doneNumberOf(w);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))),
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: w.color.withValues(alpha: .3), blurRadius: 16, spreadRadius: -3, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          // 左：照片
          SizedBox(
            width: 130,
            child: Stack(fit: StackFit.expand, children: [
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight, colors: w.hero ?? AppData.heroes[0]))),
              const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.4, 1],
                colors: [Colors.transparent, Color(0x99000000)])))),
              Positioned(left: 11, bottom: 11, right: 8, child: Text(w.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2, color: Colors.white))),
            ]),
          ),
          // 齿孔分隔
          _perforation(),
          // 右：存根
          Expanded(
            child: Container(
              color: Colors.white.withValues(alpha: .82),
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.verified_rounded, size: 15, color: w.color),
                    const SizedBox(width: 5),
                    Text('已达成', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: w.color)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('「${w.quote}」', maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.5, color: T.ink)),
                    const SizedBox(height: 8),
                    Text('NO.${no.toString().padLeft(3, '0')}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: T.accent, fontFeatures: [FontFeature.tabularFigures()])),
                    Text(ymdDots(w.doneAt!),
                        style: const TextStyle(fontSize: 10, color: T.muted, fontFeatures: [FontFeature.tabularFigures()])),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _perforation() {
    return Container(
      width: 16,
      color: Colors.white.withValues(alpha: .82),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < 7; i++)
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: Color(0xFFE8EBF6), shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

/// 全息收藏卡 —— 彩虹全息膜 + 流动反光，像球星卡
class _HoloCards extends StatefulWidget {
  const _HoloCards({required this.done});
  final List<Wish> done;
  @override
  State<_HoloCards> createState() => _HoloCardsState();
}

class _HoloCardsState extends State<_HoloCards>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 4))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(children: [
            const Text('我的收藏卡',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${widget.done.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
            const Text(' 张珍藏', style: TextStyle(fontSize: 12.5, color: T.muted)),
          ]),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: widget.done.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => _holo(context, widget.done[i], i),
          ),
        ),
      ],
    );
  }

  Widget _holo(BuildContext context, Wish w, int idx) {
    final no = AppData.I.doneNumberOf(w);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))),
      child: Container(
        width: 156,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: w.color.withValues(alpha: .4), blurRadius: 20, spreadRadius: -3, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: w.hero ?? AppData.heroes[0]))),
          const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.4, 1],
            colors: [Colors.transparent, Color(0xDD0B1020)])))),
          // 全息膜流光
          Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = (_c.value + idx * .2) % 1.0;
              return DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + v * 2, -1), end: Alignment(v * 2, 1),
                  colors: [
                    const Color(0xFF6CC6FF).withValues(alpha: .28),
                    const Color(0xFFB07BFF).withValues(alpha: .22),
                    const Color(0xFFFF9ECB).withValues(alpha: .24),
                    const Color(0xFF7BFFD6).withValues(alpha: .20),
                  ],
                  stops: const [0, .35, .65, 1],
                ),
                backgroundBlendMode: BlendMode.screen,
              ));
            },
          ))),
          // 角标
          Positioned(top: 10, left: 10, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: .4))),
            child: Text('✦ $no', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
          )),
          Positioned(left: 12, right: 12, bottom: 13, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.2, color: Colors.white)),
            const SizedBox(height: 4),
            Text(ymDots(w.doneAt!), style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: .7))),
          ])),
        ]),
      ),
    );
  }
}

/// 宇宙主题 —— 你是核心，每个完成心愿是一颗环绕的星球
class _Cosmos extends StatefulWidget {
  const _Cosmos({required this.done});
  final List<Wish> done;
  @override
  State<_Cosmos> createState() => _CosmosState();
}

class _CosmosState extends State<_Cosmos> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 40))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final n = widget.done.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
        height: 230,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .5),
          border: Border.all(color: Colors.white.withValues(alpha: .65), width: 1),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: AnimatedBuilder(animation: _c,
              builder: (context, _) => CustomPaint(painter: _CosmosPainter(_c.value, n, widget.done)))),
            Positioned(left: 18, top: 16, right: 18, child: Row(children: [
              const Text('我的宇宙', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: T.ink)),
              const Spacer(),
              Text('$n', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
              const Text(' 颗星球', style: TextStyle(fontSize: 12, color: T.muted)),
            ])),
            // 可点星球（固定角度）
            for (var i = 0; i < n; i++)
              Builder(builder: (context) {
                final ang = i / n * 6.2832 - 1.5708;
                final rx = 0.36, ry = 0.26;
                return Align(
                  alignment: Alignment(math.cos(ang) * rx * 2, math.sin(ang) * ry * 2 + .08),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => DoneWishPage(wish: widget.done[i]))),
                    child: const SizedBox(width: 44, height: 44),
                  ),
                );
              }),
          ],
        ),
      ),
    ));
  }
}

class _CosmosPainter extends CustomPainter {
  _CosmosPainter(this.t, this.n, this.done);
  final double t; final int n; final List<Wish> done;
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2 + size.height * .04;
    final center = Offset(cx, cy);
    final rx = size.width * .36, ry = size.height * .26;
    // 轨道椭圆（淡）
    canvas.drawOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0xFFAEB8E0).withValues(alpha: .5));
    // 中心核心（你）
    canvas.drawCircle(center, 22, Paint()
      ..color = const Color(0xFF8FA6FF).withValues(alpha: .22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    final coreGrad = const RadialGradient(center: Alignment(-.3,-.3), colors: [Color(0xFFEAF0FF), Color(0xFF8FA6FF)]);
    canvas.drawCircle(center, 13, Paint()..shader = coreGrad.createShader(Rect.fromCircle(center: center, radius: 13)));
    canvas.drawCircle(center, 13, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withValues(alpha: .8));
    // 星球（简约）
    for (var i = 0; i < n; i++) {
      final ang = i / n * 6.2832 - 1.5708;
      final p = center + Offset(math.cos(ang) * rx, math.sin(ang) * ry);
      final col = done[i].color;
      final tw = (t * 6 + i * .2) % 1.0;
      final glow = .5 + .5 * (0.5 - (tw - 0.5).abs()) * 2;
      canvas.drawCircle(p, 11 + 3 * glow, Paint()..color = col.withValues(alpha: .3 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      final g = RadialGradient(center: const Alignment(-.4, -.4), colors: [Color.lerp(col, Colors.white, .55)!, col]);
      canvas.drawCircle(p, 9, Paint()..shader = g.createShader(Rect.fromCircle(center: p, radius: 9)));
      canvas.drawCircle(p, 9, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Colors.white.withValues(alpha: .85));
    }
  }
  @override
  bool shouldRepaint(_CosmosPainter old) => old.t != t;
}

/// 大海主题 —— 浅色玻璃海面，完成心愿是海上的柔彩浮灯
class _Ocean extends StatefulWidget {
  const _Ocean({required this.done});
  final List<Wish> done;
  @override
  State<_Ocean> createState() => _OceanState();
}

class _OceanState extends State<_Ocean> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final n = widget.done.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .5),
            border: Border.all(color: Colors.white.withValues(alpha: .65), width: 1),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(children: [
            Positioned.fill(child: AnimatedBuilder(animation: _c,
              builder: (context, _) => CustomPaint(painter: _OceanPainter(_c.value, n, widget.done)))),
            Positioned(left: 18, top: 16, right: 18, child: Row(children: [
              const Text('心愿之海', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: T.ink)),
              const Spacer(),
              Text('$n', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.accent)),
              const Text(' 盏已点亮', style: TextStyle(fontSize: 12, color: T.muted)),
            ])),
            // 可点浮灯
            for (var i = 0; i < n; i++)
              Builder(builder: (context) {
                final fx = (i + .5) / n;
                return Align(
                  alignment: Alignment(fx * 2 - 1, -.05),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => DoneWishPage(wish: widget.done[i]))),
                    child: const SizedBox(width: 44, height: 60),
                  ),
                );
              }),
          ]),
        ),
      ),
    );
  }
}

class _OceanPainter extends CustomPainter {
  _OceanPainter(this.t, this.n, this.done);
  final double t; final int n; final List<Wish> done;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final waterTop = h * .56;
    // 三层波浪
    void wave(double baseY, Color c, double amp, double phase, double len) {
      final path = Path()..moveTo(0, baseY);
      for (double x = 0; x <= w; x += 6) {
        path.lineTo(x, baseY + math.sin((x / len) + t * 2 * math.pi + phase) * amp);
      }
      path..lineTo(w, h)..lineTo(0, h)..close();
      canvas.drawPath(path, Paint()..color = c);
    }
    wave(waterTop + 14, const Color(0xFFBFD4FF).withValues(alpha: .5), 5, 0, 30);
    wave(waterTop + 24, const Color(0xFFA9C6FF).withValues(alpha: .5), 6, 1.5, 34);
    wave(waterTop + 36, const Color(0xFF93B4F5).withValues(alpha: .55), 5, 3, 28);
    // 浮灯
    for (var i = 0; i < n; i++) {
      final fx = (i + .5) / n;
      final bob = math.sin(t * 2 * math.pi + i * .8) * 4;
      final p = Offset(w * fx, waterTop - 6 + bob);
      final col = done[i].color;
      final tw = (t * 3 + i * .2) % 1.0;
      final glow = .55 + .45 * (0.5 - (tw - 0.5).abs()) * 2;
      // 水中倒影
      canvas.drawCircle(Offset(p.dx, waterTop + 14), 7, Paint()..color = col.withValues(alpha: .18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      // 光晕
      canvas.drawCircle(p, 12 + 4 * glow, Paint()..color = col.withValues(alpha: .3 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      // 灯珠
      final g = RadialGradient(center: const Alignment(-.3,-.4), colors: [Color.lerp(col, Colors.white, .55)!, col]);
      canvas.drawCircle(p, 8, Paint()..shader = g.createShader(Rect.fromCircle(center: p, radius: 8)));
      canvas.drawCircle(p, 8, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Colors.white.withValues(alpha: .85));
    }
  }
  @override
  bool shouldRepaint(_OceanPainter old) => old.t != t;
}

/// 简笔画大树 —— 完成心愿是枝头的柔彩果实
class _Tree extends StatefulWidget {
  const _Tree({required this.done});
  final List<Wish> done;
  @override
  State<_Tree> createState() => _TreeState();
}

class _TreeState extends State<_Tree> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 5))..repeat();
  // 果实挂点（分数坐标，落在蜡笔树冠里；画布 840×900，顶部留白）
  static const _fruit = [
    Offset(.512, .350), Offset(.327, .444), Offset(.446, .556),
    Offset(.649, .533), Offset(.286, .561), Offset(.673, .400),
  ];

  Timer? _cycle;
  int _focus = 0;

  @override
  void initState() {
    super.initState();
    final n = widget.done.length;
    if (n > 0) {
      _cycle = Timer.periodic(const Duration(milliseconds: 3800), (_) {
        if (mounted) setState(() => _focus = (_focus + 1) % n);
      });
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.done.length;
    final fi = n == 0 ? 0 : _focus % n;
    // 满铺插画：到顶、到边、无框；果实坐标与图片对齐
    return AspectRatio(
      aspectRatio: 840 / 900,
      child: LayoutBuilder(builder: (context, cons) {
        final w = cons.maxWidth, h = cons.maxHeight;
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Image.asset('assets/img/tree.png', fit: BoxFit.cover),
          ),
          Positioned.fill(child: AnimatedBuilder(animation: _c,
              builder: (context, _) => CustomPaint(
                  painter: _TreePainter(_c.value, n, widget.done)))),
          // 可点果实
          for (var i = 0; i < n && i < _fruit.length; i++)
            Align(
              alignment: Alignment(_fruit[i].dx * 2 - 1, _fruit[i].dy * 2 - 1),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => DoneWishPage(wish: widget.done[i]))),
                child: const SizedBox(width: 44, height: 44),
              ),
            ),
          // 循环弹出心愿气泡 —— 一次一个，轮流从果实上冒出
          if (n > 0 && fi < _fruit.length)
            Positioned(
              left: (_fruit[fi].dx * w - 88).clamp(6.0, w - 176),
              top: (_fruit[fi].dy * h - 60).clamp(2.0, h - 40),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                      scale: Tween(begin: .5, end: 1.0).animate(anim),
                      alignment: Alignment.bottomCenter,
                      child: child),
                ),
                child: _bubble(widget.done[fi], key: ValueKey(fi)),
              ),
            ),
        ]);
      }),
    );
  }

  // 心愿气泡（白色圆角 + 颜色点 + 标题 + 向下小尾巴）
  Widget _bubble(Wish w, {required Key key}) {
    return Column(key: key, mainAxisSize: MainAxisSize.min, children: [
      Container(
        constraints: const BoxConstraints(maxWidth: 176),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(color: w.color.withValues(alpha: .35), blurRadius: 13, spreadRadius: -2),
            const BoxShadow(color: Color(0x1A243A66), blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: w.color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.ink)),
          ),
        ]),
      ),
      Transform.translate(
        offset: const Offset(0, -1),
        child: CustomPaint(size: const Size(16, 8), painter: _BubbleTail(Colors.white.withValues(alpha: .95))),
      ),
    ]);
  }
}

class _BubbleTail extends CustomPainter {
  _BubbleTail(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_BubbleTail old) => old.color != color;
}

class _TreePainter extends CustomPainter {
  _TreePainter(this.t, this.n, this.done);
  final double t; final int n; final List<Wish> done;

  // 手抖圆（蜡笔手绘感的封闭路径）
  Path _wob(Offset c, double r, double amp, double ph) {
    final p = Path();
    const seg = 24;
    for (var i = 0; i <= seg; i++) {
      final a = i / seg * 2 * math.pi;
      final rr = r + amp * math.sin(a * 3 + ph) + amp * .5 * math.sin(a * 7 + ph * 1.7);
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) { p.moveTo(pt.dx, pt.dy); } else { p.lineTo(pt.dx, pt.dy); }
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset m(double fx, double fy) => Offset(w * fx, h * fy);
    final u = w / 840; // 随画布等比缩放（画布 840 宽）

    _sun(canvas, w, h);

    // 果实（手绘蜡笔感：实心 + 手抖轮廓 + 白点高光，静止不动）
    for (var i = 0; i < n && i < _TreeState._fruit.length; i++) {
      final f = _TreeState._fruit[i];
      final p = m(f.dx, f.dy);
      final col = done[i].color;
      final r = 14.5 * u;
      final ph = i * 1.7;
      final outline = Color.lerp(col, const Color(0xFF3A2E1E), .42)!;
      // 柔影
      canvas.drawCircle(p + Offset(0, r * .22), r * .98,
          Paint()..color = const Color(0x1F000000)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .45));
      // 实心
      canvas.drawPath(_wob(p, r, r * .07, ph), Paint()..color = col);
      // 手绘轮廓
      canvas.drawPath(_wob(p, r, r * .07, ph),
          Paint()..style = PaintingStyle.stroke..strokeWidth = 2.6 * u..color = outline..strokeJoin = StrokeJoin.round);
      // 蜡笔高光
      canvas.drawCircle(p + Offset(-r * .32, -r * .34), r * .17,
          Paint()..color = Colors.white.withValues(alpha: .8));
    }
  }

  // 丑萌太阳：歪脸、腮红、咧嘴，眼珠会转、会眨眼
  void _sun(Canvas canvas, double w, double h) {
    final cx = w * .133, cy = h * .245, R = w * .058;
    final center = Offset(cx, cy);
    const yellow = Color(0xFFFFD21E), orange = Color(0xFFF2A400), ink = Color(0xFF6B4E00);

    // 光芒（长短不一）
    final ray = Paint()..color = orange..strokeWidth = R * .16..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * 2 * math.pi + .25;
      final r1 = R * 1.16, r2 = R * (1.5 + .14 * math.sin(i * 2.3));
      canvas.drawLine(center + Offset(math.cos(a) * r1, math.sin(a) * r1),
          center + Offset(math.cos(a) * r2, math.sin(a) * r2), ray);
    }
    // 身体（手抖圆）
    canvas.drawPath(_wob(center, R, R * .05, 1.3), Paint()..color = yellow);
    canvas.drawPath(_wob(center, R, R * .05, 1.3),
        Paint()..style = PaintingStyle.stroke..strokeWidth = R * .13..color = orange..strokeJoin = StrokeJoin.round);
    // 腮红
    final blush = Paint()..color = const Color(0xFFF2909A).withValues(alpha: .5);
    canvas.drawCircle(center + Offset(-R * .54, R * .30), R * .16, blush);
    canvas.drawCircle(center + Offset(R * .54, R * .30), R * .16, blush);
    // 眼睛（左大右小，会转眼珠，偶尔眨眼）
    final lEye = center + Offset(-R * .34, -R * .10);
    final rEye = center + Offset(R * .36, -R * .06);
    final blink = (t % 1.0) < .035; // 每约 5 秒眨一次
    final orbit = R * .12;
    final po = Offset(math.cos(t * 2 * math.pi) * orbit, math.sin(t * 2 * math.pi * 2) * orbit * .55);
    void eye(Offset e, double er) {
      if (blink) {
        canvas.drawArc(Rect.fromCircle(center: e, radius: er), .12 * math.pi, .76 * math.pi, false,
            Paint()..style = PaintingStyle.stroke..strokeWidth = R * .09..color = ink..strokeCap = StrokeCap.round);
      } else {
        canvas.drawCircle(e, er, Paint()..color = Colors.white);
        canvas.drawCircle(e, er, Paint()..style = PaintingStyle.stroke..strokeWidth = R * .055..color = ink.withValues(alpha: .4));
        canvas.drawCircle(e + po, er * .5, Paint()..color = ink);
        canvas.drawCircle(e + po + Offset(-er * .16, -er * .16), er * .17, Paint()..color = Colors.white);
      }
    }
    eye(lEye, R * .30); // 左眼大
    eye(rEye, R * .24); // 右眼小
    // 嘴（歪咧笑）
    final mouth = Path()
      ..moveTo(cx - R * .30, cy + R * .34)
      ..quadraticBezierTo(cx + R * .02, cy + R * .70, cx + R * .36, cy + R * .30);
    canvas.drawPath(mouth,
        Paint()..style = PaintingStyle.stroke..strokeWidth = R * .1..color = ink..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_TreePainter old) => old.t != t;
}

/// 编辑杂志式 —— 讲究排版的成就呈现
class _Editorial extends StatelessWidget {
  const _Editorial({required this.done});
  final List<Wish> done;
  @override
  Widget build(BuildContext context) {
    final latest = done.first;
    final rest = done.skip(1).toList();
    final total = AppData.I.wishes.length;
    return SheetCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 大标题区：超大数字对比
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$total', style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: T.faint,
                  fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 2),
              const Padding(padding: EdgeInsets.only(top: 1),
                child: Text('中', style: TextStyle(fontSize: 11, color: T.faint))),
              const Spacer(),
              const Text('MILESTONES', style: TextStyle(fontFamily: 'MiSans',
                  fontSize: 10.5, letterSpacing: 3, fontWeight: FontWeight.w600, color: T.faint)),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${done.length}', style: const TextStyle(
                  fontSize: 62, fontWeight: FontWeight.w800, height: .95,
                  letterSpacing: -3, color: T.ink,
                  fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
                  Text('个心愿', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2)),
                  Text('已被实现', style: TextStyle(fontSize: 13, color: T.muted)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: T.line),
          const SizedBox(height: 16),
          // 最新一张 —— 海报级主图
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => DoneWishPage(wish: latest))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(height: 172, child: Stack(fit: StackFit.expand, children: [
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight, colors: latest.hero ?? AppData.heroes[0]))),
                const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.35, 1],
                  colors: [Colors.transparent, Color(0xE60B1020)])))),
                Positioned(top: 13, left: 14, child: Row(children: [
                  Text('LATEST', style: TextStyle(fontFamily: 'MiSans', fontSize: 9.5, letterSpacing: 2.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .9))),
                  const SizedBox(width: 7),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: latest.color, shape: BoxShape.circle)),
                ])),
                Positioned(left: 16, right: 16, bottom: 15, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(latest.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -.3)),
                  const SizedBox(height: 5),
                  Text('「${latest.quote}」', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: .88))),
                  const SizedBox(height: 4),
                  Text('${latest.location ?? ''}  ${ymdDots(latest.doneAt!)}',
                      style: TextStyle(fontFamily: 'MiSans', fontSize: 10, letterSpacing: 1, color: Colors.white.withValues(alpha: .6))),
                ])),
              ])),
            ),
          ),
          const SizedBox(height: 18),
          // 其余 —— 精致编号列表
          for (var i = 0; i < rest.length; i++) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => DoneWishPage(wish: rest[i]))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text(AppData.I.doneNumberOf(rest[i]).toString().padLeft(2, '0'),
                      style: const TextStyle(fontFamily: 'MiSans', fontSize: 13, fontWeight: FontWeight.w700, color: T.accent, letterSpacing: .5)),
                  const SizedBox(width: 16),
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: rest[i].color, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(rest[i].title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                  Text(ymDots(rest[i].doneAt!),
                      style: const TextStyle(fontFamily: 'MiSans', fontSize: 11.5, color: T.faint, fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
            ),
            if (i < rest.length - 1) const Divider(height: 1, thickness: 1, color: T.line),
          ],
        ],
      ),
    );
  }
}

/// 闯关地图 —— 心愿是关卡，已完成点亮、未完成待挑战
class _LevelMap extends StatefulWidget {
  const _LevelMap({required this.done, required this.active});
  final List<Wish> done;
  final List<Wish> active;
  @override
  State<_LevelMap> createState() => _LevelMapState();
}

class _LevelMapState extends State<_LevelMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // 从上到下：待挑战（未完成，倒序让最近的在下）→ 已完成（最新在上）
    final nodes = <_Node>[
      for (final w in widget.active.reversed) _Node(w, false),
      for (final w in widget.done) _Node(w, true),
    ];
    final total = widget.done.length + widget.active.length;
    final youIdx = widget.active.length; // 角色位置：完成与未完成交界
    const spacing = 96.0;
    final mapH = nodes.length * spacing + 40;

    return CustomScrollView(
      slivers: [
        // 顶部 HUD
        SliverToBoxAdapter(child: _hud()),
        SliverToBoxAdapter(child: const SizedBox(height: 14)),
        // 关卡地图
        SliverToBoxAdapter(
          child: LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth;
            final cx = w / 2;
            const amp = 88.0;
            Offset posOf(int i) => Offset(
                cx + math.sin(i * .9) * amp, 30 + i * spacing);
            return SizedBox(
              height: mapH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 路径 + 云
                  Positioned.fill(child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => CustomPaint(
                      painter: _PathPainter(nodes, posOf, widget.done.length, widget.active.length)),
                  )),
                  // 节点
                  for (var i = 0; i < nodes.length; i++)
                    _levelNode(context, nodes[i], posOf(i), total - i),
                  // 角色「你在这里」
                  if (youIdx < nodes.length || nodes.isNotEmpty)
                    _you(posOf(youIdx.clamp(0, nodes.length))),
                ],
              ),
            );
          }),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  Widget _hud() {
    final done = widget.done.length;
    final total = done + widget.active.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1),
          ),
          child: Row(children: [
            // 等级徽章
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: T.plusGrad, shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2),
                boxShadow: [BoxShadow(color: T.accent.withValues(alpha: .5), blurRadius: 10)],
              ),
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('LV', style: TextStyle(fontFamily: 'MiSans', fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, height: 1)),
                Text('$done', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
              ]),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('心愿冒险', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE2E5F2),
                  valueColor: const AlwaysStoppedAnimation(T.accent),
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$done/$total', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T.accent)),
              const Text('已点亮', style: TextStyle(fontSize: 11, color: T.muted)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _levelNode(BuildContext context, _Node n, Offset p, int levelNo) {
    final done = n.done;
    final c = n.wish.color;
    final labelLeft = p.dx > 180;
    return Positioned(
      left: p.dx - 90,
      top: p.dy - 30,
      width: 180,
      height: 60,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => done ? DoneWishPage(wish: n.wish) : WishDetailPage(wish: n.wish))),
        child: Stack(clipBehavior: Clip.none, children: [
          // 标题小牌
          Positioned(
            top: 16,
            left: labelLeft ? null : 66,
            right: labelLeft ? 66 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: done ? .85 : .5),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white.withValues(alpha: .7)),
              ),
              child: Text(n.wish.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: done ? T.ink : T.muted)),
            ),
          ),
          // 关卡圆
          Positioned(
            left: 62, top: 2,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final glow = done ? .6 + .4 * (0.5 - ((_c.value + levelNo * .1) % 1 - .5).abs()) * 2 : 0.0;
                return Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: done
                        ? RadialGradient(center: const Alignment(-.3, -.3),
                            colors: [Color.lerp(c, Colors.white, .5)!, c])
                        : null,
                    color: done ? null : const Color(0xFFDDE1F0),
                    border: Border.all(color: Colors.white.withValues(alpha: .9), width: 3),
                    boxShadow: [
                      if (done) BoxShadow(color: c.withValues(alpha: .5 * glow + .2), blurRadius: 14, spreadRadius: 1),
                      const BoxShadow(color: Color(0x22243A66), blurRadius: 8, offset: Offset(0, 4)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: done
                      ? const Icon(Icons.star_rounded, size: 30, color: Colors.white)
                      : Icon(Icons.lock_rounded, size: 22, color: Colors.white.withValues(alpha: .9)),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _you(Offset p) {
    return Positioned(
      left: p.dx - 18,
      top: p.dy - 78,
      child: IgnorePointer(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              gradient: T.plusGrad,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: T.accent.withValues(alpha: .5), blurRadius: 8)],
            ),
            child: const Text('你在这里', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const Icon(Icons.arrow_drop_down_rounded, size: 22, color: T.accent),
        ]),
      ),
    );
  }
}

class _Node {
  _Node(this.wish, this.done);
  final Wish wish;
  final bool done;
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.nodes, this.posOf, this.doneCount, this.activeCount);
  final List<_Node> nodes;
  final Offset Function(int) posOf;
  final int doneCount, activeCount;
  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.length < 2) return;
    // 连接路径：虚线，已完成段亮、未完成段灰
    for (var i = 0; i < nodes.length - 1; i++) {
      final a = posOf(i), b = posOf(i + 1);
      final bothDone = nodes[i].done && nodes[i + 1].done;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = bothDone
            ? const Color(0xFF8FA6FF).withValues(alpha: .55)
            : const Color(0xFFC2C7DA).withValues(alpha: .6);
      _dashCurve(canvas, a, b, paint);
    }
  }

  void _dashCurve(Canvas canvas, Offset a, Offset b, Paint paint) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx, (a.dy + b.dy) / 2, b.dx, (a.dy + b.dy) / 2, b.dx, b.dy);
    final metrics = path.computeMetrics().first;
    const dash = 9.0, gap = 8.0;
    double d = 0;
    while (d < metrics.length) {
      final seg = metrics.extractPath(d, math.min(d + dash, metrics.length));
      canvas.drawPath(seg, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => false;
}

/// 成就徽章墙 —— 心愿是徽章，已解锁发光、未解锁暗格
class _BadgeWall extends StatefulWidget {
  const _BadgeWall({required this.done, required this.active});
  final List<Wish> done;
  final List<Wish> active;
  @override
  State<_BadgeWall> createState() => _BadgeWallState();
}

class _BadgeWallState extends State<_BadgeWall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.done, ...widget.active.map((w) => w)];
    final done = widget.done.length;
    final total = all.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        // HUD
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1),
              ),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(gradient: T.plusGrad, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2),
                    boxShadow: [BoxShadow(color: T.accent.withValues(alpha: .5), blurRadius: 10)]),
                  alignment: Alignment.center,
                  child: const Icon(Icons.emoji_events_rounded, size: 24, color: Colors.white),
                ),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('成就墙', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 7,
                      backgroundColor: const Color(0xFFE2E5F2), valueColor: const AlwaysStoppedAnimation(T.accent))),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$done/$total', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T.accent)),
                  const Text('已解锁', style: TextStyle(fontSize: 11, color: T.muted)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // 徽章网格
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 12, childAspectRatio: .8),
          itemCount: all.length,
          itemBuilder: (context, i) {
            final w = all[i];
            final isDone = i < done;
            return _badge(context, w, isDone, i);
          },
        ),
      ],
    );
  }

  Widget _badge(BuildContext context, Wish w, bool done, int i) {
    final c = w.color;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => done ? DoneWishPage(wish: w) : WishDetailPage(wish: w))),
      child: Column(children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final glow = done ? .5 + .5 * (0.5 - ((_c.value + i * .12) % 1 - .5).abs()) * 2 : 0.0;
            return Container(
              width: 74, height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: done ? RadialGradient(center: const Alignment(-.3, -.3),
                    colors: [Color.lerp(c, Colors.white, .55)!, c]) : null,
                color: done ? null : const Color(0xFFDBDFEE),
                border: Border.all(color: Colors.white.withValues(alpha: .9), width: 3),
                boxShadow: [
                  if (done) BoxShadow(color: c.withValues(alpha: .35 + .3 * glow), blurRadius: 14, spreadRadius: 1),
                  const BoxShadow(color: Color(0x1A243A66), blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.star_rounded, size: 36, color: Colors.white)
                  : Icon(Icons.lock_rounded, size: 26, color: Colors.white.withValues(alpha: .95)),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.2, fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                color: done ? T.ink : T.faint)),
      ]),
    );
  }
}

/// 技能树 —— 心愿是技能节点，已点亮/未点亮，分支连线
class _SkillTree extends StatefulWidget {
  const _SkillTree({required this.done, required this.active});
  final List<Wish> done;
  final List<Wish> active;
  @override
  State<_SkillTree> createState() => _SkillTreeState();
}

class _SkillTreeState extends State<_SkillTree>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.done, ...widget.active];
    final done = widget.done.length;
    // 技能树布局：中轴主干 + 左右分支
    // 行结构：row 0 = 根(1)，之后每行 2-3 个交替
    final rows = <List<int>>[];
    var idx = 0;
    final pattern = [1, 2, 1, 2, 3, 2, 3];
    var r = 0;
    while (idx < all.length) {
      final cnt = pattern[r % pattern.length];
      final row = <int>[];
      for (var k = 0; k < cnt && idx < all.length; k++) { row.add(idx++); }
      rows.add(row); r++;
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1)),
              child: Row(children: [
                Container(width: 46, height: 46,
                  decoration: BoxDecoration(gradient: T.plusGrad, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2),
                    boxShadow: [BoxShadow(color: T.accent.withValues(alpha: .5), blurRadius: 10)]),
                  alignment: Alignment.center, child: const Icon(Icons.hub_rounded, size: 22, color: Colors.white)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('心愿天赋树', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: all.isEmpty ? 0 : done / all.length, minHeight: 7,
                      backgroundColor: const Color(0xFFE2E5F2), valueColor: const AlwaysStoppedAnimation(T.accent))),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$done/${all.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T.accent)),
                  const Text('已点亮', style: TextStyle(fontSize: 11, color: T.muted)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, cons) {
          final w = cons.maxWidth;
          const rowH = 104.0;
          final h = rows.length * rowH + 30;
          // 计算每个节点位置
          final pos = <int, Offset>{};
          for (var ri = 0; ri < rows.length; ri++) {
            final row = rows[ri];
            for (var ci = 0; ci < row.length; ci++) {
              final frac = row.length == 1 ? 0.5 : (ci + 1) / (row.length + 1);
              pos[row[ci]] = Offset(w * frac, 24 + ri * rowH);
            }
          }
          return SizedBox(
            height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: AnimatedBuilder(animation: _c,
                builder: (context, _) => CustomPaint(painter: _SkillPainter(rows, pos, done)))),
              for (var i = 0; i < all.length; i++)
                _skillNode(context, all[i], pos[i]!, i < done, i),
            ]),
          );
        }),
      ],
    );
  }

  Widget _skillNode(BuildContext context, Wish w, Offset p, bool done, int i) {
    final c = w.color;
    return Positioned(
      left: p.dx - 50, top: p.dy - 34, width: 100,
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => done ? DoneWishPage(wish: w) : WishDetailPage(wish: w))),
        child: Column(children: [
          AnimatedBuilder(animation: _c, builder: (context, _) {
            final glow = done ? .5 + .5 * (0.5 - ((_c.value + i * .12) % 1 - .5).abs()) * 2 : 0.0;
            return Container(
              width: 50, height: 50,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: done ? RadialGradient(center: const Alignment(-.3, -.3),
                    colors: [Color.lerp(c, Colors.white, .55)!, c]) : null,
                color: done ? null : const Color(0xFFDBDFEE),
                border: Border.all(color: Colors.white.withValues(alpha: .9), width: 2.5),
                boxShadow: [if (done) BoxShadow(color: c.withValues(alpha: .35 + .3 * glow), blurRadius: 12, spreadRadius: 1),
                  const BoxShadow(color: Color(0x1A243A66), blurRadius: 6, offset: Offset(0, 3))]),
              alignment: Alignment.center,
              child: Icon(done ? Icons.star_rounded : Icons.lock_rounded,
                  size: done ? 26 : 18, color: Colors.white.withValues(alpha: done ? 1 : .95)));
          }),
          const SizedBox(height: 5),
          Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                  color: done ? T.ink : T.faint)),
        ]),
      ),
    );
  }
}

class _SkillPainter extends CustomPainter {
  _SkillPainter(this.rows, this.pos, this.doneCount);
  final List<List<int>> rows;
  final Map<int, Offset> pos;
  final int doneCount;
  @override
  void paint(Canvas canvas, Size size) {
    // 连接相邻行的节点
    for (var ri = 0; ri < rows.length - 1; ri++) {
      for (final a in rows[ri]) {
        for (final b in rows[ri + 1]) {
          final pa = pos[a]!, pb = pos[b]!;
          final bothDone = a < doneCount && b < doneCount;
          final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round
            ..color = bothDone ? const Color(0xFF8FA6FF).withValues(alpha: .5) : const Color(0xFFC8CCDE).withValues(alpha: .5);
          final path = Path()..moveTo(pa.dx, pa.dy + 25)
            ..cubicTo(pa.dx, (pa.dy + pb.dy) / 2, pb.dx, (pa.dy + pb.dy) / 2, pb.dx, pb.dy - 25);
          canvas.drawPath(path, paint);
        }
      }
    }
  }
  @override
  bool shouldRepaint(_SkillPainter old) => false;
}

/// 探索大地图 —— 已完成心愿是点亮的岛屿，未完成藏在迷雾里
class _ExploreMap extends StatefulWidget {
  const _ExploreMap({required this.done, required this.active});
  final List<Wish> done;
  final List<Wish> active;
  @override
  State<_ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends State<_ExploreMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 4))..repeat();
  // 岛屿位置（分数坐标，散布）
  static const _pos = [
    Offset(.24, .18), Offset(.62, .12), Offset(.82, .30),
    Offset(.44, .34), Offset(.18, .44), Offset(.70, .48),
    Offset(.34, .60), Offset(.60, .68), Offset(.86, .60),
    Offset(.22, .74), Offset(.50, .84), Offset(.78, .82),
  ];
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.done, ...widget.active];
    final done = widget.done.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1)),
              child: Row(children: [
                Container(width: 46, height: 46,
                  decoration: BoxDecoration(gradient: T.plusGrad, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2),
                    boxShadow: [BoxShadow(color: T.accent.withValues(alpha: .5), blurRadius: 10)]),
                  alignment: Alignment.center, child: const Icon(Icons.explore_rounded, size: 24, color: Colors.white)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('心愿大陆', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: all.isEmpty ? 0 : done / all.length, minHeight: 7,
                      backgroundColor: const Color(0xFFE2E5F2), valueColor: const AlwaysStoppedAnimation(T.accent))),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$done/${all.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T.accent)),
                  const Text('已探索', style: TextStyle(fontSize: 11, color: T.muted)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // 地图
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 440,
            child: Stack(children: [
              // 海洋底
              Positioned.fill(child: DecoratedBox(decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFFD6E4FB), Color(0xFFE3DAF6), Color(0xFFDCE9F5)])))),
              Positioned.fill(child: AnimatedBuilder(animation: _c,
                builder: (context, _) => CustomPaint(painter: _ExplorePainter(_c.value)))),
              // 岛屿
              for (var i = 0; i < all.length && i < _pos.length; i++)
                _island(context, all[i], _pos[i], i < done, i),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _island(BuildContext context, Wish w, Offset f, bool done, int i) {
    return Align(
      alignment: Alignment(f.dx * 2 - 1, f.dy * 2 - 1),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => done ? DoneWishPage(wish: w) : WishDetailPage(wish: w))),
        child: SizedBox(width: 96, child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(animation: _c, builder: (context, _) {
            final glow = done ? .5 + .5 * (0.5 - ((_c.value + i * .1) % 1 - .5).abs()) * 2 : 0.0;
            if (!done) {
              // 迷雾岛
              return Container(width: 48, height: 48,
                decoration: BoxDecoration(color: const Color(0xFFC4C9DE).withValues(alpha: .55), shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .5), width: 2)),
                alignment: Alignment.center, child: Icon(Icons.help_rounded, size: 22, color: Colors.white.withValues(alpha: .8)));
            }
            final c = w.color;
            return Container(width: 52, height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(center: const Alignment(-.3, -.4), colors: [Color.lerp(c, Colors.white, .5)!, c]),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: c.withValues(alpha: .4 + .3 * glow), blurRadius: 14, spreadRadius: 1)]),
              alignment: Alignment.center, child: const Icon(Icons.flag_rounded, size: 24, color: Colors.white));
          }),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: done ? .8 : .45), borderRadius: BorderRadius.circular(7)),
            child: Text(done ? w.title : '？？？', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: done ? T.ink : T.faint)),
          ),
        ])),
      ),
    );
  }
}

class _ExplorePainter extends CustomPainter {
  _ExplorePainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 波纹
    final wave = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withValues(alpha: .3);
    for (var i = 0; i < 5; i++) {
      final y = h * (i + .5) / 5 + math.sin(t * 2 * math.pi + i) * 4;
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= w; x += 8) { path.lineTo(x, y + math.sin(x / 26 + t * 2 * math.pi + i) * 3); }
      canvas.drawPath(path, wave);
    }
  }
  @override
  bool shouldRepaint(_ExplorePainter old) => old.t != t;
}

/// 收集罐 —— 完成的心愿是掉进罐子里的发光宝石
class _GachaJar extends StatefulWidget {
  const _GachaJar({required this.done, required this.active});
  final List<Wish> done;
  final List<Wish> active;
  @override
  State<_GachaJar> createState() => _GachaJarState();
}

class _GachaJarState extends State<_GachaJar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 4))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.done, ...widget.active];
    final done = widget.done.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1)),
              child: Row(children: [
                Container(width: 46, height: 46,
                  decoration: BoxDecoration(gradient: T.plusGrad, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2),
                    boxShadow: [BoxShadow(color: T.accent.withValues(alpha: .5), blurRadius: 10)]),
                  alignment: Alignment.center, child: const Icon(Icons.diamond_rounded, size: 22, color: Colors.white)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('心愿收藏罐', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: all.isEmpty ? 0 : done / all.length, minHeight: 7,
                      backgroundColor: const Color(0xFFE2E5F2), valueColor: const AlwaysStoppedAnimation(T.accent))),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$done', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.accent)),
                  const Text('颗宝石', style: TextStyle(fontSize: 11, color: T.muted)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 玻璃罐
        LayoutBuilder(builder: (context, cons) {
          final w = cons.maxWidth;
          final jarW = w * .72;
          return Center(child: SizedBox(
            width: jarW, height: 340,
            child: Stack(clipBehavior: Clip.none, children: [
              // 罐口
              Positioned(top: 0, left: jarW * .22, right: jarW * .22, child: Container(height: 14,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border.all(color: Colors.white, width: 1.5)))),
              // 罐身（玻璃）
              Positioned(top: 12, left: 0, right: 0, bottom: 0, child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18), bottom: Radius.circular(40)),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: Container(
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .28),
                    border: Border.all(color: Colors.white.withValues(alpha: .8), width: 2),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18), bottom: Radius.circular(40))))))),
              // 宝石（堆在罐底）
              ...List.generate(done, (i) {
                final cols = 4;
                final row = i ~/ cols, col = i % cols;
                final gemW = jarW / (cols + 1);
                final x = gemW * .6 + col * gemW + (row.isOdd ? gemW * .5 : 0);
                final y = 300.0 - row * gemW * .82;
                return Positioned(left: x, top: y, child: AnimatedBuilder(animation: _c, builder: (context, _) {
                  final bob = math.sin(_c.value * 2 * math.pi + i) * 1.5;
                  return Transform.translate(offset: Offset(0, bob), child: _gem(context, widget.done[i], gemW));
                }));
              }),
              // 未获得提示
              if (done < all.length)
                Positioned(top: 40, left: 0, right: 0, child: Center(child: Text(
                  '还有 ${all.length - done} 颗心愿\n等待点亮收集',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.6, color: T.muted.withValues(alpha: .8), fontWeight: FontWeight.w500)))),
            ]),
          ));
        }),
      ],
    );
  }

  Widget _gem(BuildContext context, Wish w, double size) {
    final c = w.color;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))),
      child: Container(
        width: size * .78, height: size * .78,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(center: const Alignment(-.35, -.4), colors: [Colors.white, Color.lerp(c, Colors.white, .3)!, c]),
          border: Border.all(color: Colors.white.withValues(alpha: .9), width: 2),
          boxShadow: [BoxShadow(color: c.withValues(alpha: .55), blurRadius: 12, spreadRadius: 1)]),
        alignment: Alignment.center,
        child: Container(width: size * .2, height: size * .2, decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .7), shape: BoxShape.circle)),
      ),
    );
  }
}

/// 盲盒墙 —— 未完成是待拆盲盒，已完成是拆出的发光手办
class _BlindBox extends StatefulWidget {
  const _BlindBox({required this.done, required this.active});
  final List<Wish> done;
  final List<Wish> active;
  @override
  State<_BlindBox> createState() => _BlindBoxState();
}

class _BlindBoxState extends State<_BlindBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.done, ...widget.active];
    final done = widget.done.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1)),
              child: Row(children: [
                Container(width: 46, height: 46,
                  decoration: BoxDecoration(gradient: T.plusGrad, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2),
                    boxShadow: [BoxShadow(color: T.accent.withValues(alpha: .5), blurRadius: 10)]),
                  alignment: Alignment.center, child: const Icon(Icons.card_giftcard_rounded, size: 22, color: Colors.white)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('心愿盲盒', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: all.isEmpty ? 0 : done / all.length, minHeight: 7,
                      backgroundColor: const Color(0xFFE2E5F2), valueColor: const AlwaysStoppedAnimation(T.accent))),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$done/${all.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T.accent)),
                  const Text('已开启', style: TextStyle(fontSize: 11, color: T.muted)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 12, childAspectRatio: .82),
          itemCount: all.length,
          itemBuilder: (context, i) => _box(context, all[i], i < done, i),
        ),
      ],
    );
  }

  Widget _box(BuildContext context, Wish w, bool opened, int i) {
    final c = w.color;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => opened ? DoneWishPage(wish: w) : WishDetailPage(wish: w))),
      child: AnimatedBuilder(animation: _c, builder: (context, _) {
        final glow = opened ? .5 + .5 * (0.5 - ((_c.value + i * .1) % 1 - .5).abs()) * 2 : 0.0;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: opened
                ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color.lerp(c, Colors.white, .7)!, Color.lerp(c, Colors.white, .35)!])
                : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xFFEDEFF8), Color(0xFFDDE1F0)]),
            border: Border.all(color: Colors.white.withValues(alpha: .85), width: 1.5),
            boxShadow: [
              if (opened) BoxShadow(color: c.withValues(alpha: .3 + .25 * glow), blurRadius: 14, spreadRadius: -2, offset: const Offset(0, 6)),
              const BoxShadow(color: Color(0x14243A66), blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (opened) ...[
              // 拆开的手办 = 发光球 + 光芒
              Container(width: 46, height: 46,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(center: const Alignment(-.3,-.4), colors: [Colors.white, c]),
                  boxShadow: [BoxShadow(color: c.withValues(alpha: .6), blurRadius: 12, spreadRadius: 1)]),
                child: const Icon(Icons.auto_awesome_rounded, size: 22, color: Colors.white)),
              const SizedBox(height: 8),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w600, color: T.ink))),
            ] else ...[
              // 未拆盲盒
              Stack(alignment: Alignment.center, children: [
                Icon(Icons.inventory_2_rounded, size: 46, color: Colors.white.withValues(alpha: .95)),
                Positioned(child: Container(width: 22, height: 22,
                  decoration: BoxDecoration(color: c.withValues(alpha: .35), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)))),
              ]),
              const SizedBox(height: 8),
              const Text('待开启', style: TextStyle(fontSize: 11, color: T.faint)),
            ],
          ]),
        );
      }),
    );
  }
}

/// 养成小屋 —— 完成心愿点亮房间里的物件，家越来越丰富
class _CozyRoom extends StatefulWidget {
  const _CozyRoom({required this.done, required this.active});
  final List<Wish> done;
  final List<Wish> active;
  @override
  State<_CozyRoom> createState() => _CozyRoomState();
}

class _CozyRoomState extends State<_CozyRoom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))..repeat();
  // 房间里的物件位置和图标
  static const _slots = [
    [.20, .40, 0xe332], // 台灯 lightbulb-ish -> 用 Icons 常量下面替换
  ];
  static const _icons = [
    Icons.local_florist_rounded, Icons.chair_rounded, Icons.menu_book_rounded,
    Icons.music_note_rounded, Icons.wb_incandescent_rounded, Icons.pets_rounded,
    Icons.coffee_rounded, Icons.photo_rounded, Icons.spa_rounded,
    Icons.cake_rounded, Icons.videogame_asset_rounded, Icons.brush_rounded,
  ];
  static const _pos = [
    Offset(.16, .30), Offset(.40, .22), Offset(.66, .26), Offset(.86, .34),
    Offset(.24, .52), Offset(.52, .46), Offset(.78, .54), Offset(.14, .70),
    Offset(.42, .70), Offset(.66, .74), Offset(.88, .72), Offset(.32, .86),
  ];
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.done, ...widget.active];
    final done = widget.done.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1)),
              child: Row(children: [
                Container(width: 46, height: 46,
                  decoration: BoxDecoration(gradient: T.plusGrad, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2),
                    boxShadow: [BoxShadow(color: T.accent.withValues(alpha: .5), blurRadius: 10)]),
                  alignment: Alignment.center, child: const Icon(Icons.cottage_rounded, size: 22, color: Colors.white)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('心愿小屋', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: all.isEmpty ? 0 : done / all.length, minHeight: 7,
                      backgroundColor: const Color(0xFFE2E5F2), valueColor: const AlwaysStoppedAnimation(T.accent))),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$done/${all.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T.accent)),
                  const Text('件已点亮', style: TextStyle(fontSize: 11, color: T.muted)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // 房间
        ClipRRect(borderRadius: BorderRadius.circular(22),
          child: SizedBox(height: 380, child: Stack(children: [
            // 房间背景（墙 + 地板）
            Positioned.fill(child: DecoratedBox(decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFE9E4F7), Color(0xFFE4E9F8)])))),
            Positioned(left: 0, right: 0, bottom: 0, height: 90, child: DecoratedBox(decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFDCD2C4), Color(0xFFCFC3B2)])))),
            // 窗户装饰
            Positioned(right: 24, top: 24, child: Container(width: 70, height: 84,
              decoration: BoxDecoration(color: const Color(0xFFCFE0FB).withValues(alpha: .7),
                borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: .8), width: 3)))),
            // 物件
            for (var i = 0; i < all.length && i < _pos.length; i++)
              _item(context, all[i], _pos[i], i < done, i),
          ])),
        ),
      ],
    );
  }

  Widget _item(BuildContext context, Wish w, Offset f, bool lit, int i) {
    final c = w.color;
    final icon = _icons[i % _icons.length];
    return Align(
      alignment: Alignment(f.dx * 2 - 1, f.dy * 2 - 1),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => lit ? DoneWishPage(wish: w) : WishDetailPage(wish: w))),
        child: AnimatedBuilder(animation: _c, builder: (context, _) {
          final glow = lit ? .5 + .5 * (0.5 - ((_c.value + i * .1) % 1 - .5).abs()) * 2 : 0.0;
          return Container(
            width: 52, height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: lit ? Colors.white.withValues(alpha: .9) : const Color(0xFFCFCFDD).withValues(alpha: .5),
              border: Border.all(color: Colors.white.withValues(alpha: lit ? .95 : .5), width: 2),
              boxShadow: [if (lit) BoxShadow(color: c.withValues(alpha: .35 + .3 * glow), blurRadius: 14, spreadRadius: 1)]),
            alignment: Alignment.center,
            child: Icon(icon, size: 26, color: lit ? c : Colors.white.withValues(alpha: .7)),
          );
        }),
      ),
    );
  }
}

/// 水族箱 —— 完成心愿游进一条发光的鱼，未完成是气泡
class _Aquarium extends StatefulWidget {
  const _Aquarium({required this.done, required this.active});
  final List<Wish> done;
  final List<Wish> active;
  @override
  State<_Aquarium> createState() => _AquariumState();
}

class _AquariumState extends State<_Aquarium>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 12))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.done, ...widget.active];
    final done = widget.done.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1)),
              child: Row(children: [
                Container(width: 46, height: 46,
                  decoration: BoxDecoration(gradient: T.plusGrad, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2),
                    boxShadow: [BoxShadow(color: T.accent.withValues(alpha: .5), blurRadius: 10)]),
                  alignment: Alignment.center, child: const Icon(Icons.water_rounded, size: 22, color: Colors.white)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('心愿水族箱', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: all.isEmpty ? 0 : done / all.length, minHeight: 7,
                      backgroundColor: const Color(0xFFE2E5F2), valueColor: const AlwaysStoppedAnimation(T.accent))),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$done', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.accent)),
                  const Text('条鱼', style: TextStyle(fontSize: 11, color: T.muted)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(22),
          child: SizedBox(height: 400, child: Stack(children: [
            // 水
            Positioned.fill(child: DecoratedBox(decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFCFE4FB), Color(0xFFBBD4F5), Color(0xFFAAC6EE)])))),
            // 光束
            Positioned.fill(child: AnimatedBuilder(animation: _c,
              builder: (context, _) => CustomPaint(painter: _AquaPainter(_c.value, done, all.length - done)))),
            // 鱼（可点）
            for (var i = 0; i < done; i++)
              _fish(context, widget.done[i], i),
            // 底部水草
            Positioned(left: 0, right: 0, bottom: 0, height: 50, child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [const Color(0xFF9FD4C0).withValues(alpha: 0), const Color(0xFF88C8B0).withValues(alpha: .6)])))),
          ])),
        ),
      ],
    );
  }

  Widget _fish(BuildContext context, Wish w, int i) {
    final c = w.color;
    return AnimatedBuilder(animation: _c, builder: (context, _) {
      final phase = (_c.value + i / (widget.done.length.clamp(1, 99))) % 1.0;
      final x = phase; // 0..1 从左到右
      final baseY = 0.2 + (i % 4) * 0.18;
      final y = baseY + math.sin(_c.value * 2 * math.pi + i) * 0.03;
      final faceRight = true;
      return Align(
        alignment: Alignment(x * 2 - 1, y * 2 - 1),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoneWishPage(wish: w))),
          child: SizedBox(width: 56, height: 40, child: CustomPaint(painter: _FishPainter(c))),
        ),
      );
    });
  }
}

class _FishPainter extends CustomPainter {
  _FishPainter(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w * .5, cy = h * .5;
    // 光晕
    canvas.drawCircle(Offset(cx, cy), 20, Paint()..color = c.withValues(alpha: .3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    final body = Paint()..shader = RadialGradient(center: const Alignment(-.3,-.4),
      colors: [Color.lerp(c, Colors.white, .5)!, c]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 16));
    // 身体
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 30, height: 20), body);
    // 尾巴
    final tail = Path()..moveTo(cx - 12, cy)..lineTo(cx - 26, cy - 10)..lineTo(cx - 26, cy + 10)..close();
    canvas.drawPath(tail, body);
    // 眼睛
    canvas.drawCircle(Offset(cx + 8, cy - 2), 2.2, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + 9, cy - 2), 1.1, Paint()..color = const Color(0xFF2A3350));
  }
  @override
  bool shouldRepaint(_FishPainter old) => false;
}

class _AquaPainter extends CustomPainter {
  _AquaPainter(this.t, this.fish, this.bubbles);
  final double t; final int fish; final int bubbles;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 光束
    final beam = Paint()..color = Colors.white.withValues(alpha: .12);
    final p = Path()..moveTo(w * .2, 0)..lineTo(w * .35, 0)..lineTo(w * .55, h)..lineTo(w * .3, h)..close();
    canvas.drawPath(p, beam);
    // 未完成 = 上升的气泡
    for (var i = 0; i < bubbles; i++) {
      final bx = (i * 0.17 + 0.1) % 1.0 * w;
      final by = h - ((t + i * 0.13) % 1.0) * h;
      canvas.drawCircle(Offset(bx, by), 4 + (i % 3) * 2, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 1.4..color = Colors.white.withValues(alpha: .45));
    }
  }
  @override
  bool shouldRepaint(_AquaPainter old) => old.t != t;
}
