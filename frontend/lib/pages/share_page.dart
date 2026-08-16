import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:gal/gal.dart';
import '../data.dart';
import '../photos.dart';
import '../share_poster.dart' show donePosterAssets;
import '../theme.dart';
import '../ui.dart';

/// 分享卡片：描边、流光扫过、渐变标题、点亮入场动画。
/// 两种形态：已完成 = 「已点亮」金色凭证；进行中 = 「我要去做」热血宣告卡
/// （熔岩橙红 + 必达印章，说出去更容易做到）。
/// [celebrate] 只在刚完成心愿跳进来时为 true：放一场烟花 + 达成提示。

// 宣告卡（热血版）配色：熔岩橙红
const _flameGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFB25C), Color(0xFFFF5A3C), Color(0xFFD92A2A)],
);
const _flameTextGrad = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFE3B0), Color(0xFFFFA85C), Color(0xFFFF6B4A)],
);
const _flame = Color(0xFFFF5A3C);

/// 宣告卡默认封面：登山 / 火炬 / 冲刺，可左右滑切换。
/// 这是内置兜底，管理端 cover_declare 表下发的图优先（运营换图不用发版）。
const _declareCovers = [
  'assets/img/hero/declare_cover.jpg',
  'assets/img/hero/declare_cover2.jpg',
  'assets/img/hero/declare_cover3.jpg',
];

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
  int _coverPage = 0; // 宣告卡默认封面当前页（指示点用）
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
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 预热内置封面的解码：宣告卡三张要滑动切换不掉帧；凭证卡那张是远程图
    // 换链接期间的占位，不预热的话首帧会空一下（远程图和本地图同时在解码）
    if (!_precached) {
      _precached = true;
      for (final a
          in widget.declare
              ? _declareCovers
              : const ['assets/img/hero/default_cover.jpg']) {
        precacheImage(AssetImage(a), context);
      }
    }
  }

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
                painter: FireworksPainter(_fireworks.value),
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
    final w = widget.wish;
    final no = AppData.I.doneNumberOf(w);
    // 达成海报：优先管理端下发的（运营换图不用发版），没有就用内置的四张。
    // 按心愿 id 稳定取一张——同一条心愿每次看到的都一样，不同心愿配不同的图。
    final builtin =
        donePosterAssets[w.id.hashCode.abs() % donePosterAssets.length];
    final remote = AppData.I.donePosters;
    final remoteUrl = remote.isEmpty
        ? null
        : remote[w.id.hashCode.abs() % remote.length];

    showPosterDialog(
      context,
      title: '心愿达成',
      body: '「${w.title}」\n你点亮的第 $no 个心愿',
      action: '收下这一刻',
      asset: builtin,
      // 有自己拍的照片就用它当底图；否则用下发的达成海报；
      // 两者都取不到时 showPosterDialog 会回落到 asset（内置图）
      image: w.photos.isNotEmpty
          ? WishPhoto(
              w.photos.last,
              fit: BoxFit.cover,
              fallback: Image.asset(builtin, fit: BoxFit.cover),
            )
          : remoteUrl == null
          ? null
          : WishPhoto(
              remoteUrl,
              fit: BoxFit.cover,
              fallback: Image.asset(builtin, fit: BoxFit.cover),
              loading: Image.asset(builtin, fit: BoxFit.cover),
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
            decoration: BoxDecoration(
              // 宣告卡用暗红余烬底，凭证卡保持暗夜蓝
              gradient: RadialGradient(
                center: const Alignment(0, -1),
                radius: 1.6,
                colors: widget.declare
                    ? const [
                        Color(0xFF3B1712),
                        Color(0xFF1C0D0A),
                        Color(0xFF120807),
                      ]
                    : const [
                        Color(0xFF16233F),
                        Color(0xFF0B1120),
                        Color(0xFF080C17),
                      ],
                stops: const [0, .55, 1],
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
                              widget.declare ? '此 愿 必 达' : '已 点 亮',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: widget.declare
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                letterSpacing: 4,
                                color: widget.declare
                                    ? const Color(0xFFFFD9C4)
                                    : const Color(0xFFE8EEF8),
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
                    // 封面指示点：提示宣告卡默认封面可以左右滑
                    if (widget.declare && w.photos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _coverCount; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: _coverPage == i ? 14 : 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: _coverPage == i ? .9 : .35,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    BigBtn(
                      '保存图片',
                      gradient: widget.declare ? _flameGrad : T.goldGrad,
                      fg: widget.declare
                          ? Colors.white
                          : const Color(0xFF3A2C10),
                      onTap: () => _saveCard(context),
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

  /// 没有真实照片时的默认封面：宣告卡用破晓登山（热血橙红），凭证卡用暗夜星空。
  /// 管理端下发了就用远程的，拉不到/换链接期间回落到内置图。
  Widget _coverGradient(Wish w) {
    final builtin = widget.declare
        ? _declareCovers.first
        : 'assets/img/hero/default_cover.jpg';
    final remote = widget.declare
        ? AppData.I.declareCovers
        : AppData.I.doneCovers;
    final fallback = Image.asset(
      builtin,
      height: 210,
      width: double.infinity,
      fit: BoxFit.cover,
    );
    if (remote.isEmpty) return fallback;
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: WishPhoto(
        remote.first,
        fit: BoxFit.cover,
        fallback: fallback,
        loading: fallback,
      ),
    );
  }

  /// 宣告卡可滑动的封面组：远程下发的优先，空了用内置三张
  List<Widget> _declareCoverPages() {
    final remote = AppData.I.declareCovers;
    if (remote.isEmpty) {
      return [
        for (final a in _declareCovers) Image.asset(a, fit: BoxFit.cover),
      ];
    }
    return [
      for (var i = 0; i < remote.length; i++)
        WishPhoto(
          remote[i],
          fit: BoxFit.cover,
          // 兜底按位置对应内置图，数量对不上就用第一张
          fallback: Image.asset(
            _declareCovers[i % _declareCovers.length],
            fit: BoxFit.cover,
          ),
          loading: Image.asset(
            _declareCovers[i % _declareCovers.length],
            fit: BoxFit.cover,
          ),
        ),
    ];
  }

  /// 封面指示点的个数：跟实际渲染的页数一致
  int get _coverCount => AppData.I.declareCovers.isEmpty
      ? _declareCovers.length
      : AppData.I.declareCovers.length;

  Widget _card(Wish w, int no, int total, int days) {
    final hot = widget.declare; // 宣告卡 = 熔岩橙红；凭证卡 = 金箔
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: hot ? _flameGrad : T.foilGrad,
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          const BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
          BoxShadow(
            color: (hot ? _flame : T.gold).withValues(alpha: .3),
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
                      else if (widget.declare)
                        // 宣告卡默认封面有三张（登山/火炬/冲刺），左右滑挑一张
                        SizedBox(
                          height: 210,
                          width: double.infinity,
                          child: PageView(
                            onPageChanged: (i) =>
                                setState(() => _coverPage = i),
                            children: _declareCoverPages(),
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
                      // 左上角：头像 + 昵称
                      Positioned(
                        top: 10,
                        left: 12,
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .25),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .5),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: AppData.I.avatarUrl != null
                                  ? WishPhoto(
                                      AppData.I.avatarUrl!,
                                      width: 30,
                                      height: 30,
                                      fallback: const Icon(
                                        Icons.person_rounded,
                                        size: 17,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 17,
                                      color: Colors.white,
                                    ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              AppData.I.nickname,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 12,
                        // 和左边 30px 头像行同高垂直居中，跟昵称一条线
                        child: SizedBox(
                          height: 30,
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/icon/logo_mark.png',
                                width: 22,
                                color: Colors.white.withValues(alpha: .95),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '人生清单',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                  color: Colors.white.withValues(alpha: .9),
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x66000000),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 文字区
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, hot ? 10 : 16),
                    child: hot
                        // 宣告卡：宣言、信息行在上；最底一行标题居左、必达印章居右，同一条中心线
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fade(
                                .55,
                                .85,
                                child: Text(
                                  [
                                    if (w.targetAt != null)
                                      '${ymdDots(w.targetAt!)} 之前',
                                    if (w.steps.isNotEmpty)
                                      '里程碑 ${w.doneStepCount}/${w.steps.length}',
                                  ].join(' · '),
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    letterSpacing: 1.5,
                                    color: T.darkMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _fade(
                                .65,
                                .95,
                                // 左边标题+宣言两行，「必达」印章对着两行的垂直中线
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ShaderMask(
                                            shaderCallback: (r) =>
                                                _flameTextGrad.createShader(r),
                                            child: Text(
                                              w.title,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '「${(w.desc?.isNotEmpty ?? false) ? w.desc : '不是说说而已，我说到就会做到'}」',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              height: 1.8,
                                              color: Color(0xFFEBC9B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Transform.rotate(
                                      angle: -.16,
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          5,
                                          6,
                                          5,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: _flame.withValues(alpha: .9),
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          '必达',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 4,
                                            color: Color(0xFFFF6B4A),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        // 凭证卡：星花 + 烫金标题 + 引言 + 信息行，保持原样
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _stars(T.gold),
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
                                  '「${w.quote ?? ''}」',
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

  Widget _stars(Color color) {
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
                  color: color,
                  shadows: [
                    Shadow(color: color.withValues(alpha: .85), blurRadius: 12),
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
class FireworksPainter extends CustomPainter {
  FireworksPainter(this.t);
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
  bool shouldRepaint(FireworksPainter old) => old.t != t;
}
