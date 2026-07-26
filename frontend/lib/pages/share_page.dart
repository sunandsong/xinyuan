import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';

/// 分享卡片：金箔描边、流光扫过、烫金标题、点亮入场动画
class SharePage extends StatefulWidget {
  const SharePage({super.key, required this.wish});
  final Wish wish;
  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..forward();
  late final AnimationController _shine = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3800))
    ..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wish;
    final no = AppData.I.doneNumberOf(w);
    final total = AppData.I.wishes.length;
    final days = w.doneAt == null
        ? 0
        : w.doneAt!.difference(w.createdAt).inDays;
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
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context)),
                    const Expanded(
                      child: Center(
                        child: Text('已 点 亮',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 4,
                                color: Color(0xFFE8EEF8))),
                      ),
                    ),
                    const SizedBox(width: 38),
                  ],
                ),
                const Spacer(),
                _card(w, no, total, days),
                const Spacer(),
                BigBtn('生成点亮视频 · 3 秒',
                    gradient: T.goldGrad,
                    fg: const Color(0xFF3A2C10), onTap: () {
                  _intro.duration = const Duration(milliseconds: 3000);
                  _intro.forward(from: 0);
                }),
                const SizedBox(height: 9),
                BigBtn('保存图片',
                    bg: Colors.white.withValues(alpha: .1),
                    onTap: () => snack(context, '已保存到相册（演示）')),
                const SizedBox(height: 9),
                const Text('竖版 9:16，适配朋友圈与小红书',
                    style:
                        TextStyle(fontSize: 15, color: T.darkMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Wish w, int no, int total, int days) {
    // 金箔描边框
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: T.foilGrad,
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          const BoxShadow(
              color: Color(0xB3000000), blurRadius: 40, offset: Offset(0, 16)),
          BoxShadow(
              color: T.gold.withValues(alpha: .3),
              blurRadius: 26,
              spreadRadius: -6),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17.5),
        child: Container(
          color: T.darkCard,
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 凭证照片
                  Stack(
                    children: [
                      Container(
                        height: 210,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: w.hero ?? AppData.heroes[0],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [.4, 1],
                              colors: [
                                Colors.transparent,
                                T.darkCard.withValues(alpha: .95),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 12,
                        child: Text('No.$no / $total',
                            style: TextStyle(
                              fontSize: 14.5,
                              letterSpacing: 2,
                              color: Colors.white.withValues(alpha: .8),
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            )),
                      ),
                    ],
                  ),
                  // 文字区
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _stars(),
                        const SizedBox(height: 8),
                        _fade(.45, .75,
                            child: ShaderMask(
                              shaderCallback: (r) =>
                                  T.goldTextGrad.createShader(r),
                              child: Text(w.title,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            )),
                        const SizedBox(height: 7),
                        _fade(.55, .85,
                            child: Text('「${w.quote ?? ''}」',
                                style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.8,
                                    color: Color(0xFFC6D2E8)))),
                        const SizedBox(height: 8),
                        _fade(.65, .95,
                            child: Text(
                              [
                                if (w.doneAt != null) ymdDots(w.doneAt!),
                                if (w.location != null) w.location!,
                                '第 $no 个心愿',
                                '$days 天',
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 14.5,
                                letterSpacing: 1.5,
                                color: T.darkMuted,
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              // 流光扫过
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _shine,
                    builder: (context, _) {
                      final t = _shine.value;
                      final x = t < .5 ? -.6 : (t - .5) * 2 * 2.4 - .6;
                      return Align(
                        alignment: Alignment(x * 2 - 1, 0),
                        child: Transform.rotate(
                          angle: .32,
                          child: Container(
                            width: 70,
                            height: 500,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: .14),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stars() {
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _intro,
              curve: Interval(.1 + i * .12, .35 + i * .12,
                  curve: Curves.elasticOut),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Text('✦',
                  style: TextStyle(
                    fontSize: 18,
                    color: T.gold,
                    shadows: [
                      Shadow(
                          color: T.gold.withValues(alpha: .85),
                          blurRadius: 12),
                    ],
                  )),
            ),
          ),
      ],
    );
  }

  Widget _fade(double from, double to, {required Widget child}) {
    return FadeTransition(
      opacity: CurvedAnimation(
          parent: _intro,
          curve: Interval(from, to, curve: Curves.easeOut)),
      child: child,
    );
  }
}
