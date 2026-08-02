import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';

/// 一枚成就：达成条件由现有数据现算；点亮记录（recordedAt）云端持久化，拿到即永久
class Achv {
  const Achv(this.emoji, this.name, this.desc, this.goal, this.value,
      this.color, this.recordedAt);
  final String emoji;
  final String name;
  final String desc;
  final int goal;
  final int value;
  final Color color;
  final int? recordedAt; // 点亮时间(ms)；非空 = 永久点亮
  bool get met => value >= goal; // 当前条件是否满足
  bool get done => recordedAt != null || met;
}

/// 使用 App 的成就清单（按进阶顺序排列）
List<Achv> achievements(AppData d) {
  final doneTasks = d.doneTaskCount;
  final streak = d.streakDays;
  final doneWishes = d.wishes.where((w) => w.done).length;
  final total = d.wishes.length;
  final pct = total == 0 ? 0 : doneWishes * 100 ~/ total;
  final hasStep =
      d.wishes.any((w) => w.steps.any((s) => s.done)) ? 1 : 0;
  final hasPhoto = d.wishes.any((w) => w.photos.isNotEmpty) ? 1 : 0;
  final hasNote = d.wishes.any((w) => w.notes.isNotEmpty) ? 1 : 0;
  final hasLetter = d.letters.isNotEmpty ? 1 : 0;
  final rec = d.achvUnlocked;
  Achv a(String emoji, String name, String desc, int goal, int value,
          Color color) =>
      Achv(emoji, name, desc, goal, value, color, rec[name]);
  return [
    a('🎯', '初试身手', '完成第 1 个任务', 1, doneTasks,
        const Color(0xFF6FA8DC)),
    a('✅', '渐入佳境', '完成 10 个任务', 10, doneTasks,
        const Color(0xFF5EB87C)),
    a('💯', '百炼成钢', '完成 100 个任务', 100, doneTasks,
        const Color(0xFFB07E2E)),
    a('🔥', '三日之约', '连续 3 天完成任务', 3, streak,
        const Color(0xFFE0855A)),
    a('📆', '七日成习', '连续 7 天完成任务', 7, streak,
        const Color(0xFFD96A8B)),
    a('🏔️', '三十而立', '连续 30 天完成任务', 30, streak,
        const Color(0xFF8B5AD9)),
    a('⭐', '首愿达成', '点亮第 1 个心愿', 1, doneWishes,
        const Color(0xFFF3C877)),
    a('🌟', '五愿成真', '点亮 5 个心愿', 5, doneWishes,
        const Color(0xFFE8B44C)),
    a('👑', '十全十美', '点亮 10 个心愿', 10, doneWishes,
        const Color(0xFFDA9A2B)),
    a('🌗', '心愿过半', '清单完成度达到 50%', 50, pct,
        const Color(0xFF7A8FD8)),
    a('🧩', '拆解行家', '完成 1 个心愿里程碑', 1, hasStep,
        const Color(0xFF4FA394)),
    a('📸', '留下印记', '给心愿传第 1 张照片', 1, hasPhoto,
        const Color(0xFF6A5AE0)),
    a('📝', '过程记录者', '写下第 1 条心愿笔记', 1, hasNote,
        const Color(0xFF5C8A6E)),
    a('✉️', '时光旅人', '写 1 封给未来的信', 1, hasLetter,
        const Color(0xFFA06AD8)),
  ];
}

/// 荣誉殿堂 —— 使用 App 攒下的成就奖章：达成是金属立体奖章，未达成是待点亮的暗格
class TreePage extends StatelessWidget {
  const TreePage({super.key});

  static const _bg1 = Color(0xFF1B2038);
  static const _bg2 = Color(0xFF0C0F1B);
  static const _goldHi = Color(0xFFFFE9B0);
  static const _gold = Color(0xFFF3C877);
  static const _goldLo = Color(0xFFB07E2E);
  static const _lightInk = Color(0xFFE8EEF8);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final all = achievements(AppData.I);
        final got = all.where((a) => a.done).length;
        final total = all.length;

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
                          const SizedBox(width: 38),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                        children: [
                          _hero(got, total),
                          const SizedBox(height: 26),
                          _shelfLabel('成 就'),
                          const SizedBox(height: 16),
                          _grid(context, all),
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
                text: '  / $total 枚成就',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _lightInk.withValues(alpha: .55))),
          ]),
        ),
        const SizedBox(height: 8),
        Text(
            got >= total
                ? '殿堂已收满，了不起'
                : '再点亮 ${total - got} 枚，收满整座殿堂',
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

  Widget _grid(BuildContext context, List<Achv> all) {
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

  Widget _slot(BuildContext context, Achv a) {
    final locked = !a.done;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDetail(context, a),
      child: Column(
        children: [
          _Medallion(color: a.color, emoji: a.emoji, locked: locked),
          const SizedBox(height: 12),
          Text(
            a.name,
            maxLines: 1,
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
            locked
                ? '${a.value.clamp(0, a.goal)}/${a.goal}'
                : a.recordedAt != null
                    ? ymDots(DateTime.fromMillisecondsSinceEpoch(
                        a.recordedAt!))
                    : '已点亮',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: locked
                    ? _lightInk.withValues(alpha: .25)
                    : _gold.withValues(alpha: .8)),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, Achv a) {
    showBlurDialog(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(a.emoji,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(a.name,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            a.done ? a.desc : '${a.desc}\n当前进度 ${a.value.clamp(0, a.goal)}/${a.goal}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.6, color: T.muted),
          ),
          const SizedBox(height: 18),
          BigBtn(a.done ? '真棒' : '继续加油',
              onTap: () => Navigator.pop(context)),
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
