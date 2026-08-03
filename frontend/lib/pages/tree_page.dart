import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../data.dart';
import '../ui.dart';

/// 一枚成就：达成条件由现有数据现算；点亮记录（recordedAt）云端持久化，拿到即永久
class Achv {
  const Achv(this.emoji, this.name, this.desc, this.goal, this.value,
      this.color, this.recordedAt, this.slug);
  final String emoji;
  final String name;
  final String desc;
  final int goal;
  final int value;
  final Color color;
  final int? recordedAt; // 点亮时间(ms)；非空 = 永久点亮
  final String slug; // 奖杯图标文件名，见 assets/img/honor/
  /// 奖杯图标；文件不存在时弹窗自动退回奖章样式
  String get icon => 'assets/img/honor/$slug.png';
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
          Color color, String slug) =>
      Achv(emoji, name, desc, goal, value, color, rec[name], slug);
  return [
    a('🎯', '初试身手', '完成第 1 个任务', 1, doneTasks,
        const Color(0xFF6FA8DC), 'first_task'),
    a('✅', '渐入佳境', '完成 10 个任务', 10, doneTasks,
        const Color(0xFF5EB87C), 'task_10'),
    a('💯', '百炼成钢', '完成 100 个任务', 100, doneTasks,
        const Color(0xFFB07E2E), 'task_100'),
    a('🔥', '三日之约', '连续 3 天完成任务', 3, streak,
        const Color(0xFFE0855A), 'streak_3'),
    a('📆', '七日成习', '连续 7 天完成任务', 7, streak,
        const Color(0xFFD96A8B), 'streak_7'),
    a('🏔️', '三十而立', '连续 30 天完成任务', 30, streak,
        const Color(0xFF8B5AD9), 'streak_30'),
    a('⭐', '首愿达成', '点亮第 1 个心愿', 1, doneWishes,
        const Color(0xFFF3C877), 'first_wish'),
    a('🌟', '五愿成真', '点亮 5 个心愿', 5, doneWishes,
        const Color(0xFFE8B44C), 'wish_5'),
    a('👑', '十全十美', '点亮 10 个心愿', 10, doneWishes,
        const Color(0xFFDA9A2B), 'wish_10'),
    a('🌗', '心愿过半', '清单完成度达到 50%', 50, pct,
        const Color(0xFF7A8FD8), 'half_way'),
    a('🧩', '拆解行家', '完成 1 个心愿里程碑', 1, hasStep,
        const Color(0xFF4FA394), 'first_step'),
    a('📸', '留下印记', '给心愿传第 1 张照片', 1, hasPhoto,
        const Color(0xFF6A5AE0), 'first_photo'),
    a('📝', '过程记录者', '写下第 1 条心愿笔记', 1, hasNote,
        const Color(0xFF5C8A6E), 'first_note'),
    a('✉️', '时光旅人', '写 1 封给未来的信', 1, hasLetter,
        const Color(0xFFA06AD8), 'first_letter'),
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

  void _showDetail(BuildContext context, Achv a) => showTrophyDialog(context, a);
}

/// 奖杯弹窗：没有卡片没有按钮，奖杯从暗场里升起来，轻点任意处收起。
/// 已点亮 = 光芒 + 奖杯；未点亮 = 暗奖杯 + 一圈进度。
Future<void> showTrophyDialog(BuildContext context, Achv a,
    {bool justUnlocked = false}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: a.name,
    barrierColor: const Color(0xE60A0C16),
    transitionDuration: const Duration(milliseconds: 460),
    pageBuilder: (_, __, ___) => _TrophyView(a: a, justUnlocked: justUnlocked),
    transitionBuilder: (context, anim, __, child) {
      final t = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16 * anim.value, sigmaY: 16 * anim.value),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: .62, end: 1.0).animate(t),
            child: child,
          ),
        ),
      );
    },
  );
}

class _TrophyView extends StatefulWidget {
  const _TrophyView({required this.a, required this.justUnlocked});
  final Achv a;
  final bool justUnlocked;
  @override
  State<_TrophyView> createState() => _TrophyViewState();
}

