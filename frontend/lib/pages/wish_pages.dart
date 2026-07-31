import 'package:flutter/material.dart';
import '../data.dart';
import '../notify.dart';
import '../photos.dart';
import '../presets.dart';
import '../sheets.dart';
import '../theme.dart';
import '../ui.dart';
import 'login_page.dart';
import 'share_page.dart';

/// 心愿详情（进行中）
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
                                  final imgH =
                                      h - (_pillH - _pillOverlap);
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

  /// 头图：有真实照片就用最新一张（"现在进行时"，用当下的样子）；
  /// 没有就用心愿自己的颜色画一块有质感的抽象场景，而不是一块死板的纯色矩形。
  /// 一直铺到屏幕最顶（含状态栏/刘海那一截）。
  Widget _hero(BuildContext context) {
    final photo = wish.photos.isNotEmpty ? wish.photos.last : null;
    return GestureDetector(
      onTap: () => showEditWishSheet(context, wish),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _heroArt(wish),
            )
          else
            _heroArt(wish),
          // 底部渐暗遮罩，保证白字在任何图上都读得清楚
          const DecoratedBox(
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
          Positioned(
            left: 13,
            right: 13,
            bottom: _heroTextBottom,
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
        ],
      ),
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

  // ---------- 里程碑 ----------
  Widget _steps(BuildContext context) {
    final steps = wish.steps;
    final template = steps.isEmpty
        ? stepTemplateFor(wish.title)
        : const <String>[];
    return SheetCard(
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
    return IntrinsicHeight(
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
    return IntrinsicHeight(
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
    );
  }

  // ---------- 关联任务 ----------
  Widget _tasksCard(BuildContext context, List<Task> tasks) {
    final active = tasks.where((t) => !t.done).toList();
    final done = tasks.where((t) => t.done).toList();
    return SheetCard(
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
    return GestureDetector(
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
    );
  }

  // ---------- 照片（真实图片，存云存储）----------
  Widget _photos(BuildContext context) {
    final photos = wish.photos;
    return SheetCard(
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
          if (photos.isEmpty)
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
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (context, i) => _photoTile(context, photos[i]),
              ),
            ),
          ],
        ],
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
            child: Image.network(
              url,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              // 链接过期或断网时不要炸成红屏，给一块灰底
              errorBuilder: (_, __, ___) => Container(
                width: 96,
                height: 96,
                color: T.field,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 20,
                  color: T.faint,
                ),
              ),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(width: 96, height: 96, color: T.field),
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
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除照片'),
        content: const Text('把这张照片从心愿里移除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppData.I.removeWishPhoto(wish, url);
            },
            style: TextButton.styleFrom(foregroundColor: T.danger),
            child: const Text('删除'),
          ),
        ],
      ),
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

/// 头图的照片轮播：左右滑动看这条心愿存的每一张照片，默认停在最新一张。
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
  late int _page = widget.photos.length - 1;
  late final PageController _controller = PageController(initialPage: _page);

  @override
  void didUpdateWidget(_PhotoCarousel old) {
    super.didUpdateWidget(old);
    if (widget.photos.length != old.photos.length) {
      final next = (widget.photos.length - 1).clamp(
        0,
        widget.photos.length - 1,
      );
      _page = next;
      if (_controller.hasClients) _controller.jumpToPage(next);
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
          itemBuilder: (context, i) => Image.network(
            widget.photos[i],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
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
  int _hero = 0;
  final _quote = TextEditingController();
  final _loc = TextEditingController();

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            onTap: () => setState(
                              () => _hero = (_hero + 1) % AppData.heroes.length,
                            ),
                            child: Container(
                              height: 170,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: AppData.heroes[_hero],
                                ),
                              ),
                              alignment: Alignment.bottomRight,
                              padding: const EdgeInsets.all(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .35),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '点击换一张（演示）',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 11),
                          TextField(
                            controller: _quote,
                            decoration: fieldDeco('这一刻想说的话…'),
                            style: const TextStyle(fontSize: 16.5),
                            maxLines: 2,
                            minLines: 1,
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: _loc,
                            decoration: fieldDeco('在哪儿完成的（可选，会点亮地图）'),
                            style: const TextStyle(fontSize: 16.5),
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
    AppData.I.completeWish(
      widget.wish,
      quote: _quote.text.trim(),
      location: _loc.text.trim(),
      heroIndex: _hero,
    );
    // 已经完成了就别再到期提醒
    cancelWishReminder(widget.wish);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SharePage(wish: widget.wish)),
    );
  }
}

/// 已完成详情（凭证）
class DoneWishPage extends StatelessWidget {
  const DoneWishPage({super.key, required this.wish});
  final Wish wish;

  @override
  Widget build(BuildContext context) {
    final tasks = AppData.I.tasksOfWish(wish.id);
    final firstTask = tasks.isEmpty ? null : tasks.last.day;
    final days = wish.doneAt!.difference(wish.createdAt).inDays;
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
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  PillBtn(
                    icon: Icons.ios_share_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SharePage(wish: wish)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SheetCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 170,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: wish.hero ?? AppData.heroes[0],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  wish.title,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: T.accentSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '已完成',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: T.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '「${wish.quote}」',
                            style: const TextStyle(fontSize: 16.5, height: 1.8),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (wish.location != null) wish.location!,
                              ymdDots(wish.doneAt!),
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 15.5,
                              color: T.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 11),
                    SheetCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '这条心愿的一生',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _step(ymDots(wish.createdAt), '写下心愿'),
                          if (firstTask != null)
                            _step(ymDots(firstTask), '第一个任务'),
                          _step(
                            ymDots(wish.doneAt!),
                            '完成 · 共 $days 天${tasks.isNotEmpty ? ' · ${tasks.length} 个任务' : ''}',
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(String date, String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 15.5,
                color: T.accent,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
