import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data.dart';
import '../ui.dart';
import 'wish_pages.dart';

/// 荣誉殿堂 —— 已完成心愿是金属立体奖章，进行中的是待点亮的暗格
class TreePage extends StatelessWidget {
  const TreePage({super.key});

  static const _bg1 = Color(0xFF1B2038);
  static const _bg2 = Color(0xFF0C0F1B);
  static const _goldHi = Color(0xFFFFE9B0);
  static const _gold = Color(0xFFF3C877);
  static const _goldLo = Color(0xFFB07E2E);
  static const _lightInk = Color(0xFFE8EEF8);

  // 从心愿标题猜一个奖章图标
  static String _emoji(String t) {
    bool has(String s) => t.contains(s);
    if (has('马拉松') || has('跑')) return '🏃';
    if (has('潜')) return '🤿';
    if (has('游泳')) return '🏊';
    if (has('菜') || has('做饭') || has('厨')) return '🍳';
    if (has('出版')) return '✍️';
    if (has('读') || has('书')) return '📚';
    if (has('十万') || has('攒') || has('钱') || has('存')) return '💰';
    if (has('极光') || has('冰岛')) return '🌌';
    if (has('吉他') || has('弹') || has('琴')) return '🎸';
    if (has('海')) return '🏖️';
    if (has('爸妈') || has('周末') || has('家')) return '🏡';
    if (has('旅') || has('远方')) return '🧳';
    return '🏅';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final data = AppData.I;
        final unlocked = data.doneWishes;
        final locked = data.activeWishes;
        final total = data.wishes.length;
        final got = unlocked.length;
        final all = [...unlocked, ...locked];

        return Scaffold(
          backgroundColor: _bg2,
          body: Stack(
            children: [
              // 背景：竖向渐变 + 顶部聚光
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_bg1, _bg2],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -120,
                left: 0,
                right: 0,
                child: Container(
                  height: 360,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: .9,
                      colors: [
                        _gold.withValues(alpha: .16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    // 顶栏
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          DarkPill(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.pop(context)),
                          const Expanded(
                            child: Center(
                              child: Text('荣 誉 殿 堂',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 4,
                                      color: _lightInk)),
                            ),
                          ),
                          DarkPill(
                              icon: Icons.ios_share_rounded,
                              onTap: () => snack(context, '已保存到相册（演示）')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                        children: [
                          _hero(got, total),
                          const SizedBox(height: 26),
                          _shelfLabel('已 点 亮'),
                          const SizedBox(height: 16),
                          _grid(context, unlocked, locked, all),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 顶部：环形进度包着大奖杯
  Widget _hero(int got, int total) {
    final frac = total == 0 ? 0.0 : got / total;
    return Column(
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 奖杯底部辉光
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _gold.withValues(alpha: .28),
                        blurRadius: 34,
                        spreadRadius: 2),
                  ],
                ),
              ),
              CustomPaint(
                  size: const Size(132, 132), painter: _RingPainter(frac)),
              const Text('🏆', style: TextStyle(fontSize: 54)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('HALL OF HONOR',
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
                color: _gold.withValues(alpha: .7))),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$got',
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: _goldHi,
                    fontFeatures: [FontFeature.tabularFigures()])),
            TextSpan(
                text: '  / $total 枚荣誉',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _lightInk.withValues(alpha: .55))),
          ]),
        ),
        const SizedBox(height: 8),
        Text('再点亮 ${total - got} 枚，收满整座殿堂',
            style: TextStyle(
                fontSize: 12.5, color: _lightInk.withValues(alpha: .4))),
      ],
    );
  }

  Widget _shelfLabel(String text) {
    return Row(
      children: [
        Expanded(
            child: Container(
                height: 1,
                color: _gold.withValues(alpha: .16))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text,
              style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                  color: _gold.withValues(alpha: .75))),
        ),
        Expanded(
            child: Container(
                height: 1,
                color: _gold.withValues(alpha: .16))),
      ],
    );
  }

  Widget _grid(BuildContext context, List<Wish> unlocked, List<Wish> locked,
      List<Wish> all) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 22,
      crossAxisSpacing: 10,
      childAspectRatio: .70,
      children: [
        for (var i = 0; i < all.length; i++)
          StaggerIn(index: i, child: _slot(context, all[i])),
      ],
    );
  }

  Widget _slot(BuildContext context, Wish w) {
    final locked = !w.done;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              locked ? WishDetailPage(wish: w) : DoneWishPage(wish: w),
        ),
      ),
      child: Column(
        children: [
          _Medallion(color: w.color, emoji: _emoji(w.title), locked: locked),
          const SizedBox(height: 12),
          Text(
            w.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: locked
                    ? _lightInk.withValues(alpha: .38)
                    : _lightInk.withValues(alpha: .92)),
          ),
          const SizedBox(height: 3),
          Text(
            locked ? '未点亮' : ymDots(w.doneAt!),
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: locked
                    ? _lightInk.withValues(alpha: .25)
                    : _gold.withValues(alpha: .8)),
          ),
        ],
      ),
    );
  }
}

