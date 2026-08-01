import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:gal/gal.dart';
import '../data.dart';
import '../photos.dart';
import '../theme.dart';
import '../ui.dart';

/// 分享卡片：金箔描边、流光扫过、烫金标题、点亮入场动画。
/// 两种形态：已完成 = 「已点亮」凭证；进行中 = 「我要去做」宣告卡（说出去更容易做到）。
/// [celebrate] 只在刚完成心愿跳进来时为 true：放一场烟花 + 达成提示。
class SharePage extends StatefulWidget {
  SharePage({
    super.key,
    required this.wish,
    bool? declare,
    this.celebrate = false,
  }) : declare = declare ?? !wish.done;
  final Wish wish;
  final bool declare;
  final bool celebrate;
  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> with TickerProviderStateMixin {
  final _cardKey = GlobalKey();
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3800),
  )..repeat();
  // 烟花：只放一场，放完自己消失
  late final AnimationController _fireworks = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  // 烟花放在全局 Overlay 上（且在弹窗之后插入），才能盖在恭喜弹窗上面一起放
  OverlayEntry? _fxEntry;

  @override
  void initState() {
    super.initState();
    if (widget.celebrate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCongrats();
        _fxEntry = OverlayEntry(
          builder: (_) => IgnorePointer(
            child: AnimatedBuilder(
              animation: _fireworks,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: _FireworksPainter(_fireworks.value),
              ),
            ),
          ),
        );
        Overlay.of(context, rootOverlay: true).insert(_fxEntry!);
        _fireworks.forward().whenComplete(_removeFx);
      });
    }
  }

  void _removeFx() {
    _fxEntry?.remove();
    _fxEntry = null;
  }

  void _showCongrats() {
    final no = AppData.I.doneNumberOf(widget.wish);
    showBlurDialog(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🎉',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 44),
          ),
          const SizedBox(height: 10),
          const Text(
            '恭喜！心愿达成',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '「${widget.wish.title}」\n你点亮的第 $no 个心愿',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.6, color: T.muted),
          ),
          const SizedBox(height: 18),
          BigBtn('太棒了', onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _removeFx();
    _intro.dispose();
    _shine.dispose();
    _fireworks.dispose();
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1),
                radius: 1.6,
                colors: [
                  Color(0xFF16233F),
                  Color(0xFF0B1120),
                  Color(0xFF080C17),
                ],
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
                          onTap: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              widget.declare ? '我 要 去 做' : '已 点 亮',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 4,
                                color: Color(0xFFE8EEF8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 38),
                      ],
                    ),
                    const Spacer(),
                    RepaintBoundary(
                      key: _cardKey,
                      child: _card(w, no, total, days),
                    ),
                    const Spacer(),
                    BigBtn(
                      '保存图片',
                      gradient: T.goldGrad,
                      fg: const Color(0xFF3A2C10),
                      onTap: () => _saveCard(context),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      '竖版 9:16，适配朋友圈与小红书',
                      style: TextStyle(fontSize: 15, color: T.darkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 把卡片截成图存进相册（3x 清晰度，够发朋友圈/小红书）
  Future<void> _saveCard(BuildContext context) async {
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await Gal.putImageBytes(
        bytes.buffer.asUint8List(),
        name: 'wish_${widget.wish.id}',
      );
      if (context.mounted) snack(context, '已保存到相册');
    } on GalException catch (e) {
      if (context.mounted) {
        snack(
          context,
          e.type == GalExceptionType.accessDenied
              ? '没有相册权限，去设置里打开一下'
              : '保存失败，请重试',
        );
      }
    } catch (_) {
      if (context.mounted) snack(context, '保存失败，请重试');
    }
  }

  /// 这条心愿写下来多少天了（宣告卡用）
  int _wantDays(Wish w) =>
      dOnly(DateTime.now()).difference(dOnly(w.createdAt)).inDays;

  /// 没有真实照片时的默认封面：暗夜星空图，跟卡片的暗底金字一个调子
  Widget _coverGradient(Wish w) => Image.asset(
    'assets/img/hero/default_cover.jpg',
    height: 210,
    width: double.infinity,
    fit: BoxFit.cover,
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
            color: Color(0xB3000000),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
          BoxShadow(
            color: T.gold.withValues(alpha: .3),
            blurRadius: 26,
            spreadRadius: -6,
          ),
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
                  // 凭证照片：有照片就能左右滑挑一张（最新在第一页），没有退回渐变色块
                  Stack(
                    children: [
                      if (w.photos.isNotEmpty)
                        SizedBox(
                          height: 210,
                          width: double.infinity,
                          child: PageView.builder(
                            itemCount: w.photos.length,
                            itemBuilder: (_, i) => WishPhoto(
                              w.photos[w.photos.length - 1 - i],
                              fit: BoxFit.cover,
                              fallback: _coverGradient(w),
                            ),
                          ),
                        )
                      else
                        _coverGradient(w),
                      // IgnorePointer：遮罩不能挡手势，不然照片划不动
                      Positioned.fill(
                        child: IgnorePointer(
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
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
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
                        _fade(
                          .45,
                          .75,
                          child: ShaderMask(
                            shaderCallback: (r) =>
                                T.goldTextGrad.createShader(r),
                            child: Text(
                              w.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        _fade(
                          .55,
                          .85,
                          child: Text(
                            widget.declare
                                ? '「${(w.desc?.isNotEmpty ?? false) ? w.desc : '这件事，我一定会去做'}」'
                                : '「${w.quote ?? ''}」',
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.8,
                              color: Color(0xFFC6D2E8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _fade(
                          .65,
                          .95,
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
                          ),
                        ),
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
              curve: Interval(
                .1 + i * .12,
                .35 + i * .12,
                curve: Curves.elasticOut,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Text(
                '✦',
                style: TextStyle(
                  fontSize: 18,
                  color: T.gold,
                  shadows: [
                    Shadow(
                      color: T.gold.withValues(alpha: .85),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fade(double from, double to, {required Widget child}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _intro,
        curve: Interval(from, to, curve: Curves.easeOut),
      ),
      child: child,
    );
  }
}

/// 一场烟花：几朵错峰绽放的彩色粒子环，带一点下坠和拖尾感。
/// 参数写死成一张表（位置/起爆时刻/颜色），不用随机数也够热闹。
class _FireworksPainter extends CustomPainter {
  _FireworksPainter(this.t);
  final double t; // 0~1 整场进度

  // (fx, fy, 起爆时刻0~1, 色相颜色)
  static const _bursts = [
    (.25, .22, .00, Color(0xFFFFD873)),
    (.72, .16, .12, Color(0xFF8FD3FF)),
    (.50, .32, .24, Color(0xFFFF9BC2)),
    (.15, .45, .38, Color(0xFFB9FFB0)),
    (.85, .40, .48, Color(0xFFE0B9FF)),
    (.40, .12, .60, Color(0xFFFFC29E)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (fx, fy, start, color) in _bursts) {
      // 每朵占全场 0.45 的时长，错峰起爆
      final local = ((t - start) / .45).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final center = Offset(size.width * fx, size.height * fy);
      final radius = size.width * .22 * Curves.easeOut.transform(local);
      final fade = 1 - local;
      const n = 18;
      for (var i = 0; i < n; i++) {
        final a = i / n * 2 * math.pi;
        // 粒子随时间下坠一点，别是完美的圆
        final drop = 26 * local * local;
        final p =
            center + Offset(math.cos(a) * radius, math.sin(a) * radius + drop);
        // 拖尾：往回画一小段线
        final tail =
            center +
            Offset(
              math.cos(a) * radius * .82,
              math.sin(a) * radius * .82 + drop * .8,
            );
        canvas.drawLine(
          tail,
          p,
          Paint()
            ..color = color.withValues(alpha: fade * .55)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          p,
          2.3 * fade + .6,
          Paint()..color = color.withValues(alpha: fade),
        );
      }
      // 起爆点残留的一点光晕
      canvas.drawCircle(
        center,
        10 * fade,
        Paint()
          ..color = color.withValues(alpha: fade * .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter old) => old.t != t;
}