class _TrophyViewState extends State<_TrophyView>
    with SingleTickerProviderStateMixin {
  // 必须在 initState 建：未点亮的奖杯不画光芒，build 里碰不到它，
  // 用 late 初始化会拖到 dispose 才建，那时 ticker 已经取不到了
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    if (widget.a.done) _spin.repeat(); // 未点亮不画光芒，也就不用转
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final done = a.done;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 光芒：只有点亮了才转
                    if (done)
                      AnimatedBuilder(
                        animation: _spin,
                        builder: (_, __) => CustomPaint(
                          size: const Size(300, 300),
                          painter: _RaysPainter(_spin.value, a.color),
                        ),
                      ),
                    // 底光
                    Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          (done ? a.color : const Color(0xFF3A4166))
                              .withValues(alpha: done ? .34 : .16),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                    // 未点亮：外圈进度
                    if (!done)
                      CustomPaint(
                        size: const Size(196, 196),
                        painter: _RingPainter(
                            a.goal == 0 ? 0 : a.value / a.goal),
                      ),
                    _trophy(a, done),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (widget.justUnlocked) ...[
                Text('新 荣 誉 到 手',
                    style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w700,
                        color: TreePage._gold.withValues(alpha: .85))),
                const SizedBox(height: 10),
              ],
              Text(
                a.name,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: done ? Colors.white : const Color(0xFF9AA2C4),
                  shadows: done
                      ? [
                          Shadow(
                              color: a.color.withValues(alpha: .55),
                              blurRadius: 22)
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              Text(a.desc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: .6))),
              const SizedBox(height: 16),
              _footnote(a, done),
              const SizedBox(height: 34),
              Text('轻点任意处收起',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: .3))),
            ],
          ),
        ),
      ),
    );
  }

  /// 奖杯图：有图标用图标，没有就退回奖章（图标还没生成时也不会崩）
  Widget _trophy(Achv a, bool done) {
    final fallback =
        _Medallion(color: a.color, emoji: a.emoji, locked: !done, size: 138);
    final img = Image.asset(
      a.icon,
      width: 168,
      height: 168,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
    return done
        ? img
        : ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              .2126, .7152, .0722, 0, 0, //
              .2126, .7152, .0722, 0, 0,
              .2126, .7152, .0722, 0, 0,
              0, 0, 0, .55, 0,
            ]),
            child: img,
          );
  }

  /// 底部一行：已点亮显示日期，未点亮显示进度
  Widget _footnote(Achv a, bool done) {
    final text = done
        ? (a.recordedAt != null
            ? '${ymDots(DateTime.fromMillisecondsSinceEpoch(a.recordedAt!))} 点亮'
            : '已点亮')
        : '${a.value.clamp(0, a.goal)} / ${a.goal}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: Colors.white.withValues(alpha: .07),
        border: Border.all(
            color: (done ? TreePage._gold : const Color(0xFF8892B8))
                .withValues(alpha: .3)),
      ),
      child: Text(text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: done ? TreePage._gold : const Color(0xFF9AA2C4),
          )),
    );
  }
}

/// 奖杯背后的旋转光芒
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.t, this.color);
  final double t;
  final Color color;
  static const _count = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 2 * math.pi);
    for (var i = 0; i < _count; i++) {
      final a0 = i * 2 * math.pi / _count;
      // 长短相间，转起来才有闪烁感
      final len = r * (i.isEven ? 1.0 : .72);
      final half = (i.isEven ? .036 : .022) * math.pi;
      final p = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(a0 - half) * len, math.sin(a0 - half) * len)
        ..lineTo(math.cos(a0 + half) * len, math.sin(a0 + half) * len)
        ..close();
      canvas.drawPath(
          p,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withValues(alpha: .34),
              color.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: Offset.zero, radius: r)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.t != t || old.color != color;
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
      {required this.color,
      required this.emoji,
      this.locked = false,
      this.size = 74.0});
  final Color color;
  final String emoji;
  final bool locked;
  final double size;

  double get _ring => size;
  double get _disc => size * .784;

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
              height: _ring * .19,
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
                size: Size(_ring * .405, _ring * .297),
                painter: _RibbonPainter(color)),
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
            bottom: _ring * .108,
            right: _ring * .108,
            child: Container(
              width: _ring * .3,
              height: _ring * .3,
              decoration: BoxDecoration(
                color: const Color(0xFF4A5170),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF232842), width: 2),
              ),
              child: Icon(Icons.lock_rounded,
                  size: _ring * .15, color: const Color(0xFFC7CCE0)),
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