/// 环形进度（奖杯外圈）
class _RingPainter extends CustomPainter {
  _RingPainter(this.frac);
  final double frac;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 5;
    final rect = Rect.fromCircle(center: c, radius: r);
    // 轨道
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF2E3556));
    // 进度弧
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * frac.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [
            TreePage._goldLo,
            TreePage._gold,
            TreePage._goldHi,
            TreePage._gold
          ],
        ).createShader(rect),
    );
    // 弧头亮点
    final a = -math.pi / 2 + 2 * math.pi * frac.clamp(0, 1);
    final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
    canvas.drawCircle(p, 4.5, Paint()..color = TreePage._goldHi);
    canvas.drawCircle(
        p,
        8,
        Paint()
          ..color = TreePage._goldHi.withValues(alpha: .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.frac != frac;
}

/// 金属立体奖章：金边环 + 彩色盘面 + 高光 + 彩带 + 底部辉光；未点亮为暗刻
class _Medallion extends StatelessWidget {
  const _Medallion(
      {required this.color, required this.emoji, this.locked = false});
  final Color color;
  final String emoji;
  final bool locked;

  static const _ring = 74.0;
  static const _disc = 58.0;

  @override
  Widget build(BuildContext context) {
    if (locked) return _lockedView();

    final discLight = Color.lerp(color, Colors.white, .45)!;
    final discDark = Color.lerp(color, Colors.black, .28)!;
    return SizedBox(
      width: _ring,
      height: _ring + 8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 底部辉光
          Positioned(
            bottom: 2,
            child: Container(
              width: _ring * .8,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: .55),
                      blurRadius: 18,
                      spreadRadius: -4),
                ],
              ),
            ),
          ),
          // 彩带
          Positioned(
            bottom: -2,
            child: CustomPaint(
                size: const Size(30, 22), painter: _RibbonPainter(color)),
          ),
          // 金边环
          Container(
            width: _ring,
            height: _ring,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TreePage._goldHi,
                  TreePage._goldLo,
                  TreePage._goldHi,
                  TreePage._goldLo,
                ],
                stops: [0, .35, .7, 1],
              ),
              boxShadow: [
                BoxShadow(
                    color: Color(0x66F3C877),
                    blurRadius: 16,
                    spreadRadius: -3),
                BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0, 4)),
              ],
            ),
            alignment: Alignment.center,
            // 盘面
            child: Container(
              width: _disc,
              height: _disc,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-.35, -.4),
                  radius: .95,
                  colors: [discLight, color, discDark],
                  stops: const [0, .55, 1],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: _disc * .14,
                    left: _disc * .2,
                    child: Container(
                      width: _disc * .32,
                      height: _disc * .18,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text(emoji, style: TextStyle(fontSize: _disc * .42)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockedView() {
    return SizedBox(
      width: _ring,
      height: _ring + 8,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 暗刻环
          Container(
            width: _ring,
            height: _ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A4166), Color(0xFF232842)],
              ),
              border: Border.all(color: const Color(0xFF454C70), width: 1),
            ),
            alignment: Alignment.center,
            child: Container(
              width: _disc,
              height: _disc,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-.3, -.35),
                  colors: [Color(0xFF2B3050), Color(0xFF171B2E)],
                ),
              ),
              alignment: Alignment.center,
              child: Opacity(
                opacity: .3,
                child: Text(emoji, style: TextStyle(fontSize: _disc * .4)),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF4A5170),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF232842), width: 2),
              ),
              child: const Icon(Icons.lock_rounded,
                  size: 11, color: Color(0xFFC7CCE0)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 奖章下方的小彩带
class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final left = Path()
      ..moveTo(w * .18, 0)
      ..lineTo(w * .42, 0)
      ..lineTo(w * .40, h)
      ..lineTo(w * .28, h * .8)
      ..lineTo(w * .16, h)
      ..close();
    final right = Path()
      ..moveTo(w * .58, 0)
      ..lineTo(w * .82, 0)
      ..lineTo(w * .84, h)
      ..lineTo(w * .72, h * .8)
      ..lineTo(w * .60, h)
      ..close();
    final dark = Color.lerp(color, Colors.black, .25)!;
    canvas.drawPath(left, Paint()..color = dark);
    canvas.drawPath(right, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.color != color;
}
