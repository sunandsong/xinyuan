import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../api/api.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';

/// 分享卡片：金箔描边、流光扫过、烫金标题、点亮入场动画。
/// 两种形态：已完成 = 「已点亮」凭证；进行中 = 「我要去做」宣告卡（说出去更容易做到）。
class SharePage extends StatefulWidget {
  SharePage({super.key, required this.wish, bool? declare})
      : declare = declare ?? !wish.done;
  final Wish wish;
  final bool declare;
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
                    Expanded(
                      child: Center(
                        child: Text(widget.declare ? '我 要 去 做' : '已 点 亮',
                            style: const TextStyle(
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
                if (!widget.declare) ...[
                  BigBtn('生成点亮视频 · 3 秒',
                      gradient: T.goldGrad,
                      fg: const Color(0xFF3A2C10), onTap: () {
                    _intro.duration = const Duration(milliseconds: 3000);
                    _intro.forward(from: 0);
                  }),
                  const SizedBox(height: 9),
                ],
                BigBtn('保存图片',
                    bg: Colors.white.withValues(alpha: .1),
                    onTap: () => snack(context, '已保存到相册（演示）')),
                const SizedBox(height: 9),
                BigBtn('生成分享码',
                    bg: Colors.white.withValues(alpha: .1),
                    onTap: () => _shareLink(context)),
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

  Future<void> _shareLink(BuildContext context) async {
    if (!AppData.I.signedIn) {
      snack(context, '请先登录后再分享');
      return;
    }
    try {
      final path = await AppData.I.shareWish(widget.wish);
      await Clipboard.setData(ClipboardData(text: path));
      if (!context.mounted) return;
      snack(context, '分享码已复制：$path');
    } on ApiException catch (e) {
      if (!context.mounted) return;
      snack(context, e.message);
    } catch (_) {
      if (!context.mounted) return;
      snack(context, '生成分享码失败，请重试');
    }
  }

  /// 这条心愿写下来多少天了（宣告卡用）
  int _wantDays(Wish w) =>
      dOnly(DateTime.now()).difference(dOnly(w.createdAt)).inDays;

  /// 没有真实照片时的凭证底色：进行中用心愿自己的颜色压暗，已完成用预设的
  /// 四组渐变色之一
  Widget _coverGradient(Wish w) => Container(
        height: 210,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.declare
                ? [
                    Color.lerp(w.color, T.darkCard, .25)!,
                    Color.lerp(w.color, T.darkCard, .72)!,
                  ]
                : (w.hero ?? AppData.heroes[0]),
          ),
        ),
      );

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
                  // 凭证照片：心愿存过真实照片就用最新一张，没有再退回渐变色块
                  Stack(
                    children: [
                      if (w.photos.isNotEmpty)
                        SizedBox(
                          height: 210,
                          width: double.infinity,
                          child: Image.network(
                            w.photos.last,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _coverGradient(w),
                          ),
                        )
                      else
                        _coverGradient(w),
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
                        child: Text(
                            widget.declare
                                ? '清 单 之 一 / $total'
                                : 'No.$no / $total',
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
                            child: Text(
                                widget.declare
                                    ? '「${(w.desc?.isNotEmpty ?? false) ? w.desc : '这件事，我一定会去做'}」'
                                    : '「${w.quote ?? ''}」',
                                style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.8,
                                    color: Color(0xFFC6D2E8)))),
                        const SizedBox(height: 8),
                        _fade(.65, .95,
                            child: Text(
                              (widget.declare
                                      ? [
                                          '写下 ${_wantDays(w)} 天',
                                          if (w.targetAt != null)
                                            '${ymdDots(w.targetAt!)} 之前',
                                          if (w.steps.isNotEmpty)
                                            '里程碑 ${w.doneStepCount}/${w.steps.length}',
                                        ]
                                      : [
                                          if (w.doneAt != null)
                                            ymdDots(w.doneAt!),
                                          if (w.location != null) w.location!,
                                          '第 $no 个心愿',
                                          '$days 天',
                                        ])
                                  .join(' · '),
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
