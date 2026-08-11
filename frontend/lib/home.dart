import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';
import 'pages/share_page.dart' show FireworksPainter;
import 'pages/login_page.dart';
import 'pages/tree_page.dart' show achievements, Achv, showTrophyDialog;
import 'tabs/me_tab.dart';
import 'tabs/tasks_tab.dart';
import 'tabs/wishes_tab.dart';
import 'theme.dart';
import 'ui.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex;
  // 启动后把重页面以 1% 透明度画一帧，提前编译着色器（首次切页不卡），画完即拆
  bool _warmedUp = false;

  // ---------- 成就点亮监听 ----------
  // 点亮记录在 AppData.achvUnlocked（本机 + 云端持久化）；这里只负责发现新达成并庆祝
  bool _achvReady = false;
  bool _achvBusy = false;
  late final AnimationController _fx;

  static const _tabs = [TasksTab(), WishesTab(), MeTab()];

  @override
  void initState() {
    super.initState();
    _fx = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _warmedUp = true);
      });
    });
    _initAchvWatch();
    AppData.I.addListener(_checkSessionExpired);
  }

  /// 后台同步撞见 401 时（见 AppData._handleUnauthorized）弹一次提示 + 登录框，
  /// 复位标记别重复弹；本地数据没清，弹完重新登录就接着同步
  void _checkSessionExpired() {
    if (!mounted || !AppData.I.sessionExpired) return;
    AppData.I.sessionExpired = false;
    snack(context, '登录已过期，请重新登录');
    showBlurDialog(context, const LoginForm());
  }

  Future<void> _initAchvWatch() async {
    final p = await SharedPreferences.getInstance();
    // 老数据首次升级：把已达成的静默入账（记录会推云端），别开屏放一串烟花
    if (!(p.getBool('achv_seeded') ?? false)) {
      AppData.I.unlockAchvs(
          achievements(AppData.I).where((a) => a.met).map((a) => a.slug));
      await p.setBool('achv_seeded', true);
    }
    _achvReady = true;
    AppData.I.addListener(_checkNewAchv);
  }

  void _checkNewAchv() {
    if (!_achvReady || _achvBusy || !mounted) return;
    final fresh = achievements(AppData.I)
        .where((a) => a.met && a.recordedAt == null)
        .toList();
    if (fresh.isEmpty) return;
    // 一次数据变更只弹第一枚，其余静默入账（比如登录整体拉取时别连环弹窗）
    _achvBusy = true;
    AppData.I.unlockAchvs(fresh.map((a) => a.slug));
    _achvBusy = false;
    final a = fresh.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _celebrateAchv(a);
    });
  }

  /// 点亮成就：烟花盖全屏 + 恭喜弹窗
  void _celebrateAchv(Achv a) {
    HapticFeedback.mediumImpact();
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _fx,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: FireworksPainter(_fx.value),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    _fx.forward(from: 0).whenComplete(entry.remove);
    showTrophyDialog(context, a, justUnlocked: true);
  }

  @override
  void dispose() {
    AppData.I.removeListener(_checkNewAchv);
    AppData.I.removeListener(_checkSessionExpired);
    _fx.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBg()),
          // 切换无动画（瞬间切，保留各页状态）；
          // TickerMode 让没在看的 tab 里的循环动画停表，别白烧帧
          //
          // 套一层 ListenableBuilder：PreviewShield 是不是要拦截点击，看的是
          // 登录状态；不听 AppData 的话，登录成功后这层拦截罩不会跟着撤下去，
          // 点心愿还是会再弹一次登录框
          ListenableBuilder(
            listenable: AppData.I,
            builder: (context, _) => IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  TickerMode(
                    enabled: i == _index,
                    // 「我的」页要留着让人点登录，其余两页未登录时只读
                    child: i == 2
                        ? _tabs[i]
                        : PreviewShield(
                            onBlocked: () =>
                                showBlurDialog(context, const LoginForm()),
                            child: _tabs[i],
                          ),
                  ),
              ],
            ),
          ),
          if (!_warmedUp && _index != 1)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: .01,
                  child: TickerMode(
                      enabled: false, child: const WishesTab()),
                ),
              ),
            ),
          // 同步出错横幅：云端拿不到 / 改动推不上去都明着说，
          // 绝不悄悄拿本地数据顶替——那样出了问题完全看不见
          ListenableBuilder(
            listenable: AppData.I,
            builder: (context, _) {
              final err = AppData.I.syncError;
              if (err == null) return const SizedBox.shrink();
              return Positioned(
                top: MediaQuery.paddingOf(context).top + 6,
                left: 13,
                right: 13,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE05A5A),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: T.shadowCard,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            err,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => AppData.I.retrySync(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 30),
                          ),
                          child: const Text('重试',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // ponytail: 实时背景模糊太贵（每帧重算），换成高不透明度纯色；想要毛玻璃再换回 BackdropFilter
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
              top: BorderSide(
                  color: Colors.white.withValues(alpha: .5), width: .5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                _item(0, Icons.calendar_today_outlined,
                    Icons.calendar_month_rounded, '任务'),
                _item(1, Icons.star_outline_rounded, Icons.star_rounded,
                    '人生清单'),
                _item(2, Icons.person_outline_rounded,
                    Icons.person_rounded, '我的'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData outline, IconData filled, String label) {
    final on = _index == i;
    Widget iconWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (c, a) =>
          ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
      child: on
          ? ShaderMask(
              key: const ValueKey('on'),
              shaderCallback: (r) => T.plusGrad.createShader(r),
              child: Icon(filled, size: 22, color: Colors.white),
            )
          : Icon(outline, key: const ValueKey('off'), size: 22, color: T.muted),
    );
    if (i == 1) {
      iconWidget = AnimatedRotation(
        turns: on ? 1 : 0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        child: iconWidget,
      );
    }
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _go(i),
        child: SizedBox(
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              padding:
                  EdgeInsets.symmetric(horizontal: on ? 15 : 11, vertical: 8),
              decoration: BoxDecoration(
                gradient: on
                    ? const LinearGradient(
                        colors: [Color(0xFFDDE4FF), Color(0xFFEBE2FF)])
                    : null,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    child: on
                        ? Row(
                            children: [
                              const SizedBox(width: 7),
                              Text(label,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: T.accent)),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 多彩柔光背景 —— 静态极光（不动，省一整条 60fps 的帧预算）
class AuroraBg extends StatelessWidget {
  const AuroraBg({super.key});

  // (left, top, size, color)
  static const _blobs = <(double, double, double, int)>[
    (-80, -60, 320, 0xFFB9C9FF),
    (180, 120, 300, 0xFFE6C9FF),
    (-60, 380, 320, 0xFFFFCFE6),
    (200, 560, 300, 0xFFC6F0E6),
    (-40, 760, 340, 0xFFCBD8FF),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFEDEFF8)),
        child: Stack(
          children: [
            for (final (left, top, size, color) in _blobs)
              Positioned(
                left: left,
                top: top,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Color(color).withValues(alpha: .7),
                      Color(color).withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
