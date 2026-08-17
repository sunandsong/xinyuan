import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../api/api.dart';
import '../data.dart';
import '../photos.dart';
import '../presets.dart';
import '../sheets.dart';
import '../theme.dart';
import '../ui.dart';
import 'login_page.dart';
import 'share_page.dart';

/// 心愿详情（进行中）
/// 「N 人也想做 · M 人已实现」：全网同名心愿的人数统计（不含自己）。
/// 没登录、接口失败或没别人设过，整行都不出现。
class CrowdStatsLine extends StatefulWidget {
  const CrowdStatsLine({super.key, required this.title});
  final String title;
  @override
  State<CrowdStatsLine> createState() => _CrowdStatsLineState();
}

class _CrowdStatsLineState extends State<CrowdStatsLine> {
  int _wanted = 0;
  int _done = 0;

  /// 跟排行榜同一套显隐条件
  bool get _visible => AppData.I.signedIn && AppData.I.showRank;

  @override
  void initState() {
    super.initState();
    // 跟心愿页右上角的排行榜入口同进同出：没登录 or 管理端关了都不显示，
    // 连请求都不发——藏起来还照发请求没意义（没登录时这个接口本来也是 401）
    if (!_visible) return;
    RankApi.wishStats(widget.title).then((r) {
      if (!mounted) return;
      setState(() {
        _wanted = (r['wanted'] as num?)?.toInt() ?? 0;
        _done = (r['done'] as num?)?.toInt() ?? 0;
      });
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _wanted == 0) return const SizedBox.shrink();
    final parts = [
      '$_wanted 人也想做',
      if (_done > 0) '$_done 人已实现',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14243A66),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            '🌏 ${parts.join(' · ')}',
            style: const TextStyle(
              fontSize: 12.5,
              color: T.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class WishDetailPage extends StatelessWidget {
  const WishDetailPage({super.key, required this.wish});
  final Wish wish;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: T.bg,
      body: ListenableBuilder(
        listenable: AppData.I,
        builder: (context, _) {
          final tasks = AppData.I.tasksOfWish(wish.id);
          return Stack(
            children: [
              // 头图要一直铺到屏幕最顶（含刘海/状态栏那一截），所以内容区不整体套
              // SafeArea，只在底部按钮那里单独避让
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomScrollView(
                          slivers: [
                            // 头部：图片填满整块，下拉超出时图片跟着变大（stretch）；
                            // 统计卡固定大小、压在图片底部、锚在头部底——下拉时它和
                            // 下面内容一起下移，只有图片放大，卡片始终盖住图片一点点。
                            SliverAppBar(
                              primary: false,
                              pinned: false,
                              stretch: true,
                              expandedHeight:
                                  topInset + _heroH + (_pillH - _pillOverlap),
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              automaticallyImplyLeading: false,
                              flexibleSpace: LayoutBuilder(
                                builder: (context, c) {
                                  // 头部当前高度：正常=expandedHeight，下拉时更大
                                  final h = c.maxHeight;
                                  final imgH = h - (_pillH - _pillOverlap);
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // 图片：占顶部，下拉时高度变大 = 放大
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        height: imgH,
                                        child: _hero(context),
                                      ),
                                      // 统计卡：锚在头部底，固定大小、压住图片底部一点
                                      Positioned(
                                        left: 13,
                                        right: 13,
                                        bottom: 0,
                                        child: _statCard(context, tasks),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            // 下面各版块，跟头部一起动
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(13, 11, 13, 0),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  CrowdStatsLine(title: wish.title),
                                  _targetTag(context),
                                  const SizedBox(height: 11),
                                  _steps(context),
                                  const SizedBox(height: 11),
                                  _tasksCard(context, tasks),
                                  const SizedBox(height: 11),
                                  _notes(context),
                                  const SizedBox(height: 11),
                                  _photos(context),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        child: BigBtn(
                          '完成这个心愿',
                          onTap: () {
                            if (!AppData.I.signedIn) {
                              showBlurDialog(context, const LoginForm());
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompleteWishPage(wish: wish),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 返回/更多悬浮在头图上，不随内容滚动
              Positioned(
                top: topInset + 8,
                left: 13,
                right: 13,
                child: Row(
                  children: [
                    PillBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    PillBtn(
                      icon: Icons.more_horiz_rounded,
                      onTap: () => _showMore(context),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- 头卡：色点 + 标题 + 标签 + 统计条 ----------
  // 头图高度 / 悬浮统计卡高度 / 二者的重叠量，三个数定死，方便手算布局。
  // 标题文字块要留在 overlap 区域之上，否则会被悬浮卡片盖住
  static const _heroH = 210.0;
  static const _pillH = 60.0;
  static const _pillOverlap = 18.0;
  static const _heroTextBottom = _pillOverlap + 16;

  /// 悬浮统计卡：现在放进内容列表，和下方版块一起动
  Widget _statCard(BuildContext context, List<Task> tasks) {
    final wantDays = dOnly(
      DateTime.now(),
    ).difference(dOnly(wish.createdAt)).inDays;
    final doneTasks = tasks.where((t) => t.done).toList();
    final pushedDays = doneTasks.map((t) => dOnly(t.day)).toSet().length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: T.shadowDock,
      ),
      child: Row(
        children: [
          _stat('$wantDays', '天前写下'),
          _statDivider(),
          _stat('$pushedDays', '天在推进'),
          _statDivider(),
          _stat('${doneTasks.length}/${tasks.length}', '任务完成'),
        ],
      ),
    );
  }

  /// 头图：有真实照片就显示照片——多张可以左右滑（默认最新一张）；
  /// 没有就用心愿自己的颜色画一块有质感的抽象场景，而不是一块死板的纯色矩形。
  /// 一直铺到屏幕最顶（含状态栏/刘海那一截）。
  Widget _hero(BuildContext context) {
    final photos = wish.photos;
    // 不绑点击编辑：滑照片容易误触，编辑走右上角"…"菜单
    return Stack(
      fit: StackFit.expand,
      children: [
        if (photos.length > 1)
          _PhotoCarousel(
            photos: photos,
            topInset: MediaQuery.paddingOf(context).top,
          )
        else if (photos.isNotEmpty)
          WishPhoto(photos.last, fit: BoxFit.cover, fallback: _heroArt(wish))
        else
          _heroArt(wish),
        // 底部渐暗遮罩，保证白字在任何图上都读得清楚。
        // IgnorePointer：遮罩和文字都不能挡手势，不然下面的照片划不动
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .45, 1],
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xB3000000),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 13,
          right: 13,
          bottom: _heroTextBottom,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wish.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  (wish.desc?.isNotEmpty ?? false)
                      ? wish.desc!
                      : '为什么想做这件事？写一句给以后的自己',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: .85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 没有真实照片时的兜底头图：五张预置场景图（日出/海浪/山峦/星空/极光），
  /// 按心愿 id 稳定分到其中一张——同一条心愿每次看到的都一样，不同心愿配不同的图
  static const _defaultHeroes = [
    'assets/img/hero/sunrise.jpg',
    'assets/img/hero/ocean.jpg',
    'assets/img/hero/mountains.jpg',
    'assets/img/hero/stars.jpg',
    'assets/img/hero/aurora.jpg',
  ];

  Widget _heroArt(Wish w) {
    final asset = _defaultHeroes[w.id.hashCode.abs() % _defaultHeroes.length];
    return Image.asset(asset, fit: BoxFit.cover);
  }

  Widget _stat(String v, String label) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: T.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 12, color: T.muted)),
      ],
    ),
  );

  Widget _statDivider() => Container(width: 1, height: 24, color: T.line);

  /// 目标日期：没设时是个"+ 设个期限"的胶囊，设了之后显示倒计时，点 x 清掉。
  /// 两个状态都给了白底+投影，跟页面里其它卡片同一套质感，不再是贴在
  /// 背景上的一块死板色块。
  Widget _targetTag(BuildContext context) {
    final target = wish.targetAt;
    if (target == null) {
      return GestureDetector(
        onTap: () => _pickTarget(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: wish.color.withValues(alpha: .3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14243A66),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 15, color: wish.color),
              const SizedBox(width: 3),
              Text(
                '设个期限',
                style: TextStyle(
                  fontSize: 13.5,
                  color: wish.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final left = dOnly(target).difference(dOnly(DateTime.now())).inDays;
    final label = left > 0
        ? '还有 $left 天'
        : left == 0
        ? '就是今天'
        : '已经过了 ${-left} 天';
    return GestureDetector(
      onTap: () => _pickTarget(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: wish.color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: wish.color.withValues(alpha: .22),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active_rounded, size: 14, color: wish.color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: wish.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => AppData.I.setWishTarget(wish, null),
              child: Icon(Icons.close_rounded, size: 15, color: wish.color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTarget(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: wish.targetAt ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked == null) return;
    AppData.I.setWishTarget(wish, picked);
  }

  // ---------- 里程碑 ----------
  Widget _steps(BuildContext context) {
    final steps = wish.steps;
    final template = steps.isEmpty
        ? stepTemplateFor(wish.title)
        : const <String>[];
    return SheetCard(
      solid: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '里程碑',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (steps.isNotEmpty)
                Text(
                  '${wish.doneStepCount} / ${steps.length}',
                  style: const TextStyle(fontSize: 14, color: T.muted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (steps.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '拆成几步，就不再是一件遥远的事',
                style: TextStyle(fontSize: 15, color: T.faint),
              ),
            ),
            if (template.isNotEmpty)
              TapRow(
                onTap: () {
                  AppData.I.addSteps(wish, template);
                  snack(context, '已拆成 ${template.length} 步，可以随便改');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 17,
                        color: wish.color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '一键拆成 ${template.length} 步',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: T.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          // 时间线：完成的节点之间用实色连线，形成一段一段点亮的效果
          for (final s in steps) _stepRow(context, s),
          _addStepNode(context, empty: steps.isEmpty),
        ],
      ),
    );
  }

  Widget _stepRow(BuildContext context, WishStep s) {
    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      // 划过 1/4 就算数，默认的 40% 手感太钝、老弹回去
      dismissThresholds: const {DismissDirection.endToStart: .25},
      onDismissed: (_) => AppData.I.deleteStep(wish, s),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 10),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: T.danger,
          size: 20,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Cb(
                  done: s.done,
                  burstColor: wish.color,
                  onTap: () => AppData.I.toggleStep(wish, s),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: s.done ? wish.color.withValues(alpha: .45) : T.field,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showTextSheet(
                    context,
                    title: '改一步',
                    hint: '这一步是…',
                    initial: s.title,
                    onOk: (t) => AppData.I.renameStep(wish, s, t),
                    onDelete: () => AppData.I.deleteStep(wish, s),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.title,
                          style: TextStyle(
                            fontSize: 15.5,
                            color: s.done ? T.faint : T.ink,
                            decoration: s.done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: T.faint,
                          ),
                        ),
                      ),
                      if (s.done && s.doneAt != null)
                        Text(
                          md(s.doneAt!),
                          style: const TextStyle(fontSize: 12, color: T.faint),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 时间线收尾的"加一步"节点，接着最后一个里程碑往下长
  Widget _addStepNode(BuildContext context, {required bool empty}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTextSheet(
        context,
        title: '加一步',
        hint: '下一步先做什么？',
        okLabel: '加进里程碑',
        onOk: (t) => AppData.I.addStep(wish, t),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: T.line, width: 1.5),
            ),
            child: const Icon(Icons.add_rounded, size: 12, color: T.faint),
          ),
          const SizedBox(width: 10),
          Text(
            empty ? '自己写一步' : '再加一步',
            style: const TextStyle(fontSize: 15, color: T.muted),
          ),
        ],
      ),
    );
  }

  // ---------- 过程笔记 ----------
  Widget _notes(BuildContext context) {
    final notes = wish.notes;
    return SheetCard(
      solid: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '这一路',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (notes.isNotEmpty)
                Text(
                  '${notes.length} 条',
                  style: const TextStyle(fontSize: 14, color: T.muted),
                ),
            ],
          ),
          if (notes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                '随手记一句，以后回头看就是这件事的来龙去脉',
                style: TextStyle(fontSize: 15, color: T.faint),
              ),
            )
          else
            const SizedBox(height: 6),
          // 时间线：小圆点顺着一条竖线往下，最后接一个"记一笔"的入口
          for (final n in notes) _noteRow(context, n),
          _addNoteNode(context),
        ],
      ),
    );
  }

  Widget _addNoteNode(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTextSheet(
        context,
        title: '记一笔',
        hint: '今天为它做了什么 / 想到了什么…',
        okLabel: '记下来',
        maxLines: 4,
        onOk: (t) => AppData.I.addNote(wish, t),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Icon(Icons.edit_note_rounded, size: 19, color: wish.color),
          ),
          const SizedBox(width: 10),
          const Text(
            '记一笔',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: T.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteRow(BuildContext context, WishNote n) {
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: .25},
      onDismissed: (_) => AppData.I.deleteNote(wish, n),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 10),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: T.danger,
          size: 20,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: wish.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: wish.color.withValues(alpha: .35),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: T.field,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 16),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showTextSheet(
                    context,
                    title: '改一笔',
                    hint: '…',
                    initial: n.text,
                    maxLines: 4,
                    onOk: (t) {
                      n.text = t;
                      AppData.I.updateWish(wish);
                    },
                    onDelete: () => AppData.I.deleteNote(wish, n),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.text,
                        style: const TextStyle(fontSize: 15.5, height: 1.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ymdDots(n.at),
                        style: const TextStyle(fontSize: 12, color: T.faint),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 关联任务 ----------
  Widget _tasksCard(BuildContext context, List<Task> tasks) {
    final active = tasks.where((t) => !t.done).toList();
    final done = tasks.where((t) => t.done).toList();
    return SheetCard(
      solid: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '为它做点什么',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (tasks.isNotEmpty)
                Text(
                  '${done.length} / ${tasks.length}',
                  style: const TextStyle(fontSize: 14, color: T.muted),
                ),
            ],
          ),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '把它拆成一件件小事，日历里就会出现它的颜色',
                style: TextStyle(fontSize: 15, color: T.faint),
              ),
            )
          else ...[
            const SizedBox(height: 4),
            for (final t in active) _taskRow(context, t),
            for (final t in done) _taskRow(context, t),
          ],
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showNewTaskSheet(context, DateTime.now(), wish: wish),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 18, color: wish.color),
                  const SizedBox(width: 7),
                  const Text(
                    '加一个任务',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: T.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskRow(BuildContext context, Task t) {
    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: .25},
      onDismissed: (_) => AppData.I.deleteTask(t),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 10),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: T.danger,
          size: 20,
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showEditTaskPage(context, t),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Cb(
                done: t.done,
                burstColor: wish.color,
                onTap: () => AppData.I.toggleTask(t),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: t.done ? T.faint : T.ink,
                    decoration: t.done ? TextDecoration.lineThrough : null,
                    decorationColor: T.faint,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                md(t.day),
                style: const TextStyle(fontSize: 13, color: T.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 照片（真实图片，存云存储）----------
  Widget _photos(BuildContext context) {
    final photos = wish.photos;
    final uploading = AppData.I.photoUploadingWishId == wish.id;
    return SheetCard(
      solid: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '照片',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _addPhoto(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '加照片',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: T.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (photos.isEmpty && !uploading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '路上的照片可以先存这儿，完成时再挑一张当凭证',
                style: TextStyle(fontSize: 15, color: T.faint),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length + (uploading ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (context, i) => i < photos.length
                    ? _photoTile(context, photos[i])
                    : _uploadingTile(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 上传中的占位格：立刻出现，传完被真图顶掉
  Widget _uploadingTile() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: T.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: T.accent),
        ),
      ),
    );
  }

  Widget _photoTile(BuildContext context, String url) {
    return GestureDetector(
      onLongPress: () => _confirmDeletePhoto(context, url),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: WishPhoto(
              url,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              // 链接过期或断网时不要炸成红屏，给一块灰底
              fallback: Container(
                width: 96,
                height: 96,
                color: T.field,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 20,
                  color: T.faint,
                ),
              ),
              loading: Container(width: 96, height: 96, color: T.field),
            ),
          ),
          // 长按也能删，但那太隐蔽了，另外放一个看得见的删除角标
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _confirmDeletePhoto(context, url),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePhoto(BuildContext context, String url) {
    return showConfirmDialog(
      context,
      emoji: '📷',
      title: '移除这张照片？',
      body: '照片会从这个心愿里拿掉',
      confirmText: '移除',
      onConfirm: () => AppData.I.removeWishPhoto(wish, url),
    );
  }

  Future<void> _addPhoto(BuildContext context) async {
    showAppSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _moreRow(Icons.photo_library_outlined, '从相册选', () {
            Navigator.pop(context);
            pickAndUploadWishPhoto(context, wish);
          }),
          _moreRow(Icons.photo_camera_outlined, '拍一张', () {
            Navigator.pop(context);
            pickAndUploadWishPhoto(context, wish, fromCamera: true);
          }),
        ],
      ),
    );
  }

  // ---------- 更多：编辑 / 分享 / 删除 ----------
  void _showMore(BuildContext context) {
    showAppSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _moreRow(Icons.edit_rounded, '修改心愿', () {
            Navigator.pop(context);
            showEditWishSheet(context, wish);
          }),
          _moreRow(Icons.auto_awesome_rounded, '做成宣告卡', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SharePage(wish: wish)),
            );
          }),
          _moreRow(Icons.delete_outline_rounded, '删除心愿', () {
            Navigator.pop(context);
            // 删完这条心愿就不存在了，详情页一起退掉
            confirmDeleteWish(
              context,
              wish,
              after: () => Navigator.pop(context),
            );
          }, danger: true),
        ],
      ),
    );
  }

  Widget _moreRow(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? T.danger : T.ink;
    return TapRow(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 16.5, color: color)),
          ],
        ),
      ),
    );
  }
}

/// 头图的照片轮播：第一页是最新一张，往左滑翻更早的照片。
/// 用 StatefulWidget 单独拎出来，是为了让滑到第几张能在页面其它地方触发的
/// 刷新（勾一个里程碑之类）之间保持住，不会每次 rebuild 就跳回第一张
class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photos, required this.topInset});
  final List<String> photos;
  final double topInset;
  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _page = 0;
  final PageController _controller = PageController();

  // photos 里旧的在前；展示时反过来，第 0 页 = 最新
  String _photoAt(int i) => widget.photos[widget.photos.length - 1 - i];

  @override
  void didUpdateWidget(_PhotoCarousel old) {
    super.didUpdateWidget(old);
    if (widget.photos.length != old.photos.length) {
      // 加了/删了照片就跳回第一页（最新那张）
      _page = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => WishPhoto(
            _photoAt(i),
            fit: BoxFit.cover,
            fallback: Container(
              color: T.field,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_outlined,
                size: 28,
                color: T.faint,
              ),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            right: 13,
            top: widget.topInset + 60,
            child: Row(
              children: [
                for (var i = 0; i < widget.photos.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(left: 4),
                    width: i == _page ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: i == _page ? .95 : .5,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 完成打卡：照片 + 一句话
class CompleteWishPage extends StatefulWidget {
  const CompleteWishPage({super.key, required this.wish});
  final Wish wish;
  @override
  State<CompleteWishPage> createState() => _CompleteWishPageState();
}

class _CompleteWishPageState extends State<CompleteWishPage> {
  // 没传照片时凭证卡的兜底渐变下标（换底色功能已撤，固定第一组）
  final int _hero = 0;
  int _coverPage = 0; // 照片封面选择：0 = 最新一张
  final _quote = TextEditingController();
  final _loc = TextEditingController();
  bool _locating = false;
  // 进页面时已有的照片数：封面只认之后新拍/新传的，过程里的旧照片不掺和
  late final int _photosBefore = widget.wish.photos.length;

  @override
  void initState() {
    super.initState();
    // 进页面就自动定位填好；定不到也不吵，手填/点圆片随时覆盖
    _useGps(silent: true);
  }

  /// 用手机定位填"在哪儿完成的"：GPS 坐标 → 系统反地理编码拿城市名（免费无 Key）
  Future<void> _useGps({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!silent && mounted) snack(context, '没有定位权限，去设置里打开一下');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 10));
      final marks = await Geocoding(
        locale: const Locale('zh', 'CN'),
      ).placemarkFromCoordinates(pos.latitude, pos.longitude);
      final m = marks.isEmpty ? null : marks.first;
      // 城市名优先，取不到就逐级退：区县 → 省 → 国家
      final name = [
        m?.locality,
        m?.subAdministrativeArea,
        m?.administrativeArea,
        m?.country,
      ].firstWhere((s) => s?.isNotEmpty ?? false, orElse: () => null);
      if (name == null) {
        if (!silent && mounted) snack(context, '定位到了，但认不出这是哪儿');
        return;
      }
      // 自动定位不覆盖用户已经手填/选好的内容
      if (mounted && (!silent || _loc.text.isEmpty)) {
        setState(() => _loc.text = name);
      }
    } catch (e) {
      debugPrint('[gps] $e');
      if (!silent && mounted) snack(context, '定位失败，手动填一个也行');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<String> get _newPhotos {
    final photos = widget.wish.photos;
    return photos.length > _photosBefore
        ? photos.sublist(_photosBefore)
        : const [];
  }

  /// 封面：此刻新传的照片左右滑挑一张；还没传就是一块"上传照片"的引导区
  Widget _cover() {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final photos = _newPhotos;
        final uploading = AppData.I.photoUploadingWishId == widget.wish.id;
        if (photos.isEmpty) {
          return GestureDetector(
            onTap: uploading ? null : _addPhoto,
            child: Container(
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: T.field,
                border: Border.all(color: T.faint.withValues(alpha: .35)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    uploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: T.accent,
                            ),
                          )
                        : Icon(
                            Icons.add_a_photo_outlined,
                            size: 26,
                            color: widget.wish.color,
                          ),
                    const SizedBox(height: 8),
                    Text(
                      uploading ? '正在上传…' : '拍一张此刻的照片，作为完成的凭证',
                      style: const TextStyle(fontSize: 14.5, color: T.muted),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 170,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _coverPage = i),
                      itemBuilder: (_, i) => WishPhoto(
                        photos[photos.length - 1 - i],
                        fit: BoxFit.cover,
                        fallback: Container(color: T.field),
                      ),
                    ),
                    Positioned(
                      right: 9,
                      bottom: 9,
                      child: IgnorePointer(
                        child: _coverChip(
                          uploading
                              ? '上传中…'
                              : photos.length > 1
                              ? '左右滑，这张当封面 ${_coverPage + 1}/${photos.length}'
                              : '这张当封面',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: uploading ? null : _addPhoto,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 16,
                    color: widget.wish.color,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '再加一张',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: T.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _coverChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 14, color: Colors.white),
    ),
  );

  void _addPhoto() {
    showAppSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TapRow(
            onTap: () {
              Navigator.pop(context);
              pickAndUploadWishPhoto(context, widget.wish);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.photo_library_outlined, size: 19),
                  SizedBox(width: 12),
                  Text('从相册选', style: TextStyle(fontSize: 16.5)),
                ],
              ),
            ),
          ),
          TapRow(
            onTap: () {
              Navigator.pop(context);
              pickAndUploadWishPhoto(context, widget.wish, fromCamera: true);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.photo_camera_outlined, size: 19),
                  SizedBox(width: 12),
                  Text('拍一张', style: TextStyle(fontSize: 16.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
          child: Column(
            children: [
              Row(
                children: [
                  PillBtn(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '完成了？',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SheetCard(
                      solid: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _cover(),
                          const SizedBox(height: 11),
                          TextField(
                            controller: _quote,
                            decoration: fieldDeco('这一刻想说的话…'),
                            style: const TextStyle(fontSize: 16.5),
                            maxLines: 2,
                            minLines: 1,
                          ),
                          const SizedBox(height: 9),
                          // 完成地点 = 当前位置，不可手选；点一下可重新定位
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _locating ? null : _useGps,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: T.field,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  _locating
                                      ? const SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: T.accent,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.my_location_rounded,
                                          size: 16,
                                          color: T.accent,
                                        ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      _locating
                                          ? '正在定位…'
                                          : _loc.text.isEmpty
                                          ? '未能定位（不影响完成，点我重试）'
                                          : _loc.text,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _loc.text.isEmpty
                                            ? T.faint
                                            : T.ink,
                                      ),
                                    ),
                                  ),
                                  if (_loc.text.isNotEmpty)
                                    const Text(
                                      '会点亮地图',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: T.faint,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              BigBtn('完成这个心愿', onTap: _submit),
              const SizedBox(height: 8),
              const Text(
                '照片和这句话会永远留在清单里',
                style: TextStyle(fontSize: 15.5, color: T.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    // 滑到哪张就把哪张设成封面（photos.last 即封面）；只在此刻新传的里挑
    final fresh = _newPhotos;
    if (fresh.isNotEmpty && _coverPage != 0) {
      AppData.I.setCoverPhoto(
        widget.wish,
        fresh[fresh.length - 1 - _coverPage],
      );
    }
    AppData.I.completeWish(
      widget.wish,
      quote: _quote.text.trim(),
      location: _loc.text.trim(),
      heroIndex: _hero,
    );
    // 把完成页和已经过时的"进行中详情页"一起关掉再弹点亮卡，
    // 关掉卡片直接回列表——不然退回旧详情页还挂着"完成这个心愿"，像没完成一样
    Navigator.of(context)
      ..pop()
      ..pop()
      ..push(
        MaterialPageRoute(
          builder: (_) => SharePage(wish: widget.wish, celebrate: true),
        ),
      );
  }
}

/// 已实现的心愿列表（点首页顶部统计进来）
class DoneListPage extends StatelessWidget {
  const DoneListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 0),
          child: Column(
            children: [
              Row(
                children: [
                  PillBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '已实现的心愿',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListenableBuilder(
                  listenable: AppData.I,
                  builder: (context, _) {
                    final done = AppData.I.doneWishes
                      ..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));
                    if (done.isEmpty) {
                      return const Center(
                        child: Text(
                          '还没有点亮的心愿\n完成第一个，它就会出现在这里',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.8,
                            color: T.faint,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: done.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _doneCard(context, done[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _doneCard(BuildContext context, Wish w) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DoneWishPage(wish: w)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: T.shadowCard,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 40,
                height: 40,
                child: w.photos.isNotEmpty
                    ? WishPhoto(
                        w.photos.last,
                        fit: BoxFit.cover,
                        fallback: _heroThumb(w),
                      )
                    : _heroThumb(w),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      ymdDots(w.doneAt!),
                      if (w.location != null) w.location!,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 13, color: T.faint),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: T.faint),
          ],
        ),
      ),
    );
  }

  /// 没有照片时的缩略图：心愿本色打底 + 勋章图标
  Widget _heroThumb(Wish w) => ColoredBox(
    color: w.color.withValues(alpha: .16),
    child: Center(
      child: Icon(Icons.emoji_events_rounded, size: 20, color: w.color),
    ),
  );
}

/// 已完成详情（凭证）：全幅头图压标题 + 引言卡 + 数据条 + 时间线 + 过程笔记
class DoneWishPage extends StatelessWidget {
  const DoneWishPage({super.key, required this.wish});
  final Wish wish;

  Future<void> _confirmUncomplete(BuildContext context) {
    return showConfirmDialog(
      context,
      emoji: '↩️',
      title: '变回进行中？',
      body: '完成时间和地点会清除\n（世界地图上的点会熄灭），当时写的话保留',
      confirmText: '变回进行中',
      onConfirm: () {
        AppData.I.uncompleteWish(wish);
        // 这页是"已完成凭证"，心愿都不再是完成态了，退出去
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final tasks = AppData.I.tasksOfWish(wish.id);
    final days = wish.doneAt!.difference(wish.createdAt).inDays;
    final no = AppData.I.doneNumberOf(wish);
    return Scaffold(
      backgroundColor: T.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _hero(context, top, no)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(13, 14, 13, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (wish.quote?.isNotEmpty ?? false) ...[
                      _quoteCard(),
                      const SizedBox(height: 11),
                    ],
                    _statsRow(days, tasks.length),
                    const SizedBox(height: 11),
                    _timelineCard(tasks, days),
                    if (wish.notes.isNotEmpty) ...[
                      const SizedBox(height: 11),
                      _notesCard(),
                    ],
                  ]),
                ),
              ),
            ],
          ),
          // 顶栏浮在头图上
          Positioned(
            top: top + 8,
            left: 13,
            right: 13,
            child: Row(
              children: [
                DarkPill(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                DarkPill(
                  icon: Icons.replay_rounded,
                  onTap: () => _confirmUncomplete(context),
                ),
                const SizedBox(width: 8),
                DarkPill(
                  icon: Icons.ios_share_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SharePage(wish: wish)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 头图：照片轮播/默认封面 + 压暗 + 序号标题地点 ----------
  Widget _hero(BuildContext context, double top, int no) {
    return SizedBox(
      height: 340,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (wish.photos.isNotEmpty)
            _PhotoCarousel(photos: wish.photos, topInset: top)
          else
            Image.asset('assets/img/hero/default_cover.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .35, 1],
                colors: [
                  Color(0x59000000),
                  Color(0x1A000000),
                  Color(0xD9000000),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: T.gold.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '第 $no 个实现',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                      color: Color(0xFF3A2C10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  wish.title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x66000000), blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (wish.location?.isNotEmpty ?? false) ...[
                      const Icon(Icons.place_rounded,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          wish.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    const Icon(Icons.event_available_rounded,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 3),
                    Text(
                      ymdDots(wish.doneAt!),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.white70,
                        fontFeatures: [FontFeature.tabularFigures()],
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

  // ---------- 当时写下的那句话 ----------
  Widget _quoteCard() {
    return SheetCard(
      solid: true,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u201C',
            style: TextStyle(
              fontSize: 46,
              height: 1,
              fontWeight: FontWeight.w700,
              color: T.accent.withValues(alpha: .25),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 2),
            child: Text(
              wish.quote!,
              style: const TextStyle(
                fontSize: 16.5,
                height: 1.85,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 三格数据条 ----------
  Widget _statsRow(int days, int taskCount) {
    final stepDone = wish.doneStepCount;
    return Row(
      children: [
        _stat('$days', '天走完'),
        const SizedBox(width: 10),
        _stat('$taskCount', '个任务'),
        const SizedBox(width: 10),
        _stat(
          wish.steps.isEmpty ? '${wish.photos.length}' : '$stepDone',
          wish.steps.isEmpty ? '张照片' : '个里程碑',
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: T.shadowCard,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1,
                color: T.accent,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 12.5, color: T.muted)),
          ],
        ),
      ),
    );
  }

  // ---------- 时间线：写下 → 第一个任务 → 里程碑 → 实现 ----------
  Widget _timelineCard(List<Task> tasks, int days) {
    final rows = <(DateTime, String)>[
      (wish.createdAt, '写下这个心愿'),
      if (tasks.isNotEmpty) (tasks.last.day, '迈出第一步'),
      for (final s in wish.steps)
        if (s.done && s.doneAt != null) (s.doneAt!, s.title),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return SheetCard(
      solid: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '这条心愿的一生',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          for (final (at, text) in rows) _node(ymdDots(at), text),
          _node(ymdDots(wish.doneAt!), '实现了 · 一共走了 $days 天',
              last: true, gold: true),
        ],
      ),
    );
  }

  Widget _node(String date, String text,
      {bool last = false, bool gold = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold ? T.gold : T.accent.withValues(alpha: .45),
                  boxShadow: gold
                      ? [
                          BoxShadow(
                              color: T.gold.withValues(alpha: .5),
                              blurRadius: 8),
                        ]
                      : null,
                ),
              ),
              if (!last)
                Expanded(child: Container(width: 1.5, color: T.field)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.2,
                      fontWeight: gold ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: T.faint,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 过程笔记 ----------
  Widget _notesCard() {
    return SheetCard(
      solid: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '一路上的 ${wish.notes.length} 条记录',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          for (final n in wish.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.text,
                      style: const TextStyle(fontSize: 15, height: 1.6)),
                  const SizedBox(height: 2),
                  Text(
                    ymdDots(n.at),
                    style: const TextStyle(
                      fontSize: 12,
                      color: T.faint,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
